#!/bin/bash
#
# Apply kernel / TCP tuning for AI terminal tools running on WSL2.
#
# Why this exists:
#   WSL2 under Mirrored networking (with Tailscale, Docker, etc.) accumulates
#   phantom eth interfaces and runs out of socket / netlink buffer space
#   (errno=105 ENOBUFS). When that happens, every persistent HTTPS connection
#   stalls at the same time — which is what causes Claude Code, Copilot, and
#   Gemini terminals to freeze simultaneously for minutes at a time.
#
#   The defaults also set tcp_keepalive_time=7200 (2h), so idle HTTP/2
#   streams to AI providers sit on dead NAT tunnels before the kernel
#   notices.
#
# Rerun-safe: skips entirely when the target file already has this content.

source ./scripts/utils.sh

echo_info "Installing WSL AI-terminal network tuning..."

SYSCTL_FILE="/etc/sysctl.d/99-wsl-ai-tuning.conf"

# Desired content held in a variable: no temp-file write under --dry-run.
# (read -d '' returns non-zero at EOF by design; best-effort script.)
read -r -d '' SYSCTL_CONTENT <<'EOF'
# WSL2 tuning for AI terminal tools (Claude Code, Copilot, Gemini)
# Managed by https://github.com/alexandre-machado/wsl-setup

# --- Socket buffers (bump from 208KB default to 16MB) ----------------------
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 65536

# --- TCP auto-tuning window ------------------------------------------------
net.ipv4.tcp_rmem = 4096 1048576 16777216
net.ipv4.tcp_wmem = 4096 1048576 16777216

# --- Keepalive (was 7200s = 2h) --------------------------------------------
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 5

# --- Netlink / backlog -----------------------------------------------------
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 4096

# --- TCP reliability under packet loss -------------------------------------
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mtu_probing = 1
EOF

if printf '%s\n' "$SYSCTL_CONTENT" | cmp -s - "$SYSCTL_FILE"; then
  echo_info "Network tuning already applied ($SYSCTL_FILE) - skipping."
elif [ "$DRY_RUN" = true ]; then
  echo_dry "sudo tee $SYSCTL_FILE (write kernel/TCP tuning config)"
  echo_dry "sudo sysctl -p $SYSCTL_FILE"
else
  printf '%s\n' "$SYSCTL_CONTENT" | sudo tee "$SYSCTL_FILE" > /dev/null
  sudo chmod 644 "$SYSCTL_FILE"
  sudo sysctl -p "$SYSCTL_FILE" > /dev/null
  echo_success "Network tuning applied ($SYSCTL_FILE)."
fi
