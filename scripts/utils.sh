#!/bin/bash
#
# Some functions used in install scripts

# Dry-run mode: exported by setup.sh, defaults to false when a module
# is executed standalone (e.g. DRY_RUN=true bash ./scripts/ssh.sh).
DRY_RUN="${DRY_RUN:-false}"
export DRY_RUN

source ./scripts/user.sh

# Global variables
DOTFILES_DIRECTORY="$PWD"

# Info message
echo_info() {
  printf "\n$(tput setaf 3)%s$(tput sgr0)\n" "$@"
  [ "$DRY_RUN" = true ] || sleep 2
}

# Success message
echo_success() {
  printf "\n$(tput setaf 2)✓ %s$(tput sgr0)\n" "$@"
  [ "$DRY_RUN" = true ] || sleep 2
}

# Warning message
echo_warning() {
  printf "\n$(tput setaf 136)! %s$(tput sgr0)\n" "$@"
  [ "$DRY_RUN" = true ] || sleep 2
}

# Dry-run message (intended action that was NOT executed)
echo_dry() {
  printf "$(tput setaf 6)  [dry-run] %s$(tput sgr0)\n" "$@"
}

# Run a simple command, or just print it in dry-run mode.
# Only for plain commands (no pipes/redirections/heredocs) — guard those
# explicitly with `if [ "$DRY_RUN" = true ]`.
run() {
  if [ "$DRY_RUN" = true ]; then
    echo_dry "$*"
  else
    "$@"
  fi
}

# Clone a repository only if the destination does not exist yet.
clone_once() {
  local url="$1" dest="$2"
  if [ -d "$dest" ]; then
    echo_info "Already present: ${dest} - skipping clone."
  elif [ "$DRY_RUN" = true ]; then
    echo_dry "git clone ${url} ${dest}"
  else
    git clone "$url" "$dest"
  fi
}

# Add a multi-valued git config entry only once (guards `--add` duplication).
git_config_add_once() {
  local key="$1" value="$2"
  if git config --global --get "$key" > /dev/null 2>&1; then
    echo_info "git config ${key} already set - skipping."
  else
    run git config --global --add "$key" "$value"
  fi
}

# Append a line to a file only if it is not already there.
# Exact whole-line match (-x): a commented/partial variant must not
# silently suppress the append.
append_once() {
  local file="$1" line="$2"
  if grep -qxF "$line" "$file" 2> /dev/null; then
    echo_info "Already in ${file} - skipping append."
  elif [ "$DRY_RUN" = true ]; then
    echo_dry "append to ${file}: ${line}"
  else
    printf '%s\n' "$line" >> "$file"
  fi
}

# Force move/replace files (normalizes CRLF -> LF so dotfiles are always clean in Linux)
replace() {
  local src="${DOTFILES_DIRECTORY}/${1}" dest="${HOME}/${2}"
  if [ "$DRY_RUN" = true ]; then
    echo_dry "install (LF normalized) ${src} -> ${dest}"
  else
    tr -d '\r' < "$src" > "${dest}.tmp" && mv -f "${dest}.tmp" "$dest"
  fi
}
