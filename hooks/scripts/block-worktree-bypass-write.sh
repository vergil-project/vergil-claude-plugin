#!/usr/bin/env bash
# block-worktree-bypass-write.sh — PreToolUse hook for Write|Edit.
#
# Blocks file modifications to the main worktree when the parallel-AI-agent
# worktree convention is active. Forces agents to write to their assigned
# .worktrees/<name>/ subdirectory instead. The one exception is ignored
# agent state under the main clone's build/.vergil-state/ (the paad
# review doctrine's private state directories).
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml (see hooks/scripts/lib/managed-repo-check.sh), with
# exceptions that apply everywhere: a relative target path is denied;
# without python3 every Write and Edit is denied; and a write whose path
# python3 cannot normalise is denied.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/hook-input.sh"

hook_input_read gated
file_path=$(printf '%s' "$HOOK_INPUT" \
  | jq -r '.tool_input | objects | .file_path | strings')

# Write and Edit always carry a file_path. Without one the target cannot
# be checked, so the call fails closed (#776) — unless the payload's cwd
# (the only scope signal left) is outside a managed repo.
if [ -z "$file_path" ]; then
  hook_input_scope_dir
  if ! is_managed_repo "$HOOK_SCOPE_DIR"; then
    exit 0
  fi
  hook_input_fail_closed "the hook input has no tool_input.file_path string"
fi

# The target must be an absolute path; a relative one is denied. It is
# then normalised before any match: every `.`, `..` and symlink in it is
# resolved, for a new file as well as an existing one (os.path.realpath
# resolves the existing part of a path and normalises the rest).
deny_target() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}
case "$file_path" in
  /*) ;;
  *)
    deny_target "The worktree write guard denies the relative target path $file_path. Use an absolute path."
    ;;
esac
if ! command -v python3 >/dev/null 2>&1; then
  deny_target "The worktree write guard could not check the target path $file_path: python3 is not installed or not on PATH. The guard needs python3 to normalise every target path, so it denies every Write and Edit, in any repo, until python3 is available."
fi
# python3 runs isolated (-I: no PYTHON* environment, no user site), and
# its stderr is kept apart from the path it prints. The result must be a
# single absolute path.
py_err=$(mktemp) || deny_target "The worktree write guard could not create a temporary file to check the target path $file_path. The write cannot be checked, so it is denied."
trap 'rm -f "$py_err"' EXIT
if ! resolved=$(python3 -I -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$file_path" 2>"$py_err"); then
  deny_target "The worktree write guard could not normalise the target path $file_path: python3 failed ($(head -c 300 "$py_err")). The write cannot be checked, so it is denied."
fi
case "$resolved" in
  /*) ;;
  *) deny_target "The worktree write guard could not normalise the target path $file_path: python3 returned no absolute path. The write cannot be checked, so it is denied." ;;
esac
if [ "$(printf '%s\n' "$resolved" | wc -l)" -ne 1 ]; then
  deny_target "The worktree write guard could not normalise the target path $file_path: python3 returned more than one line. The write cannot be checked, so it is denied."
fi

# Find the nearest existing ancestor directory for the target file.
# Needed when the agent creates a file in a directory that doesn't exist yet.
check_dir=$(dirname "$resolved")
while [ -n "$check_dir" ] && [ "$check_dir" != "/" ] && [ ! -d "$check_dir" ]; do
  check_dir=$(dirname "$check_dir")
done

if [ -z "$check_dir" ] || [ "$check_dir" = "/" ]; then
  exit 0
fi

# Early exit for non-managed repos. The check is pure shell, with no
# further subprocess after the normalisation above.
if ! is_managed_repo "$check_dir"; then
  exit 0
fi

# From here we know the file is inside a managed repo. Resolve the git
# repo root and check the worktree convention.
toplevel=$(git -C "$check_dir" rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$toplevel" ]; then
  exit 0
fi

# Find the main repo root. In a worktree, --show-toplevel returns the
# worktree's own root. --git-common-dir points at the shared .git dir;
# its parent is the main repo root.
git_common=$(git -C "$check_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "")
if [ -n "$git_common" ]; then
  main_root=$(dirname "$git_common")
else
  main_root="$toplevel"
fi

# Has this repo adopted the worktree convention? Signal: a line reading
# exactly `.worktrees/` in the repo-root .gitignore.
if ! [ -f "$main_root/.gitignore" ] || ! grep -qxF '.worktrees/' "$main_root/.gitignore" 2>/dev/null; then
  exit 0
fi

# The worktree convention is active. The file must be inside a worktree,
# or be ignored agent state under the main clone's build/.vergil-state/
# (the convention's one exception to the read-only main worktree).
case "$resolved" in
  "$main_root"/.worktrees/*)
    exit 0
    ;;
  "$main_root"/build/.vergil-state/*)
    exit 0
    ;;
  *)
    jq -n --arg path "$file_path" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("File writes must target a worktree under .worktrees/<name>/ per the worktree convention. You are attempting to write to \($path), which is in the main worktree. Use the absolute path to your assigned worktree instead.\n\nSee docs/specs/worktree-convention.md in vergil-tooling for the full convention.")
      }
    }'
    exit 0
    ;;
esac
