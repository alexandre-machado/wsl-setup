# Architecture

**Analysis Date:** 2026-04-14

## Pattern Overview

**Overall:** Scripted pipeline architecture with one orchestrator and task-specific modules.

**Key Characteristics:**
- One top-level Linux orchestrator (`setup.sh`) executes install modules in a fixed sequence.
- Cross-platform bootstrap boundary from Windows PowerShell (`wsl-setup.ps1`) into WSL Bash (`setup.sh`).
- Shared utility and user-context scripts (`scripts/utils.sh`, `scripts/user.sh`) are sourced by most modules.

## Layers

**Windows Bootstrap Layer:**
- Purpose: Install/prepare WSL and hand off execution to Linux setup.
- Location: `wsl-setup.ps1`
- Contains: `winget`/`wsl` commands, interactive prompts for Git identity, `wsl ... bash -lc` handoff.
- Depends on: Windows `winget`, `wsl`, network access, GitHub clone.
- Used by: Windows-first installation flow.

**Linux Orchestration Layer:**
- Purpose: Coordinate full environment setup sequence.
- Location: `setup.sh`
- Contains: Ordered execution of modules (`apps.sh`, `dotfiles.sh`, `npm.sh`, optional `ssh.sh`/`gpg.sh`), cleanup, final messaging.
- Depends on: `scripts/utils.sh`, `scripts/user.sh`, module scripts.
- Used by: Native WSL setup flow and PowerShell bootstrap flow.

**Task Module Layer:**
- Purpose: Execute focused setup concerns per script.
- Location: `scripts/apps.sh`, `scripts/dotfiles.sh`, `scripts/npm.sh`, `scripts/ssh.sh`, `scripts/gpg.sh`
- Contains: Package installs, shell/dotfile setup, Node/NVM setup, key generation.
- Depends on: Shared helpers from `scripts/utils.sh`, exported identity vars from `scripts/user.sh`.
- Used by: `setup.sh`.

**Shared Context/Utilities Layer:**
- Purpose: Provide reusable console output helpers and identity data.
- Location: `scripts/utils.sh`, `scripts/user.sh`
- Contains: `echo_*` helper functions, `replace` function, `GIT_NAME`/`GIT_EMAIL` export flow.
- Depends on: shell built-ins and `tput`.
- Used by: Most module scripts and `setup.sh`.

**Maintenance Layer:**
- Purpose: Post-install cleanup and disk recovery.
- Location: `cleanup.sh`
- Contains: Dynamic target discovery, dry-run/reporting mode, cache/tool cleanup.
- Depends on: system tools (`du`, `df`, `bc`, `apt`, `journalctl`) and optional package managers.
- Used by: Manual operator invocation after setup.

## Data Flow

**Windows Bootstrap -> WSL Setup Flow:**

1. `wsl-setup.ps1` verifies/installs WSL, updates distro state, collects Git identity.
2. `wsl-setup.ps1` launches `wsl ... bash -lc` to clone repository and run `./setup.sh`.
3. `setup.sh` sources shared scripts and invokes module scripts in sequence.

**Native WSL Setup Flow:**

1. User clones repository and runs `./setup.sh`.
2. `setup.sh` sources `scripts/utils.sh` and `scripts/user.sh` to establish helpers/context.
3. Module scripts execute side effects (APT, Git config, shell profile, SSH/GPG).

**State Management:**
- Runtime state is shell environment-based (`GIT_NAME`, `GIT_EMAIL`, optional `SSH_DISABLED`, `GPG_DISABLED`).
- Persistent state is file/system side effects (`~/.zshrc`, `~/.ssh`, global Git config, installed packages).

## Key Abstractions

**Module Script as Capability Unit:**
- Purpose: Keep setup concerns isolated by domain and callable from one orchestrator.
- Examples: `scripts/apps.sh`, `scripts/dotfiles.sh`, `scripts/npm.sh`, `scripts/ssh.sh`, `scripts/gpg.sh`
- Pattern: Source shared context, run ordered shell commands, emit status via helper functions.

**Shared Helper Interface:**
- Purpose: Normalize output formatting and file replacement behavior across modules.
- Examples: `scripts/utils.sh`
- Pattern: Global vars/functions sourced into module runtime (`echo_info`, `echo_success`, `replace`).

## Entry Points

**Main Installer:**
- Location: `setup.sh`
- Triggers: Direct user execution in WSL; invoked indirectly from `wsl-setup.ps1`.
- Responsibilities: End-to-end install orchestration and terminal cleanup.

**Windows Bootstrap Installer:**
- Location: `wsl-setup.ps1`
- Triggers: One-liner `irm ... | iex` or direct PowerShell execution.
- Responsibilities: Install/prepare WSL and bridge into Linux installer.

**Cleanup Utility:**
- Location: `cleanup.sh`
- Triggers: Manual execution, optionally with `--dry-run`.
- Responsibilities: Cache/disposable data removal and before/after usage reporting.

## Error Handling

**Strategy:** Fail-fast only in cleanup path; best-effort execution in setup modules.

**Patterns:**
- Strict mode enabled in `cleanup.sh` (`set -euo pipefail`) to stop on command/variable/pipeline errors.
- Setup scripts generally rely on command exit behavior without strict mode; optional steps gated by env flags in `setup.sh`.

## Cross-Cutting Concerns

**Logging:** Shared terminal messaging wrappers in `scripts/utils.sh`; cleanup script has local formatting helpers.
**Validation:** Argument validation exists in `cleanup.sh` (`--dry-run`, `--help`); setup flow has minimal precondition checks.
**Authentication:** Git identity from `scripts/user.sh`; SSH key flow in `scripts/ssh.sh`; GPG signing setup in `scripts/gpg.sh`.

---

*Architecture analysis: 2026-04-14*
