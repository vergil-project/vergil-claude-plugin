#!/usr/bin/env bash
# guard-task-dispatch.sh — PreToolUse hook for the Agent tool.
# Keeps every task run on the vergil:task-runner agent and its pinned
# model (vergil-project/vergil-claude-plugin#1431, epic
# vergil-project/.github#1823). A dispatch is a task run when its whole
# description matches one of epic-implement's four task-run forms. The
# hook denies:
#   - a task run whose subagent_type is not exactly vergil:task-runner
#     (absent included), so it never falls back to an inheriting agent;
#   - a vergil:task-runner dispatch with a non-empty model, which would
#     outrank the agent definition's pin;
#   - a vergil:implementer dispatch whose model is anything but absent
#     or "sonnet" (vergil-project/vergil-claude-plugin#1467). A first
#     try passes no model and the one escalation retry passes
#     model: "sonnet"; any other per-invocation model would outrank the
#     Haiku pin. A non-string model is refused too;
#   - a description whose first word is Task or Batch, followed by a
#     space, that matches none of the forms (a malformed task run).
# A description that only names a task among other words (a writer or
# reviewer dispatch, say) is not a task run.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml. Input that cannot be parsed, or that has no
# tool_input.description string, fails closed (exit 2, #776).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/hook-input.sh"

RUNNER="vergil:task-runner"
WRITER="vergil:implementer"
WRITER_RETRY_MODEL="sonnet"

hook_input_read gated
hook_input_scope_dir
cwd="$HOOK_SCOPE_DIR"
if ! is_managed_repo "$cwd"; then
  exit 0
fi

description=$(printf '%s' "$HOOK_INPUT" | jq -r \
  'if (.tool_input | type) != "object" then error("no tool_input object")
   elif (.tool_input.description | type) != "string" then error("no description")
   else .tool_input.description end' 2>/dev/null) ||
  hook_input_fail_closed "the hook input has no tool_input.description string"

# subagent_type as it is when a string, empty when absent or null, and
# its JSON text otherwise (which never equals the runner's name).
subagent_type=$(printf '%s' "$HOOK_INPUT" | jq -r \
  '.tool_input.subagent_type | if . == null then "" elif type == "string" then . else tojson end') ||
  hook_input_fail_closed "could not read tool_input.subagent_type from the hook input"

# model as it is when a string, empty when absent, null or "", and its
# JSON text otherwise (so a non-string never equals a model name).
model=$(printf '%s' "$HOOK_INPUT" | jq -r \
  '.tool_input.model | if . == null or . == "" then "" elif type == "string" then . else tojson end') ||
  hook_input_fail_closed "could not read tool_input.model from the hook input"

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# The four task-run forms of epic-implement's task-description table,
# matched against the whole description (POSIX ERE).
FORM_TASK='^Task [^ ]+ [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+$'
FORM_TASK_NO_ID='^Task [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+$'
FORM_BATCH='^Batch [^ #][^ ]*( #[0-9]+)+$'
FORM_BATCH_NO_ID='^Batch( #[0-9]+)+$'
TASK_LIKE='^(Task|Batch)[ ]'

is_task_run=false
if [[ "$description" =~ $FORM_TASK ]] || [[ "$description" =~ $FORM_TASK_NO_ID ]] ||
  [[ "$description" =~ $FORM_BATCH ]] || [[ "$description" =~ $FORM_BATCH_NO_ID ]]; then
  is_task_run=true
fi

if [ "$is_task_run" = true ] && [ "$subagent_type" != "$RUNNER" ]; then
  shown="$subagent_type"
  if [ -z "$shown" ]; then
    shown="an unset subagent_type"
  fi
  deny "task run '$description' must be dispatched as $RUNNER, not $shown"
fi

if [ "$is_task_run" = false ] && [[ "$description" =~ $TASK_LIKE ]]; then
  deny "description '$description' starts like a task run but matches none of the task-run forms; use one of: Task <id> <owner>/<repo>#<N>, Task <owner>/<repo>#<N>, Batch <ids> #<N>…, Batch #<N>…"
fi

if [ "$subagent_type" = "$RUNNER" ] && [ -n "$model" ]; then
  deny "$RUNNER must not be dispatched with a model; its pin is in the agent definition"
fi

if [ "$subagent_type" = "$WRITER" ] && [ -n "$model" ] && [ "$model" != "$WRITER_RETRY_MODEL" ]; then
  deny "$WRITER may be dispatched only with no model (a first try) or model \"$WRITER_RETRY_MODEL\" (the one retry), not model $model"
fi

exit 0
