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

# gh_api_targets <command-text> <url-regex>
#
# Succeeds when the command runs `gh api` outside any quoted span and
# its raw text names a URL matching <url-regex> (an ERE), followed by
# whitespace, a quote, a query string or the end of the text. The URL
# is read from the raw command, not the stripped one, so a quoted URL
# is still seen (as block-github-contents-api.sh does).
gh_api_targets() {
	local command="$1" url_regex="$2" stripped
	stripped=$(strip_quoted_segments "$command")
	printf '%s' "$stripped" | grep -qE 'gh\s+api(\s|$)' || return 1
	printf '%s' "$command" | grep -qE "${url_regex}([\"'[:space:]?]|\$)"
}

# gh_api_sends_method <command-text> <METHOD>
#
# Succeeds when the command's `gh api` call sends <METHOD>: a method
# flag names it (-X M, -XM, -X=M, --method M or --method=M, quoted or
# not, in any case), or <METHOD> is POST, no method flag is given and a
# field or input flag is (-f, -F, --raw-field, --field, --input), since
# gh api then defaults to POST.
gh_api_sends_method() {
	local command="$1" method="$2" stripped
	if printf '%s' "$command" \
		| grep -qiE "(^|\s)(-X\s*=?\s*|--method(\s+|=))[\"']?${method}([\"'[:space:]]|\$)"; then
		return 0
	fi
	[ "$method" = POST ] || return 1
	stripped=$(strip_quoted_segments "$command")
	if printf '%s' "$stripped" | grep -qE '(^|\s)(-X|--method)'; then
		return 1
	fi
	printf '%s' "$stripped" \
		| grep -qE '(^|\s)(-[fF]|--raw-field(\s|=|$)|--field(\s|=|$)|--input(\s|=|$))'
}

# normalize_command_words <command-text>
#
# Prints the command text as strip_quoted_segments would, except that
# a quoted span holding a single plain word (letters, digits and
# _ . / : @ % + , = -) is replaced by that word rather than by "", and
# a backslash before such a character outside any quoted span is
# dropped. The shell removes these quotes and backslashes before it
# runs the command, so 'commit', "git", g"it" and \git read as the
# words the shell sees. Spans holding anything else still become "",
# so quoted prose never reaches command position.
normalize_command_words() {
	printf '%s' "$1" | jq -Rsr '
		gsub("(?<q>\"(\\\\.|[^\"\\\\])*\"|'\''[^'\'']*'\'')";
			(.q[1:-1]) as $in
			| if ($in | test("^[A-Za-z0-9_./:@%+,=-]+$")) then $in else "\"\"" end)
		| gsub("\\\\(?<c>[A-Za-z0-9_./:@%+,=-])"; .c)'
}

# GIT_COMMIT_RE: an ERE matching a `git commit` invocation in the text
# normalize_command_words prints. The git word sits in command position
# (a line start, or after ; & | ( or {), optionally after variable
# assignments, `!`, and command wrappers (env, command, exec, nohup,
# time, nice, sudo, timeout, xargs and the like, with their options and
# arguments). It may be path-qualified (/usr/bin/git), and may carry
# git's global options before `commit`. GIT_COMMIT_GLOBAL_OPT_RE is
# one of those global options, with its argument where it takes one.
_gc_assign='[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*'
_gc_wrapper='([^[:space:]]*/)?(env|command|builtin|exec|nohup|time|nice|ionice|sudo|doas|timeout|xargs|stdbuf|setsid|chronic)'
_gc_warg='(-[uUgCnaIPSsLd]|--unset|--chdir|--user|--group)[[:space:]]+[^[:space:]]+|-[^[:space:]]*|[0-9][0-9.]*[smhd]?|'"$_gc_assign"
_gc_prefix="($_gc_assign|!|$_gc_wrapper([[:space:]]+($_gc_warg))*)[[:space:]]+"
GIT_COMMIT_GLOBAL_OPT_RE='[[:space:]]+(-C|-c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix|--attr-source)[[:space:]]+[^[:space:]]+|[[:space:]]+--[a-z-]+=[^[:space:]]*|[[:space:]]+(-p|-P|--paginate|--no-pager|--bare|--exec-path|--no-replace-objects|--no-lazy-fetch|--no-optional-locks|--no-advice|--literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs)'
GIT_COMMIT_RE="(^|[;&|({][[:space:]]*)($_gc_prefix)*([^[:space:]]*/)?git($GIT_COMMIT_GLOBAL_OPT_RE)*[[:space:]]+commit([[:space:];&|)}]|\$)"
unset _gc_assign _gc_wrapper _gc_warg _gc_prefix

# git_commit_invoked <command-text>
#
# Succeeds when the command runs `git commit`: GIT_COMMIT_RE matches
# the normalized text.
git_commit_invoked() {
	normalize_command_words "$1" | grep -qE "$GIT_COMMIT_RE"
}
