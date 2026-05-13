#!/usr/bin/env bash
# enforce-host-container-split.sh — PreToolUse hook for Bash.
# Enforces the host-vs-container tool routing rule from #96.
#
# - DENY: wrapping a host-only tool in vrg-docker-run --
# - WARN: bare-invoking a container-only tool without vrg-docker-run --
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/host-container-tools.sh"

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

if ! is_managed_repo "$cwd"; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

# Check for host tools wrapped in vrg-docker-run -- (DENY)
for tool in "${HOST_TOOLS[@]}"; do
  if echo "$command" | grep -qE "(^|[;&|]\s*)vrg-docker-run\s+--\s+$tool(\s|$)"; then
    jq -n --arg tool "$tool" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("\($tool) is a host command — invoke directly without vrg-docker-run wrapping. See issue #96: https://github.com/vergil-project/vergil-claude-plugin/issues/96")
      }
    }'
    exit 0
  fi
done

# Check for container tools invoked directly (WARN)
for tool in "${CONTAINER_TOOLS[@]}"; do
  if echo "$command" | grep -qE "(^|[;&|]\s*)(vrg-docker-run\s+--\s+)?$tool(\s|$)"; then
    jq -n --arg tool "$tool" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: ("WARNING: \($tool) should not be invoked directly. Use vrg-docker-run -- vrg-validate for validation — it handles tool routing internally. See issue #168: https://github.com/vergil-project/vergil-claude-plugin/issues/168")
      }
    }'
    exit 0
  fi
done

exit 0
