#!/bin/bash
#
# Install Oh My Zsh and set dotfiles
# Install dotfiles and configure git
# Rerun-safe: clones and shell/git mutations are guarded.

source ./scripts/utils.sh

echo_info "Installing dotfiles..."

# Install Oh My Zsh (guard: skip when already installed)
if [ -d "${HOME}/.oh-my-zsh" ]; then
  echo_info "Oh My Zsh already installed - skipping."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "install Oh My Zsh (unattended): sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
else
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install plugin zsh-autosuggestions
clone_once https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# Install plugin zsh-completions
clone_once https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions

# Install plugin F-Sy-H
clone_once https://github.com/z-shell/F-Sy-H.git ~/.oh-my-zsh/custom/plugins/F-Sy-H

# Install NVM (checkout latest tag; subshell so the cd does not leak)
clone_once https://github.com/nvm-sh/nvm.git ~/.nvm
if [ "$DRY_RUN" = true ]; then
  echo_dry "cd ~/.nvm && git checkout \$(git describe --abbrev=0 --tags)"
elif [ -d ~/.nvm/.git ]; then
  (cd ~/.nvm && git checkout `git describe --abbrev=0 --tags`)
fi

# Move permanent files to Home directory
replace "./scripts/.zshrc" ".zshrc"
replace "./scripts/.tmux.conf" ".tmux.conf"
run mkdir -p "${HOME}/.local/bin"
TMUX_VSCODE_SRC="${DOTFILES_DIRECTORY}/scripts/tmux-vscode-session.sh"
TMUX_VSCODE_DEST="${HOME}/.local/bin/tmux-vscode-session"
if cmp -s "$TMUX_VSCODE_SRC" "$TMUX_VSCODE_DEST"; then
  echo_info "tmux-vscode-session already up to date - skipping."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "install -m 755 ${TMUX_VSCODE_SRC} ${TMUX_VSCODE_DEST}"
else
  install -m 755 "$TMUX_VSCODE_SRC" "$TMUX_VSCODE_DEST"
fi

# Set Zsh as default shell in Linux (guard: skip when already the login shell)
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(which zsh)" ]; then
  echo_info "Zsh is already the default shell - skipping."
else
  run chsh -s $(which zsh)
fi

# Fix “zsh compinit: insecure directories” warnings
fpath=(/usr/local/share/zsh-completions $fpath)

# Git configs (plain `set` calls are idempotent; `--add` calls are guarded)
run git config --global user.name "$GIT_NAME"
run git config --global user.email "$GIT_EMAIL"
run git config --global init.defaultBranch main
git_config_add_once oh-my-zsh.hide-dirty 1
git_config_add_once oh-my-zsh.hide-status 1

# Finish
echo_success "Dotfiles settings complete."
