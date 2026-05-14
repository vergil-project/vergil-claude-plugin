#!/usr/bin/env bash
# block-github-contents-api.sh — PreToolUse hook for Bash.
#
# Blocks gh api calls that write to the GitHub Contents API. File changes
# must go through the local workflow (worktree → vrg-commit → vrg-submit-pr),
# not bypass it via direct API writes to remote branches.
#
# Only blocks write methods (PUT, POST, DELETE). GET requests (the default
# when no method flag is present) are allowed — reading file contents is fine.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml. See hooks/scripts/lib/managed-repo-check.sh.
set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
if ! is_managed_repo "$cwd"; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

# Check if the command uses gh api targeting the Contents API with a write method.
#
# Patterns matched:
#   gh api --method PUT|POST|DELETE repos/.../contents/...
#   gh api --method PUT|POST|DELETE https://api.github.com/repos/.../contents/...
#   gh api -X PUT|POST|DELETE repos/.../contents/...
#   gh api -XPUT|-XPOST|-XDELETE repos/.../contents/...
#   Method flag before or after the URL argument (agents use both orderings).
#
# NOT matched:
#   gh api repos/.../contents/...          (no method flag → defaults to GET)
#   gh api --method GET repos/.../contents/...
#   gh api repos/.../issues/...            (not the Contents API)

has_contents_url=false
has_write_method=false

# Check for Contents API URL (short or full form).
if echo "$command" | grep -qE 'gh\s+api\s' && echo "$command" | grep -qE '(repos/[^[:space:]]*/contents/|https://api\.github\.com/repos/[^[:space:]]*/contents/)'; then
  has_contents_url=true
fi

# Check for a write method flag.
# Handles: --method PUT, --method POST, --method DELETE, -X PUT, -X POST,
#           -X DELETE, -XPUT, -XPOST, -XDELETE
if echo "$command" | grep -qiE '(--method\s+(PUT|POST|DELETE)|-X\s*(PUT|POST|DELETE))'; then
  has_write_method=true
fi

if [ "$has_contents_url" = true ] && [ "$has_write_method" = true ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Direct writes to the GitHub Contents API are blocked. File changes must go through the local workflow: edit files in your worktree, commit with vrg-commit, and submit with vrg-submit-pr. Note: vrg-gh denies gh api entirely.\n\nSee docs/specs/worktree-convention.md in vergil-tooling for the full convention."
    }
  }'
else
  exit 0
fi
