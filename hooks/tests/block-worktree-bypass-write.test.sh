#!/usr/bin/env bash
# block-worktree-bypass-write.test.sh — table-driven tests for the
# worktree write guard.
#
# Builds a scratch managed repo on the worktree convention and feeds
# the hook Write payloads for paths in a worktree, in the main worktree
# and under the main clone's build/, asserting each
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

# Keep git hermetic: no global or system config, and no user-level
# ignore file, so only each scratch repo's own .gitignore decides what
# git reports ignored.
mkdir -p "$TMP/home/.config"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/home/.config"

# S: a managed repo on the worktree convention, with a worktree, a
# source directory, a state directory and some links.
S="$TMP/main"
mkdir -p "$S/.worktrees/wt/sub" "$S/src" "$S/build/.vergil-state/issue-implement/9001/1"
git -C "$S" init --quiet
printf '[project]\n' >"$S/vergil.toml"
printf '.worktrees/\nbuild/\n' >"$S/.gitignore"
printf 'x\n' >"$S/build/tracked.txt"
git -C "$S" add -f build/tracked.txt
ln -s "$S" "$S/.worktrees/wt/up"
ln -s "$S" "$S/.worktrees/wt2"
ln -s "$S/src" "$S/build/.vergil-state/src"
ln -s "$S/src" "$S/build/out"
ln -s "$S/build" "$S/src/tobuild"

# L: a second managed repo whose build/.vergil-state is itself a link.
L="$TMP/linked"
mkdir -p "$L/.worktrees" "$L/src" "$L/build"
git -C "$L" init --quiet
printf '[project]\n' >"$L/vergil.toml"
printf '.worktrees/\nbuild/\n' >"$L/.gitignore"
ln -s "$L/src" "$L/build/.vergil-state"

# B: a third managed repo whose build is itself a link to its source.
B="$TMP/buildlink"
mkdir -p "$B/.worktrees" "$B/src"
git -C "$B" init --quiet
printf '[project]\n' >"$B/vergil.toml"
printf '.worktrees/\nbuild/\n' >"$B/.gitignore"
ln -s "$B/src" "$B/build"

# N: a fourth managed repo on the convention that does not ignore build/.
N="$TMP/notignored"
mkdir -p "$N/.worktrees" "$N/build"
git -C "$N" init --quiet
printf '[project]\n' >"$N/vergil.toml"
printf '.worktrees/\n' >"$N/.gitignore"

NL=$'\n'

# A directory outside any managed repo.
U="$TMP/unmanaged"
mkdir -p "$U"

# A PATH without python3.
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/mask-hook-guard.sh"
mask_tool_path "$TMP/mask" python3
NOPY_PATH="$MASKED_PATH"

# A PATH whose python3 writes to stderr before running the real one.
NOISY="$TMP/noisy"
mkdir -p "$NOISY"
printf '#!/usr/bin/env bash\necho "noise from python3" >&2\nexec %s "$@"\n' "$(command -v python3)" >"$NOISY/python3"
chmod +x "$NOISY/python3"
NOISY_PATH="$NOISY:$PATH"

# A PATH whose git fails `check-ignore` with exit 128 and runs the real
# git for every other command.
GITSHIM="$TMP/gitshim"
mkdir -p "$GITSHIM"
printf '#!/usr/bin/env bash\nfor a in "$@"; do\n\tif [ "$a" = check-ignore ]; then\n\t\techo "fatal: shim check-ignore failure" >&2\n\t\texit 128\n\tfi\ndone\nexec %s "$@"\n' "$(command -v git)" >"$GITSHIM/git"
chmod +x "$GITSHIM/git"
GITSHIM_PATH="$GITSHIM:$PATH"

T_NAME=(
	"write inside a worktree is allowed"
	"write in a worktree with a resolvable dot-dot segment is allowed"
	"write to the main worktree is denied"
	"write outside a managed repo is allowed"
	"write under the state directory is allowed"
	"write under a new state subdirectory is allowed"
	"write elsewhere under build/ is allowed"
	"write to a sibling of the state directory is allowed"
	"normalisation: worktree path, case 1"
	"normalisation: worktree path, case 2"
	"normalisation: worktree path, case 3"
	"normalisation: state path, case 1"
	"normalisation: state path, case 2"
	"normalisation: state path, case 3"
	"a relative target path is denied"
	"a target path with a control character is denied"
	"without python3, a write in a worktree is denied"
	"without python3, a write to a managed repo from outside it is denied"
	"without python3, a write outside a managed repo is denied"
	"a python3 that writes to stderr: a write to the main worktree is denied"
	"a python3 that writes to stderr: a write inside a worktree is allowed"
	"write under a new build/ subdirectory is allowed"
	"write with a resolvable dot-dot segment inside build/ is allowed"
	"write through a link into build/ is allowed"
	"write to the build directory itself is denied"
	"write to a sibling with build as a prefix is denied"
	"normalisation: build path, case 1"
	"normalisation: build path, case 2"
	"normalisation: build path, case 3"
	"normalisation: build path, case 4"
	"write under a build/ that is not ignored is denied"
	"write to a tracked file under build/ is denied"
	"a git check-ignore failure under build/ is denied"
)
T_PATH=(
	"$S/.worktrees/wt/new.txt"
	"$S/.worktrees/wt/sub/../new.txt"
	"$S/new.txt"
	"$U/new.txt"
	"$S/build/.vergil-state/issue-implement/9001/1/details.md"
	"$S/build/.vergil-state/design-review/42/S1/security.md"
	"$S/build/new.txt"
	"$S/build/.vergil-state-other/new.txt"
	"$S/.worktrees/wt/../../new.txt"
	"$S/.worktrees/wt/up/new.txt"
	"$S/.worktrees/wt2/new.txt"
	"$S/build/.vergil-state/../../new.txt"
	"$S/build/.vergil-state/src/new.txt"
	"$L/build/.vergil-state/new.txt"
	".worktrees/wt/new.txt"
	"$S/$NL"
	"$S/.worktrees/wt/new.txt"
	"$S/new.txt"
	"$U/new.txt"
	"$S/new.txt"
	"$S/.worktrees/wt/new.txt"
	"$S/build/scratch/deep/new.txt"
	"$S/build/.vergil-state/../scratch/new.txt"
	"$S/src/tobuild/new.txt"
	"$S/build"
	"$S/buildx/new.txt"
	"$S/build/../new.txt"
	"$S/build/out/new.txt"
	"$S/build/scratch/../../src/new.txt"
	"$B/build/new.txt"
	"$N/build/new.txt"
	"$S/build/tracked.txt"
	"$S/build/new.txt"
)
T_CWD=(
	"$S" "$S" "$S" "$U" "$S" "$S" "$S" "$S"
	"$S" "$S" "$S" "$S" "$S" "$L" "$S" "$S"
	"$S" "$U" "$U"
	"/" "$S"
	"$S" "$S" "$S" "$S" "$S" "$S" "$S" "$S" "$B"
	"$N" "$S" "$S"
)
T_PATHVAR=(
	"" "" "" "" "" "" "" ""
	"" "" "" "" "" "" "" ""
	"$NOPY_PATH" "$NOPY_PATH" "$NOPY_PATH"
	"$NOISY_PATH" "$NOISY_PATH"
	"" "" "" "" "" "" "" "" ""
	"" "" "$GITSHIM_PATH"
)
T_EXPECT=(
	"allow"
	"allow"
	"deny"
	"allow"
	"allow"
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
	"deny"
	"deny"
	"deny"
	"deny"
	"allow"
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
	"deny"
)

# Text a row's deny reason must contain, where it matters. The last
# three rows each deny under build/ for one reason, not another: the
# two not reported ignored, and the check-ignore failure.
T_REASON=()
T_REASON[$((${#T_NAME[@]} - 3))]="does not report it ignored"
T_REASON[$((${#T_NAME[@]} - 2))]="does not report it ignored"
T_REASON[$((${#T_NAME[@]} - 1))]="could not check"

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

	want_reason="${T_REASON[$i]:-}"
	if [ -n "$want_reason" ] && [ "$verdict" = "deny" ]; then
		reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')
		case "$reason" in
			*"$want_reason"*) ;;
			*) verdict="deny for another reason" ;;
		esac
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
