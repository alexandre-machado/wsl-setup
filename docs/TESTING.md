# Testing

## Current Testing Model

This repository currently uses script-level validation and manual end-to-end checks.

There is no formal automated test framework configured in the root project.

## Quick Automated Checks

Run Bash syntax validation:

```bash
bash -n setup.sh
bash -n cleanup.sh
for f in scripts/*.sh; do bash -n "$f"; done
```

Run PowerShell Dry-Run validation:

```pwsh
pwsh -File .\wsl-setup.ps1 -DryRun
```

## Manual Verification Scenarios

### Windows bootstrap dry-run

1. Run `pwsh -File .\wsl-setup.ps1 -DryRun`
2. Confirm preflight provisioning plan summary appears with all configured distros
3. Confirm dry-run completes cleanly without mutating system state

### Linux setup flow

1. Run [setup.sh](../setup.sh)
2. Confirm apps, dotfiles, and npm modules run in order
3. Confirm optional SSH/GPG modules can be skipped via env flags

### Cleanup utility

1. Run dry-run mode:

```bash
./cleanup.sh --dry-run
```

2. Review reported targets and potential reclaim
3. Run actual cleanup only when output looks correct

## Regression Checklist

Before merging script changes:

- Bash syntax checks pass
- Bootstrap safety markers still present
- README and docs reflect changed behavior
- No secrets introduced into docs or scripts
