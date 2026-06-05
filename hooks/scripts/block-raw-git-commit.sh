#!/usr/bin/env bash
# block-raw-git-commit.sh — PreToolUse hook for Bash.
# Delegates to vrg-hook-guard for comprehensive git/gh blocking.
# Falls back to a regex check for git commit if vrg-hook-guard
# is not installed.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml. See hooks/scripts/lib/managed-repo-check.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

if ! is_managed_repo "$cwd"; then
  exit 0
fi

if command -v vrg-hook-guard &>/dev/null; then
  printf '%s' "$input" | exec vrg-hook-guard
fi

command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")

if echo "$stripped" | grep -qE '(^|[;&|({]\s*)git\s+commit(\s|$)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Raw git commit is blocked. Use vrg-commit instead. All git operations should use vrg-git, which enforces subcommand allowlists and audit logging."
    }
  }'
else
  exit 0
fi
