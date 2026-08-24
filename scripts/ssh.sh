#!/bin/bash
#
# Configure SSH & Persistent Git credentials
# Rerun-safe: imports persistent keys if available, guards ssh-keygen and config appends.

source ./scripts/utils.sh

SSH_KEY="${HOME}/.ssh/id_ed25519"
SSH_PUB="${HOME}/.ssh/id_ed25519.pub"
SSH_CONFIG="${HOME}/.ssh/config"

echo_info "Configuring git to use SSH and Git Credential Manager..."
run git config --global url.ssh://git@github.com/.insteadOf https://github.com/

# Configure Windows Git Credential Manager for HTTPS if available
GCM_EXE="/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe"
if [ -f "$GCM_EXE" ]; then
  echo_info "Configuring Git Credential Manager (${GCM_EXE})..."
  run git config --global credential.helper "$GCM_EXE"
  run git config --global credential.https://dev.azure.com.useHttpPath true
fi

# Ensure ~/.ssh exists with secure permissions
if [ "$DRY_RUN" != true ]; then
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
fi

# Search for persistent master SSH keys in OneDrive / Windows Host
found_persistent_key=""
candidates=()

# 1. Check OneDrive WorkSpace path via cmd.exe
if command -v cmd.exe &>/dev/null; then
  win_onedrive=$(cmd.exe /c "echo %OneDrive%" 2>/dev/null | tr -d '\r')
  if [ -n "$win_onedrive" ] && [ "$win_onedrive" != "%OneDrive%" ]; then
    wsl_od=$(wslpath -u "$win_onedrive" 2>/dev/null || true)
    if [ -n "$wsl_od" ]; then
      candidates+=("${wsl_od}/Projetos/WorkSpace/ssh/id_ed25519")
      candidates+=("${wsl_od}/WSL/ssh/id_ed25519")
      candidates+=("${wsl_od}/ssh/id_ed25519")
    fi
  fi
  win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
  if [ -n "$win_user" ]; then
    candidates+=("/mnt/c/Users/${win_user}/.ssh/id_ed25519")
  fi
fi

# Additional well-known drive mount fallbacks
candidates+=(
  "/mnt/c/Users/"*"/OneDrive/Projetos/WorkSpace/ssh/id_ed25519"
  "/mnt/c/Users/"*"/.ssh/id_ed25519"
)

for cand in "${candidates[@]}"; do
  if [ -f "$cand" ]; then
    found_persistent_key="$cand"
    break
  fi
done

if [ -f "$SSH_KEY" ]; then
  echo_info "SSH key already exists (${SSH_KEY}) - skipping generation."
elif [ -n "$found_persistent_key" ]; then
  echo_info "Found persistent master SSH key at ${found_persistent_key}."
  if [ "$DRY_RUN" = true ]; then
    echo_dry "cp -f ${found_persistent_key} ${SSH_KEY} && chmod 600 ${SSH_KEY}"
    if [ -f "${found_persistent_key}.pub" ]; then
      echo_dry "cp -f ${found_persistent_key}.pub ${SSH_PUB} && chmod 644 ${SSH_PUB}"
    fi
  else
    cp -f "$found_persistent_key" "$SSH_KEY"
    chmod 600 "$SSH_KEY"
    if [ -f "${found_persistent_key}.pub" ]; then
      cp -f "${found_persistent_key}.pub" "$SSH_PUB"
      chmod 644 "$SSH_PUB"
    fi
    echo_success "Restored master SSH key from OneDrive/Host."
  fi
elif [ "$DRY_RUN" = true ]; then
  echo_dry "ssh-keygen -q -t ed25519 -o -a 100 -C \"$GIT_EMAIL\" -f ${SSH_KEY}"
else
  echo_info "Generating new SSH key..."
  ssh-keygen -q -t ed25519 -o -a 100 -C "$GIT_EMAIL" -f "$SSH_KEY"
fi

# ~/.ssh/config entries (guarded appends: no duplicates on rerun)
if [ "$DRY_RUN" != true ]; then
  touch "$SSH_CONFIG"
fi
if grep -qsxF " IgnoreUnknown UseKeychain" "$SSH_CONFIG"; then
  echo_info "Host block already in ${SSH_CONFIG} - skipping append."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "append Host block (AddKeysToAgent/UseKeychain) to ${SSH_CONFIG}"
else
  echo -e "Host *\n IgnoreUnknown UseKeychain\n AddKeysToAgent yes\n UseKeychain yes\n" >> "$SSH_CONFIG"
fi
append_once "$SSH_CONFIG" "IdentityFile ~/.ssh/id_ed25519"

if [ "$DRY_RUN" = true ]; then
  echo_dry "eval \"\$(ssh-agent -s)\" && ssh-add ${SSH_KEY} && ssh -T git@github.com"
else
  eval "$(ssh-agent -s)"
  if [ -f "$SSH_KEY" ]; then
    ssh-add "$SSH_KEY" 2>/dev/null || true
  fi
  ssh -T -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true
fi

# Finish
echo_success "SSH and Git credentials configured."
