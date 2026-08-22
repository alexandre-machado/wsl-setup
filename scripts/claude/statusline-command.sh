#!/bin/bash
# Claude Code statusLine — derived from ~/.bashrc PS1, plus context-usage and turn-count segments.
input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir')

# Shorten $HOME to ~ (PS1 \w style): only when the path is $HOME itself or
# lies under it, so /home/other-user is left untouched.
case "$dir" in
  "$HOME") dir="~" ;;
  "$HOME"/*) dir="~${dir#"$HOME"}" ;;
esac
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
tpath=$(echo "$input" | jq -r '.transcript_path // empty')

# Tokens used in the last turn (last API call): sum of input + output +
# cache-creation + cache-read tokens from context_window.current_usage.
last_turn_tokens=$(echo "$input" | jq -r '
  .context_window.current_usage as $u
  | if $u then (($u.input_tokens // 0) + ($u.output_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0))
    else empty
    end
')

# Turn count: number of genuine user turns in the session transcript JSONL
# file. The JSON payload has no direct "turn count" field, so this is
# derived from transcript_path: each line is a JSON record; Claude Code
# transcripts mark both real user prompts and tool-result deliveries as
# type "user", so tool-result records (message.content containing a
# tool_result block) are filtered out to count only real user turns.
turns=0
if [ -n "$tpath" ] && [ -f "$tpath" ]; then
  turns=$(jq -r '
    select(.type == "user")
    | .message.content as $c
    | if ($c | type) == "array" then
        (if ($c | any(.type == "tool_result")) then "tool" else "user" end)
      else "user"
      end
  ' "$tpath" 2>/dev/null | grep -c '^user$')
fi

# Total tokens consumed across the whole session: sum of input + output +
# cache-creation + cache-read tokens from every assistant message's usage
# block in the transcript, INCLUDING subagent transcripts. Subagent turns
# are recorded in separate files at
# <transcript_dir>/<session_id>/subagents/agent-*.jsonl (siblings of the
# main <transcript_dir>/<session_id>.jsonl), so those must be globbed in
# too or subagent token usage is silently dropped from the total.
total_tokens=0
if [ -n "$tpath" ] && [ -f "$tpath" ]; then
  tdir=$(dirname "$tpath")
  sid=$(basename "$tpath" .jsonl)
  subdir="$tdir/$sid/subagents"
  files=("$tpath")
  if [ -d "$subdir" ]; then
    for f in "$subdir"/agent-*.jsonl; do
      [ -f "$f" ] && files+=("$f")
    done
  fi
  total_tokens=$(jq -s '
    map(select(.type == "assistant") | .message.usage // empty)
    | map((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
    | add // 0
  ' "${files[@]}" 2>/dev/null)
fi

printf '\033[2;32m%s@%s\033[0m:\033[2;34m%s\033[0m' "$(whoami)" "$(hostname -s)" "$dir"

if [ -n "$ctx" ]; then
  printf ' \033[2;33m| Ctx:%.0f%%\033[0m' "$ctx"
fi

printf ' \033[2;36m| Turns:%s\033[0m' "$turns"

if [ -n "$total_tokens" ] && [ "$total_tokens" -gt 0 ] 2>/dev/null; then
  tokens_fmt=$(awk -v t="$total_tokens" 'BEGIN {
    if (t >= 1000000) printf "%.1fM", t/1000000
    else if (t >= 1000) printf "%.1fK", t/1000
    else printf "%d", t
  }')
  printf ' \033[2;35m| Tokens:%s\033[0m' "$tokens_fmt"
fi

if [ -n "$last_turn_tokens" ] && [ "$last_turn_tokens" -gt 0 ] 2>/dev/null; then
  last_fmt=$(awk -v t="$last_turn_tokens" 'BEGIN {
    if (t >= 1000000) printf "%.1fM", t/1000000
    else if (t >= 1000) printf "%.1fK", t/1000
    else printf "%d", t
  }')
  printf ' \033[2;31m| Last:%s\033[0m' "$last_fmt"
fi
