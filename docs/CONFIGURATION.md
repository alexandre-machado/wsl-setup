# Configuration

## Runtime Inputs

### Required identity variables

The setup flow uses these variables:

- `GIT_NAME`
- `GIT_EMAIL`

How values are set:

- In Windows bootstrap: prompted via [wsl-setup.ps1](../wsl-setup.ps1) before handoff
- In Linux flow: prompted in [scripts/user.sh](../scripts/user.sh) when missing

### Optional module toggles

Used by [setup.sh](../setup.sh):

- `SSH_DISABLED` — skip [scripts/ssh.sh](../scripts/ssh.sh) when set
- `GPG_DISABLED` — skip [scripts/gpg.sh](../scripts/gpg.sh) when set

## WSL Bootstrap Behavior

Bootstrap mode in [wsl-setup.ps1](../wsl-setup.ps1):

- `create-new` (default): ensures `Ubuntu-24.04` exists and is default
- `use-existing`: keeps existing distro state untouched
- `replace-existing`: requires explicit `Y` confirmation before unregistering the target distro

## Script Configuration Surfaces

### [scripts/.zshrc](../scripts/.zshrc)

Shell aliases, plugins, and prompt behavior are copied into user home by [scripts/dotfiles.sh](../scripts/dotfiles.sh).

### Git global config

Configured in [scripts/dotfiles.sh](../scripts/dotfiles.sh):

- `user.name`
- `user.email`
- `init.defaultBranch`
- Oh My Zsh status display settings

### Signing defaults

Configured in [scripts/gpg.sh](../scripts/gpg.sh):

- `user.signingkey`
- `commit.gpgsign`
- `tag.gpgSign`

## System and Tooling Configuration

### Package installation configuration

[scripts/apps.sh](../scripts/apps.sh) uses apt and additional install scripts for:

- core build tools and shell utilities
- Git from `ppa:git-core/ppa`
- Node.js from NodeSource setup script
- Lazydocker install script

### Node version configuration

[scripts/npm.sh](../scripts/npm.sh) installs Node via NVM (`nvm install 18`).

## Operational Configuration

### Cleanup behavior

[cleanup.sh](../cleanup.sh) supports:

- `--dry-run` / `-n`: show intended cleanup without deleting
- default mode: perform cleanup operations

## VERIFY Markers

The following claims depend on external systems and should be validated in your environment:

<!-- VERIFY: NodeSource setup script URL remains valid and trustworthy in scripts/apps.sh -->
<!-- VERIFY: Lazydocker install script endpoint remains valid and trustworthy in scripts/apps.sh -->
<!-- VERIFY: winget package ID Microsoft.WSL behavior remains consistent on supported Windows versions -->
