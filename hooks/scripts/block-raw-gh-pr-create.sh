#!/usr/bin/env bash
# block-raw-gh-pr-create.sh — PreToolUse hook for Bash.
# Blocks raw 'gh pr create' commands. Use vrg-submit-pr instead.
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

command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

if echo "$stripped" | grep -qE '(^|[;&|({]\s*)gh\s+pr\s+create(\s|$)'; then
  deny "Raw gh pr create is blocked. Use vrg-submit-pr instead. All gh operations should use vrg-gh, which enforces subcommand allowlists, credential selection, and audit logging."
elif echo "$stripped" | grep -qE 'gh\s+api\s+.*(/pulls)(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+POST|--method\s+POST|-XPOST)'; then
  deny "gh api POST to /pulls is equivalent to gh pr create and is blocked. Use vrg-submit-pr instead. All gh operations should use vrg-gh."
else
  exit 0
fi
