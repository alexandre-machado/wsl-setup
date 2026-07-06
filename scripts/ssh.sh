#!/bin/bash
#
# Generate SSH
# Rerun-safe: key generation and ~/.ssh/config appends are guarded,
# so a second run adds no duplicate entries.

source ./scripts/utils.sh

SSH_KEY="${HOME}/.ssh/id_ed25519"
SSH_CONFIG="${HOME}/.ssh/config"

echo_info "Configuring git to use SSH..."
run git config --global url.ssh://git@github.com/.insteadOf https://github.com/

echo_info "Generating SSH key..."

if [ -f "$SSH_KEY" ]; then
  echo_info "SSH key already exists (${SSH_KEY}) - skipping generation."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "ssh-keygen -q -t ed25519 -o -a 100 -C \"$GIT_EMAIL\" -f ${SSH_KEY}"
else
  echo_info "Create a password for SSH key:"
  ssh-keygen -q -t ed25519 -o -a 100 -C "$GIT_EMAIL" -f "$SSH_KEY"
fi

# ~/.ssh/config entries (guarded appends: no duplicates on rerun)
if [ "$DRY_RUN" != true ]; then
  mkdir -p "${HOME}/.ssh"
  touch "$SSH_CONFIG"
fi
# Exact whole-line match (-x): a commented-out variant must not skip the append
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
  ssh-add "$SSH_KEY"
  ssh -T git@github.com
fi

echo_warning "Use copyssh command to copy the SSH key to the clipboard."

# Finish
echo_success "Generated SSH key."
