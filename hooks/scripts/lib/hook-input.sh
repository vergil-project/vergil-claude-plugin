#!/usr/bin/env bash
# hook-input.sh — shared fail-closed reader for the plugin's gating
# hook scripts (#776).
#
# A PreToolUse gate that cannot parse its stdin must refuse the tool
# call, not let it through. Before this helper, each script ran `jq`
# under `set -e`; on malformed input jq failed with a non-blocking exit
# code and Claude Code ran the call unchecked. These functions refuse
# such input with Claude Code's blocking exit code 2 and a stderr
# message naming the problem, matching vrg-hook-guard and the
# repo-level guard.sh shim (vergil-project/vergil-tooling#3773).
#
# Scope mirrors vrg-hook-guard. A gated hook (one that is a no-op
# outside a managed repo) still allows unparseable input when the hook
# process's own working directory is outside a managed repo, since the
# input names no usable cwd. An ungated hook refuses it everywhere.
# Behaviour on well-formed input is unchanged.
#
# This file is meant to be `source`d, not executed directly. It sources
# managed-repo-check.sh itself.
#
# Usage:
#   source "$SCRIPT_DIR/lib/hook-input.sh"
#   hook_input_read gated          # sets HOOK_INPUT, or exits
#   hook_input_scope_dir           # sets HOOK_SCOPE_DIR
#   if ! is_managed_repo "$HOOK_SCOPE_DIR"; then exit 0; fi
#   hook_input_command             # sets HOOK_COMMAND, or exits 2

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/managed-repo-check.sh"

HOOK_NAME="${HOOK_NAME:-${0##*/}}"

# hook_input_fail_closed <problem>
#
# Refuses the tool call: prints the problem to stderr and exits 2, the
# PreToolUse blocking exit code (Claude Code feeds stderr to the agent).
hook_input_fail_closed() {
	printf '%s: blocked: %s. This hook cannot check the tool call, so it fails closed and refuses it. This is a hook-protocol problem, not a problem with the command itself.\n' "$HOOK_NAME" "$1" >&2
	exit 2
}

# hook_input_read <gated|ungated>
#
# Reads stdin into HOOK_INPUT and checks it is exactly one JSON object.
# On failure: a gated hook exits 0 when the hook process's working
# directory is outside a managed repo; otherwise the call is refused.
hook_input_read() {
	local scope="$1" problem="" shape=""
	HOOK_INPUT=""
	if ! command -v jq >/dev/null 2>&1; then
		problem="jq is not installed, so the hook input cannot be parsed"
	elif ! HOOK_INPUT=$(cat); then
		problem="could not read the hook input from stdin"
	elif [ -z "${HOOK_INPUT//[[:space:]]/}" ]; then
		problem="the hook input on stdin is empty"
	elif ! shape=$(printf '%s' "$HOOK_INPUT" | jq -rs \
		'if length != 1 then "several JSON values"
		 elif (.[0] | type) != "object" then "a JSON \(.[0] | type)"
		 else "object" end' 2>/dev/null); then
		problem="the hook input is not valid JSON"
	elif [ "$shape" != "object" ]; then
		problem="the hook input is not a JSON object (got $shape)"
	fi

	if [ -z "$problem" ]; then
		return 0
	fi
	if [ "$scope" = "gated" ] && ! is_managed_repo "$PWD"; then
		exit 0
	fi
	hook_input_fail_closed "$problem"
}

# hook_input_scope_dir
#
# Sets HOOK_SCOPE_DIR to the directory whose ancestry decides whether a
# gated hook applies: tool_input.cwd, else the top-level cwd, else ".".
# Non-string or empty values are skipped rather than erroring.
hook_input_scope_dir() {
	HOOK_SCOPE_DIR=$(printf '%s' "$HOOK_INPUT" | jq -r \
		'((.tool_input | objects | .cwd | strings | select(. != ""))
		  // (.cwd | strings | select(. != ""))
		  // ".")') ||
		hook_input_fail_closed "could not read the cwd from the hook input"
}

# hook_input_command
#
# Sets HOOK_COMMAND to tool_input.command. A missing or non-string
# command is refused; an empty string is allowed through as-is.
hook_input_command() {
	HOOK_COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r \
		'if (.tool_input | type) != "object" then error("no tool_input object")
		 elif (.tool_input.command | type) != "string" then error("no command")
		 else .tool_input.command end' 2>/dev/null) ||
		hook_input_fail_closed "the hook input has no tool_input.command string"
}
