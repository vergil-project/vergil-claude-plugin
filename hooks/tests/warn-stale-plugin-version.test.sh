#!/usr/bin/env bash
# warn-stale-plugin-version.test.sh — tests for the hook that warns when
# a session serves an older vergil plugin than the one installed (#1129).
#
# Each case builds a scratch Claude config directory (CLAUDE_CONFIG_DIR)
# with a plugin cache and an installed_plugins.json, runs the hook with a
# chosen CLAUDE_PLUGIN_ROOT and asserts its verdict: silent (exit 0, no
# output), stale (the version-mismatch warning), unchecked (the
# check-could-not-run warning) or nojq (exit 1, stderr only). No case may
# ever deny or block the call. bash 3.2-compatible: no associative arrays.
#
# Usage: bash hooks/tests/warn-stale-plugin-version.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/warn-stale-plugin-version.sh"

TMP=$(mktemp -d)
trap 'chmod -R u+rwx "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
TMP=$(cd "$TMP" && pwd -P)

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/mask-hook-guard.sh"
mask_tool_path "$TMP/mask" jq
NOJQ_PATH="$MASKED_PATH"

PROJECT="$TMP/project"
OTHER="$TMP/other-project"
mkdir -p "$PROJECT" "$OTHER" "$TMP/source-mount"

# new_config <name> — a config dir with versions 1.0.0 to 1.0.2 cached.
# Prints its path.
new_config() {
	local dir="$TMP/$1" v
	for v in 1.0.0 1.0.1 1.0.2; do
		mkdir -p "$dir/plugins/cache/mkt/vergil/$v"
	done
	printf '%s\n' "$dir"
}

# entry <scope> <version> [<projectPath>] — one install record.
entry() {
	if [ -n "${3:-}" ]; then
		jq -n --arg s "$1" --arg v "$2" --arg p "$3" --arg c "$CFG" \
			'{scope: $s, projectPath: $p, version: $v, installPath: "\($c)/plugins/cache/mkt/vergil/\($v)"}'
	else
		jq -n --arg s "$1" --arg v "$2" --arg c "$CFG" \
			'{scope: $s, version: $v, installPath: "\($c)/plugins/cache/mkt/vergil/\($v)"}'
	fi
}

# installed <entry-json>... — write installed_plugins.json for vergil@mkt.
installed() {
	local entries="[]" e
	for e in "$@"; do
		entries=$(jq -c --argjson e "$e" '. + [$e]' <<<"$entries")
	done
	jq -n --argjson e "$entries" '{version: 2, plugins: {"vergil@mkt": $e}}' \
		>"$CFG/plugins/installed_plugins.json"
}

pass=0
fail=0
total=0

# check <name> <expect> <root> [<skill>] [<payload>] [<project-dir>] [<PATH>]
# Runs the hook with CLAUDE_CONFIG_DIR=$CFG. <root> "unset" leaves
# CLAUDE_PLUGIN_ROOT unset; <project-dir> "unset" leaves
# CLAUDE_PROJECT_DIR unset. <payload> "" builds a Skill payload for
# <skill> with cwd $PROJECT. <expect_text>, when set, must appear in the
# output too.
expect_text=""
check() {
	local name="$1" expect="$2" root="$3" skill="${4:-vergil:issue-implement}"
	local payload="${5-}" project="${6:-$PROJECT}" path="${7:-$PATH}"
	local out err rc verdict
	total=$((total + 1))
	if [ -z "$payload" ]; then
		payload=$(jq -nc --arg s "$skill" --arg cwd "$PROJECT" \
			'{tool_name: "Skill", tool_input: {skill: $s}, cwd: $cwd}')
	elif [ "$payload" = "EMPTY" ]; then
		payload=""
	fi
	local -a envs=(CLAUDE_CONFIG_DIR="$CFG" PATH="$path")
	[ "$root" = "unset" ] || envs+=(CLAUDE_PLUGIN_ROOT="$root")
	[ "$project" = "unset" ] || envs+=(CLAUDE_PROJECT_DIR="$project")
	out=$(printf '%s' "$payload" |
		env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR "${envs[@]}" \
			bash "$HOOK" 2>"$TMP/stderr")
	rc=$?
	err=$(cat "$TMP/stderr")

	if printf '%s' "$out" | grep -q 'permissionDecision'; then
		verdict="denied"
	elif [ "$rc" -eq 1 ] && [ -z "$out" ] && [ -n "$err" ]; then
		verdict="nojq"
	elif [ "$rc" -ne 0 ]; then
		verdict="error"
	elif [ -z "$out" ]; then
		verdict="silent"
	elif ! printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null 2>&1; then
		verdict="error"
	elif printf '%s' "$out" | grep -q 'WARNING: stale vergil plugin'; then
		verdict="stale"
	elif printf '%s' "$out" | grep -q 'version check could not run'; then
		verdict="unchecked"
	else
		verdict="error"
	fi

	if [ "$verdict" = "$expect" ] && { [ -z "$expect_text" ] || printf '%s%s' "$out" "$err" | grep -qF -- "$expect_text"; }; then
		echo "PASS [$total] $name"
		pass=$((pass + 1))
	else
		echo "FAIL [$total] $name — expected $expect${expect_text:+ with '$expect_text'}, got $verdict (rc=$rc)"
		printf '%s\n%s\n' "$out" "$err" | head -8 | sed 's/^/       /'
		fail=$((fail + 1))
	fi
	expect_text=""
}

CFG=$(new_config base)
C="$CFG/plugins/cache/mkt/vergil"

installed "$(entry user 1.0.1)"
check "the loaded version is the installed one" silent "$C/1.0.1"
expect_text="loaded vergil@mkt 1.0.0"
check "an older loaded version warns" stale "$C/1.0.0"
expect_text="but 1.0.1 is installed"
check "the warning names the installed version" stale "$C/1.0.0"
expect_text="/reload-plugins"
check "the warning asks for /reload-plugins" stale "$C/1.0.0"
check "a trailing slash on the root still matches" silent "$C/1.0.1/"
check "a non-vergil skill is never checked" silent "$C/1.0.0" "paad:vibe"
check "a skill named like vergil without the colon is not checked" silent "$C/1.0.0" "vergilant"
check "a slash-prefixed vergil skill is checked" stale "$C/1.0.0" "/vergil:issue-implement"
check "a root outside the cache (source mount) is silent" silent "$TMP/source-mount"
check "a root too deep in the cache is silent" silent "$C/1.0.0/skills"

# The project-scope entry for this project wins over the user entry.
installed "$(entry user 1.0.0)" "$(entry project 1.0.2 "$PROJECT")"
check "a project entry newer than the loaded user version warns" stale "$C/1.0.0"
check "the loaded version matches the project entry" silent "$C/1.0.2"
check "another project's entry does not apply" silent "$C/1.0.0" "" "" "$OTHER"
check "with no CLAUDE_PROJECT_DIR the payload cwd picks the project" silent "$C/1.0.2" "" "" unset

# A local-scope entry wins over a project-scope one.
installed "$(entry user 1.0.0)" "$(entry project 1.0.1 "$PROJECT")" "$(entry local 1.0.2 "$PROJECT")"
check "the local entry wins over the project entry" silent "$C/1.0.2"
check "the project entry is shadowed by the local one" stale "$C/1.0.1"

# The install path reached through a symlink matches its target.
ln -s "$C/1.0.1" "$TMP/link-1.0.1"
installed "$(jq -n --arg p "$TMP/link-1.0.1" '{scope: "user", version: "1.0.1", installPath: $p}')"
check "an install path through a symlink matches" silent "$C/1.0.1"

# Problems that stop the check are reported, never a match.
installed "$(entry project 1.0.1 "$OTHER")"
expect_text="records no install"
check "no install record for this session is reported" unchecked "$C/1.0.1"
jq -n '{version: 2, plugins: {}}' >"$CFG/plugins/installed_plugins.json"
check "no record of the plugin at all is reported" unchecked "$C/1.0.1"
installed "$(jq -n '{scope: "user", version: "1.0.1"}')"
expect_text="no installPath"
check "an entry with no installPath is reported" unchecked "$C/1.0.1"
jq -n '{version: 2, plugins: {"vergil@mkt": "oops"}}' >"$CFG/plugins/installed_plugins.json"
check "a malformed install list is reported" unchecked "$C/1.0.1"
printf 'not json' >"$CFG/plugins/installed_plugins.json"
expect_text="could not be read as JSON"
check "an invalid installed_plugins.json is reported" unchecked "$C/1.0.1"
installed "$(entry user 1.0.1)"
if [ "$(id -u)" -ne 0 ]; then
	chmod 000 "$CFG/plugins/installed_plugins.json"
	check "an unreadable installed_plugins.json is reported" unchecked "$C/1.0.1"
	chmod 644 "$CFG/plugins/installed_plugins.json"
fi
rm "$CFG/plugins/installed_plugins.json"
expect_text="does not exist"
check "a missing installed_plugins.json is reported" unchecked "$C/1.0.1"
check "a missing file is not checked for a non-vergil skill" silent "$C/1.0.1" "paad:vibe"

installed "$(entry user 1.0.1)"
expect_text="CLAUDE_PLUGIN_ROOT is not set"
check "an unset CLAUDE_PLUGIN_ROOT is reported" unchecked unset
check "invalid hook input is reported, not blocked" unchecked "$C/1.0.0" "" "not json"
check "empty hook input is reported, not blocked" unchecked "$C/1.0.0" "" "EMPTY"
check "a JSON array as hook input is reported" unchecked "$C/1.0.0" "" '[1]'
check "without jq the hook exits non-blocking" nojq "$C/1.0.0" "" "" "" "$NOJQ_PATH"

echo "----------------------------------------"
echo "warn-stale-plugin-version: $pass passed, $fail failed, $total total"
[ "$fail" -eq 0 ]
