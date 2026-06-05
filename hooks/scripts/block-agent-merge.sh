#!/usr/bin/env bash
# block-agent-merge.sh — PreToolUse hook for Bash.
# Unconditionally denies gh pr merge / gh pr review --approve and the
# equivalent gh api calls. Under the 2.1 workflow agents have no merge
# path at all (credential-enforced); merging is the human's Phase-6
# action via vrg-finalize-pr. This hook is the ergonomic fast-fail on
# top of that hard credential gate.
# Note: vrg-gh also rejects pr merge for non-escalated contexts.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

if ! is_managed_repo "$cwd"; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

is_merge_command=false

if echo "$command" \
     | grep -qE '(^|[;&|]\s*)gh\s+pr\s+(merge(\s|$)|review\s+.*--approve)'; then
  is_merge_command=true
fi

if echo "$command" | grep -qE 'gh\s+api\s+.*/pulls/[0-9]+/merge(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+PUT|--method\s+PUT|-XPUT)'; then
  is_merge_command=true
fi

if echo "$command" | grep -qE 'gh\s+api\s+.*/pulls/[0-9]+/reviews(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+POST|--method\s+POST|-XPOST)'; then
  is_merge_command=true
fi

if [ "$is_merge_command" = false ]; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Agents never merge or approve PRs. Merging is a human action (Phase 6 of the 2.1 workflow, via vrg-finalize-pr) -- hand the PR URL to the human. This applies to all identities and all branches, release PRs included. See issue #441."
  }
}'
