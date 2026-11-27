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
source "$SCRIPT_DIR/lib/hook-input.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"

hook_input_read gated
hook_input_scope_dir
cwd="$HOOK_SCOPE_DIR"
if ! is_managed_repo "$cwd"; then
  exit 0
fi

# Check the input before delegating, so malformed input fails closed
# even under a vrg-hook-guard that predates its own fail-closed check.
hook_input_command
command="$HOOK_COMMAND"

# Delegate and stop. The guard's verdict is final: the regex fallback
# below must not also run, or a raw git commit would emit two JSON
# documents on stdout (#776). The guard's exit code, including its
# blocking exit 2, is passed through.
if command -v vrg-hook-guard &>/dev/null; then
  guard_rc=0
  printf '%s' "$HOOK_INPUT" | vrg-hook-guard || guard_rc=$?
  exit "$guard_rc"
fi

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
