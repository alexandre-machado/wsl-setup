# Technology Stack

**Analysis Date:** 2026-04-14

## Languages

**Primary:**
- Bash - Main automation scripts and setup flow in `setup.sh`, `cleanup.sh`, and `scripts/*.sh`

**Secondary:**
- PowerShell - Windows bootstrap and WSL provisioning in `wsl-setup.ps1`
- Zsh config syntax - User shell profile and aliases in `scripts/.zshrc`

## Runtime

**Environment:**
- Linux shell runtime on WSL Debian/Ubuntu (Bash and Zsh), driven by `setup.sh`
- Windows PowerShell runtime for host-side bootstrap in `wsl-setup.ps1`

**Package Manager:**
- System packages: APT (`sudo apt ...`) in `scripts/apps.sh`, `setup.sh`, `cleanup.sh`
- Windows packages: Winget (`winget ...`) in `wsl-setup.ps1`
- Node version manager: NVM (`nvm install 18`) in `scripts/npm.sh`
- Lockfile: Not applicable (no `package.json` / language lockfile detected)

## Frameworks

**Core:**
- Not detected (script-driven setup, no app framework)

**Testing:**
- Not detected

**Build/Dev:**
- Oh My Zsh bootstrap tooling via remote install script in `scripts/dotfiles.sh`
- Git CLI configuration and key setup in `scripts/dotfiles.sh`, `scripts/ssh.sh`, `scripts/gpg.sh`

## Key Dependencies

**Critical:**
- `apt` and Ubuntu repositories - Base package install/upgrade path in `scripts/apps.sh`
- `git` - Required for cloning setup/plugin repositories in `scripts/dotfiles.sh` and `wsl-setup.ps1`
- `curl` - Used for remote installer scripts (NodeSource, Oh My Zsh, Lazydocker) in `scripts/apps.sh` and `scripts/dotfiles.sh`
- `nvm` / Node.js 18 - Node runtime pinning in `scripts/npm.sh`

**Infrastructure:**
- WSL CLI (`wsl`) - Linux distribution install/update in `wsl-setup.ps1`
- GnuPG (`gpg`) - Key generation/config in `scripts/gpg.sh`
- OpenSSH (`ssh-keygen`, `ssh-agent`, `ssh-add`) - SSH key provisioning in `scripts/ssh.sh`

## Script Entrypoints

- `wsl-setup.ps1`: Windows entrypoint; installs/updates WSL, prompts for Git identity, clones repo, runs `./setup.sh`
- `setup.sh`: Main Linux setup orchestrator; sources shared functions/user data and runs app/dotfile/npm/SSH/GPG steps
- `cleanup.sh`: Optional cleanup utility with dry-run support for caches, apt cleanup, and disk usage reporting

## Configuration

**Environment:**
- Required user identity vars: `GIT_NAME`, `GIT_EMAIL` (prompted/exported in `scripts/user.sh`; also passed from `wsl-setup.ps1`)
- Optional behavior toggles: `SSH_DISABLED`, `GPG_DISABLED` checked in `setup.sh`

**Build:**
- No build system detected
- Shell behavior and aliases configured via `scripts/.zshrc`

## Platform Requirements

**Development:**
- Windows 10/11 host with WSL support (documented in `README.md`)
- Debian/Ubuntu-based WSL distro with sudo access

**Production:**
- Not applicable (workstation bootstrap scripts, not a deployed service)

---

*Stack analysis: 2026-04-14*
