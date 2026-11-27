#!/usr/bin/env bash
# agent-models.test.sh — tests for validate-custom's agent model check
# (vergil-project/vergil-claude-plugin#1430).
#
# Each case builds a scratch root with agents/*.md and a model map at
# docs/site/docs/agents/models.md, runs check_agent_models on it (sourced
# from scripts/bin/validate-custom) and asserts the exit status and the
# file each error names. bash 3.2-compatible. Run from anywhere.
#
# Usage: bash hooks/tests/agent-models.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_CUSTOM="$SCRIPT_DIR/../../scripts/bin/validate-custom"
MAP=docs/site/docs/agents/models.md
# A backtick, for the code spans of the model map's table cells.
B=$'\x60'

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

# new_root <name> — an empty scratch root with agents/ and the map's
# directory. Prints its path.
new_root() {
	local root="$TMP/$1"
	mkdir -p "$root/agents" "$root/$(dirname "$MAP")"
	printf '%s\n' "$root"
}

# agent <root> <name> <frontmatter line>... — write agents/<name>.md
# with a name line, a description and each given frontmatter line.
agent() {
	local root="$1" name="$2" line
	shift 2
	{
		printf -- '---\nname: %s\ndescription: >-\n  A test agent.\n' "$name"
		for line in "$@"; do
			printf '%s\n' "$line"
		done
		printf -- '---\n\n# %s\n' "$name"
	} >"$root/agents/$name.md"
}

# map <root> <row>... — write the model map with an Agents section
# holding a table of the given rows, then a skills table whose rows must
# never be read as agent rows.
map() {
	local root="$1" row
	shift
	{
		printf '# Model map\n\n## Agents\n\n'
		printf '| Agent | Model | Reason |\n| --- | --- | --- |\n'
		for row in "$@"; do
			printf '%s\n' "$row"
		done
		printf '\n## Skills\n\n'
		printf '| Skill | Where it runs | Model there | Validation alias |\n'
		printf '| --- | --- | --- | --- |\n'
		printf '| %s | session | opus | %s |\n' "${B}vergil:ghost${B}" "${B}opus${B}"
	} >"$root/$MAP"
}

# run_case <name> <root> <expected status> <expected error file>...
# Each expected file must appear on an ERROR line; with none expected,
# no ERROR line may appear.
run_case() {
	local name="$1" root="$2" expect="$3" out rc path ok=1
	shift 3
	out="$( (
		# shellcheck source=/dev/null
		source "$VALIDATE_CUSTOM"
		check_agent_models "$root"
	) 2>&1)"
	rc=$?
	if [[ "$rc" -ne "$expect" ]]; then
		ok=0
	fi
	if [[ "$#" -eq 0 ]]; then
		if grep -q '^ERROR:' <<<"$out"; then
			ok=0
		fi
	fi
	for path in "$@"; do
		if ! grep -qF "ERROR: $path: " <<<"$out"; then
			ok=0
		fi
	done
	if [[ "$ok" -eq 1 ]]; then
		pass=$((pass + 1))
		echo "PASS: $name"
	else
		fail=$((fail + 1))
		echo "FAIL: $name (exit $rc, expected $expect)"
		printf '%s\n' "$out" | sed 's/^/    /'
	fi
}

test_agent_without_model_fails() {
	local root
	root=$(new_root no-model)
	agent "$root" a "tools: Read"
	map "$root" "| ${B}vergil:a${B} | sonnet | Drives. |"
	run_case "an agent with no model line fails" "$root" 1 agents/a.md
}

test_two_model_lines_fails() {
	local root
	root=$(new_root two-models)
	agent "$root" a "model: sonnet" "model: opus"
	map "$root" "| ${B}vergil:a${B} | sonnet | Drives. |"
	run_case "an agent with two model lines fails" "$root" 1 agents/a.md
}

test_unknown_model_value_fails() {
	local root
	root=$(new_root unknown)
	agent "$root" a "model: gpt-5"
	map "$root" "| ${B}vergil:a${B} | gpt-5 | Drives. |"
	run_case "an unknown model value fails" "$root" 1 agents/a.md
}

test_inherit_without_map_row_fails() {
	local root
	root=$(new_root inherit-no-row)
	agent "$root" a "model: inherit"
	map "$root"
	run_case "inherit with no model map row fails" "$root" 1 agents/a.md
}

test_inherit_with_map_row_and_reason_passes() {
	local root
	root=$(new_root inherit-reason)
	agent "$root" a "model: inherit"
	map "$root" "| ${B}vergil:a${B} | ${B}inherit${B} | Takes its caller's model on purpose. |"
	run_case "inherit with a reasoned model map row passes" "$root" 0
}

test_inherit_with_empty_reason_fails() {
	local root
	root=$(new_root inherit-empty)
	agent "$root" a "model: inherit"
	map "$root" "| ${B}vergil:a${B} | inherit |  |"
	run_case "inherit with an empty reason fails" "$root" 1 agents/a.md
}

test_map_model_mismatch_fails() {
	local root
	root=$(new_root mismatch)
	agent "$root" a "model: haiku"
	map "$root" "| ${B}vergil:a${B} | sonnet | Drives. |"
	run_case "a model map row with another model fails" "$root" 1 agents/a.md
}

test_agent_missing_from_map_fails() {
	local root
	root=$(new_root missing-row)
	agent "$root" a "model: sonnet"
	agent "$root" b "model: haiku"
	map "$root" "| ${B}vergil:a${B} | sonnet | Drives. |"
	run_case "an agent with no model map row fails" "$root" 1 agents/b.md
}

test_map_row_without_agent_fails() {
	local root
	root=$(new_root orphan-row)
	agent "$root" a "model: sonnet"
	map "$root" "| ${B}vergil:a${B} | sonnet | Drives. |" \
		"| ${B}vergil:gone${B} | haiku | Writes. |"
	run_case "a model map row with no agent file fails" "$root" 1 "$MAP"
}

test_pinned_agents_pass() {
	local root
	root=$(new_root pinned)
	agent "$root" a "tools: Read" "model: sonnet"
	agent "$root" b "model: \"haiku\""
	agent "$root" c "model: opus"
	map "$root" "| ${B}vergil:a${B} | ${B}sonnet${B} | Drives. |" \
		"| ${B}vergil:b${B} | haiku | Writes. |" \
		"| ${B}vergil:c${B} | opus | Judges. |" \
		"| ${B}paad:paad-delegate${B} | opus | Passed by the dispatch. |"
	run_case "pinned agents with matching rows pass" "$root" 0
}

test_agent_without_model_fails
test_two_model_lines_fails
test_unknown_model_value_fails
test_inherit_without_map_row_fails
test_inherit_with_map_row_and_reason_passes
test_inherit_with_empty_reason_fails
test_map_model_mismatch_fails
test_agent_missing_from_map_fails
test_map_row_without_agent_fails
test_pinned_agents_pass

echo "agent-models: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
