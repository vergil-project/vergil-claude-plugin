#!/usr/bin/env bash
# block-worktree-bypass-write.sh — PreToolUse hook for Write|Edit.
#
# Blocks file modifications to the main worktree when the parallel-AI-agent
# worktree convention is active. Forces agents to write to their assigned
# .worktrees/<name>/ subdirectory instead.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# standard-tooling.toml. See hooks/scripts/lib/managed-repo-check.sh.
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')

if [ -z "$file_path" ] || [ "$file_path" = "null" ]; then
  exit 0
fi

# Best-effort symlink resolution. If the file exists, resolve to its real
# path so symlinks into the main worktree are caught. If it doesn't exist
# yet (new file creation), use the path as-is.
if [ -e "$file_path" ]; then
  resolved=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$file_path" 2>/dev/null || echo "$file_path")
else
  resolved="$file_path"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"

# Early exit for non-managed repos. Pure shell, no subprocess — fast for
# writes to /tmp, non-repo paths, and unmanaged repos.
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

# The worktree convention is active. The file must be inside a worktree.
case "$resolved" in
  "$main_root"/.worktrees/*)
    exit 0
    ;;
  *)
    jq -n --arg path "$file_path" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("File writes must target a worktree under .worktrees/<name>/ per the worktree convention. You are attempting to write to \($path), which is in the main worktree. Use the absolute path to your assigned worktree instead.\n\nSee docs/specs/worktree-convention.md in standard-tooling for the full convention.")
      }
    }'
    exit 0
    ;;
esac
