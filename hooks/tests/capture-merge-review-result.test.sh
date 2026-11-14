#!/usr/bin/env bash
# capture-merge-review-result.test.sh — tests for the SubagentStop hook
# that stores the merge reviewer's reply (#1065).
#
# Builds a scratch private directory with a request file and a reviewer
# transcript, stubs vrg-merge-review-request on PATH, feeds SubagentStop
# payloads to the hook and checks what it stored. bash 3.2-compatible.
#
# Usage: bash hooks/tests/capture-merge-review-result.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/capture-merge-review-result.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TMP=$(cd "$TMP" && pwd -P)

MAIN="$TMP/main"
WT="$MAIN/.worktrees/issue-7-x"
DIR="$MAIN/build/.vergil-state/issue-implement/7/merge-review"
mkdir -p "$WT" "$DIR"
chmod 700 "$MAIN/build/.vergil-state" "$MAIN/build/.vergil-state/issue-implement" \
	"$MAIN/build/.vergil-state/issue-implement/7" "$DIR"

# The stub prints STUB_ENSURED (default: the real directory) for the
# exact ensure-dir call, or exits STUB_EXIT.
BIN="$TMP/bin"
mkdir -p "$BIN"
# shellcheck disable=SC2016 # the stub's variables must expand when the stub runs
printf '%s\n' \
	'#!/usr/bin/env bash' \
	'if [ "${STUB_EXIT:-0}" != 0 ]; then echo "ERROR: refused" >&2; exit "$STUB_EXIT"; fi' \
	'if [ "$*" != "--issue owner/repo#7 --ensure-dir" ]; then echo "bad args: $*" >&2; exit 2; fi' \
	'printf "%s\n" "$STUB_ENSURED"' >"$BIN/vrg-merge-review-request"
chmod +x "$BIN/vrg-merge-review-request"
export PATH="$BIN:$PATH"
export STUB_ENSURED="$DIR"

RID="0123456789abcdef0123456789abcdef"

# write_request <step> [<step in the file>]
write_request() {
	jq -n --arg step "${2:-$1}" --arg rid "$RID" --arg wt "$WT" \
		'{schema: "merge-review-request/1", request_id: $rid, step: $step,
		  repo: "owner/repo", issue: "owner/repo#7", worktree: $wt}' >"$DIR/request-$1.json"
}

# write_transcript <prompt>
write_transcript() {
	jq -nc --arg p "$1" '{type: "user", message: {role: "user", content: $p}}' >"$TMP/transcript.jsonl"
	jq -nc '{type: "assistant", message: {content: [{type: "text", text: "ignored"}]}}' >>"$TMP/transcript.jsonl"
	jq -nc '{type: "user", message: {role: "user", content: "a later user line"}}' >>"$TMP/transcript.jsonl"
}

# The reply: a result block, Unicode prose and trailing blank lines, all
# of which must survive byte for byte.
REPLY_FILE="$TMP/reply.md"
printf '%s\n' '```merge-review-result' \
	'{"schema": "merge-review-result/1", "step": "review", "request_id": "x", "findings": []}' \
	'```' '' 'Nothing met the bar — I read the diff “in full”.' '' '' >"$REPLY_FILE"

# payload [<agent_type>] [--no-message]
payload() {
	local agent="${1:-vergil:merge-reviewer}"
	if [ "${2:-}" = "--no-message" ]; then
		jq -n --arg a "$agent" --arg t "$TMP/transcript.jsonl" \
			'{hook_event_name: "SubagentStop", stop_hook_active: false, agent_id: "a1",
			  agent_type: $a, agent_transcript_path: $t}'
	else
		jq -n --arg a "$agent" --arg t "$TMP/transcript.jsonl" --rawfile m "$REPLY_FILE" \
			'{hook_event_name: "SubagentStop", stop_hook_active: false, agent_id: "a1",
			  agent_type: $a, agent_transcript_path: $t, last_assistant_message: $m}'
	fi
}

reset_dir() {
	rm -f "$DIR"/* "$DIR"/.capture-* 2>/dev/null
	export STUB_ENSURED="$DIR"
	unset STUB_EXIT
}

pass=0
fail=0

ok() {
	echo "PASS $1"
	pass=$((pass + 1))
}
bad() {
	echo "FAIL $1 — $2"
	fail=$((fail + 1))
}

sha() {
	if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

mode_of() {
	if stat -c %a "$1" >/dev/null 2>&1; then stat -c %a "$1"; else stat -f %Lp "$1"; fi
}

# expect_refusal <name>: the hook exits 1, names itself on stderr, and
# leaves no result, capture or temporary file.
expect_refusal() {
	local name="$1" rc err
	err=$(payload "${PAYLOAD_AGENT:-vergil:merge-reviewer}" "${PAYLOAD_FLAG:-}" | bash "$HOOK" 2>&1 >/dev/null)
	rc=$?
	if [ "$rc" -ne 1 ]; then
		bad "$name" "exit $rc, expected 1"
	elif ! printf '%s' "$err" | grep -q '^capture-merge-review-result: '; then
		bad "$name" "no error message on stderr"
	elif ls "$DIR"/result-* "$DIR"/capture-* "$DIR"/.capture-* >/dev/null 2>&1; then
		bad "$name" "files were left in the private directory"
	else
		ok "$name"
	fi
}

# 1. Another subagent type is a no-op.
reset_dir
write_request review
write_transcript "$DIR/request-review.json"
out=$(payload general-purpose | bash "$HOOK" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && ! ls "$DIR"/result-* >/dev/null 2>&1; then
	ok "another subagent type is ignored"
else
	bad "another subagent type is ignored" "exit $rc, output '$out'"
fi

# 2. The reviewer's reply is stored byte for byte, with its capture record.
reset_dir
write_request review
write_transcript "$DIR/request-review.json"
out=$(payload | bash "$HOOK" 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
	bad "the reply is stored unchanged" "exit $rc: $out"
elif ! cmp -s "$REPLY_FILE" "$DIR/result-review.md"; then
	bad "the reply is stored unchanged" "result-review.md differs from the reply"
else
	ok "the reply is stored unchanged"
	cap="$DIR/capture-review.json"
	if [ "$(jq -r '.schema, .step, .request_id, .agent_id' "$cap" | tr '\n' ' ')" = "merge-review-capture/1 review $RID a1 " ] &&
		[ "$(jq -r '.result_sha256' "$cap")" = "$(sha "$DIR/result-review.md")" ] &&
		[ "$(jq -r 'keys | join(",")' "$cap")" = "agent_id,request_id,result_sha256,schema,step" ]; then
		ok "the capture record binds the request and the result's sha256"
	else
		bad "the capture record binds the request and the result's sha256" "$(cat "$cap")"
	fi
	if [ "$(mode_of "$DIR/result-review.md")" = 600 ] && [ "$(mode_of "$cap")" = 600 ]; then
		ok "the stored files are mode 600"
	else
		bad "the stored files are mode 600" "modes $(mode_of "$DIR/result-review.md") $(mode_of "$cap")"
	fi
	if ls "$DIR"/.capture-* >/dev/null 2>&1; then
		bad "no temporary file is left" "found $(ls -a "$DIR")"
	else
		ok "no temporary file is left"
	fi
fi

# 3. A check step stores result-<step>.md, replacing an earlier one.
reset_dir
write_request check-2
write_transcript "$DIR/request-check-2.json"
printf 'stale\n' >"$DIR/result-check-2.md"
out=$(payload | bash "$HOOK" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && cmp -s "$REPLY_FILE" "$DIR/result-check-2.md" &&
	[ "$(jq -r .step "$DIR/capture-check-2.json")" = check-2 ]; then
	ok "a check step's result replaces an earlier one"
else
	bad "a check step's result replaces an earlier one" "exit $rc: $out"
fi

# Refusals: each leaves nothing behind.
reset_dir
write_request review
write_transcript "$DIR/request-review.json"
PAYLOAD_FLAG=--no-message expect_refusal "a payload with no last_assistant_message is refused"

reset_dir
write_request review
write_transcript "Review the branch at $DIR/request-review.json"
expect_refusal "a prompt that is not the request path alone is refused"

reset_dir
write_request review
write_transcript "$DIR/request-review.json
second line"
expect_refusal "a multi-line prompt is refused"

reset_dir
write_request review
write_transcript "$TMP/elsewhere/request-review.json"
expect_refusal "a request outside a private directory is refused"

reset_dir
write_request review
write_transcript "$DIR/request-fix.json"
expect_refusal "a request name that is not a step is refused"

reset_dir
write_transcript "$DIR/request-review.json"
expect_refusal "a missing request file is refused"

reset_dir
write_request review check
write_transcript "$DIR/request-review.json"
expect_refusal "a request whose step does not match its name is refused"

reset_dir
write_request review
write_transcript "$DIR/request-review.json"
export STUB_EXIT=1
expect_refusal "an ensure-dir refusal stops the capture"

reset_dir
write_request review
write_transcript "$DIR/request-review.json"
export STUB_ENSURED="$MAIN/build/.vergil-state/issue-implement/8/merge-review"
expect_refusal "a request outside its issue's own directory is refused"

echo "----------------------------------------"
echo "capture-merge-review-result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
