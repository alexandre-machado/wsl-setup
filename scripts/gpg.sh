#!/bin/bash
#
# GPG key generation script
# Generating a GPG key

source ./scripts/utils.sh

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

# Detect the last created GPG key ID
KEY_ID=$(gpg --list-secret-keys --with-colons | grep '^sec' | tail -1 | cut -d: -f5)

# Export the public key in ASCII armor format
# gpg --armor --export "$KEY_ID"
# Prints the GPG key ID, in ASCII armor format and add on https://github.com/settings/gpg/new

# Configure git to use the new key
git config --global user.signingkey "$KEY_ID"
git config --global commit.gpgsign true
git config --global tag.gpgSign true

echo_success "GPG key generated and configured successfully."