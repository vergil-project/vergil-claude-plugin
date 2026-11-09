#!/usr/bin/env bash
# Claude Code PreToolUse hook shim.
# Delegates to vrg-hook-guard if available; falls back to a
# jq-based git/gh check that hard-denies when vergil-tooling
# is not installed.
#
# The fallback fails closed, like vrg-hook-guard: input it cannot
# check (empty stdin, invalid JSON, or no tool_input.command string),
# or a missing jq, is refused with Claude Code's blocking exit code 2
# and a stderr message, never let through unchecked.
set -euo pipefail

if command -v vrg-hook-guard &>/dev/null; then
  exec vrg-hook-guard
fi

fail_closed() {
  printf 'guard.sh: blocked: %s. The hook guard cannot check this call for raw git/gh, so it fails closed and refuses it.\n' "$1" >&2
  exit 2
}

command -v jq &>/dev/null || fail_closed "neither vrg-hook-guard nor jq is installed"

input=$(cat)
[ -n "${input//[[:space:]]/}" ] || fail_closed "the hook input on stdin is empty"

# A well-formed payload for a tool other than Bash passes through with
# no command, matching vrg-hook-guard.
filter='if type != "object" then error("the hook input is not a JSON object")
  elif (.tool_name | type) == "string" and .tool_name != "Bash" then ""
  elif (.tool_input | type) != "object" then error("the hook input has no tool_input object")
  elif (.tool_input.command | type) != "string" then error("the hook input has no tool_input.command string")
  else .tool_input.command end'
cmd=$(printf '%s' "$input" | jq -r "$filter" 2>/dev/null) \
  || fail_closed "the hook input is not valid JSON or has no tool_input.command string"

bin=$(printf '%s' "$cmd" | awk '{print $1}')
base=$(basename "$bin" 2>/dev/null || printf '%s' "$bin")

case "$base" in
  git|gh)
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "Raw git/gh is blocked in Vergil-managed repos. Install vergil-tooling to enable the vrg-git/vrg-gh wrappers."
      }
    }'
    exit 0
    ;;
esac

exit 0
