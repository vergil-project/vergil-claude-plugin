#!/usr/bin/env bash
# guard-task-dispatch.test.sh — tests for the PreToolUse hook that keeps
# every task run on the vergil:task-runner agent and its pinned model
# (vergil-project/vergil-claude-plugin#1431).
#
# Each case feeds the hook a realistic Agent-tool PreToolUse payload,
# with its cwd in a scratch managed repo (or an unmanaged directory),
# and asserts the verdict: deny (a permissionDecision "deny" JSON
# response, exit 0) or allow (exit 0, no output). Malformed input is
# covered by hook-input.test.sh. bash 3.2-compatible.
#
# Usage: bash hooks/tests/guard-task-dispatch.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/guard-task-dispatch.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

MANAGED="$TMP/managed"
mkdir -p "$MANAGED"
git -C "$MANAGED" init --quiet
printf '[project]\n' >"$MANAGED/vergil.toml"

UNMANAGED="$TMP/unmanaged"
mkdir -p "$UNMANAGED"

RUNNER=vergil:task-runner

pass=0
fail=0

# agent_payload <cwd> <description> [<subagent_type>] [<model>]
# A realistic Claude Code Agent payload. An empty <subagent_type> or
# <model> leaves the field out; the literal EMPTY gives it the value "".
agent_payload() {
	jq -cn --arg cwd "$1" --arg d "$2" --arg t "${3:-}" --arg m "${4:-}" '{
		session_id: "s", transcript_path: "/dev/null", cwd: $cwd,
		permission_mode: "default", hook_event_name: "PreToolUse",
		tool_name: "Agent",
		tool_input: ({description: $d, prompt: "Run the skill."}
			+ (if $t == "" then {} elif $t == "EMPTY" then {subagent_type: ""} else {subagent_type: $t} end)
			+ (if $m == "" then {} elif $m == "EMPTY" then {model: ""} else {model: $m} end))}'
}

# run <cwd> <description> [<subagent_type>] [<model>] — sets OUT, ERR, RC.
run() {
	OUT=$( (cd "$1" && agent_payload "$@" | bash "$HOOK" 2>"$TMP/stderr"))
	RC=$?
	ERR=$(cat "$TMP/stderr")
}

verdict() {
	if [ "$RC" -ne 0 ] || [ -n "$ERR" ]; then
		echo error
	elif [ -z "$OUT" ]; then
		echo allow
	elif printf '%s' "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"
		and .hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
		echo deny
	else
		echo error
	fi
}

# expect <name> <allow|deny> [<reason substring>]
expect() {
	local name="$1" want="$2" needle="${3:-}" got reason=""
	got=$(verdict)
	if [ "$got" = deny ]; then
		reason=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason')
	fi
	if [ "$got" = "$want" ] &&
		{ [ -z "$needle" ] || printf '%s' "$reason" | grep -qF -- "$needle"; }; then
		echo "PASS $name"
		pass=$((pass + 1))
	else
		echo "FAIL $name — expected $want${needle:+ with '$needle'}, got $got (rc=$RC)"
		printf '%s\n' "$OUT" "$ERR" | head -5 | sed 's/^/       /'
		fail=$((fail + 1))
	fi
}

FORMS=(
	"Task 6b vergil-project/vergil-tooling#4931"
	"Batch 6b/6c/9 #4917 #4918 #4926"
	"Task vergil-project/vergil-tooling#5012"
	"Batch #5012 #5013"
)

test_each_form_refused_as_general_purpose() {
	local d
	for d in "${FORMS[@]}"; do
		run "$MANAGED" "$d" general-purpose
		expect "'$d' as general-purpose is refused" deny \
			"task run '$d' must be dispatched as vergil:task-runner, not general-purpose"
	done
}

test_each_form_allowed_as_task_runner() {
	local d
	for d in "${FORMS[@]}"; do
		run "$MANAGED" "$d" "$RUNNER"
		expect "'$d' as vergil:task-runner is allowed" allow
	done
}

test_non_digit_id_is_a_task_run() {
	run "$MANAGED" "Task D2 vergil-project/vergil-tooling#5012" general-purpose
	expect "a D2 task ID as general-purpose is refused" deny "must be dispatched as vergil:task-runner"
	run "$MANAGED" "Task D2 vergil-project/vergil-tooling#5012" "$RUNNER"
	expect "a D2 task ID as vergil:task-runner is allowed" allow
	run "$MANAGED" "Batch 6/D2 #4917 #5012" "$RUNNER"
	expect "a batch with a D2 ID as vergil:task-runner is allowed" allow
}

test_missing_subagent_type_refused_for_task_run() {
	run "$MANAGED" "Task 6b vergil-project/vergil-tooling#4931"
	expect "a task run with no subagent_type is refused" deny "must be dispatched as vergil:task-runner"
	run "$MANAGED" "Task 6b vergil-project/vergil-tooling#4931" EMPTY
	expect "a task run with an empty subagent_type is refused" deny "must be dispatched as vergil:task-runner"
	run "$MANAGED" "Task 6b vergil-project/vergil-tooling#4931" vergil:task-runner-x
	expect "a task run as a near-miss agent type is refused" deny "must be dispatched as vergil:task-runner"
}

test_writer_dispatch_naming_task_allowed() {
	run "$MANAGED" "Write vergil-project/vergil-tooling#4931 (Task 6b)" vergil:implementer
	expect "a writer dispatch that names its task is allowed" allow
	run "$MANAGED" "Review vergil-project/vergil-tooling#4931 (Task 6b)" vergil:merge-reviewer
	expect "a reviewer dispatch that names its task is allowed" allow
}

test_short_ref_refused_as_malformed() {
	run "$MANAGED" "Task 6b #4931" general-purpose
	expect "'Task 6b #4931' as general-purpose is refused as malformed" deny \
		"description 'Task 6b #4931' starts like a task run but matches none of the task-run forms"
	run "$MANAGED" "Task 6b #4931" "$RUNNER"
	expect "'Task 6b #4931' as vergil:task-runner is refused as malformed" deny \
		"matches none of the task-run forms"
}

test_trailing_word_refused_as_malformed() {
	local d
	for d in "Task 6b vergil-project/vergil-tooling#4931 retry" \
		"Batch 6b/6c #4917 #4918 again" \
		"Task vergil-project/vergil-tooling#5012 (resume)"; do
		run "$MANAGED" "$d" "$RUNNER"
		expect "'$d' is refused as malformed" deny "matches none of the task-run forms"
	done
	run "$MANAGED" "Task 6b vergil-project/vergil-tooling#4931 retry"
	expect "a malformed task run with no subagent_type is refused" deny "matches none of the task-run forms"
}

test_task_word_mid_description_allowed() {
	run "$MANAGED" "Run Task 6b checks" general-purpose
	expect "'Run Task 6b checks' is allowed" allow
}

test_tasks_word_allowed() {
	run "$MANAGED" "Tasks overview" general-purpose
	expect "'Tasks overview' is allowed" allow
	run "$MANAGED" "Batching plan" general-purpose
	expect "'Batching plan' is allowed" allow
}

test_task_runner_with_model_refused() {
	run "$MANAGED" "Task 6b vergil-project/vergil-tooling#4931" "$RUNNER" opus
	expect "a task run as vergil:task-runner with a model is refused" deny \
		"vergil:task-runner must not be dispatched with a model; its pin is in the agent definition"
	run "$MANAGED" "Explore the epic" "$RUNNER" haiku
	expect "any vergil:task-runner dispatch with a model is refused" deny "must not be dispatched with a model"
}

test_task_runner_with_empty_model_allowed() {
	run "$MANAGED" "Task 6b vergil-project/vergil-tooling#4931" "$RUNNER" EMPTY
	expect "a task run as vergil:task-runner with an empty model is allowed" allow
}

test_unmanaged_repo_noop() {
	run "$UNMANAGED" "Task 6b vergil-project/vergil-tooling#4931" general-purpose
	expect "a task run as general-purpose outside a managed repo is allowed" allow
	run "$UNMANAGED" "Task 6b #4931" general-purpose
	expect "a malformed task run outside a managed repo is allowed" allow
}

test_pr_watch_reentry_form_allowed_as_task_runner() {
	# A re-entry is a task run of issue-implement, dispatched in a task-run
	# form: for a reported-ready task with an open PR (pr-watch resumes it)
	# and for one lost before submit (no PR yet).
	run "$MANAGED" "Task 3 vergil-project/vergil-claude-plugin#1431" "$RUNNER"
	expect "an open-PR re-entry as vergil:task-runner is allowed" allow
	run "$MANAGED" "Task vergil-project/vergil-claude-plugin#1431" "$RUNNER"
	expect "a no-PR re-entry as vergil:task-runner is allowed" allow
	run "$MANAGED" "Task 3 vergil-project/vergil-claude-plugin#1431" general-purpose
	expect "a re-entry as general-purpose is refused" deny "must be dispatched as vergil:task-runner"
}

test_each_form_refused_as_general_purpose
test_each_form_allowed_as_task_runner
test_non_digit_id_is_a_task_run
test_missing_subagent_type_refused_for_task_run
test_writer_dispatch_naming_task_allowed
test_short_ref_refused_as_malformed
test_trailing_word_refused_as_malformed
test_task_word_mid_description_allowed
test_tasks_word_allowed
test_task_runner_with_model_refused
test_task_runner_with_empty_model_allowed
test_unmanaged_repo_noop
test_pr_watch_reentry_form_allowed_as_task_runner

echo "----------------------------------------"
echo "guard-task-dispatch: $pass passed, $fail failed, $((pass + fail)) total"
[ "$fail" -eq 0 ]
