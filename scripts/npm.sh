#!/bin/bash
#
# npm packages
# Add or exclude packages before installation
# Rerun-safe: skips when the Node version is already installed.

source ./scripts/utils.sh

echo_info "Setting Node.js and npm packages..."

if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo_dry "source ~/.nvm/nvm.sh && nvm install 18"
    exit 0
  fi
  echo_warning "NVM not found (~/.nvm/nvm.sh). Run the dotfiles module first."
  exit 1
fi

. $HOME/.nvm/nvm.sh

# Install nodejs (guard: skip when version 18 is already installed)
if nvm ls 18 > /dev/null 2>&1; then
  echo_info "Node.js 18 already installed - skipping."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "nvm install 18"
else
  nvm install 18
fi

if [ "$DRY_RUN" != true ]; then
  nvm run node --version
fi

# Finish
echo_success "Finished Node.js and npm settings."
