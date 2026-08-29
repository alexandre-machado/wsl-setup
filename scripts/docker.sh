#!/bin/bash
#
# Docker CLI wiring for a Docker Desktop-backed WSL2 distro.
#
# The distro does NOT run its own dockerd. It uses Docker Desktop's engine,
# reached through the cross-distro socket under /mnt/wsl/docker-desktop.
#
# Why this module exists (the failure it heals):
#   Docker Desktop's "WSL Integration" injects its own CLI into the distro as
#   symlinks pointing into /mnt/wsl/docker-desktop/cli-tools, and bind-mounts
#   /var/run/docker.sock. That injection can end up HALF-APPLIED — most easily
#   after splitting or renaming a distro, which is what happened here: the
#   distro was still listed in Docker Desktop's IntegratedWslDistros, the
#   per-distro proxy socket was created, but cli-tools was left EMPTY and
#   /var/run/docker.sock left stale. Every docker symlink then dangles and the
#   distro reports:
#
#       The command 'docker' could not be found in this WSL 2 distro.
#
#   ...while the engine is perfectly healthy and reachable from Windows. The
#   damage is silent and wide: anything shelling out to `docker` from cron
#   dies with "docker: command not found" and, if it has no alerting of its
#   own, simply stops running. That is not hypothetical — it silently killed
#   a nightly `docker exec` backup for two days before anyone noticed.
#
# The fix is to stop depending on the injected CLI at all:
#   1. Install the distro's NATIVE docker CLI from apt and repair /usr/bin/docker
#      whenever Docker Desktop has clobbered it with a dangling symlink.
#   2. Bind /var/run/docker.sock to docker.proxy.sock, which Docker Desktop
#      exposes unconditionally, via a boot-time systemd unit.
#
# Rerun-safe: apt installs are idempotent and every mutation is guarded.

source ./scripts/utils.sh

echo_info "Configuring Docker CLI (Docker Desktop engine)..."

DOCKER_PROXY_SOCK=/mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
DOCKER_LINK_BIN=/usr/local/bin/docker-desktop-socket-link
DOCKER_LINK_UNIT=/etc/systemd/system/docker-desktop-socket.service

# --- 1. Native CLI ----------------------------------------------------------
# docker.io ships the client AND dockerd; we keep the client and make sure the
# daemon never starts (Docker Desktop owns the engine). docker-buildx is
# required by `docker compose build` — without it the injected Docker Desktop
# buildx symlink is the only one present, and it dangles under this failure.
run sudo apt install -y docker.io docker-compose-v2 docker-buildx
run sudo systemctl disable --now docker.service docker.socket 2>/dev/null || true
run sudo usermod -aG docker "$USER" 2>/dev/null || true

# Heal a clobbered client: Docker Desktop replaces the package-owned binary
# with a symlink into cli-tools, so a dangling link means dpkg's file is gone.
for path in /usr/bin/docker /usr/local/bin/docker; do
  if [ -L "$path" ] && [ ! -e "$path" ]; then
    echo_info "Repairing dangling Docker Desktop symlink: $path"
    if [ "$DRY_RUN" = true ]; then
      echo_dry "sudo rm -f $path && sudo apt install --reinstall -y docker.io"
    else
      sudo rm -f "$path"
      # /usr/local/bin/docker is Docker Desktop's, not dpkg's — removing it is
      # the whole repair. Only /usr/bin/docker needs the package restored.
      [ "$path" = /usr/bin/docker ] && sudo apt install --reinstall -y docker.io
    fi
  fi
done

# --- 2. Socket --------------------------------------------------------------
# docker.proxy.sock is the one endpoint Docker Desktop exposes to every
# integrated distro regardless of how the CLI injection went. Pointing the
# well-known path at it makes plain `docker` work for interactive shells,
# scripts and cron alike — no DOCKER_HOST in a profile that cron never reads.
if [ "$DRY_RUN" = true ]; then
  echo_dry "install $DOCKER_LINK_BIN + $DOCKER_LINK_UNIT (systemd, enabled)"
else
  tmp_bin="$(mktemp)"
  cat > "$tmp_bin" <<'LINK_SCRIPT'
#!/usr/bin/env bash
# Point /var/run/docker.sock at Docker Desktop's WSL guest-services proxy socket.
# Installed by wsl-setup scripts/docker.sh — see that file for the full rationale.
set -euo pipefail

PROXY=/mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
TARGET=/var/run/docker.sock

[ -S "$PROXY" ] || { echo "docker-desktop-socket-link: $PROXY absent; nothing to do"; exit 0; }

# If the well-known path already talks to an engine, Docker Desktop's own
# integration is healthy — leave it alone rather than fight it.
if curl -s -m 3 --unix-socket "$TARGET" http://localhost/_ping 2>/dev/null | grep -q OK; then
  echo "docker-desktop-socket-link: $TARGET already healthy"
  exit 0
fi

rm -f "$TARGET"
ln -s "$PROXY" "$TARGET"
echo "docker-desktop-socket-link: $TARGET -> $PROXY"
LINK_SCRIPT
  sudo install -m 755 "$tmp_bin" "$DOCKER_LINK_BIN" && rm -f "$tmp_bin" \
    || echo_warning "Failed to install $DOCKER_LINK_BIN"

  tmp_unit="$(mktemp)"
  cat > "$tmp_unit" <<UNIT
[Unit]
Description=Link /var/run/docker.sock to the Docker Desktop WSL guest-services proxy socket
Documentation=https://github.com/alexandre-machado/wsl-setup
After=local-fs.target
ConditionPathExists=${DOCKER_PROXY_SOCK}

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${DOCKER_LINK_BIN}

[Install]
WantedBy=multi-user.target
UNIT
  sudo install -m 644 "$tmp_unit" "$DOCKER_LINK_UNIT" && rm -f "$tmp_unit" \
    || echo_warning "Failed to install $DOCKER_LINK_UNIT"

  # systemd may be absent (wsl.conf systemd=false) — never fail the run on it.
  # NOTE: `systemctl is-system-running` exits non-zero on "degraded", which is
  # the NORMAL state of a WSL distro (some units never apply). Test for the
  # systemd runtime directory instead, or this silently skips the unit.
  if [ -d /run/systemd/system ] && command -v systemctl > /dev/null 2>&1; then
    sudo systemctl daemon-reload
    sudo systemctl enable --now docker-desktop-socket.service || true
  else
    echo_info "systemd unavailable — running the socket link once directly."
    sudo "$DOCKER_LINK_BIN" || true
  fi
fi

# --- 3. Verify --------------------------------------------------------------
# "Installed" is not "working": the whole point of this module is a failure
# where every binary was present and nothing could talk to the engine.
if [ "$DRY_RUN" = true ]; then
  echo_dry "docker version (verify the client reaches the engine)"
elif docker version > /dev/null 2>&1; then
  echo_success "Docker CLI reaches the Docker Desktop engine."
else
  echo_info "Docker CLI installed but the engine is not reachable yet."
  echo_info "  Check Docker Desktop is running and this distro is enabled under"
  echo_info "  Settings > Resources > WSL Integration, then re-run: --only docker"
fi

echo_success "Finished Docker CLI configuration."
