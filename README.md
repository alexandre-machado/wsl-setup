# WSL Multi-Profile & Dotfiles (Pure As-Code)

Infrastructure-as-Code and dotfiles to provision, manage, and recover isolated _Windows Subsystem for Linux (WSL 2)_ environments with dedicated persistent data storage and automatic credential restoration.

---

## 🏛️ Architecture & Separation of Concerns

This setup uses a **three-tier decoupled architecture** designed to survive complete Windows formatting or SSD failure with zero data loss and 2-minute recovery:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. STATELESS OS LAYER (SSD C:)                                              │
│    • Ubuntu-Personal (%LOCALAPPDATA%\wsl\Ubuntu-Personal)                   │
│    • Ubuntu-CloudHumans (%LOCALAPPDATA%\wsl\Ubuntu-CloudHumans)             │
│    -> Provisioned in seconds from Canonical rootfs. 100% disposable & as-code. │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. STATEFUL DATA LAYER (Dedicated Drive D:)                                 │
│    • D:\wsl\data\repos.vhdx (ext4 filesystem, LABEL=wsl-repos)              │
│    -> Mounted dynamically at /home/ubuntu-24/repos across all distros.      │
│    -> All git repos (~25GB), docker volumes & workspaces live here.          │
│    -> Survives Windows reformatting (C:) completely untouched.              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. CREDENTIALS & METADATA (OneDrive Cloud Sync)                             │
│    • OneDrive\Projetos\WorkSpace\ssh\id_ed25519 (SSH Master Key)            │
│    • OneDrive\Projetos\WorkSpace\gh\hosts.yml (GitHub CLI Auth Token)      │
│    • OneDrive\Projetos\WorkSpace\wsl-profiles.json (Distro Definitions)      │
│    -> Auto-discovered and injected on first boot into new distros.         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start / Provisioning

### 1. Configure Profiles (`wsl-profiles.json`)

Define your distro profiles in `%OneDrive%\Projetos\WorkSpace\wsl-profiles.json` (or copy from [`wsl-profiles.template.json`](wsl-profiles.template.json)):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "defaultVersion": "24.04",
  "dataDiskPath": "D:\\wsl\\data\\repos.vhdx",
  "dataDiskMountName": "repos",
  "setDefaultDistro": "Ubuntu-Personal",
  "replaceExisting": false,
  "provisionGit": true,
  "distros": [
    {
      "name": "Ubuntu-Personal",
      "version": "24.04",
      "installLocation": "%LOCALAPPDATA%\\wsl\\Ubuntu-Personal",
      "gitName": "Your Name",
      "gitEmail": "your.email@example.com"
    },
    {
      "name": "Ubuntu-Work",
      "version": "24.04",
      "installLocation": "%LOCALAPPDATA%\\wsl\\Ubuntu-Work",
      "gitName": "Your Name",
      "gitEmail": "your.work.email@example.com"
    },
    {
      "name": "Ubuntu-CI",
      "version": "24.04",
      "installLocation": "%LOCALAPPDATA%\\wsl\\Ubuntu-CI",
      "mountDataDisk": false,
      "isolated": true
    }
  ]
}
```

### 2. Run Pure As-Code Provisioner (PowerShell)

Run from PowerShell (as Administrator or regular user with WSL permissions):

```pwsh
irm https://raw.githubusercontent.com/alexandre-machado/wsl-setup/main/wsl-profiles.ps1 | iex
```

Or from a local clone:

```pwsh
.\wsl-profiles.ps1
```

#### What `wsl-profiles.ps1` executes automatically:
1. **Rootfs Download & Cache:** Fetches the official Canonical Ubuntu 24.04 WSL rootfs (~380 MB) to `%TEMP%\wsl-cache`.
2. **Distro Creation:** Imports each distro into its dedicated SSD location (`%LOCALAPPDATA%\wsl\<DistroName>`).
3. **User Bootstrap:** Creates user `ubuntu-24` with passwordless `sudo` and default Zsh shell.
4. **Data Disk Mounting:** Attaches `D:\wsl\data\repos.vhdx` and configures `/etc/fstab` using direct ext4 label `LABEL=wsl-repos /home/ubuntu-24/repos ext4 defaults,nofail 0 0`.
5. **Credential Injection:** Restores SSH keys and GitHub CLI (`gh`) auth tokens from OneDrive.
6. **Toolchain Installation:** Runs [`setup.sh`](setup.sh) inside the distro, installing `docker.io`, `docker-compose-v2`, `gh`, `jq`, `psql`, `rclone`, `rtk`, `lazydocker`, `btop`, and `claude`.

---

## 🆘 Disaster Recovery: Reinstalling / Formatting Windows (C:)

If you format Windows completely (clean installation of Windows 11 on `C:`), follow this step-by-step runbook to restore your entire development environment in **under 3 minutes**:

### Step 1: Install WSL on Fresh Windows
Open PowerShell as Administrator:
```pwsh
wsl --install --no-distribution
```

### Step 2: Ensure OneDrive is Synced
Ensure Microsoft OneDrive is signed in and your workspace folder is available:
- `C:\Users\<user>\OneDrive\Projetos\WorkSpace` (contains `ssh/`, `gh/`, and `wsl-profiles.json`).

### Step 3: Run the WSL Profiles Provisioner
From PowerShell:
```pwsh
irm https://raw.githubusercontent.com/alexandre-machado/wsl-setup/main/wsl-profiles.ps1 | iex
```
*`wsl-profiles.ps1` will recreate all distros on `C:`, auto-attach `D:\wsl\data\repos.vhdx`, restore your SSH keys and `gh` tokens, and configure all dotfiles.*

### Step 4: Install & Connect Docker Desktop
1. Download and install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/).
2. In Docker Desktop Settings:
   - **Resources -> WSL integration**: Enable integration with `Ubuntu-Personal` and `Ubuntu-CloudHumans`.
3. Restart WSL from PowerShell:
   ```pwsh
   wsl --shutdown
   ```

### Step 5: Start Chat Services / Repositories
Open your terminal into `Ubuntu-Personal`:
```zsh
wsl -d Ubuntu-Personal
cd ~/repos/NexaDuo/chat-services
./scripts/run-stack.sh up
./scripts/run-stack.sh status
```
*All 22 containers (PostgreSQL pgvector, Redis, Chatwoot, Dify, Evolution API, Traefik, Grafana) will start immediately with 100% of previous database data intact from the volumes on `D:`.*

### Step 6: VS Code Integration
1. Install [VS Code](https://code.visualstudio.com/) and the [WSL Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl).
2. Open any repository directly:
   ```zsh
   code ~/repos/NexaDuo/chat-services
   ```

---

### 🐧 Distribuições Linux Suportadas (Pure As-Code)

Você pode escolher a distribuição Linux (`distribution`) e a versão (`version`) de forma independente para cada profile no `wsl-profiles.json`:

| Distribuição (`distribution`) | Versões Suportadas (`version`) | Família / Base | Tamanho RootFS |
| :--- | :--- | :--- | :--- |
| **`Ubuntu`** *(Padrão)* | `24.04` (Noble LTS), `22.04` (Jammy LTS), `20.04` (Focal LTS) | Debian / APT | ~380 MB |
| **`Debian`** | `12` (Bookworm), `11` (Bullseye) | Debian / APT | ~110 MB |
| **`Alpine`** | `3.20`, `3.19` | Musl / APK (Ultra-leve) | **~3 MB** |
| **`Arch`** | `rolling` | Arch / Pacman | ~180 MB |
| **`Fedora`** | `40` | Red Hat / DNF | ~160 MB |
| **`Custom`** | Qualquer URL HTTP/HTTPS direta | Custom | Variável |

---

## 🧰 Key Features & Scripts Reference

| Script | Purpose |
| :--- | :--- |
| [`wsl-profiles.ps1`](wsl-profiles.ps1) | Main Windows orchestrator: multi-profile provisioning, VHDX mounting, user bootstrap. |
| [`setup.sh`](setup.sh) | Main in-distro orchestrator: runs modular setup scripts idempotently. |
| [`scripts/apps.sh`](scripts/apps.sh) | Installs `docker.io`, `docker-compose-v2`, `gh`, `jq`, `psql`, `rclone`, `claude`, `lazydocker`, `btop`. |
| [`scripts/ssh.sh`](scripts/ssh.sh) | Discovers and restores master SSH keys from OneDrive; configures GCM. |
| [`scripts/dotfiles.sh`](scripts/dotfiles.sh) | Configures Oh My Zsh, plugins (`F-Sy-H`, `zsh-autosuggestions`), and Claude statusLine. |
| [`scripts/.zshrc`](scripts/.zshrc) | Shell configuration, aliases (`hc`, `marc`, `copyssh`, `copygpg`, `gitcfg`), and auto-mount fallback. |
| [`scripts/network-tuning.sh`](scripts/network-tuning.sh) | Kernel & TCP buffer optimization for AI terminal tools under Mirrored networking. |

---

## ⚡ Shell Aliases

- `hc` — Runs Claude Code with permissions auto-accepted: `claude --dangerously-skip-permissions`
- `marc` — Runs mARC Tech Lead orchestrator via Telegram channel.
- `copyssh` — Copies public SSH key to Windows clipboard.
- `copygpg` — Copies public GPG key to Windows clipboard.
- `repos` — Navigates to `~/repos` (`D:\wsl\data\repos.vhdx`).
- `zshcfg` — Opens `~/.zshrc` in VS Code.
- `gitcfg` — Opens `~/.gitconfig` in VS Code.

---

## 📜 License

MIT License © Alexandre Machado
