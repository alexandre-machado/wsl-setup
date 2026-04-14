# Feature Landscape

**Domain:** Windows-first WSL bootstrap toolkit
**Researched:** 2026-04-14

## Table Stakes

Features users expect. Missing these makes the setup feel unsafe or unfinished.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| Single guided Windows entrypoint | Users should not have to understand both PowerShell and Bash to get started | Medium | PowerShell, WSL, network, GitHub | Keep the one-command install path, but make it the guided path rather than a thin launcher |
| Preflight checks before changes | A setup tool should fail early on missing admin rights, WSL state, distro mismatch, or network problems | Medium | Windows admin context, `wsl`, `winget`, repo access | This is the main safety gap in the current flow |
| Non-destructive existing-install handling | Re-running setup should repair or continue, not silently wipe a working distro | High | WSL distro inspection, user confirmation | The current unregister-and-reinstall behavior is too risky for a simplification milestone |
| Clear Git identity capture | Git config is a core setup input, and users need one obvious place to enter name/email | Low | Prompt handling, shell env propagation | Keep a single prompt or config source and reuse it across host-to-guest handoff |
| Explicit optional SSH and GPG setup | Key management is valuable, but it should be opt-in and clearly explained | Medium | OpenSSH, GPG, Git config | Users should choose these steps instead of receiving them as an unconditional surprise |
| Idempotent module reruns | Users need to be able to retry a failed setup without duplicating config or breaking state | High | Script guards, file existence checks | Important for dotfiles, git config, SSH config, and remote clones |
| Clear progress and final state reporting | Windows users need to know what completed, what was skipped, and what to do next | Low | Console messaging | The current flow has progress markers, but they should be more explicit about branch choices and recoverable failures |
| Fast path onboarding docs | The docs should show the shortest successful path first, with advanced steps clearly separated | Low | README and setup docs | The docs should mirror the simplified Windows flow, not the underlying script sequence |

## Differentiators

Features that would make the Windows-first experience feel intentionally simplified rather than merely less broken.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| Safe first-run bootstrap with confirmation gates | Lets users install or update WSL without fear of losing an existing distro | High | WSL state inspection, confirmation prompts, recovery messaging | This is the best place to reduce anxiety and support load |
| One decision screen for setup choices | Users choose distro target, optional keys, and installation mode once, then the toolkit executes consistently | Medium | Interactive prompt flow, environment variable handoff | Good fit for a guided PowerShell front door |
| Recovery-aware rerun mode | A failed setup can be resumed or re-run with skip/repair behavior instead of starting over | High | State markers, idempotent modules, detection of partial installs | Strong differentiator for real-world onboarding failures |
| Version-pinned stable defaults | Users get supported defaults without having to research which Node, Git, or package versions are current | Medium | Package pinning, release tracking | Better than hard-coding old majors; prefer current supported stable defaults |
| Distro-aware Windows handoff | The Windows bootstrap should detect the expected WSL distro and guide the user if a different one is present | Medium | `wsl --list --verbose`, distro naming conventions | Avoids the current assumption that a single distro name can be unconditionally replaced |
| Post-install health summary | After setup, the tool should summarize installed capabilities, skipped options, and next steps | Low | Output aggregation | Helps users trust what happened and reduces support questions |
| Safer cleanup and maintenance guidance | Cleanup should remain available, but it should be framed as a separate maintenance action with clear impact | Medium | Cleanup script, confirmation UX | Keeps bootstrap focused while preserving the maintenance utility |

## Anti-Features

Features this milestone should explicitly avoid.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Unconditional distro unregister/reinstall | It destroys user state and makes first-run setup dangerous | Detect existing WSL instances and require a deliberate confirm/repair path |
| Pipe-to-shell style critical installs without verification | It weakens trust and makes supply-chain risk worse | Prefer pinned packages, explicit downloads, or at minimum clear provenance and confirmation |
| Mandatory SSH/GPG key generation | Not every user wants local signing or automatic key material creation | Make both steps opt-in and clearly labeled |
| Hidden side effects in the Windows launcher | Surprising host-side mutation makes debugging harder | Show the Windows actions explicitly before handing off to Linux |
| GUI installer rewrite | A new UI layer would add scope without improving the shell-based mental model | Keep the shell-first flow and simplify the interaction model in place |
| Support for non-Debian/Ubuntu WSL distros in this milestone | Broad distro support adds branching logic and testing burden | Keep the optimization focused on Debian/Ubuntu users already in scope |
| Silent repeated writes to shell or Git config | Re-runs can duplicate entries and produce hard-to-undo config drift | Add guards and only write when needed |

## Feature Dependencies

Preflight validation -> safe bootstrap gating -> optional choice capture -> Linux handoff -> module-level idempotency -> post-install summary.

SSH/GPG setup depends on Git identity, a working Linux shell, and explicit user opt-in.

Cleanup and repair features depend on reliable state detection and clear confirmation prompts.

## MVP Recommendation

Prioritize:
1. Non-destructive Windows bootstrap with preflight checks and confirmation gates.
2. One guided setup path that captures Git identity and optional features once.
3. Idempotent reruns for dotfiles, SSH, GPG, and package setup.

Defer: broad distro support, GUI installer ideas, and deeper recovery automation beyond clear rerun/repair behavior.
