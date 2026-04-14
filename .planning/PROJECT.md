# WSL Setup Revamp

## What This Is

WSL Setup Revamp modernizes an existing WSL bootstrap toolkit for Debian/Ubuntu users on Windows. It keeps the current shell-based setup flow while improving reliability, maintainability, and onboarding speed. The immediate focus is to simplify the Windows entry path and refresh version-pinned tooling to current, stable choices.

## Core Value

A Windows user should be able to run one guided path and end with a working, modern WSL developer environment with minimal manual fixes.

## Requirements

### Validated

- ✓ Provide a Windows bootstrap path that can launch WSL setup — existing (`wsl-setup.ps1`)
- ✓ Provide a Linux orchestrator for setup modules — existing (`setup.sh`)
- ✓ Install core CLI/dev tooling via apt-based scripts — existing (`scripts/apps.sh`)
- ✓ Configure shell and dotfiles for daily workflow — existing (`scripts/dotfiles.sh`)
- ✓ Support Node/npm setup through NVM — existing (`scripts/npm.sh`)
- ✓ Support optional SSH and GPG setup — existing (`scripts/ssh.sh`, `scripts/gpg.sh`)
- ✓ Provide cleanup tooling for post-install maintenance — existing (`cleanup.sh`)

### Active

- [ ] Simplify and harden Windows bootstrap flow so first-run setup is predictable and low-friction.
- [ ] Review and update pinned tool/library versions to current supported defaults.
- [ ] Reduce setup complexity by consolidating duplicate or confusing steps across scripts.
- [ ] Improve script safety/validation so failures are clear and recoverable.
- [ ] Improve docs so Windows-first users can choose the fastest successful install path.

### Out of Scope

- Building a GUI installer — not required for current shell-first workflow.
- Supporting non-Debian/Ubuntu WSL distributions — currently unsupported and increases complexity.
- Replacing shell scripts with a new implementation language — not required to deliver the revamp goal.

## Context

This repository already provides a working brownfield setup system with a PowerShell entrypoint and Bash module pipeline. Existing code is script-driven (Bash + PowerShell), with no package-lock ecosystem and no formal test suite. The revamp should preserve the current mental model (entrypoint + orchestrator + modules) while reducing onboarding friction, especially for Windows users invoking setup from PowerShell.

## Constraints

- **Compatibility**: Must continue supporting Windows 10/11 + WSL2 with Debian/Ubuntu-based distros — matches current user base and docs.
- **Tech Stack**: Keep Bash/PowerShell architecture with incremental improvements — minimizes migration risk.
- **Security**: Avoid introducing insecure defaults in bootstrap steps (credential/key handling, remote script usage) — setup runs with elevated privileges in parts of the flow.
- **Usability**: Windows-first install path should minimize required manual commands — core revamp objective.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Treat this as a brownfield revamp, not a rewrite | Existing scripts already deliver value and are in use | — Pending |
| Prioritize Windows bootstrap simplification in early phases | Primary request is to simplify setup on Windows | — Pending |
| Keep shell-based architecture and improve in place | Lowest-risk route to fast improvements | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -> still the right priority?
3. Audit Out of Scope -> reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-14 after initialization*
