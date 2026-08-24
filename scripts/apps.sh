#!/bin/bash
#
# Install applications
# Comment (with #) what should not be installed and add the applications you want to install.
# Rerun-safe: repository setups are guarded; apt installs are naturally idempotent.

source ./scripts/utils.sh

echo_info "Installing apps..."

# Update Ubuntu
run sudo apt update
run sudo apt upgrade -y

# Essential package
run sudo apt install -y build-essential

# Common packages
run sudo apt install -y apt-transport-https ca-certificates curl gawk jq ssh-askpass tree unzip wget zsh

# Git (guard: only add the PPA once — check active source files only,
# so leftover *.save / *.distUpgrade copies don't suppress the setup)
if grep -qs "git-core/ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
  echo_info "git-core PPA already configured - skipping."
else
  run sudo add-apt-repository -y ppa:git-core/ppa
  run sudo apt update
fi
run sudo apt install -y git

# Nodejs (guard: only add the NodeSource repository once)
if ls /etc/apt/sources.list.d/nodesource*.list /etc/apt/sources.list.d/nodesource*.sources > /dev/null 2>&1; then
  echo_info "NodeSource repository already configured - skipping."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
else
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
fi
run sudo apt install -y nodejs yarn

# Resource Monitor
run sudo apt install -y btop

# Terminal multiplexer (guard: skip when already installed)
if command -v tmux > /dev/null 2>&1; then
  echo_info "tmux already installed - skipping."
else
  run sudo apt install -y tmux
fi

# Lazydocker (guard: skip when already installed)
if command -v lazydocker > /dev/null 2>&1; then
  echo_info "lazydocker already installed - skipping."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash"
else
  curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
fi

# GitHub CLI (guard: skip when already installed)
if command -v gh > /dev/null 2>&1; then
  echo_info "gh already installed - skipping."
else
  run sudo apt install -y gh
fi

# Restore gh config from OneDrive if available and missing locally
if [ ! -f "$HOME/.config/gh/hosts.yml" ]; then
  for onedrive_gh in \
    "/mnt/c/Users/$USER/OneDrive/Projetos/WorkSpace/gh" \
    "/mnt/c/Users/"*"/OneDrive/Projetos/WorkSpace/gh"; do
    if [ -d "$onedrive_gh" ]; then
      echo_info "Restoring GitHub CLI configuration from $onedrive_gh..."
      mkdir -p "$HOME/.config/gh"
      cp -f "$onedrive_gh"/* "$HOME/.config/gh/" 2>/dev/null || true
      chmod 600 "$HOME/.config/gh"/* 2>/dev/null || true
      break
    fi
  done
fi

# Database Client (psql)
run sudo apt install -y postgresql-client

# Cloud Storage Sync (rclone)
run sudo apt install -y rclone

# Docker CLI & Compose plugin (native Linux binaries, service disabled to use Docker Desktop socket)
run sudo apt install -y docker.io docker-compose-v2
run sudo systemctl disable --now docker.service docker.socket 2>/dev/null || true
run sudo usermod -aG docker "$USER" 2>/dev/null || true

# Claude Code CLI (guard: skip when already installed)
if command -v claude > /dev/null 2>&1; then
  echo_info "claude already installed - skipping."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "curl -fsSL https://claude.ai/install.sh | bash"
else
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Finish
echo_success "Finished applications installation."
