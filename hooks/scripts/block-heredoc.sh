#!/usr/bin/env bash
# block-heredoc.sh — PreToolUse hook for Bash.
# Blocks heredoc syntax (<<EOF, <<'EOF', etc.) in shell commands.
# Heredocs cause shell escaping failures with apostrophes, backticks,
# and special characters. Write to a temp file and use --body-file instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/hook-input.sh"

# Not gated on managed-repo detection, so input it cannot parse is
# refused everywhere (#776).
hook_input_read ungated
hook_input_command
command="$HOOK_COMMAND"

# Match heredoc operators: <<EOF, <<'EOF', <<"EOF", <<-EOF, etc.
# But not << used in other contexts (e.g., bitshift in Python/etc.).
if echo "$command" | grep -qE '<<-?\s*'\''?[A-Z_]+'\''?'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Heredoc syntax (<<EOF) is blocked. Write multi-line content to a temporary file and pass it via --body-file or --file instead."
    }
  }'
else
  exit 0
fi
