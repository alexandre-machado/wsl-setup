# External Integrations

**Analysis Date:** 2026-04-14

## APIs & External Services

**Source Code Hosting / Raw Installers:**
- GitHub - Repository clone and remote script/plugin fetches
  - SDK/Client: Git CLI + HTTPS endpoints in `wsl-setup.ps1`, `scripts/dotfiles.sh`, `scripts/apps.sh`
  - Auth: SSH key setup for GitHub in `scripts/ssh.sh`

**Package Feeds:**
- Ubuntu APT repositories - Base package installation in `scripts/apps.sh`
  - Client: `apt`, `add-apt-repository`
- Git Core PPA (`ppa:git-core/ppa`) - Git package source in `scripts/apps.sh`
- NodeSource setup endpoint (`https://deb.nodesource.com/setup_lts.x`) - Node.js repo bootstrap in `scripts/apps.sh`

**Remote Installer Scripts:**
- Oh My Zsh installer (`raw.githubusercontent.com/ohmyzsh/.../install.sh`) in `scripts/dotfiles.sh`
- Lazydocker installer (`raw.githubusercontent.com/jesseduffield/.../install_update_linux.sh`) in `scripts/apps.sh`

## Data Storage

**Databases:**
- Not applicable

**File Storage:**
- Local filesystem only (`$HOME`, `~/.ssh`, `~/.nvm`, `~/.oh-my-zsh`, `~/repos`) via `setup.sh` and `scripts/*.sh`

**Caching:**
- Local tool caches only (e.g., `~/.cache`, `~/.npm`, `~/.yarn`) cleaned by `cleanup.sh`

## Authentication & Identity

**Auth Provider:**
- Custom local key-based auth setup
  - SSH keys generated and added to agent in `scripts/ssh.sh`
  - GPG keys generated and configured for git signing in `scripts/gpg.sh`

## Monitoring & Observability

**Error Tracking:**
- None detected

**Logs:**
- CLI output only (stdout/stderr in shell scripts)

## CI/CD & Deployment

**Hosting:**
- Not applicable

**CI Pipeline:**
- None detected

## Environment Configuration

**Required env vars:**
- `GIT_NAME`, `GIT_EMAIL` (required for git config/key metadata in `scripts/user.sh`, `scripts/dotfiles.sh`, `scripts/gpg.sh`, `scripts/ssh.sh`)

**Optional env vars:**
- `SSH_DISABLED`, `GPG_DISABLED` (feature toggles in `setup.sh`)

**Secrets location:**
- No repository-managed secret store detected
- SSH/GPG private material is generated locally under user home directories

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None (only direct CLI calls to package and source endpoints)

---

*Integration audit: 2026-04-14*
