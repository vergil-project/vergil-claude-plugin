#!/usr/bin/env bash
# warn-stale-plugin-version.sh — PreToolUse hook for Skill (#1129).
#
# A running Claude Code session keeps serving the plugin version it
# loaded at start, even after a newer one is installed. Before each
# Skill call for a `vergil:` skill, this hook compares the plugin folder
# the session loaded (CLAUDE_PLUGIN_ROOT, which for a hook is the loaded
# version's cache directory) with the install path that
# installed_plugins.json records for the plugin. On a mismatch it adds a
# warning to the agent's context naming both versions and telling it to
# ask the human for `/reload-plugins` or a session restart.
#
# Advisory only: it never denies or blocks the call, so a session that
# cannot reload (a remote one, say) is not trapped. Every problem that
# stops the check (unparseable input, no CLAUDE_PLUGIN_ROOT, a missing
# or unreadable installed_plugins.json, no install record) is reported
# in the added context, never treated as a match. A plugin root outside
# the plugin cache (a `claude --plugin-dir` source mount) has no install
# record to compare with, so the hook stays silent there.
#
# Not gated on managed-repo detection: a stale skill misleads anywhere.
set -uo pipefail

# context <message> — print the advisory response and exit 0.
context() {
	jq -n --arg msg "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: $msg
    }
  }'
	exit 0
}

# Without jq the hook can build no response, so the problem goes to
# stderr with a non-blocking exit code (the call goes ahead).
if ! command -v jq >/dev/null 2>&1; then
	echo "warn-stale-plugin-version.sh: jq is not installed, so the vergil plugin version check could not run." >&2
	exit 1
fi

CHECK_FAILED="WARNING: the vergil plugin version check could not run"
CHECK_FAILED_TAIL="so this session may be serving an older vergil skill than the one installed. Tell the human, and ask them to run /reload-plugins (or restart the session) if a vergil plugin release was installed while this session was running."

input=$(cat) || context "$CHECK_FAILED: the hook input could not be read from stdin, $CHECK_FAILED_TAIL"
if [ -z "${input//[[:space:]]/}" ]; then
	context "$CHECK_FAILED: the hook input on stdin is empty, $CHECK_FAILED_TAIL"
fi
if ! skill=$(printf '%s' "$input" | jq -rs \
	'if length == 1 and (.[0] | type) == "object" then .[0].tool_input.skill | strings
	 else error("not one JSON object") end' 2>/dev/null); then
	context "$CHECK_FAILED: the hook input is not a single JSON object, $CHECK_FAILED_TAIL"
fi
skill="${skill#/}"

case "$skill" in
vergil:*) ;;
*) exit 0 ;;
esac

if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
	context "$CHECK_FAILED: CLAUDE_PLUGIN_ROOT is not set, so the loaded plugin folder is unknown, $CHECK_FAILED_TAIL"
fi

# physical_dir <dir> — the directory with every symlink resolved, or the
# path unchanged when it does not exist.
physical_dir() {
	(cd -P -- "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"
}

plugins_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"
cache_dir=$(physical_dir "$plugins_dir/cache")
loaded=$(physical_dir "$CLAUDE_PLUGIN_ROOT")
loaded="${loaded%/}"

# The cache layout is <cache>/<marketplace>/<plugin>/<version>. Any
# other root is a source mount, which has no install record.
rel="${loaded#"$cache_dir"/}"
if [ "$rel" = "$loaded" ]; then
	exit 0
fi
case "$rel" in
*/*/*/*) exit 0 ;;
*/*/*) ;;
*) exit 0 ;;
esac
marketplace="${rel%%/*}"
rest="${rel#*/}"
plugin="${rest%%/*}"
loaded_version="${rest#*/}"
key="$plugin@$marketplace"

installed_file="$plugins_dir/installed_plugins.json"
if [ ! -e "$installed_file" ]; then
	context "$CHECK_FAILED: $installed_file does not exist, so the installed version of $key is unknown (this session loaded $loaded_version), $CHECK_FAILED_TAIL"
fi
if ! [ -r "$installed_file" ] || ! installed_json=$(jq -c . "$installed_file" 2>/dev/null); then
	context "$CHECK_FAILED: $installed_file could not be read as JSON, so the installed version of $key is unknown (this session loaded $loaded_version), $CHECK_FAILED_TAIL"
fi

project="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project" ]; then
	project=$(printf '%s' "$input" | jq -r '.cwd | strings')
fi

# The install that applies to this session: a local-scope, then a
# project-scope entry for this project, else the user-scope entry.
if ! entry=$(printf '%s' "$installed_json" | jq -c --arg key "$key" --arg project "$project" '
    (.plugins[$key] // []) as $entries
    | if ($entries | type) != "array" then error("entries for \($key) are not a list") else . end
    | ([$entries[] | select(.scope == "local" and .projectPath == $project)]
       + [$entries[] | select(.scope == "project" and .projectPath == $project)]
       + [$entries[] | select(.scope == "user")])
    | first // empty' 2>/dev/null); then
	context "$CHECK_FAILED: $installed_file has no readable install list for $key, $CHECK_FAILED_TAIL"
fi
if [ -z "$entry" ]; then
	context "$CHECK_FAILED: $installed_file records no install of $key for this session (project ${project:-unknown}; this session loaded $loaded_version), $CHECK_FAILED_TAIL"
fi

install_path=$(printf '%s' "$entry" | jq -r '.installPath | strings')
if [ -z "$install_path" ]; then
	context "$CHECK_FAILED: the $key entry in $installed_file has no installPath, $CHECK_FAILED_TAIL"
fi
installed=$(physical_dir "$install_path")
installed="${installed%/}"
if [ "$installed" = "$loaded" ]; then
	exit 0
fi

installed_version=$(printf '%s' "$entry" | jq -r '.version | strings')
if [ -z "$installed_version" ]; then
	installed_version="${installed##*/}"
fi

context "WARNING: stale vergil plugin. This session loaded $key $loaded_version (from $loaded), but $installed_version is installed (at $installed). The skill \`$skill\` you are about to use is the $loaded_version text and may not match the installed release. Stop before relying on it: ask the human to run /reload-plugins in this session (or to restart it), then invoke the skill again. If the human says the session cannot reload, follow their direction."
