# Getting Started

## Prerequisites

- Windows 10 or Windows 11 with WSL support
- Internet access for package/tool downloads
- GitHub access for repository clone during bootstrap

## Fastest Path (Windows-first)

Run the bootstrap script from PowerShell:

```pwsh
irm https://raw.githubusercontent.com/alexandre-machado/wsl-setup/main/wsl-setup.ps1 | iex
```

What to expect:

1. Ensures WSL package and `.wslconfig` are installed
2. Resolves `wsl-profiles.json` (or `wsl-profiles.template.json`)
3. Preflight provisioning plan summary is rendered
4. Attaches dedicated data disk (`repos.vhdx`)
5. Imports Linux distros from cached rootfs and provisions `ubuntu-24` user
6. Executes As-Code setup ([setup.sh](../setup.sh)) inside each distro

## Existing WSL Installation Path

If WSL is already configured and you prefer to run directly inside Linux:

```bash
git clone https://github.com/alexandre-machado/wsl-setup.git
chmod 700 wsl-setup/ -R
cd wsl-setup
./setup.sh
```

## Optional Module Controls

To skip optional modules in Linux setup, set env vars before running [setup.sh](../setup.sh):

```bash
export SSH_DISABLED=1
export GPG_DISABLED=1
./setup.sh
```

## Verification Checklist

After setup finishes:

- `git --version` returns a valid version
- `zsh --version` works
- `node --version` returns a valid version
- `$HOME/repos` directory exists

## Safety Notes

- Existing distros are preserved by default (`replaceExisting: false`)
- Distro replacement only occurs if `replaceIfExists: true` is configured and confirmed (or `-Force` is passed)
