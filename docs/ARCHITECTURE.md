# Architecture

## Overview

This repository uses a two-stage setup flow:

1. Windows bootstrap in [wsl-setup.ps1](../wsl-setup.ps1)
2. Linux setup orchestration in [setup.sh](../setup.sh) with modular scripts in [scripts](../scripts)

The bootstrap handles WSL installation/state checks and then hands off to Bash inside WSL to complete developer environment setup.

## Layers

### Windows Bootstrap Layer

- Entry point: [wsl-setup.ps1](../wsl-setup.ps1)
- Responsibilities:
  - Detect if WSL package is installed via `winget`
  - Detect existing distro state with `wsl --list --quiet`
  - Present a preflight summary before destructive choices
  - Route to one of three modes: `create-new`, `use-existing`, `replace-existing`
  - Require explicit confirmation before destructive replace flow
  - Pass Git identity values to the Linux setup handoff

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

1. User runs the PowerShell bootstrap command from [README.md](../README.md)
2. [wsl-setup.ps1](../wsl-setup.ps1) checks/installs WSL package and prints preflight summary
3. User chooses bootstrap mode
4. Script ensures WSL distro state and sets default distro as needed
5. Script prompts for Git identity
6. Script launches WSL Bash handoff to clone and execute [setup.sh](../setup.sh)
7. [setup.sh](../setup.sh) runs module scripts

### Native WSL flow

1. User clones repository in WSL
2. User runs [setup.sh](../setup.sh)
3. Orchestrator runs modules directly

## Data and State

Runtime state is primarily environment-variable based:

- `GIT_NAME`, `GIT_EMAIL` for identity propagation
- `SSH_DISABLED`, `GPG_DISABLED` to skip optional setup modules

Persistent state is written to:

- shell profile files under `$HOME`
- Git global config
- SSH and GPG key material under user home
- system package manager and tool installation locations

## Design Characteristics

- Script-first architecture (PowerShell + Bash)
- Sequential orchestration with explicit module boundaries
- Interactive setup steps for identity and destructive choices
- Stronger safety in Windows bootstrap path via confirmation-gated replacement
