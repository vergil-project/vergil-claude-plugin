#!/usr/bin/env bash
# block-worktree-bypass-write.test.sh — table-driven tests for the
# worktree write guard.
#
# Builds a scratch managed repo on the worktree convention and feeds
# the hook Write payloads for paths in a worktree, in the main worktree
# and under the main clone's build/.vergil-state/, asserting each
# decision. bash 3.2-compatible: parallel indexed arrays, no
# associative arrays.
#
# Usage: bash hooks/tests/block-worktree-bypass-write.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/block-worktree-bypass-write.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TMP=$(cd "$TMP" && pwd -P)

# S: a managed repo on the worktree convention, with a worktree, a
# source directory, a state directory and some links.
S="$TMP/main"
mkdir -p "$S/.worktrees/wt/sub" "$S/src" "$S/build/.vergil-state/agentic-review/9001/1"
git -C "$S" init --quiet
printf '[project]\n' >"$S/vergil.toml"
printf '.worktrees/\n' >"$S/.gitignore"
ln -s "$S" "$S/.worktrees/wt/up"
ln -s "$S" "$S/.worktrees/wt2"
ln -s "$S/src" "$S/build/.vergil-state/src"

# L: a second managed repo whose build/.vergil-state is itself a link.
L="$TMP/linked"
mkdir -p "$L/.worktrees" "$L/src" "$L/build"
git -C "$L" init --quiet
printf '[project]\n' >"$L/vergil.toml"
printf '.worktrees/\n' >"$L/.gitignore"
ln -s "$L/src" "$L/build/.vergil-state"

# A directory outside any managed repo.
U="$TMP/unmanaged"
mkdir -p "$U"

# A PATH without python3.
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/mask-hook-guard.sh"
mask_tool_path "$TMP/mask" python3
NOPY_PATH="$MASKED_PATH"

T_NAME=(
	"write inside a worktree is allowed"
	"write in a worktree with a resolvable dot-dot segment is allowed"
	"write to the main worktree is denied"
	"write outside a managed repo is allowed"
	"write under the state directory is allowed"
	"write under a new state subdirectory is allowed"
	"write elsewhere under build/ is denied"
	"write to a sibling of the state directory is denied"
	"normalisation: worktree path, case 1"
	"normalisation: worktree path, case 2"
	"normalisation: worktree path, case 3"
	"normalisation: state path, case 1"
	"normalisation: state path, case 2"
	"normalisation: state path, case 3"
	"a path that cannot be normalised in a managed repo is refused"
	"a path that cannot be normalised into a managed repo from outside it is refused"
	"a path that cannot be normalised outside a managed repo is allowed"
)
T_PATH=(
	"$S/.worktrees/wt/new.txt"
	"$S/.worktrees/wt/sub/../new.txt"
	"$S/new.txt"
	"$U/new.txt"
	"$S/build/.vergil-state/agentic-review/9001/1/details.md"
	"$S/build/.vergil-state/design-review/42/S1/security.md"
	"$S/build/new.txt"
	"$S/build/.vergil-state-other/new.txt"
	"$S/.worktrees/wt/../../new.txt"
	"$S/.worktrees/wt/up/new.txt"
	"$S/.worktrees/wt2/new.txt"
	"$S/build/.vergil-state/../../new.txt"
	"$S/build/.vergil-state/src/new.txt"
	"$L/build/.vergil-state/new.txt"
	"$S/.worktrees/wt/new.txt"
	"$S/new.txt"
	"$U/new.txt"
)
T_CWD=(
	"$S" "$S" "$S" "$U" "$S" "$S" "$S" "$S"
	"$S" "$S" "$S" "$S" "$S" "$L"
	"$S" "$U" "$U"
)
T_PATHVAR=(
	"" "" "" "" "" "" "" ""
	"" "" "" "" "" ""
	"$NOPY_PATH" "$NOPY_PATH" "$NOPY_PATH"
)
T_EXPECT=(
	"allow"
	"allow"
	"deny"
	"allow"
	"allow"
	"allow"
	"deny"
	"deny"
	"deny"
	"deny"
	"deny"
	"deny"
	"deny"
	"deny"
	"blocked"
	"blocked"
	"allow"
)

pass=0
fail=0
i=0
total=${#T_NAME[@]}

while [ "$i" -lt "$total" ]; do
	name="${T_NAME[$i]}"
	payload=$(jq -cn --arg fp "${T_PATH[$i]}" --arg cwd "${T_CWD[$i]}" '{
		session_id: "s", transcript_path: "/dev/null", cwd: $cwd,
		permission_mode: "default", hook_event_name: "PreToolUse",
		tool_name: "Write",
		tool_input: {file_path: $fp, content: "x"}}')
	run_path="${T_PATHVAR[$i]:-$PATH}"

	out=$(cd "${T_CWD[$i]}" && printf '%s' "$payload" |
		PATH="$run_path" bash "$HOOK" 2>"$TMP/stderr")
	rc=$?
	err=$(cat "$TMP/stderr")

	if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ -n "$err" ]; then
		verdict="blocked"
	elif [ "$rc" -ne 0 ] || [ -n "$err" ]; then
		verdict="error"
	elif [ -z "$out" ]; then
		verdict="allow"
	elif printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
		verdict="deny"
	else
		verdict="error"
	fi

	if [ "$verdict" = "${T_EXPECT[$i]}" ]; then
		echo "PASS [$i] $name"
		pass=$((pass + 1))
	else
		echo "FAIL [$i] $name — expected ${T_EXPECT[$i]}, got $verdict (rc=$rc)"
		printf '%s\n' "$out" "$err" | head -5 | sed 's/^/       /'
		fail=$((fail + 1))
	fi
	i=$((i + 1))
done

echo "----------------------------------------"
echo "block-worktree-bypass-write: $pass passed, $fail failed, $total total"
[ "$fail" -eq 0 ]
