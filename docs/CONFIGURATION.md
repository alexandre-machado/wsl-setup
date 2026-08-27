# Configuration

## Runtime Inputs

### Profile Configuration (`wsl-profiles.json`)

Distro definitions, data disk paths, and Git identities are defined declaratively in `wsl-profiles.json` (see `wsl-profiles.template.json`):

- `defaultDistribution`: default Linux OS (e.g. `Ubuntu`, `Debian`, `Alpine`)
- `defaultVersion`: default OS release (e.g. `24.04`, `12`, `3.20`)
- `dataDiskPath`: path to dedicated VHDX (e.g. `D:\wsl\data\repos.vhdx`)
- `dataDiskMountName`: mount point name (e.g. `repos`)
- `setDefaultDistro`: distro to mark as default WSL instance
- `distros`: list of distro profiles with `name`, `distribution`, `version`, `installLocation`, `gitName`, `gitEmail`, `isolated`, `mountDataDisk`, `replaceIfExists`

### Optional module toggles

Used by [setup.sh](../setup.sh):

- `SSH_DISABLED` — skip [scripts/ssh.sh](../scripts/ssh.sh) when set
- `GPG_DISABLED` — skip [scripts/gpg.sh](../scripts/gpg.sh) when set

## WSL Bootstrap Behavior

Bootstrap behavior in [wsl-setup.ps1](../wsl-setup.ps1):

- `-ConfigFile <path>`: specify custom path to profiles JSON
- `-DryRun`: preview all steps without mutating system state
- `-Force`: bypass interactive prompts for profile replacement

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
