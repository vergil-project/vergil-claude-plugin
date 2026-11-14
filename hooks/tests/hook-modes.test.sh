#!/usr/bin/env bash
# hook-modes.test.sh — tests for validate-custom's hook script mode
# check (#1067).
#
# Each case builds a scratch git repo with a hooks/hooks.json and its
# scripts staged at chosen modes, runs check_hook_modes on it (sourced
# from scripts/bin/validate-custom) and asserts the exit status and the
# paths its errors name. bash 3.2-compatible. Run from anywhere.
#
# Usage: bash hooks/tests/hook-modes.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_CUSTOM="$SCRIPT_DIR/../../scripts/bin/validate-custom"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

# new_repo <name> <command>... — a scratch repo whose hooks.json names
# each <command>, one PreToolUse hook apiece. Prints the repo path.
new_repo() {
	local repo="$TMP/$1" first=1 command
	shift
	mkdir -p "$repo/hooks/scripts"
	git -C "$repo" init --quiet
	{
		printf '{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": ['
		for command in "$@"; do
			[[ "$first" -eq 1 ]] || printf ', '
			first=0
			printf '{"type": "command", "command": "%s"}' "$command"
		done
		printf ']}]}}\n'
	} >"$repo/hooks/hooks.json"
	printf '%s\n' "$repo"
}

# stage <repo> <path> <+x|-x> — write a script at <path> and stage it
# with the executable bit set or cleared.
stage() {
	printf '#!/bin/sh\nexit 0\n' >"$1/$2"
	git -C "$1" add -- "$2"
	git -C "$1" update-index --chmod="$3" -- "$2"
}

# run_case <name> <repo> <expected status> <expected error path>...
# Each expected path must appear on an ERROR line; with none expected,
# no ERROR line may appear.
run_case() {
	local name="$1" repo="$2" expect="$3" out rc path ok=1
	shift 3
	out="$( (
		# shellcheck source=../../scripts/bin/validate-custom
		source "$VALIDATE_CUSTOM"
		check_hook_modes "$repo"
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
		if ! grep -q "^ERROR: $path: " <<<"$out"; then
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

P='${CLAUDE_PLUGIN_ROOT}'

repo=$(new_repo exec "$P/hooks/scripts/a.sh")
stage "$repo" hooks/scripts/a.sh +x
run_case "an executable hook script passes" "$repo" 0

repo=$(new_repo args "$P/hooks/scripts/a.sh --flag value")
stage "$repo" hooks/scripts/a.sh +x
run_case "a hook command with arguments checks its script" "$repo" 0

repo=$(new_repo nonexec "$P/hooks/scripts/a.sh" "$P/hooks/scripts/b.sh")
stage "$repo" hooks/scripts/a.sh +x
stage "$repo" hooks/scripts/b.sh -x
run_case "a non-executable hook script fails, naming it" "$repo" 1 \
	hooks/scripts/b.sh

repo=$(new_repo twobad "$P/hooks/scripts/a.sh" "$P/hooks/scripts/b.sh")
stage "$repo" hooks/scripts/a.sh -x
stage "$repo" hooks/scripts/b.sh -x
run_case "every non-executable hook script is named" "$repo" 1 \
	hooks/scripts/a.sh hooks/scripts/b.sh

repo=$(new_repo disk-only "$P/hooks/scripts/a.sh")
printf '#!/bin/sh\n' >"$repo/hooks/scripts/a.sh"
chmod +x "$repo/hooks/scripts/a.sh"
run_case "an executable script on disk but not in git fails" "$repo" 1 \
	hooks/scripts/a.sh

repo=$(new_repo missing "$P/hooks/scripts/a.sh" "$P/hooks/scripts/gone.sh")
stage "$repo" hooks/scripts/a.sh +x
run_case "a missing hook script fails, naming it" "$repo" 1 \
	hooks/scripts/gone.sh

repo=$(new_repo noprefix "/usr/local/bin/a.sh")
run_case "a command outside the plugin root fails" "$repo" 1 \
	hooks/hooks.json

repo=$(new_repo empty)
run_case "a hooks.json with no hook commands fails" "$repo" 1 \
	hooks/hooks.json

repo="$TMP/nohooks"
mkdir -p "$repo"
git -C "$repo" init --quiet
run_case "a missing hooks.json fails" "$repo" 1 hooks/hooks.json

echo "hook-modes: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
