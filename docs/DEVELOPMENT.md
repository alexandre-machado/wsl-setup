# Development

## Repository Layout

- [wsl-setup.ps1](../wsl-setup.ps1): Windows bootstrap entrypoint
- [setup.sh](../setup.sh): Linux orchestrator script
- [scripts](../scripts): setup modules and shared helpers
- [cleanup.sh](../cleanup.sh): maintenance/cleanup utility
- [docs](../docs): generated and maintained documentation

## Local Editing Workflow

1. Create a feature branch:

```bash
git checkout -b feature/my-change
```

2. Edit scripts and docs
3. Run quick validations (shell syntax and command checks)
4. Commit and push

## Recommended Script Checks

### Bash syntax checks

```bash
bash -n setup.sh
bash -n cleanup.sh
for f in scripts/*.sh; do bash -n "$f"; done
```

### Basic grep-based safety checks (bootstrap)

```bash
grep -n "preflight\|replace-existing\|Y/N\|No destructive fallback" wsl-setup.ps1
```

## Development Conventions

- Keep scripts small and focused by concern
- Prefer explicit, sequential control flow over hidden side effects
- Keep destructive operations behind clear prompts and confirmation gates
- Document behavior changes in [README.md](../README.md) and [docs](../docs)

## Modifying Windows Bootstrap

When updating [wsl-setup.ps1](../wsl-setup.ps1):

- Preserve preflight visibility before destructive paths
- Keep default mode non-destructive
- Ensure replace flow remains confirmation-gated
- Keep Bash handoff stable for existing setup path

## Modifying Linux Modules

When updating scripts under [scripts](../scripts):

- Preserve compatibility with [setup.sh](../setup.sh)
- Keep `GIT_NAME` / `GIT_EMAIL` propagation intact
- Validate optional module flags (`SSH_DISABLED`, `GPG_DISABLED`)

## Commit Scope Guidance

- `feat`: new behavior or user-facing flow
- `fix`: correctness/safety fixes
- `docs`: documentation-only changes
- `chore`: non-functional maintenance
