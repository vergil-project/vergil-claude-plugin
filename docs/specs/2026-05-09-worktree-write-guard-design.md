# Worktree Write Guard and Contents API Block

**Issue:** [#286](https://github.com/vergil-project/vergil-claude-plugin/issues/286)
**Date:** 2026-05-09

## Problem

Agents routinely bypass the worktree convention in two ways:

1. **Write/Edit to the main worktree.** Agents use the Write and Edit
   tools to create and modify files directly in the `develop` checkout
   instead of their assigned `.worktrees/<name>/` directory. This
   pollutes `git status`, causes rebase conflicts, and breaks
   `vrg-finalize-repo`. Documentation and CLAUDE.md instructions have
   proven insufficient — agents need mechanical enforcement.

2. **GitHub Contents API writes.** Agents use
   `gh api repos/.../contents/...` with PUT/POST/DELETE to push files
   directly to remote branches, bypassing all local controls (hooks,
   vrg-commit, PR process, code review, CI).

The existing hook system has no coverage for either vector. All
PreToolUse hooks match only `Bash`, and none inspect GitHub API
calls for Contents API writes.

## Approach

Two new PreToolUse hook scripts, following the existing
one-hook-one-concern pattern. Both gated on managed-repo detection
(`vergil.toml`). Hook 1 has two exceptions that apply in any repo: it
denies a relative target path, and it denies every Write and Edit when
`python3` is unavailable or a path cannot be normalised.

## Hook 1: `block-worktree-bypass-write.sh`

### Matcher

New entry in `hooks.json` under `PreToolUse`:

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/block-worktree-bypass-write.sh",
      "statusMessage": "Checking worktree write target..."
    }
  ]
}
```

This is the first non-Bash matcher in the hook system.

### Logic

1. Read JSON input from stdin, extract `tool_input.file_path`.
2. Deny a relative `file_path`. Normalise an absolute one before
   any match: resolve every `.`, `..` and symlink in it with
   `os.path.realpath`, for a new file as well as an existing one
   (the existing part of the path is resolved and the rest
   normalised). If python3 is unavailable, deny every Write and
   Edit, wherever it points, with a reason naming python3; if
   python3 fails on the path, deny with its error. Every later
   step uses this normalised path.
3. Run `is_managed_repo` check on the normalised path's nearest
   existing ancestor directory (walking up from its `dirname` if
   the directory doesn't exist yet). This is pure shell with no subprocess spawns — fast early
   exit for writes to `/tmp`, non-repo paths, and unmanaged repos.
   If not managed: exit 0.
4. Derive the git repo root from that same ancestor: run
   `git -C <ancestor> rev-parse --show-toplevel`.
5. If the normalised path is outside any git repo: exit 0 (allow).
6. Check if the repo has adopted the worktree convention:
   `.worktrees/` line in the repo root's `.gitignore`.
   If not adopted: exit 0.
7. Determine the main repo root. If inside a worktree,
   `--show-toplevel` returns the worktree root, not the main root.
   Use `git rev-parse --path-format=absolute --git-common-dir` and
   take its parent to find the main root (same technique as
   `block-protected-branch-work.sh`).
8. Check whether the normalised path falls inside
   `<main_root>/.worktrees/*` or `<main_root>/build/.vergil-state/*`.
9. If so: exit 0 (allow). `build/.vergil-state/` is ignored agent
   state, the worktree convention's one exception to the read-only
   main worktree (paad review doctrine §1.5).
10. If not: deny.

### Hook 1 denial message

```text
File writes must target a worktree under .worktrees/<name>/ per the
worktree convention. You are attempting to write to <file_path>,
which is in the main worktree. Use the absolute path to your
assigned worktree instead.

See docs/specs/worktree-convention.md in vergil-tooling for the
full convention.
```

Consistent with the language in `block-protected-branch-work.sh`.

### Edge cases

- **File outside any git repo** (e.g., `/tmp/scratch.txt`): allow.
  The hook only governs repo-internal writes.
- **File in a different managed repo**: the hook fires and checks
  that repo's worktree convention independently. Correct behavior.
- **New file in a path that doesn't exist yet**: walk up `dirname`
  until an existing ancestor is found, then `git rev-parse` from
  there.
- **Symlinks, `.` and `..`**: resolved before checking, for new
  and existing files alike.
- **A relative path**: denied, wherever it points.
- **A path that cannot be normalised** (for example, no `python3`):
  every Write and Edit is denied, wherever it points (fail closed).

## Hook 2: `block-github-contents-api.sh`

### Hook 2 matcher

Added to the existing `Bash` PreToolUse hook list in `hooks.json`:

```json
{
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/block-github-contents-api.sh",
  "statusMessage": "Checking for GitHub Contents API write..."
}
```

### Hook 2 logic

1. Read JSON input from stdin, extract `tool_input.command`.
2. Extract CWD, run `is_managed_repo` check. If not managed: exit 0.
3. Pattern-match the command for `gh api` calls that target the
   Contents API with a write method. Patterns to catch:
   - `gh api --method PUT repos/.../contents/...`
   - `gh api --method POST repos/.../contents/...`
   - `gh api --method DELETE repos/.../contents/...`
   - `gh api -X PUT repos/.../contents/...` (shorthand)
   - `gh api -XPUT repos/.../contents/...` (no space between flag
     and value — also valid for POST, DELETE)
   - Full URL form: `gh api --method PUT https://api.github.com/repos/.../contents/...`
   - Method flag before or after the URL argument (agents use both
     orderings).
   - Commands without an explicit method flag default to GET and
     are allowed — the hook only matches when a write method is
     explicitly present.
4. If no match: exit 0 (allow).
5. If match: deny.

### What it does NOT block

- `gh api repos/.../contents/...` with GET (reading is fine).
- `gh api` calls to other endpoints (issues, PRs, comments).
- Raw `curl` to the GitHub API — defense-in-depth, not hermetic.
  Server-side branch protection is the real gate for `curl`.

### Hook 2 denial message

```text
Direct writes to the GitHub Contents API are blocked. File changes
must go through the local workflow: edit files in your worktree,
commit with vrg-commit, and submit with vrg-submit-pr.

See docs/specs/worktree-convention.md in vergil-tooling for the
full convention.
```

## hooks.json changes

Two additions to the `PreToolUse` array:

1. New `Write|Edit` matcher entry (after the existing `Bash` entry).
2. New hook in the existing `Bash` matcher's hooks array.

No changes to `PostToolUse`.

## Shared infrastructure

Both scripts source `lib/managed-repo-check.sh` for the
`is_managed_repo` function, consistent with all existing hooks.

## What this does NOT cover

- **Bash-based file writes** (`echo > file`, `cp`, `tee`): not
  intercepted. Agents overwhelmingly use Write/Edit tools for file
  creation. The existing `block-protected-branch-work.sh` catches
  commits from the main worktree, providing a second line of defense.
- **Raw `curl` to the GitHub API**: server-side branch protection
  is the gate. This hook is defense-in-depth for the `gh api` path.
