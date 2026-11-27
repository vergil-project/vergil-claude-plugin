#!/usr/bin/env bash
# block-agent-merge.sh — PreToolUse hook for Bash.
# Unconditionally denies gh pr merge / gh pr review --approve and the
# equivalent gh api calls. No agent merges a PR directly or approves one:
# a PR merges only through vrg-submit-pr, which opens it with auto-merge
# on. This hook is the ergonomic fast-fail on top of the hard credential
# and server-side gates.
# Note: vrg-gh also rejects pr merge for non-escalated contexts.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/hook-input.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"

hook_input_read gated
hook_input_scope_dir
cwd="$HOOK_SCOPE_DIR"
if ! is_managed_repo "$cwd"; then
  exit 0
fi

hook_input_command
command="$HOOK_COMMAND"
stripped=$(strip_quoted_segments "$command")

is_merge_command=false

if echo "$stripped" \
     | grep -qE '(^|[;&|({]\s*)gh\s+pr\s+(merge(\s|$)|review\s+.*--approve)'; then
  is_merge_command=true
fi

if gh_api_targets "$command" '/pulls/[0-9]+/merge' \
  && gh_api_sends_method "$command" PUT; then
  is_merge_command=true
fi

if gh_api_targets "$command" '/pulls/[0-9]+/reviews' \
  && gh_api_sends_method "$command" POST; then
  is_merge_command=true
fi

if [ "$is_merge_command" = false ]; then
  exit 0
fi

reason="Agents never merge or approve PRs directly. A PR merges only through \`vrg-submit-pr\`, which opens it with auto-merge on, so it merges by itself once its checks pass; an agent never approves any PR. This applies to all identities and all branches, release PRs included. See issue #441."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
