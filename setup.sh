#!/bin/bash
#
# WSL Ubuntu Dotfiles
# Font: https://github.com/alexandre-machado/wsl-setup
# Main install script
#
# Usage: ./setup.sh [--dry-run|-n] [--only <module>[,<module>...]]
# Modules: apps, docker, network-tuning, wsl-conf, dotfiles, npm, ssh, gpg

# Honor an env-provided DRY_RUN (e.g. DRY_RUN=true ./setup.sh) — never
# silently downgrade it to a real run. Normalize truthy spellings.
case "${DRY_RUN:-false}" in
  true|1|yes) DRY_RUN=true ;;
  *)          DRY_RUN=false ;;
esac
ONLY=""
ALL_MODULES="apps docker network-tuning wsl-conf dotfiles npm ssh gpg"

usage() {
  echo "Usage: $0 [--dry-run|-n] [--only <module>[,<module>...]]"
  echo ""
  echo "  --dry-run, -n     Print intended actions per module without changing anything"
  echo "  --only <modules>  Run only the given comma-separated modules"
  echo "                    (available: ${ALL_MODULES// /, })"
  echo "  --help, -h        Show this message"
}

# Parse flags BEFORE sourcing utils.sh (which may prompt for user data)
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=true ;;
    --only)       shift
                  if [ $# -eq 0 ] || [ -z "$1" ]; then
                    echo "--only requires a value (available: ${ALL_MODULES// /, })"; exit 1
                  fi
                  ONLY="$1" ;;
    --only=*)     ONLY="${1#--only=}"
                  if [ -z "$ONLY" ]; then
                    echo "--only requires a value (available: ${ALL_MODULES// /, })"; exit 1
                  fi ;;
    --help|-h)    usage; exit 0 ;;
    *)            echo "Unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done
export DRY_RUN

# Validate --only module names against the known list
if [ -n "$ONLY" ]; then
  for module in ${ONLY//,/ }; do
    case " $ALL_MODULES " in
      *" $module "*) ;;
      *) echo "Unknown module: '$module' (available: ${ALL_MODULES// /, })"; exit 1 ;;
    esac
  done
fi

source ./scripts/utils.sh

# Add your data
source ./scripts/user.sh

# Run a module if selected (--only wins over SSH_DISABLED/GPG_DISABLED toggles)
run_module() {
  local name="$1"
  if [ -n "$ONLY" ]; then
    case ",$ONLY," in
      *",$name,"*) ;;
      *) return 0 ;;
    esac
  else
    case "$name" in
      ssh) [ -n "$SSH_DISABLED" ] && return 0 ;;
      gpg) [ -n "$GPG_DISABLED" ] && return 0 ;;
    esac
  fi
  if [ "$DRY_RUN" = true ]; then
    echo_info "[dry-run] Module: ${name}"
  fi
  bash "./scripts/${name}.sh"
}

# Install applications
run_module apps

# Wire the docker CLI to the Docker Desktop engine (and heal a half-applied
# WSL Integration, which leaves every docker symlink dangling)
run_module docker

# Apply WSL2 kernel / network tuning for AI terminals
run_module network-tuning

# Provision /etc/wsl.conf (systemd, default user) — add-missing-only merge
run_module wsl-conf

# Install dotfiles
run_module dotfiles

# Node.js and npm settings
run_module npm

# Generate SSH key
run_module ssh

# Generate GPG key
run_module gpg

# Final steps only apply to a full, real run:
# --only reruns keep the checkout, and --dry-run must never delete it.
if [ "$DRY_RUN" = true ]; then
  echo_dry "mkdir -p ${HOME}/repos"
  echo_dry "sudo apt -y autoremove"
  echo_dry "rm -rf ../scripts.zip"
  echo_dry "rm -rf ${DOTFILES_DIRECTORY} (self-delete of this checkout, full runs only)"
  echo_success "Dry run complete. Nothing was changed."
  exit 0
fi

# Create a directory for projects and development
echo_info "Creating repos directory in Home directory..."
mkdir -p "${HOME}/repos"

if [ -z "$ONLY" ]; then
  # Cleanup cached downloads and remove temporary installation folder if in /tmp
  echo_info "Removing unnecessary files..."
  sudo apt -y autoremove
  rm -rf ../scripts.zip
  if [[ "${DOTFILES_DIRECTORY}" == /tmp/* ]]; then
    rm -rf "${DOTFILES_DIRECTORY}"
  fi
fi

# Finish
echo_success "Reboot and enjoy!"
