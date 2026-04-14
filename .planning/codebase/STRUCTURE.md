# Codebase Structure

**Analysis Date:** 2026-04-14

## Directory Layout

```
wsl-setup/
├── scripts/                 # Modular installers and shared shell helpers
├── .planning/codebase/      # Generated architecture/quality/intel mapping docs
├── setup.sh                 # Main Linux orchestrator entry point
├── cleanup.sh               # Post-setup cleanup/report utility
├── wsl-setup.ps1            # Windows bootstrap and WSL handoff
└── README.md                # Usage, prerequisites, install flows
```

## Directory Purposes

**scripts/:**
- Purpose: Holds setup modules and shared runtime helpers.
- Contains: Install scripts (`apps.sh`, `dotfiles.sh`, `npm.sh`, `ssh.sh`, `gpg.sh`), context/helper scripts (`user.sh`, `utils.sh`), managed shell profile (`.zshrc`).
- Key files: `scripts/utils.sh`, `scripts/user.sh`, `scripts/apps.sh`, `scripts/dotfiles.sh`.

**.planning/codebase/:**
- Purpose: Stores generated mapping artifacts for planning/execution agents.
- Contains: Markdown documents such as `ARCHITECTURE.md`, `STRUCTURE.md`.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`.

## Key File Locations

**Entry Points:**
- `setup.sh`: Primary Linux install orchestrator.
- `wsl-setup.ps1`: Windows bootstrap that installs WSL and runs Linux setup.
- `cleanup.sh`: Optional cleanup and disk-usage reporting utility.

**Configuration:**
- `scripts/user.sh`: Identity variables (`GIT_NAME`, `GIT_EMAIL`) exported for downstream scripts.
- `scripts/.zshrc`: Shell configuration materialized into user home.

**Core Logic:**
- `scripts/apps.sh`: Apt/packages/tooling installation.
- `scripts/dotfiles.sh`: Shell, plugins, and Git global config.
- `scripts/npm.sh`: NVM/Node setup.
- `scripts/ssh.sh`: SSH key generation and agent setup.
- `scripts/gpg.sh`: GPG key creation and Git signing config.
- `scripts/utils.sh`: Shared output helpers and file replacement function.

**Testing:**
- Not detected (no test directory or test runner config in repository root).

## Naming Conventions

**Files:**
- Lowercase shell filenames by concern, typically one domain per script: `apps.sh`, `dotfiles.sh`, `user.sh`.
- Root scripts represent operator entry points: `setup.sh`, `cleanup.sh`, `wsl-setup.ps1`.

**Directories:**
- `scripts/` for executable/setup modules.
- `.planning/` for generated planning artifacts.

## Where to Add New Code

**New Setup Feature:**
- Primary code: add a new module in `scripts/<feature>.sh`.
- Orchestration hook: call the module from `setup.sh` in the appropriate sequence.

**New Shared Behavior:**
- Reusable shell helpers: extend `scripts/utils.sh`.
- Shared input/context variables: extend `scripts/user.sh` and export variables for module use.

**New Windows Bootstrap Logic:**
- Implement in `wsl-setup.ps1` only for concerns that must run before entering WSL.

**New Maintenance/Cleanup Capability:**
- Implement in `cleanup.sh` when behavior is operational and independent of install pipeline.

## Special Directories

**.planning/:**
- Purpose: Agent-generated roadmap/intelligence artifacts.
- Generated: Yes.
- Committed: Yes (present in repository).

**scripts/:**
- Purpose: Source of installer modules consumed by `setup.sh`.
- Generated: No.
- Committed: Yes.

---

*Structure analysis: 2026-04-14*
