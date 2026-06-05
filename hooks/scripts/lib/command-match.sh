#!/usr/bin/env bash
# command-match.sh — shared quote-stripping helper for the plugin's
# command matchers (#450).
#
# Tool-name matchers scan the Bash tool's raw command string. A tool
# name at the start of a line inside a quoted multi-line argument
# (vrg-commit --body, vrg-gh issue create --body) is
# indistinguishable from a tool name in command position, producing
# false denies. Stripping quoted spans first removes argument
# content from the matcher's view; what remains is command
# structure.
#
# Canonical rule and accepted gaps:
#   docs/specs/2026-06-05-450-command-matcher-quoting-design.md §2
#
# This file is meant to be `source`d, not executed directly.
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/command-match.sh"
#   stripped=$(strip_quoted_segments "$command")
#   if echo "$stripped" | grep -qE '(^|[;&|({]\s*)git\s+commit(\s|$)'; then

# strip_quoted_segments <command-text>
#
# Prints the command text with single- and double-quoted spans
# replaced by the placeholder "" in one left-to-right pass (leftmost
# match wins, mirroring how the shell scans). Double-quoted spans
# honor backslash escapes; single-quoted spans do not (shell
# semantics). Multi-line spans are handled: jq's gsub operates on
# the whole string, unlike line-oriented sed/grep. jq is already a
# hard dependency of every hook script.
#
# Unbalanced quotes leave the remainder unstripped — a
# false-positive (over-blocking) direction only; see spec §2.1.
strip_quoted_segments() {
	printf '%s' "$1" | jq -Rsr 'gsub("\"(\\\\.|[^\"\\\\])*\"|'\''[^'\'']*'\''"; "\"\"")'
}
