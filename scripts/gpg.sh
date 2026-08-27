#!/bin/bash
#
# GPG key generation script
# Generating a GPG key
# Rerun-safe: skips generation when a secret key for GIT_EMAIL already exists.

source ./scripts/utils.sh

if [ "$ISOLATED_PROFILE" = "true" ] || [ "$GPG_DISABLED" = "true" ]; then
  echo_info "GPG setup disabled for isolated profile - skipping."
  exit 0
fi

# Search for persistent master GPG keys in OneDrive / Windows Host
found_persistent_gpg=""
for cand in \
  "/mnt/c/Users/$USER/OneDrive/Projetos/WorkSpace/gpg" \
  "/mnt/c/Users/"*"/OneDrive/Projetos/WorkSpace/gpg"; do
  for sec_file in "$cand"/*.sec.asc "$cand"/*secring.gpg; do
    if [ -f "$sec_file" ]; then
      found_persistent_gpg="$sec_file"
      break 2
    fi
  done
done

# Guard: [ -d ~/.gnupg ] first, so a dry-run on a fresh machine does not
# let `gpg --list-secret-keys` create ~/.gnupg as a side effect.
if [ -d "${HOME}/.gnupg" ] && gpg --list-secret-keys "$GIT_EMAIL" > /dev/null 2>&1; then
  echo_info "GPG key for $GIT_EMAIL already exists - skipping generation."
elif [ -n "$found_persistent_gpg" ]; then
  echo_info "Found persistent master GPG key at ${found_persistent_gpg}."
  if [ "$DRY_RUN" = true ]; then
    echo_dry "gpg --import ${found_persistent_gpg}"
  else
    gpg --import "$found_persistent_gpg"
    echo_success "Restored master GPG key from OneDrive/Host."
  fi
elif [ "$DRY_RUN" = true ]; then
  echo_dry "gpg --batch --generate-key (ed25519, no protection, $GIT_NAME <$GIT_EMAIL>)"
  echo_dry "git config --global user.signingkey <KEY_ID> && commit.gpgsign=true && tag.gpgSign=true"
  exit 0
else
  gpg --batch --generate-key <<EOF
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Subkey-Type: ecdh
Subkey-Curve: cv25519
Name-Real: ${GIT_NAME:-"Seu Nome"}
Name-Email: ${GIT_EMAIL:-"seu@email.com"}
Expire-Date: 0
EOF
fi

# Detect the key ID for GIT_EMAIL (never "last key in the keyring": that
# could silently repoint the signing key to an unrelated key).
KEY_ID=$(gpg --list-secret-keys --with-colons "$GIT_EMAIL" 2> /dev/null | grep '^sec' | tail -1 | cut -d: -f5)

if [ -z "$KEY_ID" ]; then
  echo_warning "Could not find a GPG key for $GIT_EMAIL - skipping git signing config."
  exit 0
fi

# Export the public key in ASCII armor format
# gpg --armor --export "$KEY_ID"
# Prints the GPG key ID, in ASCII armor format and add on https://github.com/settings/gpg/new

# Configure git to use the key (guarded so --dry-run never mutates git config)
run git config --global user.signingkey "$KEY_ID"
run git config --global commit.gpgsign true
run git config --global tag.gpgSign true

if [ "$DRY_RUN" != true ]; then
  echo_success "GPG key generated and configured successfully."
fi
