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

# Env-overridable so the merge logic can be exercised against a scratch file.
WSL_CONF="${WSL_CONF:-/etc/wsl.conf}"
WSL_CONF_TEMPLATE="${DOTFILES_DIRECTORY}/scripts/wsl.conf.template"
WSL_CONF_USER="$(id -un)"
WSL_CONF_CHANGED=false

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
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ ("^" key "[[:space:]]*=")) { found = 1; exit }
    }
    END { exit found ? 0 : 1 }
  ' "$WSL_CONF"
}

# Add `key=value` under [section], only when the key is missing (see policy
# above). Writing /etc requires sudo, so the merged content is rebuilt with
# awk and written back via `sudo tee`.
wslconf_add_missing() {
  local section="$1" key="$2" value="$3"
  if wslconf_has_key "$section" "$key"; then
    echo_info "wsl.conf: [${section}] ${key} already set - skipping."
    return 0
  fi
  WSL_CONF_CHANGED=true
  if [ "$DRY_RUN" = true ]; then
    echo_dry "sudo tee ${WSL_CONF} (add '${key}=${value}' under [${section}])"
    return 0
  fi
  local existing="/dev/null"
  [ -f "$WSL_CONF" ] && existing="$WSL_CONF"
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
  ' "$existing" | sudo tee "$WSL_CONF" > /dev/null
  sudo chmod 644 "$WSL_CONF"
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
      wslconf_value="${wslconf_value//__USERNAME__/${WSL_CONF_USER}}"
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
