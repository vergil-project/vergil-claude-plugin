#!/usr/bin/env bash
# guard-merge-review-results.sh — PreToolUse hook for
# Write|Edit|NotebookEdit (vergil-project/vergil-claude-plugin#1065).
#
# A merge review's result-<step>.md, reply-<step>.md (its publishable
# copy) and capture-<step>.json are written only by the
# capture-merge-review-result SubagentStop hook, from the reviewer's own
# reply. This guard denies the Write, Edit and NotebookEdit tools on any
# of them in any task's private directory,
#
#   .../build/.vergil-state/issue-implement/<N>/merge-review/
#
# so an agent cannot retype, shorten or "tidy" a stored result. It
# matches the path as given (made absolute) and, when python3 is
# present, the path with every symlink resolved, so a link cannot slip a
# write past it.
#
# SOFT GATE: Bash-command writes are out of scope here. The capture
# record's sha256 is what lets the result check catch an edit made any
# other way.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/hook-input.sh"

hook_input_read gated
file_path=$(printf '%s' "$HOOK_INPUT" |
	jq -r '.tool_input | objects
      | ((.file_path | strings | select(. != ""))
         // (.notebook_path | strings | select(. != "")))
      // empty')
hook_input_scope_dir
# A call whose target cannot be read cannot be checked: refused in a
# managed repo (#776), a no-op outside one like every gated hook.
if [ -z "$file_path" ]; then
	if ! is_managed_repo "$HOOK_SCOPE_DIR"; then
		exit 0
	fi
	hook_input_fail_closed "the hook input has no tool_input.file_path or notebook_path string"
fi

case "$file_path" in
/*) candidate="$file_path" ;;
*) candidate="$HOOK_SCOPE_DIR/$file_path" ;;
esac
case "$candidate" in
/*) ;;
*) candidate="$PWD/$candidate" ;;
esac

protected_re='/build/\.vergil-state/issue-implement/[^/]+/merge-review/(result-[^/]*\.md|reply-[^/]*\.md|capture-[^/]*\.json)$'

is_protected() {
	printf '%s' "$1" | grep -Eq "$protected_re"
}

resolved=""
if command -v python3 >/dev/null 2>&1; then
	resolved=$(python3 -I -c \
		"import os,sys; print(os.path.realpath(sys.argv[1]))" \
		"$candidate" 2>/dev/null || echo "")
fi

if ! is_protected "$candidate" && { [ -z "$resolved" ] || ! is_protected "$resolved"; }; then
	exit 0
fi

# Gated like the other hooks: the private directory lives in a managed
# repo's main clone, so a matching path outside one is not a result.
check_dir="${resolved:-$candidate}"
while [ -n "$check_dir" ] && [ "$check_dir" != "/" ] && [ ! -d "$check_dir" ]; do
	check_dir="${check_dir%/*}"
done
if ! is_managed_repo "${check_dir:-/}"; then
	exit 0
fi

jq -n --arg path "$file_path" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("merge-review result guard: \($path) is a stored merge-review result, its publishable copy or its capture record. Only the capture-merge-review-result hook writes these, from the merge reviewer'"'"'s own reply; the agent never writes, edits or retypes them. Read the file instead. To get a new result, rebuild the step'"'"'s request and dispatch the reviewer again, as the merge-review skill says. See vergil-project/vergil-claude-plugin#1065.")
  }
}'
exit 0
