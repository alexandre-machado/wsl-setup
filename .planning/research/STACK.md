# Stack Research

**Project:** WSL Setup Revamp
**Milestone:** v1.1 Windows Setup Simplification
**Researched:** 2026-04-14
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| PowerShell entrypoint | Windows PowerShell 5.1+ | Host-side bootstrap and WSL handoff | Keep the existing `wsl-setup.ps1` path. It is enough for the Windows-first flow and avoids adding a new installer framework or a PowerShell 7 migration. |
| Microsoft WSL | Latest stable `Microsoft.WSL` package / WSL 2 | Provision and update the Linux environment on Windows | Microsoft documents `wsl --install` as the supported install path on Windows 10 2004+ and Windows 11. The repo should stay on that supported path instead of manual unregister/reinstall logic. |
| Ubuntu LTS distro | Ubuntu 24.04 LTS | Default Linux target for the setup flow | The repo already targets `Ubuntu-24.04`. Keeping one LTS target reduces branching, keeps docs simple, and avoids distro drift. |
| Bash + apt on WSL | Built-in to Ubuntu 24.04 LTS | Linux orchestration and system package installation | Preserve the current shell-based architecture. Bash and apt are the right fit for this brownfield toolkit and do not need replacement. |
| NVM-managed Node.js | Node.js 24.x LTS | Runtime for Node-based tooling in the setup path | Replace `nvm install 18` with a supported LTS line. Node 18 is EOL; Node 24 is the current long-lived supported line and keeps modern package-manager support available. |
| Corepack | Bundled with Node.js 24.x LTS | Package-manager shims for future Yarn/pnpm use | If JS package-manager support is needed later, Corepack lets the repo use Yarn or pnpm without a separate global install or another apt source. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Git | Latest stable from `git-core/ppa` | Clone the repo and manage user identity | Keep the current Git PPA path if you want a newer Git than the base Ubuntu archive provides. |
| OpenSSH | Ubuntu package set | Optional SSH key setup | Keep for the existing optional SSH workflow; no new SSH stack is needed. |
| GnuPG | Ubuntu package set | Optional GPG key setup | Keep for the existing optional GPG workflow; no new crypto tooling is needed. |
| Windows Package Manager (`winget`) | Stable App Installer channel | Install or repair WSL from Windows | Use it as the host-side bootstrap dependency; do not add a second Windows installer mechanism. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `wsl.exe` | Launch and manage WSL distros | Use `--install -d Ubuntu-24.04`, `--update`, and `--set-default` rather than destroying and recreating an existing distro. |
| `winget` | Windows package installation and repair | The stable client is enough; do not require preview builds or Insider channels. |
| `curl` | Remote install bootstrap in Linux | Keep only where the repo already uses trusted upstream bootstrap scripts. Avoid adding new curl-pipe installers. |
| `apt` | Ubuntu system package management | Stay with apt for OS packages; do not move this repo to Snap, Flatpak, Homebrew, or a custom package layer. |

## Installation

```bash
# Windows host prerequisites
winget install --id Microsoft.WSL --exact
wsl --update
wsl --install -d Ubuntu-24.04

# Inside WSL
nvm install 24
corepack enable  # only if the project later needs Yarn/pnpm shims
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| NVM + Node.js 24.x LTS | NodeSource apt bootstrap + Node 18 | Only if you want a second Node source and are willing to keep an EOL runtime; otherwise NVM is cleaner and safer. |
| Corepack | `apt install yarn` | Only if you are deliberately maintaining a Yarn Classic dependency tree; this repo does not need that complexity. |
| `wsl --install -d Ubuntu-24.04` with idempotent checks | `wsl --unregister Ubuntu-24.04` followed by reinstall | Only for destructive clean-room reprovision; it is not appropriate for first-run bootstrap because it can erase an existing distro. |
| Keep Bash/PowerShell split | Rewrite bootstrap in a new language or installer framework | Only if the project is intentionally leaving shell automation behind; that would be overkill for this milestone. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Node.js 18 | It is EOL and no longer a supported default for a fresh workstation setup | Node.js 24.x LTS via NVM |
| `apt install yarn` | It adds a redundant package manager and is easy to misconfigure in Ubuntu-based setups | Corepack, or no package-manager install at all until the repo actually needs one |
| A Windows GUI installer | It would broaden scope without improving the shell-first workflow enough to justify the cost | Keep the PowerShell bootstrap entrypoint |
| Multiple WSL distro targets | It increases docs and validation burden for little benefit | Standardize on Ubuntu 24.04 LTS |
| Destroy-and-recreate bootstrap behavior | It risks user data loss and makes first-run setup brittle | Idempotent install/update checks |

## Stack Patterns by Variant

**If the user is setting up a brand-new Windows machine:**
- Use `winget` to ensure WSL is available.
- Install or update WSL with `wsl.exe`.
- Target Ubuntu 24.04 LTS explicitly.
- Because this keeps the Windows path one-command simple and repeatable.

**If the user already has WSL and Ubuntu installed:**
- Skip host reinstalls and hand off directly to the Bash orchestrator.
- Keep the existing shell modules intact.
- Because the repo should be idempotent instead of destructive.

**If future JavaScript tooling is added to the repo:**
- Use Node.js 24.x LTS plus Corepack.
- Avoid adding global Yarn or pnpm installation steps.
- Because Corepack already covers package-manager shims without another install surface.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Node.js 24.x LTS | Corepack bundled in Node <25.0.0 | Corepack is available in the recommended Node line, so no separate package-manager install is required. |
| WSL 2 | Windows 10 version 2004+ / Windows 11 | Microsoft documents `wsl --install` for those host versions; keep the docs aligned to that requirement. |
| WinGet | Windows 10 version 1809+ / Windows 11 | The client is supported on modern Windows builds, but WSL install commands still need the newer WSL-capable host baseline. |
| Ubuntu 24.04 LTS | WSL 2 | Matches the repo's current distro target and keeps the Linux side stable. |
| Node.js 18 | None recommended | Treat it as retired for new setup defaults. |

## Sources

- Microsoft Learn - WSL install: https://learn.microsoft.com/en-us/windows/wsl/install
- Microsoft Learn - WinGet: https://learn.microsoft.com/en-us/windows/package-manager/winget/
- Node.js releases: https://nodejs.org/en/about/previous-releases
- Node.js Corepack docs: https://nodejs.org/api/corepack.html
- Repo implementation references: `wsl-setup.ps1`, `scripts/apps.sh`, `scripts/npm.sh`, `README.md`

---
*Stack research for: Windows-first WSL bootstrap simplification*
*Researched: 2026-04-14*
