# Architecture

## Overview

This repository uses a two-stage setup flow:

1. Windows bootstrap in [wsl-setup.ps1](../wsl-setup.ps1)
2. Linux setup orchestration in [setup.sh](../setup.sh) with modular scripts in [scripts](../scripts)

The bootstrap handles WSL installation/state checks and then hands off to Bash inside WSL to complete developer environment setup.

## Layers

### Windows Bootstrap Layer

- Entry point: [wsl-setup.ps1](../wsl-setup.ps1) (with [wsl-profiles.ps1](../wsl-profiles.ps1) backwards-compatible wrapper)
- Responsibilities:
  - Detect if WSL package is installed via `winget` and install if missing
  - Provision `%USERPROFILE%\.wslconfig` from tracked template
  - Resolve profiles configuration from `wsl-profiles.json` (or `wsl-profiles.template.json`)
  - Present preflight provisioning plan summary
  - Ensure dedicated persistent ext4 data disk (`D:\wsl\data\repos.vhdx`) is mounted
  - Import clean Linux distros (Ubuntu, Alpine, Debian, etc.) from cached rootfs images
  - Bootstrap default user (`ubuntu-24`) with passwordless sudo & `/etc/wsl.conf`
  - Mount data disk by label `LABEL=wsl-repos` in `/etc/fstab`
  - Execute in-distro As-Code setup ([setup.sh](../setup.sh)) with declarative Git identity

### Linux Orchestration Layer

- Entry point: [setup.sh](../setup.sh)
- Responsibilities:
  - Load shared helpers from [scripts/utils.sh](../scripts/utils.sh)
  - Load user context from [scripts/user.sh](../scripts/user.sh)
  - Run setup modules in a fixed sequence
  - Optionally run SSH and GPG setup (guarded by env vars)

### Module Layer

- [scripts/apps.sh](../scripts/apps.sh): apt and tool installation
- [scripts/dotfiles.sh](../scripts/dotfiles.sh): Oh My Zsh, plugins, Git config, shell defaults
- [scripts/npm.sh](../scripts/npm.sh): NVM and Node setup
- [scripts/ssh.sh](../scripts/ssh.sh): SSH key generation and agent setup
- [scripts/gpg.sh](../scripts/gpg.sh): GPG key generation and Git signing defaults

### Utility and Context Layer

- [scripts/utils.sh](../scripts/utils.sh): output helpers and file replace helper
- [scripts/user.sh](../scripts/user.sh): prompts/exports `GIT_NAME` and `GIT_EMAIL`

### Maintenance Layer

- [cleanup.sh](../cleanup.sh): optional dry-run or destructive cleanup of caches, apt cache, and journal logs

## Control Flow

### Preferred Windows-first flow

1. User runs the PowerShell bootstrap command from [README.md](../README.md) (`wsl-setup.ps1`)
2. [wsl-setup.ps1](../wsl-setup.ps1) checks/installs WSL package, installs `.wslconfig`, and resolves `wsl-profiles.json`
3. Script prints the preflight provisioning plan across all profiles
4. Script mounts the dedicated persistent data disk
5. Script imports and provisions each distro idempotently using official rootfs and in-distro [setup.sh](../setup.sh)
6. Distros are immediately ready for work with persisted repos and credentials

### Native WSL flow

1. User clones repository in WSL
2. User runs [setup.sh](../setup.sh)
3. Orchestrator runs modules directly

## Data and State

Runtime state is primarily configuration and environment-variable based:

- `wsl-profiles.json` for multi-distro definitions, disk mounting, and Git identity
- `GIT_NAME`, `GIT_EMAIL` for identity propagation
- `SSH_DISABLED`, `GPG_DISABLED` to skip optional setup modules

Persistent state is written to:

- shell profile files under `$HOME`
- Git global config
- SSH and GPG key material under user home
- persistent data disk at `/home/ubuntu-24/repos` (`repos.vhdx`)
- system package manager and tool installation locations

## Design Characteristics

- Declarative Pure As-Code architecture driven by JSON
- Three-tier decoupled architecture (Stateless OS, Stateful Data Disk, Cloud Sync Credentials)
- Sequential orchestration with explicit module boundaries
- Safe idempotency with dry-run support (`-DryRun`)
