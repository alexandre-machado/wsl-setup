#!/bin/bash
#
# npm packages
# Add or exclude packages before installation

source ./scripts/utils.sh
. $HOME/.nvm/nvm.sh

echo_info "Setting Node.js and npm packages..."

# Install nodejs
nvm install 18

nvm run node --version

# Finish
echo_success "Finished Node.js and npm settings."
