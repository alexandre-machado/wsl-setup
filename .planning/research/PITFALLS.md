# Pitfalls Research

**Domain:** WSL bootstrap simplification for Windows-first onboarding
**Researched:** 2026-04-14
**Confidence:** MEDIUM

## Critical Pitfalls

### Pitfall 1: Making the bootstrap "simpler" by resetting the user's existing WSL state

**What goes wrong:**
The setup flow becomes deterministic on paper but destructive in practice. Existing distros get unregistered, local changes disappear, and the user loses trust in the installer before they ever reach the shell setup.

**Why it happens:**
Teams often optimize for a clean-room happy path and assume every run starts from a blank machine. That leads to hardcoded distro names, forced reinstalls, and cleanup logic that is too aggressive for a brownfield toolkit.

**How to avoid:**
Treat existing WSL state as a first-class input. Detect the installed distro, preserve it unless the user explicitly opts into a reset, and make the "repair" path separate from the "fresh install" path. Any destructive action should require an unmistakable confirmation step.

**Warning signs:**
- The bootstrap removes or unregisters an existing distro before checking whether it is already usable.
- Setup docs or scripts assume exactly one distro name and fail when that name already exists.
- Re-running setup on a configured machine destroys data instead of converging safely.

**Phase to address:**
Phase 1: Windows bootstrap hardening and preflight checks.

---

### Pitfall 2: Pushing validation until after the first real mutation

**What goes wrong:**
The installer starts changing the system before it has verified prerequisites like WSL availability, Windows version support, network reachability, admin rights, disk space, or shell safety settings. When it fails, the user is left with partial state and a vague error trail.

**Why it happens:**
Simplification work tends to focus on shortening the happy path, not on failing early. Without an explicit preflight gate, validation gets treated as a nice-to-have instead of a prerequisite for safe automation.

**How to avoid:**
Add a preflight stage that runs before any destructive or stateful action. Check Windows-side requirements in PowerShell, then verify Linux-side assumptions before the Bash pipeline mutates packages or dotfiles. Use strict shell mode and explicit error handling in noninteractive scripts so failures stop the run immediately.

**Warning signs:**
- Users report partial installs with no clear point of failure.
- Errors only surface after apt work, dotfile writes, or package installs have already started.
- Scripts keep running after a missing command, a failed download, or a bad environment assumption.

**Phase to address:**
Phase 1: Windows bootstrap hardening and preflight checks.

---

### Pitfall 3: Refactoring duplicated setup steps into hidden side effects

**What goes wrong:**
A cleanup pass removes duplication but quietly moves prompts, exports, or shell initialization into files that are sourced in multiple places. The result is repeated prompts, duplicated config lines, and behavior that depends on the entrypoint order.

**Why it happens:**
The repo already has a mixed PowerShell + Bash flow, so it is easy to overcorrect by centralizing everything too early. In a script-driven installer, "DRY" can easily turn into "implicit and fragile" if the boundaries between orchestrator code and utility code disappear.

**How to avoid:**
Keep side effects in one orchestration layer only. Utility files should stay reusable and idempotent. Any write operation should guard against duplication, and any sourced file should be safe to include exactly once or multiple times without changing behavior.

**Warning signs:**
- `user.sh`-style sourcing gets triggered from more than one entry path.
- Re-running setup duplicates shell config, apt entries, or PATH exports.
- A script works when run directly but behaves differently when called through the orchestrator.

**Phase to address:**
Phase 2: Script consolidation and idempotency cleanup.

---

### Pitfall 4: Treating dependency modernization as "just bump versions"

**What goes wrong:**
Version refreshes land without checking whether the surrounding install flow, distro assumptions, or Windows handoff still match the new defaults. The scripts become newer but not more reliable.

**Why it happens:**
Teams often equate modernization with replacing pinned versions, then stop at the package list. In this repo, package updates touch the bootstrap path, NVM/node setup, apt installs, and documentation at the same time, so version changes need compatibility review, not just replacement.

**How to avoid:**
Review each pin in the context of the Windows-to-WSL journey. Update the version, the installer behavior, and the docs together. Validate the new defaults on a clean machine and on an already-provisioned machine, because dependency churn often breaks one of those paths first.

**Warning signs:**
- A package bump lands without a corresponding installer or docs change.
- New defaults work on a fresh environment but break reruns or upgrades.
- A tool update introduces interactive prompts or path assumptions that the bootstrap never handled before.

**Phase to address:**
Phase 2: Dependency refresh and compatibility validation.

---

### Pitfall 5: Optimizing for first-run success while abandoning rerun and repair behavior

**What goes wrong:**
The flow becomes polished for the initial install but brittle for the second run. Existing configs, partially installed packages, and previous bootstrap attempts make the new path fail in ways the original path never did.

**Why it happens:**
Windows-first simplification usually starts with onboarding. That creates a clean-machine bias and hides the real shape of user behavior, which includes retries, interrupted installs, and machines that were already manually touched once.

**How to avoid:**
Design each step to converge when re-run. Add explicit skip logic for already-present directories, existing keys, and already-installed tools. Make recovery actions separate from setup actions so the user can repair state without repeating the entire bootstrap.

**Warning signs:**
- A second run duplicates files, prompts, or shell setup entries.
- Existing directories are recreated instead of reused.
- Recovery from a failed run requires manual cleanup or editing scripts by hand.

**Phase to address:**
Phase 3: Documentation, recovery paths, and rerun-safe validation.

## Technical Debt Patterns

Shortcuts that look attractive during simplification but create long-term fragility.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoding a single distro name or Windows path | Fewer branches in the bootstrap path | Breaks existing users and makes future distro support painful | Never, unless isolated behind a clearly documented override |
| Keeping remote install commands unpinned for speed | Faster initial setup edits | Supply-chain drift and non-reproducible installs | Only for low-risk, optional tooling during an interim milestone |
| Moving all setup logic into one large script | Simpler navigation at first | Harder testing, more side effects, and weaker reuse | Never for the Windows entrypoint; keep a clear orchestrator/module split |
| Ignoring duplicate-write guards because "fresh machines are common" | Less code now | Re-runs become unsafe and idempotency regresses | Never for config files, PATH updates, or key generation |

## Integration Gotchas

Common mistakes when connecting PowerShell, WSL, Bash, and distro tooling.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| PowerShell to WSL handoff | Assuming the Windows script can mutate Linux state safely without checking what already exists | Validate first on the Windows side, then pass only the minimum required intent into WSL |
| WSL distro lifecycle | Unregistering or recreating the distro to "guarantee" a clean install | Preserve existing distros by default and require explicit opt-in for resets |
| Bash module pipeline | Sourcing files with side effects from multiple entrypoints | Keep utility files side-effect free and let only the orchestrator own prompts and exports |
| Package installers and NVM | Assuming current package versions behave like the pinned ones | Refresh versions together with compatibility checks and docs updates |

## Performance Traps

Patterns that are fine for a single clean install but degrade setup reliability as more state accumulates.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full-home or broad directory scans during cleanup | Slow teardown, especially on large repos or home directories | Make expensive scans optional and limit them to target directories | When user homes get large or cloud-synced |
| Repeated shell initialization work on every run | Setup feels slower and produces duplicate output | Cache or guard repeated setup steps | When reruns become common |
| Sequential validation only after mutation | Failures are slow to detect and harder to recover from | Put a fast preflight gate at the start | On any run with missing prerequisites |

## Security Mistakes

Domain-specific security issues that commonly show up in bootstrap tooling.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Destructive reset of an existing distro during bootstrap | Data loss and trust loss | Preserve existing state unless the user explicitly opts in to reset |
| Remote script execution without version pinning or verification | Supply-chain compromise | Pin versions, verify checksums or signatures where possible, and avoid pipe-to-shell patterns for core setup |
| Generating unprotected private keys by default | Local key compromise | Require a passphrase or an explicit warning-backed opt-out |
| Expanding elevated privileges beyond the minimum needed | Larger blast radius if a script misbehaves | Keep privileged actions narrow and separated from normal install logic |

## UX Pitfalls

Common mistakes that make Windows-first onboarding feel more confusing, not less.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Removing steps without replacing them with clearer guidance | Users lose the mental model for what the installer is doing | Keep the path short, but preserve explicit progress and recovery hints |
| Hiding failures behind generic output | Users cannot tell whether the issue is Windows, WSL, Bash, or package-related | Emit stage-specific failure messages and point to the next recovery action |
| Updating docs after the code without validation | Instructions drift from actual behavior | Reconcile docs with the installer path in the same phase |
| Making setup fully automatic with no escape hatch | Users cannot recover from edge cases or prefer a manual override | Provide explicit flags for reset, skip, and repair behaviors |

## "Looks Done But Isn't" Checklist

Things that often appear complete but still hide important gaps.

- [ ] **Bootstrap flow:** The installer reaches the shell prompt once, but also works when the distro already exists.
- [ ] **Validation:** The setup checks prerequisites before any file writes, package installs, or unregister actions.
- [ ] **Idempotency:** Re-running the flow does not duplicate config, prompts, or directory creation.
- [ ] **Recovery:** A failed run can be repaired without manually editing the scripts or deleting the distro.
- [ ] **Documentation:** Windows-first docs match the real entrypoint and call out destructive options clearly.
- [ ] **Security:** No core setup path depends on unpinned remote script execution or unprotected key generation.

## Recovery Strategies

When these pitfalls happen anyway, recover in a controlled way rather than by trial and error.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Destructive WSL reset | HIGH | Stop making destructive assumptions by default, restore docs around preservation, and add explicit confirmation before any unregister action |
| Late validation failure | MEDIUM | Split preflight from mutation, surface the earliest failing check, and make the command exit immediately on error |
| Hidden side effects from consolidation | MEDIUM | Move prompts and writes back to the orchestrator layer, then add idempotency guards around every config mutation |
| Unchecked dependency refresh | MEDIUM | Re-pin or downgrade to a known-good version, then retest both fresh and rerun scenarios before reintroducing the update |
| Broken rerun behavior | HIGH | Add skip/reuse logic for existing state and document a separate repair path for partially completed installs |

## Pitfall-to-Phase Mapping

How roadmap phases should prevent the failure modes above.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Destructive bootstrap reset | Phase 1: Bootstrap hardening and preflight checks | Existing distros survive a rerun unless the user explicitly chooses reset |
| Late validation failure | Phase 1: Bootstrap hardening and preflight checks | The installer exits before mutation when a prerequisite is missing |
| Hidden side effects from consolidation | Phase 2: Script consolidation and idempotency cleanup | Repeated runs do not duplicate prompts, exports, or config entries |
| Dependency refresh without compatibility review | Phase 2: Dependency refresh and compatibility validation | New pins work on both fresh and already-configured machines |
| Broken rerun behavior | Phase 3: Documentation, recovery paths, and rerun-safe validation | A second run converges safely and docs describe the repair path |

## Sources

- [/.planning/PROJECT.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/PROJECT.md)
- [/.planning/STATE.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/STATE.md)
- [/.planning/codebase/CONCERNS.md](/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/codebase/CONCERNS.md)
- [Pitfalls research template](/home/ubuntu-24/.copilot/get-shit-done/templates/research-project/PITFALLS.md)

---
*Pitfalls research for: WSL bootstrap simplification for Windows-first onboarding*
*Researched: 2026-04-14*
