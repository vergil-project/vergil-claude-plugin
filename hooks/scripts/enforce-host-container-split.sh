#!/usr/bin/env bash
# enforce-host-container-split.sh — PreToolUse hook for Bash.
# Warns when a container-only tool is invoked bare on the host (#96,
# #993). The wrapped form, vrg-container-run -- <tool>, passes
# silently, and so does a host tool wrapped in vrg-container-run: it
# fails on its own in the container, and the full vrg-validate before
# handoff is the backstop.
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
source "$SCRIPT_DIR/lib/host-container-tools.sh"
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

# A container tool in command position (at the start or after a
# separator) is a bare host call. Wrapped in vrg-container-run --, the
# tool follows "-- ", not a separator, so it does not match.
for tool in "${CONTAINER_TOOLS[@]}"; do
  if echo "$stripped" | grep -qE "(^|[;&|({]\s*)$tool(\s|$)"; then
    jq -n --arg tool "$tool" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: ("WARNING: \($tool) runs in the dev container: use vrg-container-run -- \($tool) … for an ad hoc run; a full vrg-container-run -- vrg-validate is still required before handoff.")
      }
    }'
    exit 0
  fi
done

exit 0
