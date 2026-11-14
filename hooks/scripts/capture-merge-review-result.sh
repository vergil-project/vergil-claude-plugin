#!/usr/bin/env bash
# capture-merge-review-result.sh — SubagentStop hook for the
# vergil:merge-reviewer agent (vergil-project/vergil-claude-plugin#1065).
#
# Stores the reviewer's reply as result-<step>.md, byte for byte, so the
# merge-review skill never retypes it. Claude Code hands the hook the
# subagent's last assistant message (`last_assistant_message`) and its
# transcript (`agent_transcript_path`). The reviewer's whole prompt is
# one line, the absolute path of its request file, so the transcript's
# first user message names the request; the result goes next to it:
#
#   <dir>/request-<step>.json  ->  <dir>/result-<step>.md
#                                  <dir>/capture-<step>.json
#
# capture-<step>.json records what was stored:
#
#   {"schema": "merge-review-capture/1", "step": "<step>",
#    "request_id": "<the request's request_id>",
#    "result_sha256": "<sha256 of result-<step>.md>",
#    "agent_id": "<the reviewer subagent's ID>"}
#
# so a later check can tell that the stored result is the reviewer's own
# output and refuse one edited after the capture.
#
# Before writing, it runs `vrg-merge-review-request --ensure-dir` for the
# request's issue from the request's worktree, the check the skill runs
# before every write to the private directory, and writes only when the
# directory it prints is the request's own.
#
# Any other subagent type is a no-op. Every failure prints the problem
# on stderr and exits 1, a non-blocking error: exit 2 would keep the
# reviewer running and change its last message. The skill treats a
# missing or mismatched capture as an error, so a failure here is never
# silent.
set -euo pipefail

HOOK_NAME="capture-merge-review-result"
AGENT_TYPE="vergil:merge-reviewer"

fail() {
	printf '%s: %s. The merge reviewer'\''s reply was not stored; the merge-review run must stop with error.\n' \
		"$HOOK_NAME" "$1" >&2
	exit 1
}

sha256_of() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum -- "$1" | cut -d' ' -f1
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 -- "$1" | cut -d' ' -f1
	else
		return 1
	fi
}

command -v jq >/dev/null 2>&1 || fail "jq is not installed, so the hook input cannot be parsed"
input=$(cat) || fail "could not read the hook input from stdin"
agent_type=$(printf '%s' "$input" | jq -r '.agent_type | strings' 2>/dev/null) ||
	fail "the hook input is not valid JSON"
if [ "$agent_type" != "$AGENT_TYPE" ]; then
	exit 0
fi

# Validated before anything is written.
printf '%s' "$input" | jq -e '.last_assistant_message | strings | length > 0' >/dev/null 2>&1 ||
	fail "the hook input has no last_assistant_message"
transcript=$(printf '%s' "$input" | jq -r '.agent_transcript_path | strings') ||
	fail "the hook input has no agent_transcript_path"
agent_id=$(printf '%s' "$input" | jq -r '.agent_id | strings') ||
	fail "the hook input has no agent_id"
[ -n "$agent_id" ] || fail "the hook input has no agent_id"
[ -n "$transcript" ] && [ -f "$transcript" ] ||
	fail "the reviewer's transcript is not a readable file"

# The prompt: the first user message of the transcript, a plain string.
prompt=$(jq -rs 'map(select(.type == "user")) | .[0].message.content | strings' "$transcript" 2>/dev/null) ||
	fail "cannot read the reviewer's prompt from its transcript"
# Strip surrounding whitespace only; the prompt must be the path alone.
prompt="${prompt#"${prompt%%[![:space:]]*}"}"
prompt="${prompt%"${prompt##*[![:space:]]}"}"

request_re='^/.+/build/\.vergil-state/issue-implement/[1-9][0-9]*/merge-review/request-(review|check|check-[2-9])\.json$'
if ! printf '%s' "$prompt" | grep -Eq "$request_re" || [ "$(printf '%s\n' "$prompt" | wc -l)" -ne 1 ]; then
	fail "the reviewer's prompt is not the absolute path of a merge-review request file"
fi
request="$prompt"
[ -f "$request" ] && [ ! -L "$request" ] || fail "the request file is not a regular file"

dir="${request%/*}"
base="${request##*/}"
step="${base#request-}"
step="${step%.json}"

req_step=$(jq -r '.step | strings' "$request" 2>/dev/null) || fail "the request file is not valid JSON"
request_id=$(jq -r '.request_id | strings' "$request")
issue=$(jq -r '.issue | strings' "$request")
worktree=$(jq -r '.worktree | strings' "$request")
[ "$req_step" = "$step" ] || fail "the request file's step does not match its name"
printf '%s' "$request_id" | grep -Eq '^[0-9a-f]{32}$' || fail "the request file has no valid request_id"
[ -n "$issue" ] && [ -n "$worktree" ] && [ -d "$worktree" ] ||
	fail "the request file names no issue or no existing worktree"

# The private directory check, run from the task's worktree.
ensured=$(cd "$worktree" && vrg-merge-review-request --issue "$issue" --ensure-dir) ||
	fail "vrg-merge-review-request --ensure-dir refused the private directory"
[ "$ensured" = "$dir" ] || fail "the request file is not in its issue's private directory"

tmp_result=""
tmp_capture=""
# Removes whichever temporary file has not been moved into place.
trap 'rm -f -- "$tmp_result" "$tmp_capture"' EXIT

tmp_result=$(mktemp "$dir/.capture-result.XXXXXX") || fail "cannot create a temporary file in the private directory"
tmp_capture=$(mktemp "$dir/.capture-record.XXXXXX") || fail "cannot create a temporary file in the private directory"
chmod 600 -- "$tmp_result" "$tmp_capture" || fail "cannot make the temporary files private"

# -j writes the string's exact bytes: no added newline, nothing re-encoded.
printf '%s' "$input" | jq -j '.last_assistant_message' >"$tmp_result" ||
	fail "cannot write the reviewer's reply"
digest=$(sha256_of "$tmp_result") || fail "neither sha256sum nor shasum is installed"
printf '%s' "$digest" | grep -Eq '^[0-9a-f]{64}$' || fail "the reply's sha256 could not be computed"

jq -n --arg step "$step" --arg rid "$request_id" --arg sha "$digest" --arg aid "$agent_id" '{
	schema: "merge-review-capture/1",
	step: $step,
	request_id: $rid,
	result_sha256: $sha,
	agent_id: $aid
}' >"$tmp_capture" || fail "cannot write the capture record"

mv -f -- "$tmp_result" "$dir/result-$step.md" || fail "cannot store result-$step.md"
tmp_result=""
mv -f -- "$tmp_capture" "$dir/capture-$step.json" || fail "cannot store capture-$step.json"
tmp_capture=""
exit 0
