# Contributing

## Scope

This repository provides scripts for Windows-first WSL bootstrap and Linux developer environment setup.

Contributions should prioritize safety, repeatability, and clear user guidance.

## How to Contribute

1. Fork the repository
2. Create a branch from `main`
3. Make focused changes
4. Validate scripts locally
5. Open a pull request with clear before/after behavior notes

## Local Validation Before PR

Run these checks:

```bash
bash -n setup.sh
bash -n cleanup.sh
for f in scripts/*.sh; do bash -n "$f"; done
```

If you changed [wsl-setup.ps1](wsl-setup.ps1), also verify key safety markers:

```bash
grep -n "preflight\|replace-existing\|Y/N\|No destructive fallback" wsl-setup.ps1
```

## Contribution Guidelines

- Keep changes small and reviewable
- Preserve non-destructive defaults in bootstrap flows
- Gate destructive operations with explicit confirmation
- Update docs when behavior changes
- Avoid introducing new external dependencies unless necessary

## Commit Message Guidance

Use concise, scoped commits:

- `feat:` for new behavior
- `fix:` for bug/safety fixes
- `docs:` for documentation-only changes
- `chore:` for maintenance updates

## Pull Request Checklist

- [ ] Change is focused and justified
- [ ] Local validation commands were run
- [ ] Documentation updated where needed
- [ ] No secrets or tokens added
- [ ] Destructive behavior remains explicit and confirmed
