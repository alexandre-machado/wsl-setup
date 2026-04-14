# Project Research Summary

**Project:** WSL Setup Revamp
**Domain:** Windows-first WSL bootstrap toolkit for shell-based developer environment setup
**Researched:** 2026-04-14
**Confidence:** HIGH

## Executive Summary

This is a brownfield Windows-to-WSL onboarding tool, not a greenfield installer. Experts should keep the existing PowerShell entrypoint and Bash module pipeline, but harden the handoff, make state detection explicit, and keep Linux configuration logic inside the shell layer. The right shape is a guided Windows front door that validates prerequisites, captures intent once, and then delegates to a predictable Linux orchestrator.

The strongest recommendation is to optimize for safety before convenience: preserve existing WSL state by default, add preflight checks before any mutation, and make reruns converge instead of drift. The biggest risks are destructive reset behavior, hidden side effects from over-centralized shell logic, and version refreshes that are applied without compatibility checks. Those are manageable if the roadmap treats bootstrap hardening, idempotency, and documentation updates as separate but connected phases.

## Key Findings

### Recommended Stack

See [STACK.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/STACK.md) for the detailed versioning rationale. The stack should stay close to the current architecture: PowerShell for Windows bootstrap, WSL 2 on Ubuntu 24.04 LTS, Bash and apt for Linux orchestration, and NVM-managed Node.js on a supported LTS line. The important modernization choice is to move off Node 18 and onto Node 24.x LTS, with Corepack available for future package-manager flexibility. Keep winget and the supported wsl.exe install/update path on the Windows side; avoid introducing a second installer framework.

**Core technologies:**
- PowerShell 5.1+ as the Windows entrypoint: host-side bootstrap and WSL handoff — keeps the current wsl-setup.ps1 flow and avoids a rewrite.
- Microsoft WSL 2: Linux environment provisioning — follows the supported wsl --install path and aligns with Windows host support.
- Ubuntu 24.04 LTS: default distro target — reduces branching and matches the repo’s current Debian/Ubuntu focus.
- Bash plus apt: Linux orchestration and package installation — preserves the brownfield shell architecture.
- Node.js 24.x LTS via NVM: runtime for Node-based tooling — replaces EOL Node 18 with a supported line.
- Corepack: package-manager shims — enables future Yarn/pnpm support without extra global installs.

### Expected Features

See [FEATURES.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/FEATURES.md). The product must feel safe and guided, not just less broken. Users expect one obvious Windows entrypoint, clear preflight checks, explicit choice points for optional SSH/GPG setup, and reruns that repair or converge instead of wiping state. The differentiator is a recovery-aware flow that summarizes what happened and what remains, rather than an opaque bootstrap script.

**Must have (table stakes):**
- Single guided Windows entrypoint — users should not need to understand both PowerShell and Bash just to start.
- Preflight checks before changes — the installer must fail early on missing prerequisites.
- Non-destructive existing-install handling — reruns should repair or continue, not unregister a working distro.
- Clear Git identity capture — name and email should be collected once and reused.
- Explicit optional SSH and GPG setup — key generation should be opt-in, not surprising.
- Idempotent module reruns — retries must not duplicate config or break state.
- Clear progress and final state reporting — users need to know what completed and what was skipped.

**Should have (competitive):**
- Safe first-run bootstrap with confirmation gates — reduces anxiety around WSL setup.
- One decision screen for setup choices — captures distro, optional keys, and install mode once.
- Recovery-aware rerun mode — allows partial failures to be resumed safely.
- Version-pinned stable defaults — keeps the environment aligned with supported releases.
- Post-install health summary — improves trust and reduces support questions.

**Defer (v2+):**
- Broad distro support beyond Ubuntu/Debian — adds branching and testing burden.
- GUI installer rewrite — too much scope for this milestone.
- Deeper recovery automation beyond clear rerun and repair behavior — valuable later, not required for v1.1.

### Architecture Approach

See [ARCHITECTURE.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/ARCHITECTURE.md). The architecture should remain explicitly layered: Windows bootstrap does host-side checks and launches WSL; a thin Bash orchestrator validates the handoff and runs modules in a fixed order; task modules own one concern each; shared utilities stay side-effect free; maintenance stays in a separate cleanup path. The critical design rule is to keep the PowerShell-to-Bash contract explicit and minimal so the two halves do not drift into duplicated logic or hidden state.

**Major components:**
1. wsl-setup.ps1 — Windows-side preflight, distro preparation, user input capture, and handoff.
2. setup.sh — Linux-side orchestration and module sequencing.
3. scripts/ modules and shared helpers — per-concern setup logic for apps, dotfiles, npm, SSH, GPG, identity, and utilities.
4. cleanup.sh — standalone maintenance and space-recovery path.

### Critical Pitfalls

See [PITFALLS.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/PITFALLS.md). The biggest hazards are not subtle: destructive resets, late validation, hidden side effects, and version bumps that are not tested against the actual bootstrap path. The right mitigation is to treat existing state as input, validate before mutation, keep utility code free of prompts and writes, and validate both fresh and rerun scenarios whenever defaults change.

1. **Making the bootstrap simpler by resetting the user’s existing WSL state** — preserve existing distros by default and require explicit opt-in for reset.
2. **Pushing validation until after the first real mutation** — run Windows and Linux preflights before any package install, write, or unregister action.
3. **Refactoring duplicated setup steps into hidden side effects** — keep prompts and writes in one orchestration layer and make utilities idempotent.
4. **Treating dependency modernization as just bumping versions** — update versions, installer behavior, and docs together, then validate fresh and rerun paths.
5. **Optimizing for first-run success while abandoning rerun and repair behavior** — add skip/reuse logic so repeated runs converge safely.

## Implications for Roadmap

Based on the research, the roadmap should start with safety gates, then clean up the Linux-side setup behavior, then finish by hardening documentation and rerun behavior. That sequencing follows the dependency chain in [ARCHITECTURE.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/ARCHITECTURE.md): the handoff must be stable before module simplification, and module idempotency must exist before recovery-focused documentation can be trusted.

### Phase 1: Windows Bootstrap Hardening

**Rationale:** This is the highest-risk part of the experience and the only phase that can prevent destructive behavior before it starts. It must come first because every downstream improvement depends on a predictable host-side handoff.

**Delivers:** A safer PowerShell entrypoint with explicit preflight checks, non-destructive WSL state detection, and confirmation gates for any reset-like behavior.

**Addresses:** Single guided Windows entrypoint, preflight checks, non-destructive existing-install handling, clear progress reporting.

**Avoids:** The destructive distro reset pitfall and the late-validation pitfall.

**Research flag:** No deep new research required; the pattern is standard and already anchored by Microsoft’s documented WSL install path.

### Phase 2: Script Consolidation and Dependency Refresh

**Rationale:** Once the host handoff is safe, the next highest leverage work is to make the Linux pipeline converge cleanly and move the toolchain onto supported defaults. This phase can be executed without changing the overall execution order.

**Delivers:** Idempotent module reruns, explicit Git identity flow, safer optional SSH/GPG gating, and updated stable defaults such as Node 24.x LTS.

**Uses:** PowerShell-to-Bash environment handoff, NVM, Corepack, apt, and the existing module structure.

**Implements:** The orchestrator-plus-modules architecture, especially setup.sh, scripts/user.sh, scripts/dotfiles.sh, scripts/npm.sh, scripts/ssh.sh, and scripts/gpg.sh.

**Addresses:** Idempotent reruns, clear Git identity capture, optional key setup, version-pinned stable defaults.

**Avoids:** Hidden side effects from consolidation and modernization without compatibility review.

**Research flag:** Light validation only, primarily to confirm version compatibility and rerun behavior on both fresh and already-provisioned machines.

### Phase 3: Documentation and Recovery Validation

**Rationale:** Docs and recovery guidance should reflect the real behavior, not the intended behavior. This phase belongs last because it depends on the earlier phases proving that reruns and repair paths are actually safe.

**Delivers:** Windows-first onboarding docs, explicit repair and rerun guidance, and a post-install summary that tells the user what happened and what to do next.

**Uses:** The final state reporting and rerun-safe module behavior produced by earlier phases.

**Implements:** Recovery-aware messaging around bootstrap, module reruns, and cleanup.

**Addresses:** Fast path onboarding docs, clear progress and final state reporting, post-install health summary, recovery-aware rerun mode.

**Avoids:** Broken rerun behavior and documentation drift.

**Research flag:** Standard documentation work; no additional research phase required unless implementation reveals a new recovery edge case.

### Phase Ordering Rationale

- Phase 1 comes first because host-side safety is the only way to prevent destructive setup failures before they mutate user state.
- Phase 2 follows because idempotent Linux modules and version refreshes depend on a stable handoff contract.
- Phase 3 closes the loop by documenting and verifying the behavior that the earlier phases created, rather than documenting a hypothetical flow.
- This grouping matches the architecture boundary: PowerShell owns the host, Bash owns Linux configuration, and shared utilities should stay side-effect free.

### Research Flags

Phases likely needing deeper research during planning:
- Phase 2: validate the exact Node and package-manager behavior in the current bootstrap flow, especially rerun behavior after version refresh.
- Phase 3: only if implementation uncovers a new recovery edge case that is not already covered by the documented rerun model.

Phases with standard patterns (skip research-phase):
- Phase 1: WSL preflight and host-side gating follow well-documented Microsoft guidance and common PowerShell safety patterns.
- Phase 3: onboarding documentation and recovery messaging are straightforward once the real flow is implemented.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | The stack is anchored by official Microsoft and Node guidance, and it matches the existing repo direction. |
| Features | HIGH | The feature shape is consistent across the research set and directly maps to user-facing safety and clarity needs. |
| Architecture | HIGH | The layered Windows-to-WSL handoff and module pipeline are already present in the repo and are the right fit for this milestone. |
| Pitfalls | MEDIUM | The risks are clear, but rerun and repair behavior still need implementation-level validation. |

**Overall confidence:** HIGH

### Gaps to Address

- Rerun and repair semantics: validate that rerunning after partial setup converges cleanly instead of duplicating state.
- Dependency refresh behavior: verify that Node 24.x LTS and any related package-manager changes do not alter bootstrap assumptions.
- Destructive-path confirmation UX: ensure the reset path is unmistakable and impossible to trigger accidentally.
- Documentation fidelity: confirm that Windows-first docs match the actual prompts, flow, and recovery options after implementation.

## Sources

### Primary
- [STACK.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/STACK.md) — stack and version recommendations.
- [FEATURES.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/FEATURES.md) — feature priorities, differentiators, and anti-features.
- [ARCHITECTURE.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/ARCHITECTURE.md) — component boundaries, data flow, and module structure.
- [PITFALLS.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/PITFALLS.md) — failure modes and mitigation strategies.

### Secondary
- [PROJECT.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/PROJECT.md) — milestone goals, constraints, and active requirements.
- [STACK research sources](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/research/STACK.md) — Microsoft Learn WSL and WinGet docs, Node release guidance.

---
*Research completed: 2026-04-14*
*Ready for roadmap: yes*
