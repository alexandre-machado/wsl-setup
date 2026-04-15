---
phase: 01
slug: windows-bootstrap-hardening
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-15
---

# Phase 01 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none (manual/UAT-first for Windows host flow) |
| **Config file** | none |
| **Quick run command** | `python -c "from pathlib import Path; t=Path('wsl-setup.ps1').read_text(); assert 'Write-PreflightSummary' in t"` |
| **Full suite command** | `bash -n setup.sh scripts/*.sh` |
| **Estimated runtime** | ~10 seconds (static checks only) |

## Sampling Rate

- **After every task commit:** Run the quick static assertion command.
- **After every plan wave:** Run `bash -n setup.sh scripts/*.sh`.
- **Before `/gsd-verify-work`:** run Windows-host UAT scenarios from `01-UAT.md`.
- **Max feedback latency:** 60 seconds

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | BOOT-01 | T-01-01 | Preflight state shown before destructive execution path | static + manual integration | `python3 -c "from pathlib import Path; t=Path('wsl-setup.ps1').read_text(); assert 'Write-PreflightSummary' in t"` | ✅ | ✅ green |
| 01-01-02 | 01 | 1 | BOOT-02 | T-01-02 | Replace path requires explicit Y confirmation before unregister | static + manual integration | `python3 -c "from pathlib import Path; t=Path('wsl-setup.ps1').read_text(); i=t.find('Confirm replace'); j=t.find('wsl --unregister $targetDistro'); assert i!=-1 and j!=-1 and i<j"` | ✅ | ✅ green |
| 01-01-03 | 01 | 1 | BOOT-02 | T-01-02 | Declining replacement routes to non-destructive flow | manual integration | `python3 -c "from pathlib import Path; t=Path('wsl-setup.ps1').read_text(); assert 'Ensure-CreateNewPath' in t"` | ✅ | ⬜ pending |

## Wave 0 Requirements

Existing repo infrastructure and static checks are sufficient for this phase’s planning-time validation artifacts.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Preflight state shown before destructive path on real Windows host | BOOT-01 | Requires WSL/winget runtime state | Run `wsl-setup.ps1` on Windows with existing distro and verify summary appears before mode execution. |
| Confirmation required before replace unregister | BOOT-02 | Requires interactive prompt and WSL runtime | Select `replace-existing`, enter `N`, confirm no unregister occurs; then enter `Y` and confirm unregister path executes. |

## Validation Sign-Off

- [x] All tasks have verify commands or manual-only mapping.
- [x] Sampling continuity documented.
- [x] No watch-mode flags.
- [x] Feedback latency target defined.
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
