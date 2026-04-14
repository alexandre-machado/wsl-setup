# Architecture Research

**Domain:** Windows-first WSL bootstrap and shell-based development environment setup
**Researched:** 2026-04-14
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
+-------------------------------------------------------------+
| Windows Bootstrap Layer                                     |
|  wsl-setup.ps1                                              |
|  - preflight WSL availability                               |
|  - collect user identity and setup choices                  |
|  - launch WSL with explicit handoff data                    |
+-------------------------------+-----------------------------+
                                |
                                v
+-------------------------------------------------------------+
| Linux Orchestration Layer                                   |
|  setup.sh                                                   |
|  - validate handoff inputs                                  |
|  - source shared context                                    |
|  - run module pipeline in fixed order                       |
+-------------------------------+-----------------------------+
                                |
                                v
+-------------------------------------------------------------+
| Task Module Layer                                           |
|  apps.sh | dotfiles.sh | npm.sh | ssh.sh | gpg.sh           |
|  - perform one setup concern per module                     |
|  - emit status and respect gating flags                     |
+-------------------------------+-----------------------------+
                                |
                                v
+-------------------------------------------------------------+
| Shared Context and Maintenance                              |
|  utils.sh | user.sh | cleanup.sh                             |
|  - logging, identity, file replacement, post-install cleanup|
+-------------------------------------------------------------+
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `wsl-setup.ps1` | Windows-side preflight, distro preparation, user input capture, and process handoff into WSL | Small PowerShell bootstrap with explicit error handling and parameter passing |
| `setup.sh` | Linux-side orchestration and sequencing of install modules | Thin Bash controller that validates inputs before invoking modules |
| `scripts/user.sh` | Establish Git identity for downstream modules | Environment-variable normalization and interactive fallback prompts |
| `scripts/utils.sh` | Shared output and file replacement helpers | Sourced shell utility library |
| `scripts/apps.sh` | System package installation | APT and external installer commands |
| `scripts/dotfiles.sh` | Shell, dotfile, and Git configuration | Repository-driven dotfile installation and profile setup |
| `scripts/npm.sh` | Node/NVM version setup | NVM activation and version pinning |
| `scripts/ssh.sh` and `scripts/gpg.sh` | Optional key material setup | Gated, user-approved security configuration |
| `cleanup.sh` | Space recovery and post-install cleanup | Standalone maintenance script with strict validation |

## Recommended Project Structure

```
.
├── wsl-setup.ps1        # Windows bootstrap entrypoint
├── setup.sh             # Linux orchestration entrypoint
├── scripts/             # module scripts and shared helpers
│   ├── apps.sh
│   ├── dotfiles.sh
│   ├── npm.sh
│   ├── ssh.sh
│   ├── gpg.sh
│   ├── user.sh
│   └── utils.sh
├── cleanup.sh           # post-install maintenance entrypoint
└── .planning/           # milestone and research artifacts
```

### Structure Rationale

- `wsl-setup.ps1`: Keep the Windows entrypoint at the repository root so first-run discovery stays obvious for Windows users.
- `setup.sh`: Keep orchestration separate from bootstrap so the Linux path remains reusable for native WSL runs and future automation.
- `scripts/`: Keep capability-specific setup logic isolated so changes to Windows handoff do not cascade into unrelated modules.

## Architectural Patterns

### Pattern 1: Two-Stage Bootstrap Handoff

**What:** Windows prepares the environment and then passes control to Bash for the actual Linux setup.
**When to use:** Any Windows-to-WSL setup flow where Windows must handle WSL installation, distro launch, or initial prompting.
**Trade-offs:** Keeps platform responsibilities cleanly separated, but the handoff contract must be explicit or setup becomes fragile.

**Example:**
```powershell
# PowerShell prepares the environment
# Bash receives explicit identity and setup flags
wsl ~ -e bash -lc "export GIT_NAME='$GIT_NAME' && export GIT_EMAIL='$GIT_EMAIL' && cd wsl-setup && ./setup.sh"
```

### Pattern 2: Orchestrator Plus Modules

**What:** One main shell script controls order while module scripts own individual setup concerns.
**When to use:** Brownfield shell projects that need safer changes without rewriting the toolchain.
**Trade-offs:** Easy to reason about and test incrementally, but shared state must stay narrow or modules become coupled through environment side effects.

**Example:**
```bash
source ./scripts/utils.sh
source ./scripts/user.sh
bash ./scripts/apps.sh
bash ./scripts/dotfiles.sh
bash ./scripts/npm.sh
```

### Pattern 3: Optional Capability Gating

**What:** Optional security or personalization steps are guarded by explicit flags.
**When to use:** Features like SSH or GPG setup that should not run automatically for every user.
**Trade-offs:** Reduces accidental side effects, but the flag contract must be clear in both the Windows and Bash entrypoints.

## Data Flow

### Request Flow

```
User on Windows
    -> wsl-setup.ps1
    -> WSL install/update and distro selection
    -> explicit env handoff into bash -lc
    -> setup.sh
    -> module sequence
    -> final shell state and cleanup
```

### State Management

```
Windows inputs
    -> PowerShell variables and launch arguments
    -> exported environment variables in WSL shell
    -> shell environment in setup.sh and modules
    -> persistent filesystem/config changes in the WSL home directory
```

### Key Data Flows

1. **Identity flow:** PowerShell collects Git name and email, then exports them into the WSL session so `scripts/user.sh` can normalize them without a second prompt.
2. **Capability flags:** Windows setup choices for optional SSH and GPG setup should become explicit handoff variables, not implicit shell state.
3. **Install sequencing:** `setup.sh` should remain the single source of truth for module order so Windows simplification does not duplicate install logic.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-1k users | Keep the current linear bootstrap and module pipeline; focus on clarity and safer defaults. |
| 1k-100k users | Improve idempotency and input validation before adding more setup branches or optional paths. |
| 100k+ users | Consider breaking the Windows bootstrap contract into a more formal manifest if the number of setup variants grows materially. |

### Scaling Priorities

1. **First bottleneck:** Handoff ambiguity between PowerShell and Bash. Fix with explicit parameters and validation.
2. **Second bottleneck:** Module side effects that depend on ambient shell state. Fix with tighter input contracts and more idempotent module behavior.

## Anti-Patterns

### Anti-Pattern 1: Duplicate setup logic in both layers

**What people do:** Re-implement WSL installation checks or Git identity logic in both PowerShell and Bash.
**Why it's wrong:** It creates divergent behavior and makes the Windows flow harder to reason about.
**Do this instead:** Let PowerShell own Windows/WSL preparation and Bash own Linux configuration.

### Anti-Pattern 2: Implicit handoff through ambient shell state

**What people do:** Rely on whatever variables happen to be present when Bash starts.
**Why it's wrong:** It makes failures hard to diagnose and encourages brittle setup behavior.
**Do this instead:** Pass a minimal, explicit contract from `wsl-setup.ps1` into `setup.sh`.

### Anti-Pattern 3: Reordering modules during bootstrap cleanup

**What people do:** Change install order while trying to simplify Windows setup.
**Why it's wrong:** It increases regression risk and mixes integration changes with feature changes.
**Do this instead:** Keep the Linux module order stable while the Windows handoff is being hardened.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Windows WSL | PowerShell command-line orchestration | Windows layer should install/update/select the distro before handing off to Bash |
| GitHub repository clone | `git clone` from inside WSL | Clone should happen after WSL is confirmed ready and before the Linux orchestrator runs |
| Package repositories and install scripts | Bash-driven network fetch/install | These belong to Linux modules, not the Windows bootstrap |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `wsl-setup.ps1` -> `setup.sh` | Environment variables and shell command invocation | This is the main integration seam to simplify and harden for v1.1 |
| `setup.sh` -> module scripts | Direct Bash invocation | Keep the sequence centralized in one orchestrator |
| `user.sh` -> all identity-dependent modules | Exported environment variables | Identity should be resolved once and reused downstream |
| optional setup flags -> `ssh.sh` / `gpg.sh` | Guarded invocation | Make Windows prompts and Bash gating match so these steps do not surprise users |

## Build Order Implications

1. Harden `wsl-setup.ps1` first so the setup contract is stable before touching downstream modules.
2. Update `setup.sh` and `scripts/user.sh` next so Linux validation matches the new handoff.
3. Then simplify module behavior where needed, without changing the overall execution order.
4. Only after the handoff is stable should version pinning and documentation updates be expanded across modules.

## Sources

- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/PROJECT.md`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/.planning/codebase/ARCHITECTURE.md`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/wsl-setup.ps1`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/setup.sh`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/scripts/user.sh`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/scripts/utils.sh`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/scripts/apps.sh`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/scripts/dotfiles.sh`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/scripts/npm.sh`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/scripts/ssh.sh`
- `/home/ubuntu-24/repos/alexandre-machado/wsl-setup/scripts/gpg.sh`

---
*Architecture research for: Windows-first WSL bootstrap and shell-based development environment setup*
*Researched: 2026-04-14*
