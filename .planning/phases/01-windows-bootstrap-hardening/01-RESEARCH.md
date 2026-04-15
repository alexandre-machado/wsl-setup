# Phase 1 Research: Windows Bootstrap Hardening

**Researched:** 2026-04-15  
**Requirements:** BOOT-01, BOOT-02

## Findings

Current `wsl-setup.ps1` already includes:
1. preflight WSL state detection and summary output before mode selection,
2. explicit confirmation before destructive unregister flow,
3. non-destructive continuation when destructive confirmation is declined.

Primary gap to close in planning/execution: `replace-existing` remains selectable even when target distro is absent, so destructive eligibility should be hard-gated after preflight and before branch execution.

## Relevant Files

- `wsl-setup.ps1` (primary implementation surface for Phase 1)
- `setup.sh` (handoff target after bootstrap decision)
- `README.md` (document user-facing bootstrap safety flow)
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/phases/01-windows-bootstrap-hardening/01-UAT.md`

## Recommended Implementation Direction

1. Add explicit mode eligibility checks (especially for `replace-existing`) before execution.
2. Preserve confirmation gate before any `wsl --unregister`.
3. Keep decline path non-destructive and message it clearly for UAT traceability.
4. Update docs to describe the safety flow users will see.

## Risks

- Locale-sensitive output parsing in `Get-WslPackageInstalled` may be brittle.
- User-provided values passed into shell handoff command should remain carefully quoted/escaped.

## Validation Notes

No automated Windows-host test harness is currently present for this phase; validation is currently UAT-driven via `01-UAT.md`.
