# Coding Conventions

**Analysis Date:** 2026-04-14

## Naming Patterns

**Files:**
- Script files use lowercase with hyphen or simple names (for example `setup.sh`, `cleanup.sh`, `scripts/dotfiles.sh`).
- Utility/profile files in `scripts/` may be hidden when intended for shell config (for example `scripts/.zshrc`).

**Functions:**
- Function names are lowercase snake_case in Bash (`echo_info`, `human_size`, `run_tool_clean`).
- Small UI/output helpers are defined inline as one-liners in `cleanup.sh` (`header`, `ok`, `skip`).

**Variables:**
- Environment/global constants use uppercase (`DOTFILES_DIRECTORY`, `GIT_NAME`, `DRY_RUN`, `MIN_CACHE_BYTES`).
- Local function variables use lowercase and `local` in more defensive scripts (`cleanup.sh`).

**Types:**
- Not applicable for Bash; data shape is communicated through naming and comments.

## Code Style

**Formatting:**
- No formatter config detected (`shfmt` config not detected).
- Indentation style is mixed across scripts: 2 spaces in installer scripts, 4 spaces in `cleanup.sh`.
- Use `#!/bin/bash` shebang consistently (present in all `*.sh` scripts).

**Linting:**
- No lint config detected (`shellcheck` config not detected).
- Recommended local check before changes: `bash -n setup.sh cleanup.sh scripts/*.sh`.

## Import Organization

**Order:**
1. Shebang and short header comments.
2. `source ./scripts/utils.sh` for shared helpers.
3. Main execution flow (top-down imperative commands).

**Path Aliases:**
- Not used. Paths are relative (`./scripts/*.sh`) or `$HOME`/absolute system paths.

## Error Handling

**Patterns:**
- Defensive strict mode is used in `cleanup.sh` only: `set -euo pipefail`.
- Most installer scripts rely on command exit behavior without strict mode and continue sequentially.
- Optional behavior is controlled by env toggles (`SSH_DISABLED`, `GPG_DISABLED` in `setup.sh`).

## Logging

**Framework:** console output helpers.

**Patterns:**
- Shared colorized output wrappers in `scripts/utils.sh`: `echo_info`, `echo_success`, `echo_warning`.
- `cleanup.sh` defines local output wrappers (`header`, `ok`, `skip`) and uses sectioned progress reporting.

## Comments

**When to Comment:**
- File-level headers summarize script purpose.
- Inline comments mark task blocks (package install, plugin setup, cleanup stages).

**JSDoc/TSDoc:**
- Not applicable.

## Function Design

**Size:**
- Most scripts are command-oriented and do not create many functions.
- `cleanup.sh` is function-driven and significantly larger; helper extraction keeps repeated logic centralized.

**Parameters:**
- Single-purpose parameter style (for example `clean_dir "$dir"`, `run_tool_clean <tool> <command>`).

**Return Values:**
- Functions primarily report via stdout and command exit status.

## Module Design

**Exports:**
- Shared state is sourced via environment and script sourcing (`source ./scripts/user.sh`, `source ./scripts/utils.sh`).

**Barrel Files:**
- Not applicable.

## Shell Safety Patterns

- Prefer strict mode from `cleanup.sh` (`set -euo pipefail`) in new non-interactive scripts.
- Quote variable expansions in commands and tests (`"$HOME"`, `"$dir"`), matching most of `cleanup.sh`.
- Preserve dry-run support for destructive operations, following `cleanup.sh --dry-run` behavior.
- Use guarded command checks for optional tools (`command -v yarn`, `command -v npm`, `command -v uv`, `command -v brew`).
- Keep privileged commands explicit and isolated (`sudo apt`, `sudo journalctl`) so review surface is clear.

## Prescriptive Guidance For New Scripts

- Place reusable output/helper logic in `scripts/utils.sh`; source it from entry scripts.
- For new maintenance scripts, follow `cleanup.sh` structure: argument parser, discovery phase, execute phase, summary report.
- For setup scripts, keep top-down readable flow like `setup.sh` and idempotent checks where possible.
- Use English-only user-facing text if consistency with existing mixed Portuguese/English output is not required by the feature.

---

*Convention analysis: 2026-04-14*
