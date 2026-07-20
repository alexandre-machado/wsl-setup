# WSL Debian/Ubuntu Dotfiles

This is a simple dotfiles and scripts to setup _Windows Subsystem for Linux (WSL)_ with _Debian and Ubuntu based Linux distributions_.

## Features

_Check linked files to more details._

### Installation files

- [apps.sh](scripts/apps.sh) - installs applications.
- [network-tuning.sh](scripts/network-tuning.sh) - kernel / TCP tuning for AI terminal tools (fixes ENOBUFS freezes under Mirrored networking + Tailscale).
- [.wslconfig.template](scripts/.wslconfig.template) - Windows-side `.wslconfig` provisioned by `wsl-setup.ps1` (Mirrored networking + DNS tunneling + memory caps).
- [cloud-init.user-data.template](scripts/cloud-init.user-data.template) - cloud-init user-data rendered by `wsl-setup.ps1` for brand-new Ubuntu instances (default user, locale, base packages).
- [dotfiles.sh](scripts/dotfiles.sh) - installs _Oh My Zsh_, _.zshrc_ and _Git_ configs.
- [npm.sh](scripts/npm.sh) - _Node.js_ and _npm_ settings.
- [setup.sh](setup.sh) - main installer.
- [ssh.sh](scripts/ssh.sh) - generate _SSH_.
- [user.sh](scripts/user.sh) - user data to configuration of _Git_ and _SSH_.
- [utils.sh](scripts/utils.sh) - support functions for other installers.
- [wsl-conf.sh](scripts/wsl-conf.sh) + [wsl.conf.template](scripts/wsl.conf.template) - provisions in-distro `/etc/wsl.conf` (systemd, default user) with an add-missing-only merge (see [Provisioning /etc/wsl.conf](#provisioning-etcwslconf)).
- [.zshrc](scripts/.zshrc) - terminal configs with aliases, paths, plugins and theme (this file is permanent after installation).

## Prerequisites

- Updated Windows 10 or later **(recommended is Windows 11)**
- WSL 2 with _Debian/Ubuntu_ based

## Installation

**Note:** I use the [Windows 11 Setup Script](https://github.com/alexandre-machado/windows-setup) script to configure `Windows`, install some apps and `WSL`. To use the script, just download and open it with `PowerShell`. If you use it, skip to step [Install dotfiles](#install-dotfiles).

### Install directly from Windows (PowerShell)

You can install WSL and run the setup directly from Windows with one command (no need to manually clone the repository):

```pwsh
irm https://raw.githubusercontent.com/alexandre-machado/wsl-setup/main/wsl-setup.ps1 | iex
```

When this bootstrap runs, it prints a **preflight summary** first (WSL package status, existing distros, and which paths are available), then asks for one mode:

- `create-new` (default): prepares WSL and ensures `Ubuntu-24.04` exists (brand-new instances are pre-provisioned via [cloud-init](#cloud-init-provisioning-of-new-instances)).
- `use-existing`: keeps current distro(s) without destructive actions.
- `replace-existing`: destructive path and only allowed when `Ubuntu-24.04` already exists.

`replace-existing` always requires explicit `Y` confirmation before unregister/reset actions. If you decline, it continues with a non-destructive path.

#### Backup before `replace-existing` (`wsl --export`)

Before anything destructive runs, `replace-existing` offers to snapshot the distro with `wsl --export` (default target: `%USERPROFILE%\wsl-backups\<distro>-<date>.tar`, path is customizable). The prompt shows the estimated backup size and the free space on the target drive.

- If the export **fails**, the destructive path is aborted — nothing is unregistered.
- If you **decline** the backup, you still have to pass the explicit `Y` confirmation before any unregister happens (and the confirmation prompt reminds you that no backup was taken).

To restore a backup later:

```pwsh
wsl --import Ubuntu-24.04 <install-folder> "%USERPROFILE%\wsl-backups\Ubuntu-24.04-<date>.tar"
# e.g.
wsl --import Ubuntu-24.04 "%LOCALAPPDATA%\wsl\Ubuntu-24.04" "%USERPROFILE%\wsl-backups\Ubuntu-24.04-20260706-120000.tar"
```

Note: `wsl --import` fails while a distro with the same name is still registered. Either import under a new name (e.g. `wsl --import Ubuntu-24.04-restored ...`) or unregister the existing one first with `wsl --unregister Ubuntu-24.04` (destructive — that distro's filesystem is deleted).

#### cloud-init provisioning of new instances

When `create-new` needs to install a brand-new `Ubuntu-24.04` instance, the bootstrap uses Ubuntu's officially supported [WSL cloud-init mechanism](https://documentation.ubuntu.com/wsl/latest/howto/cloud-init/) so the instance comes up pre-provisioned (default user, locale, base packages) before `setup.sh` runs:

1. It renders [scripts/cloud-init.user-data.template](scripts/cloud-init.user-data.template) with the Linux username you choose at the prompt, **shows you the exact file content**, and — only after you confirm — writes it to `%USERPROFILE%\.cloud-init\Ubuntu-24.04.user-data` (the file name must match the distro name). No host-side file is written silently.
2. It installs the distro with `wsl --install -d Ubuntu-24.04 --no-launch`. cloud-init only provisions instances that have never been launched, so the user-data file must be in place before first boot.
3. On first boot it runs `cloud-init status --wait` inside the instance and reports the result in the progress output (exit code `0` = success, `2` = done with recoverable errors). The distro is then restarted so the `[user] default=` entry cloud-init wrote to `/etc/wsl.conf` takes effect.

Notes:

- cloud-init user-data is only honored by Ubuntu WSL images. For Debian (or any non-Ubuntu distro) the step is skipped with a message and the instance boots unprovisioned, relying on `setup.sh` alone.
- Existing instances are never re-provisioned: `use-existing`, `replace-existing`, and a `create-new` run where `Ubuntu-24.04` already exists are unaffected by the user-data file (though `replace-existing` reinstalls via its own path, without cloud-init).
- If you decline the write prompt (or the template download fails), the bootstrap falls back to the previous behavior: `wsl --install` with interactive first-launch setup.
- An existing `Ubuntu-24.04.user-data` not managed by this repo (no `# managed-by: wsl-setup` marker) is backed up as `*.bak-<timestamp>` before being replaced.

### Install WSL

If you do not already have `WSL`, follow these steps to install. Open `Powershell` by searching for it in _Search_ and _right-clicking_ for a context menu and clicking _“Run as Administrator”_. Enter the following command:

```pwsh
wsl --install
```

After restarting, launch `Ubuntu.exe` from the _Start Menu_. You’ll be asked to enter a username and password (for sudo stuff).

### Install dotfiles

If you already have `Windows` and `WSL` installed, run these commands in `WSL`:

```
git clone https://github.com/alexandre-machado/wsl-setup.git
chmod 700 wsl-setup/ -R
cd wsl-setup
./setup.sh
```

#### Flags

`setup.sh` is rerun-safe: running it again on an installed system skips work already done (no duplicated `.zshrc`, git-config, or SSH-config entries).

```
./setup.sh [--dry-run|-n] [--only <module>[,<module>...]]
```

- `--dry-run`, `-n` — prints the intended actions per module without changing anything (no installs, no file writes, and it does **not** delete the checkout).
- `--only <modules>` — runs only the listed modules, comma-separated. Available modules: `apps`, `network-tuning`, `wsl-conf`, `dotfiles`, `npm`, `ssh`, `gpg`. With `--only`, the checkout is kept afterwards (a full run removes it), and an explicit selection overrides the `SSH_DISABLED`/`GPG_DISABLED` toggles.

Examples:

```
./setup.sh --dry-run                # preview everything
./setup.sh --only dotfiles,npm      # resume a failed setup from the dotfiles step
DRY_RUN=true bash ./scripts/ssh.sh  # dry-run a single module directly
```

## Provisioning /etc/wsl.conf

`setup.sh` (module `wsl-conf`) provisions the in-distro [/etc/wsl.conf](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) from [scripts/wsl.conf.template](scripts/wsl.conf.template) — the in-distro counterpart of the Windows-side `.wslconfig` template:

- `[boot] systemd=true` — required by snap and systemctl-managed services (Docker, Tailscale).
- `[user] default=<your user>` — log in as your user instead of root.

**Merge policy (add-missing-only):** the module never modifies or removes keys/sections that already exist in `/etc/wsl.conf` — it only adds template keys that are missing. So it does not fight the `[user]` section that [cloud-init](#cloud-init-provisioning-of-new-instances) writes on brand-new instances, and any value you set by hand wins over the template on reruns. To change a managed value, edit `/etc/wsl.conf` directly.

After the module adds anything, it reminds you that the change only takes effect after a restart of the distro — run from Windows:

```pwsh
wsl --shutdown
```

then reopen your WSL terminal. Setup never forces this restart.

## Remote - WSL

Install the [Remote - WSL](https://aka.ms/vscode-remote/download/wsl) extension in VSCode to get a better experience with `WSL`.

## VS Code terminal in tmux

The setup installs `tmux` (`scripts/apps.sh`), a `~/.tmux.conf` (`scripts/.tmux.conf`, with `allow-passthrough on` for clipboard/OSC integration), and a helper script `~/.local/bin/tmux-vscode-session` (`scripts/tmux-vscode-session.sh`) that opens a stable tmux session per repository. Note the tradeoff: `allow-passthrough on` lets programs running in a visible pane send OSC escape sequences to the host terminal (e.g. writing to the clipboard via OSC 52), so untrusted output printed in a pane can drive the outer terminal — if you don't want clipboard integration, set it to `off` in `~/.tmux.conf`. To make VS Code's integrated terminal land in a persistent tmux session automatically, add this to your VS Code settings (Remote [WSL] settings — `F1` → *Preferences: Open Remote Settings (WSL)* — or User settings JSON):

```jsonc
{
  "terminal.integrated.profiles.linux": {
    "zsh": {
      "path": "zsh"
    },
    "zsh-tmux": {
      "path": "zsh",
      "args": ["-c", "exec tmux-vscode-session"],
      "icon": "terminal-tmux"
    }
  },
  "terminal.integrated.defaultProfile.linux": "zsh-tmux",
  // Keep tasks and debug terminals OUT of tmux — they use this profile instead
  // of the default one.
  "terminal.integrated.automationProfile.linux": {
    "path": "zsh"
  }
}
```

How it behaves:

- **Persistent sessions per repository** — `tmux-vscode-session` uses the repo root path to derive a stable session name (`vsc_<owner>_<repo>_<hash>`). This avoids collisions between similarly named repositories from different folders/accounts. Closing the VS Code window keeps the session alive; reopening the same repository reattaches to it with scrollback and running processes intact. To really end a session, `exit` the shell inside tmux (or `tmux kill-session -t "$(tmux display-message -p '#S')"`).
- **Tasks and debug terminals are unaffected** — `terminal.integrated.automationProfile.linux` points to plain `zsh`, so VS Code tasks and debug consoles never run inside tmux. Do not remove it: without an explicit automation profile they may inherit the tmux default profile.
- **Opt-out** — the configuration is opt-in per the settings above; nothing in the scripts touches VS Code settings. To open a one-off terminal outside tmux, pick the plain `zsh` profile from the terminal dropdown (`+` → `zsh`). To opt out entirely, set `"terminal.integrated.defaultProfile.linux": "zsh"` (or remove the settings).

## Reference

- [Windows Subsystem for Linux Installation Guide for Windows](https://aka.ms/wslinstall)
- [WSL 2](https://aka.ms/wsl2)

## Utilities

- [Oh My Posh](https://ohmyposh.dev)
- [Winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [Winstall](https://winstall.app)
