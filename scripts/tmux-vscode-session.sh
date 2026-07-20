#!/usr/bin/env bash
#
# Attach VS Code terminals to a stable tmux session per repository.
# Session name format: vsc_<owner>_<repo>_<path_hash>

set -euo pipefail

sanitize_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '_'
}

repo_root="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
owner="$(basename "$(dirname "$repo_root")")"
repo="$(basename "$repo_root")"

safe_owner="$(sanitize_name "$owner")"
safe_repo="$(sanitize_name "$repo")"
path_hash="$(printf '%s' "$repo_root" | sha1sum | cut -c1-6)"

session_name="vsc_${safe_owner}_${safe_repo}_${path_hash}"
exec tmux new-session -A -s "$session_name"
