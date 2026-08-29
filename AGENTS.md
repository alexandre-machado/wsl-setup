# AGENTS.md

## Architecture

- Two-stage bootstrap across an OS boundary: `wsl-setup.ps1` runs on Windows
  (winget/wsl, provisions `%USERPROFILE%\.wslconfig` from
  `scripts/.wslconfig.template` fetched from raw.githubusercontent), then hands
  off via `wsl ... bash -lc`, which **clones this repo's `main` from GitHub**
  and runs `./setup.sh`. Changes only reach real bootstrap runs after landing
  on `main` — a local branch cannot be exercised through the PowerShell path.
- Runtime state flows through env vars only: `GIT_NAME`/`GIT_EMAIL` (required),
  `SSH_DISABLED`/`GPG_DISABLED` (opt-out toggles read by `setup.sh`).
- Error-handling model is intentionally split: `cleanup.sh` is strict
  (`set -euo pipefail`, function-driven, `--dry-run` support); the installer
  scripts are best-effort top-down with no strict mode. Match the style of the
  file you are in; prefer strict mode for new non-interactive scripts.
- `scripts/network-tuning.sh` + `.wslconfig.template` exist for one reason:
  WSL2 Mirrored networking (with Tailscale/Docker) exhausts socket/netlink
  buffers (ENOBUFS, errno=105) and the default `tcp_keepalive_time=7200` leaves
  idle HTTP/2 streams on dead NAT tunnels, freezing AI terminals (Claude Code,
  Copilot, Gemini) simultaneously. Do not "simplify" these values away.

## Constraints

- **Destructive-action policy (bootstrap):** `wsl-setup.ps1` must print a
  preflight summary (WSL package state, existing distros, available paths)
  before any change; the default path is non-destructive `create-new`;
  `wsl --unregister` is only reachable via explicit `replace-existing` mode
  plus a Y/N confirmation, and a declined confirmation falls back to the
  non-destructive path — never to deletion. Preserve this shape in any edit.
- Idempotency is fragile: re-runs can duplicate config lines and re-clone into
  existing dirs (`dotfiles.sh`, `ssh.sh`). New file/config mutations need
  existence guards (marker comment, `grep -q` before append) — see the
  managed-marker pattern in `Install-WslConfig`.
- Everything lands in tracked scripts; there is no other deploy artifact. A fix
  applied by hand on a machine does not exist.
- Known accepted risks — do not widen them: `scripts/gpg.sh` generates an
  unencrypted private key (`%no-protection`), and installers pipe remote
  scripts to shell (Oh My Zsh, NodeSource, lazydocker) without pinning.
- Destructive maintenance (`cleanup.sh` `rm -rf` of caches) must keep a working
  `--dry-run` mode.

## Release phases

- **There is no deploy pipeline and no CI.** No `.github/workflows/` exists;
  no automated test suite, no shellcheck/formatter config.
- "Done" means: `bash -n setup.sh cleanup.sh scripts/*.sh` passes;
  `./cleanup.sh --dry-run` still runs clean when cleanup is touched; and, for
  bootstrap/installer changes, a manual smoke run on a fresh or disposable WSL
  instance. PowerShell changes can only be truly validated on Windows.
- Because the bootstrap clones `main` at runtime, merging to `main` *is* the
  release; there is no staging.

## Lessons

- The bootstrap once ran `wsl --unregister Ubuntu-24.04` unconditionally,
  wiping users' existing distros. Commit `1fd569c` introduced the preflight +
  confirmation model above. Never reintroduce an unguarded destructive default.
- Simultaneous multi-minute freezes of all AI terminals under WSL2 were a
  kernel buffer/keepalive problem, not an app problem; fixed by
  `network-tuning.sh` + the `.wslconfig` template (commit `0d144ce`). If
  similar stalls recur, check `sysctl` state and phantom eth interfaces before
  blaming the tools.
- `setup.sh` deletes its own checkout at the end
  (`rm -rf ${DOTFILES_DIRECTORY}`, set to `$PWD` in `scripts/utils.sh`) —
  debugging a live run requires a separate copy.
- Agent probes against shared host state must be isolated: a review subagent
  once ran `tmux kill-server` while testing and killed the user's attached
  session. tmux experiments use an isolated socket (`tmux -L <name>`) and kill
  only that socket's server; in general, empirical verification by read-only
  reviewers must be side-effect-free on the host (temp dirs, PATH-stubbed
  `sudo`, no shared daemons).
- `awk '...' "$f" | sudo tee "$f"` truncates the file awk is still reading and
  wipes its content most runs (caught pre-merge in PR #15). Render to a temp
  file first, then `sudo install -m 644 "$tmp" "$f"` — and check the install's
  exit code before printing success.
- Docker Desktop's WSL Integration can be **half-applied**: the distro stays
  listed in `IntegratedWslDistros` and its per-distro proxy socket exists, but
  `/mnt/wsl/docker-desktop/cli-tools` is left empty, so every injected
  `docker*` symlink dangles and the distro reports "The command 'docker' could
  not be found in this WSL 2 distro" while the engine is perfectly healthy.
  Splitting/renaming a distro is the usual trigger. Do NOT diagnose this from
  the Docker Desktop settings file — it said the distro was integrated the
  whole time. Probe `docker.proxy.sock` directly; it answers `/_ping` even
  when the CLI is gone. `scripts/docker.sh` heals it with the distro's native
  apt CLI plus a systemd-linked socket, so no GUI toggle and no engine restart
  is needed. Blast radius is bigger than an interactive shell: a nightly
  `docker exec` backup in another repo died with "docker: command not found"
  for two days, silently, because only its own log recorded the failure.
