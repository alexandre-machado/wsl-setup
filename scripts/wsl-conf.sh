#!/bin/bash
#
# Provision /etc/wsl.conf (systemd enablement + default user) from
# scripts/wsl.conf.template.
#
# Replacement policy (deliberate): MERGE / ADD-MISSING-ONLY.
#   - Keys and sections already present in /etc/wsl.conf are NEVER modified
#     or removed, whatever their value. This preserves user-added settings
#     and coordinates with cloud-init, which writes `[user] default=<name>`
#     on brand-new instances (scripts/cloud-init.user-data.template) — this
#     module must not fight it.
#   - Only template keys missing from /etc/wsl.conf are added (their section
#     is created when absent).
#
# Changes take effect only after `wsl --shutdown` on the Windows side; this
# script only tells the user — it never forces a restart mid-setup.

source ./scripts/utils.sh

echo_info "Provisioning /etc/wsl.conf (systemd, default user)..."

# Target override is a TEST-ONLY hook: honored solely when WSL_CONF_TEST=1,
# so a stray WSL_CONF env var can never retarget the sudo root-write.
if [ "${WSL_CONF_TEST:-0}" = "1" ] && [ -n "${WSL_CONF:-}" ]; then
  echo_warning "wsl.conf: WSL_CONF_TEST=1 - targeting ${WSL_CONF} instead of /etc/wsl.conf."
else
  WSL_CONF="/etc/wsl.conf"
fi
WSL_CONF_TEMPLATE="${DOTFILES_DIRECTORY}/scripts/wsl.conf.template"
WSL_CONF_CHANGED=false

# Validate the invoking username before substituting it into a root-owned
# config; on mismatch, keys needing __USERNAME__ are warned about and skipped.
WSL_CONF_USER="$(id -un)"
WSL_CONF_USER_VALID=true
if ! printf '%s' "$WSL_CONF_USER" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}$'; then
  WSL_CONF_USER_VALID=false
  echo_warning "wsl.conf: username '${WSL_CONF_USER}' fails validation (^[a-z_][a-z0-9_-]{0,31}\$) - __USERNAME__ keys will be skipped."
fi

# True when [section] already contains an (uncommented) `key=` entry.
wslconf_has_key() {
  local section="$1" key="$2"
  [ -f "$WSL_CONF" ] || return 1
  awk -v section="$section" -v key="$key" '
    /^[[:space:]]*\[/ {
      s = $0
      gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", s)
      in_section = (s == section)
      next
    }
    in_section {
      # Literal key comparison (index/substr, no regex) so template keys
      # containing regex metacharacters can never break matching.
      line = $0
      sub(/^[[:space:]]+/, "", line)
      eq = index(line, "=")
      if (eq > 0) {
        k = substr(line, 1, eq - 1)
        sub(/[[:space:]]+$/, "", k)
        if (k == key) { found = 1; exit }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$WSL_CONF"
}

# Add `key=value` under [section], only when the key is missing (see policy
# above). The merged result is fully rendered to a temp file FIRST, then
# atomically installed with `sudo install` — never `awk file | sudo tee
# same-file`, which truncates the file awk is still reading and can wipe
# pre-existing content (including cloud-init's [user] block).
wslconf_add_missing() {
  local section="$1" key="$2" value="$3"
  if wslconf_has_key "$section" "$key"; then
    echo_info "wsl.conf: [${section}] ${key} already set - skipping."
    return 0
  fi
  WSL_CONF_CHANGED=true
  if [ "$DRY_RUN" = true ]; then
    echo_dry "sudo install -m 644 <merged temp> ${WSL_CONF} (add '${key}=${value}' under [${section}])"
    return 0
  fi
  local existing="/dev/null" tmp
  [ -f "$WSL_CONF" ] && existing="$WSL_CONF"
  tmp="$(mktemp)" || {
    echo_warning "wsl.conf: mktemp failed - skipping [${section}] ${key}."
    return 1
  }
  # Render the merge completely before any sudo touch of the target.
  awk -v section="$section" -v key="$key" -v value="$value" '
    {
      print
      if (!placed && $0 ~ /^[[:space:]]*\[/) {
        s = $0
        gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", s)
        if (s == section) { print key "=" value; placed = 1 }
      }
    }
    END {
      if (!placed) {
        if (NR > 0) print ""
        print "[" section "]"
        print key "=" value
      }
    }
  ' "$existing" > "$tmp" || {
    echo_warning "wsl.conf: merge render failed - leaving ${WSL_CONF} untouched."
    rm -f "$tmp"
    return 1
  }
  sudo install -m 644 "$tmp" "$WSL_CONF"
  rm -f "$tmp"
  echo_success "wsl.conf: added [${section}] ${key}=${value}."
}

# Walk the template: track [section] headers, apply each key=value with the
# add-missing policy. Comment/blank lines are skipped; __USERNAME__ is
# rendered to the invoking user.
wslconf_section=""
while IFS= read -r wslconf_line || [ -n "$wslconf_line" ]; do
  case "$wslconf_line" in
    \#* | "")
      continue
      ;;
    \[*\])
      wslconf_section="${wslconf_line#[}"
      wslconf_section="${wslconf_section%]}"
      ;;
    *=*)
      wslconf_key="${wslconf_line%%=*}"
      wslconf_value="${wslconf_line#*=}"
      case "$wslconf_value" in
        *__USERNAME__*)
          if [ "$WSL_CONF_USER_VALID" = true ]; then
            wslconf_value="${wslconf_value//__USERNAME__/${WSL_CONF_USER}}"
          else
            echo_warning "wsl.conf: skipping [${wslconf_section}] ${wslconf_key} (invalid username)."
            continue
          fi
          ;;
      esac
      wslconf_add_missing "$wslconf_section" "$wslconf_key" "$wslconf_value"
      ;;
  esac
done < "$WSL_CONF_TEMPLATE"

if [ "$WSL_CONF_CHANGED" = true ]; then
  if [ "$DRY_RUN" = true ]; then
    echo_dry "would update ${WSL_CONF}; a 'wsl --shutdown' from Windows would then be required"
  else
    echo_warning "wsl.conf updated. Run 'wsl --shutdown' from Windows and reopen the terminal for it to take effect. (Not forced here — save your work first.)"
  fi
else
  echo_info "/etc/wsl.conf already up to date - nothing to do."
fi
