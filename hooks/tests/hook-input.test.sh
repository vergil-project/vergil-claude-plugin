#!/usr/bin/env bash
# hook-input.test.sh — fail-closed tests for the plugin's gating hook
# scripts (#776).
#
# Every PreToolUse gate that parses its stdin must refuse a call whose
# input it cannot check: exit 2 (Claude Code's blocking exit code) and
# a stderr message naming the problem. This suite feeds each gate
# malformed JSON, empty stdin, non-object JSON and a payload missing
# its required field, and asserts that refusal. It also asserts the
# well-formed allow and deny paths with a realistic Claude Code payload,
# so a regression that denies good input (and would block every agent)
# fails here. bash 3.2-compatible: no associative arrays.
#
# Usage: bash hooks/tests/hook-input.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$SCRIPT_DIR/../scripts"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Scratch managed repo on the worktree convention: block-protected-
# branch-work and block-worktree-bypass-write deny at its root.
SCRATCH="$TMP/scratch-repo"
mkdir -p "$SCRATCH/.worktrees/wt"
git -C "$SCRATCH" init --quiet
printf '[project]\n' >"$SCRATCH/vergil.toml"
printf '.worktrees/\n' >"$SCRATCH/.gitignore"

# A directory outside any managed repo (no vergil.toml above it).
UNMANAGED="$TMP/unmanaged"
mkdir -p "$UNMANAGED"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/mask-hook-guard.sh"
# PATH without vrg-hook-guard, so block-raw-git-commit's own path runs.
mask_hook_guard_path "$TMP/mask"
# PATH without vrg-hook-guard or jq.
saved_path="$PATH"
PATH="$CLEAN_PATH"
mask_tool_path "$TMP/mask" jq
NOJQ_PATH="$MASKED_PATH"
PATH="$saved_path"

# A stub vrg-hook-guard: records that it ran, echoes a marker, and
# exits with $STUB_RC.
STUB_DIR="$TMP/stub"
mkdir -p "$STUB_DIR"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho STUB-GUARD-RAN\nexit "${STUB_RC:-0}"\n' \
	>"$STUB_DIR/vrg-hook-guard"
chmod +x "$STUB_DIR/vrg-hook-guard"

BASH_GATES="block-agent-merge.sh block-associative-arrays.sh block-autoclose-linkage.sh block-github-contents-api.sh block-protected-branch-work.sh block-raw-gh-pr-create.sh block-raw-git-commit.sh enforce-host-container-split.sh block-heredoc.sh"
WRITE_GATES="block-worktree-bypass-write.sh guard-audit-writes.sh"
# Gates that stay a no-op outside a managed repo, malformed input
# included (scope falls back to the hook process's working directory).
GATED="block-agent-merge.sh block-associative-arrays.sh block-autoclose-linkage.sh block-github-contents-api.sh block-protected-branch-work.sh block-raw-gh-pr-create.sh block-raw-git-commit.sh enforce-host-container-split.sh block-worktree-bypass-write.sh"

pass=0
fail=0

# run_hook <script> <run-dir> <payload> [<PATH>] [<identity>]
# Sets OUT, ERR and RC.
run_hook() {
	local script="$1" dir="$2" payload="$3" path="${4:-$CLEAN_PATH}" identity="${5:-audit}"
	OUT=$( (cd "$dir" && printf '%s' "$payload" |
		PATH="$path" VRG_IDENTITY_MODE="$identity" bash "$SCRIPTS/$script" 2>"$TMP/stderr"))
	RC=$?
	ERR=$(cat "$TMP/stderr")
}

# verdict — classify the last run: blocked (exit 2 + stderr), deny
# (JSON deny, exit 0), context (advisory JSON, exit 0), allow (exit 0,
# no output) or error (anything else).
verdict() {
	if [ "$RC" -eq 2 ] && [ -z "$OUT" ] && [ -n "$ERR" ]; then
		echo blocked
	elif [ "$RC" -ne 0 ] || [ -n "$ERR" ]; then
		echo error
	elif [ -z "$OUT" ]; then
		echo allow
	elif printf '%s' "$OUT" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
		echo deny
	elif printf '%s' "$OUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
		echo context
	else
		echo error
	fi
}

# check <name> <expected-verdict> [<stderr-substring>]
check() {
	local name="$1" expect="$2" needle="${3:-}" got
	got=$(verdict)
	if [ "$got" = "$expect" ] &&
		{ [ -z "$needle" ] || printf '%s' "$ERR" | grep -qF -- "$needle"; }; then
		echo "PASS $name"
		pass=$((pass + 1))
	else
		echo "FAIL $name — expected $expect${needle:+ with '$needle'}, got $got (rc=$RC)"
		printf '%s\n' "$OUT" "$ERR" | head -5 | sed 's/^/       /'
		fail=$((fail + 1))
	fi
}

# bash_payload <command> <cwd> — a realistic Claude Code Bash payload.
bash_payload() {
	jq -cn --arg cmd "$1" --arg cwd "$2" '{
		session_id: "s", transcript_path: "/dev/null", cwd: $cwd,
		permission_mode: "default", hook_event_name: "PreToolUse",
		tool_name: "Bash",
		tool_input: {command: $cmd, description: "d"}}'
}

# write_payload <file_path> <cwd> — a realistic Claude Code Write payload.
write_payload() {
	jq -cn --arg fp "$1" --arg cwd "$2" '{
		session_id: "s", transcript_path: "/dev/null", cwd: $cwd,
		permission_mode: "default", hook_event_name: "PreToolUse",
		tool_name: "Write",
		tool_input: {file_path: $fp, content: "x"}}'
}

is_in() {
	case " $2 " in *" $1 "*) return 0 ;; esac
	return 1
}

missing_field_msg() {
	case "$1" in
	block-worktree-bypass-write.sh) echo "no tool_input.file_path string" ;;
	*) echo "no tool_input.command string" ;;
	esac
}

# --- Malformed input is refused, in a managed repo ---------------------
NO_FIELD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd, tool_name: "Bash", tool_input: {cwd: $cwd}}')
STRING_TOOL_INPUT=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd, tool_input: "git commit"}')

for script in $BASH_GATES $WRITE_GATES; do
	run_hook "$script" "$ROOT" '{"tool_input": {"command": "git commit'
	check "$script: malformed JSON is blocked" blocked "$script: blocked: the hook input is not valid JSON"

	run_hook "$script" "$ROOT" ''
	check "$script: empty stdin is blocked" blocked "$script: blocked: the hook input on stdin is empty"

	run_hook "$script" "$ROOT" '   '
	check "$script: whitespace-only stdin is blocked" blocked "the hook input on stdin is empty"

	run_hook "$script" "$ROOT" '["git commit"]'
	check "$script: non-object JSON is blocked" blocked "not a JSON object (got a JSON array)"

	run_hook "$script" "$ROOT" '{} {}'
	check "$script: several JSON values are blocked" blocked "not a JSON object (got several JSON values)"

	run_hook "$script" "$ROOT" '{"tool_input": {}}' "$NOJQ_PATH"
	check "$script: missing jq is blocked" blocked "jq is not installed"

	if [ "$script" = "guard-audit-writes.sh" ]; then
		# A missing path was already denied (JSON) before #776; unchanged.
		run_hook "$script" "$ROOT" "$NO_FIELD"
		check "$script: missing file path is denied" deny
		run_hook "$script" "$ROOT" "$STRING_TOOL_INPUT"
		check "$script: non-object tool_input is denied" deny
	else
		run_hook "$script" "$ROOT" "$NO_FIELD"
		check "$script: missing field is blocked" blocked "$script: blocked: the hook input has $(missing_field_msg "$script")"
		run_hook "$script" "$ROOT" "$STRING_TOOL_INPUT"
		check "$script: non-object tool_input is blocked" blocked "$(missing_field_msg "$script")"
	fi
done

# --- Scope: gated hooks stay a no-op outside managed repos -------------
UNMANAGED_NO_FIELD=$(jq -cn --arg cwd "$UNMANAGED" '{cwd: $cwd, tool_input: {}}')
for script in $BASH_GATES $WRITE_GATES; do
	run_hook "$script" "$UNMANAGED" 'not json'
	if is_in "$script" "$GATED"; then
		check "$script: malformed JSON outside a managed repo is allowed" allow
		run_hook "$script" "$UNMANAGED" "$UNMANAGED_NO_FIELD"
		check "$script: missing field outside a managed repo is allowed" allow
	else
		check "$script: malformed JSON outside a managed repo is still blocked" blocked "not valid JSON"
	fi
done

# guard-audit-writes constrains only the audit identity.
run_hook guard-audit-writes.sh "$ROOT" 'not json' "$CLEAN_PATH" user
check "guard-audit-writes.sh: malformed JSON for a non-audit identity is allowed" allow

# --- Well-formed input: allow and deny paths are unchanged --------------
deny_command() {
	case "$1" in
	block-agent-merge.sh) echo "gh pr merge 1" ;;
	block-associative-arrays.sh) echo "declare -A map" ;;
	block-autoclose-linkage.sh) echo "vrg-submit-pr --linkage Fixes" ;;
	block-github-contents-api.sh) echo "gh api --method PUT repos/o/r/contents/f" ;;
	block-protected-branch-work.sh) echo "git commit -m x" ;;
	block-raw-gh-pr-create.sh) echo "gh pr create --title x" ;;
	block-raw-git-commit.sh) echo "git commit -m x" ;;
	enforce-host-container-split.sh) echo "vrg-container-run -- vrg-commit" ;;
	block-heredoc.sh) echo "cat <<EOF" ;;
	esac
}

for script in $BASH_GATES; do
	run_hook "$script" "$ROOT" "$(bash_payload "ls -la && echo done" "$ROOT")"
	check "$script: realistic benign Bash payload is allowed" allow

	run_hook "$script" "$ROOT" "$(bash_payload "" "$ROOT")"
	check "$script: empty command string is allowed" allow

	run_hook "$script" "$ROOT" "$(bash_payload "$(deny_command "$script")" "$SCRATCH")"
	check "$script: realistic offending Bash payload is denied" deny
done

run_hook enforce-host-container-split.sh "$ROOT" "$(bash_payload "shellcheck x.sh" "$ROOT")"
check "enforce-host-container-split.sh: container tool still warns" context

run_hook block-worktree-bypass-write.sh "$ROOT" \
	"$(write_payload "$SCRATCH/.worktrees/wt/file.txt" "$SCRATCH")"
check "block-worktree-bypass-write.sh: write inside a worktree is allowed" allow
run_hook block-worktree-bypass-write.sh "$ROOT" "$(write_payload "$SCRATCH/README.md" "$SCRATCH")"
check "block-worktree-bypass-write.sh: write to the main worktree is denied" deny
run_hook block-worktree-bypass-write.sh "$ROOT" "$(write_payload "$UNMANAGED/x.txt" "$ROOT")"
check "block-worktree-bypass-write.sh: write outside a managed repo is allowed" allow

run_hook guard-audit-writes.sh "$ROOT" "$(write_payload "$ROOT/.vergil/audit-feedback.yml" "$ROOT")"
check "guard-audit-writes.sh: audit write to its artifact is allowed" allow
run_hook guard-audit-writes.sh "$ROOT" "$(write_payload "$ROOT/README.md" "$ROOT")"
check "guard-audit-writes.sh: audit write to a repo file is denied" deny
run_hook guard-audit-writes.sh "$ROOT" "$(write_payload "$ROOT/README.md" "$ROOT")" "$CLEAN_PATH" user
check "guard-audit-writes.sh: user write is unconstrained" allow

# --- block-raw-git-commit delegation to vrg-hook-guard ------------------
STUB_PATH="$STUB_DIR:$CLEAN_PATH"

run_hook block-raw-git-commit.sh "$ROOT" "$(bash_payload "git commit -m x" "$ROOT")" "$STUB_PATH"
if [ "$RC" -eq 0 ] && [ "$OUT" = "STUB-GUARD-RAN" ]; then
	echo "PASS block-raw-git-commit.sh: delegates to vrg-hook-guard and stops (one verdict)"
	pass=$((pass + 1))
else
	echo "FAIL block-raw-git-commit.sh: delegation — expected only the guard's output, got rc=$RC:"
	printf '%s\n' "$OUT" "$ERR" | head -10 | sed 's/^/       /'
	fail=$((fail + 1))
fi

export STUB_RC=2
run_hook block-raw-git-commit.sh "$ROOT" "$(bash_payload "git commit -m x" "$ROOT")" "$STUB_PATH"
if [ "$RC" -eq 2 ]; then
	echo "PASS block-raw-git-commit.sh: passes the guard's blocking exit code through"
	pass=$((pass + 1))
else
	echo "FAIL block-raw-git-commit.sh: guard exit 2 — got rc=$RC"
	fail=$((fail + 1))
fi
unset STUB_RC

run_hook block-raw-git-commit.sh "$ROOT" 'not json' "$STUB_PATH"
check "block-raw-git-commit.sh: malformed JSON is blocked before delegating" blocked "not valid JSON"
run_hook block-raw-git-commit.sh "$ROOT" "$NO_FIELD" "$STUB_PATH"
check "block-raw-git-commit.sh: missing command is blocked before delegating" blocked "no tool_input.command string"

echo "----------------------------------------"
echo "hook-input: $pass passed, $fail failed, $((pass + fail)) total"
[ "$fail" -eq 0 ]
