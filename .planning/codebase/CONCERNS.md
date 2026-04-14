# Codebase Concerns

**Analysis Date:** 2026-04-14

## Tech Debt

**Inconsistent shell safety model:**
- Issue: Only `cleanup.sh` uses strict mode (`set -euo pipefail`); install scripts run without equivalent guardrails.
- Files: `cleanup.sh`, `setup.sh`, `scripts/apps.sh`, `scripts/dotfiles.sh`, `scripts/npm.sh`, `scripts/ssh.sh`, `scripts/gpg.sh`
- Impact: Silent partial setup and hard-to-diagnose state drift when a mid-pipeline command fails.
- Fix approach: Apply strict mode to non-interactive scripts and add explicit error handling for interactive steps.

**Duplicated context sourcing and side effects:**
- Issue: `scripts/utils.sh` sources `scripts/user.sh`, while `setup.sh` also sources `scripts/user.sh` directly.
- Files: `scripts/utils.sh`, `scripts/user.sh`, `setup.sh`
- Impact: Repeated prompts/exports are easy to reintroduce when scripts are reused in different entry paths.
- Fix approach: Keep `user.sh` sourcing in one orchestrator layer only; keep utility files side-effect free.

## Known Bugs

**Destructive bootstrap resets existing distro:**
- Symptoms: Existing `Ubuntu-24.04` instance is removed before install.
- Files: `wsl-setup.ps1`
- Trigger: Running the PowerShell bootstrap path.
- Workaround: Comment/remove `wsl --unregister Ubuntu-24.04` before execution.

**Duplicate `mkdir` argument in setup:**
- Symptoms: Same directory path is passed twice.
- Files: `setup.sh`
- Trigger: Always during setup tail stage (`mkdir ${HOME}/repos ${HOME}/repos`).
- Workaround: Use `mkdir -p "${HOME}/repos"`.

## Security Considerations

**Remote script execution without pinning or verification:**
- Risk: Supply-chain compromise can execute arbitrary code during bootstrap/install.
- Files: `README.md`, `wsl-setup.ps1`, `scripts/apps.sh`, `scripts/dotfiles.sh`
- Current mitigation: HTTPS transport only.
- Recommendations: Pin versions/commits, verify checksums/signatures, and avoid pipe-to-shell where possible.

**Unprotected local GPG private key generation:**
- Risk: `%no-protection` generates an unencrypted private key on disk.
- Files: `scripts/gpg.sh`
- Current mitigation: None detected.
- Recommendations: Remove `%no-protection` and require passphrase (or explicit opt-out flag with warning).

## Performance Bottlenecks

**Heavy disk scans in cleanup path:**
- Problem: Full `$HOME` and multi-directory `du -sb` scans are expensive on large home directories.
- Files: `cleanup.sh`
- Cause: Snapshot/reporting computes many sizes sequentially, including full-home totals.
- Improvement path: Make full-home scan optional, parallelize independent size checks, and cache pre/post target sizes only.

## Fragile Areas

**Global shell/user config mutation is not idempotent:**
- Files: `scripts/dotfiles.sh`, `scripts/ssh.sh`, `scripts/.zshrc`
- Why fragile: Re-runs can duplicate config lines, re-clone into existing directories, and force shell changes unexpectedly.
- Safe modification: Add existence checks and append guards (`grep -q` before write, skip clone if dir exists).
- Test coverage: No automated tests detected for repeat-run behavior.

**Cleanup can remove broad cache targets:**
- Files: `cleanup.sh`
- Why fragile: Dynamic target discovery and `rm -rf` can remove large tool caches required for offline or deterministic workflows.
- Safe modification: Add allowlist confirmation mode and preserve marker files for protected caches.
- Test coverage: No automated tests for target selection safety.

## Scaling Limits

**Single-machine bootstrap assumptions:**
- Current capacity: Optimized for one developer workstation and one WSL distro name (`Ubuntu-24.04`).
- Limit: Multi-user/team rollout lacks parameterization, profile separation, and environment matrices.
- Scaling path: Add CLI flags/config file for distro name, package profile, and optional modules.

## Dependencies at Risk

**Third-party installers fetched at runtime:**
- Risk: Upstream script changes can break setup or introduce insecure behavior.
- Impact: Setup reproducibility and security posture degrade unpredictably.
- Migration plan: Replace runtime installer pipes with pinned package sources or vendored install logic.

## Missing Critical Features

**No preflight validation gate:**
- Problem: Setup starts before verifying required tools/network/permissions.
- Blocks: Reliable unattended execution and clear early failure diagnostics.

**No rollback/recovery path:**
- Problem: Setup and cleanup are mostly irreversible once run.
- Blocks: Safe experimentation and quick recovery from partial installs.

## Test Coverage Gaps

**No automated regression suite:**
- What's not tested: Setup idempotency, bootstrap safety, destructive-path guards, and failure handling.
- Files: `setup.sh`, `wsl-setup.ps1`, `cleanup.sh`, `scripts/*.sh`
- Risk: Breakages surface only during live user runs.
- Priority: High

---

*Concerns audit: 2026-04-14*
