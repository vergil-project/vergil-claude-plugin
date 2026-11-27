#!/usr/bin/env bash
# block-protected-branch-work.sh — PreToolUse hook for Bash.
#
# Blocks raw `git commit` invocations that shouldn't happen at the
# project root:
#
# 1. If the repo has adopted the parallel-AI-agent worktree convention
#    (signal: `.worktrees/` line in .gitignore), enforce that commits
#    originate from a `.worktrees/<name>/` subdirectory. The main tree
#    is read-only for source under that convention (ignored scratch in
#    its build/ is not a source edit).
#
# 2. If the repo has NOT adopted the convention, fall back to the
#    long-standing behavior: block commits on `main` or `develop`.
#
# A raw `git commit` whose repository the hook cannot work out from the
# command text is denied too: one that sets the git directory or work
# tree, changes directory other than with one `cd` at the start of the
# command or with git's own -C (a command wrapper's directory option
# included), or names a directory the hook cannot resolve to an
# existing path.
#
# Does NOT block branch operations (checkout, merge, push, pull, etc.).
# Does NOT match `vrg-commit`: it enforces the protected-branch rule
# itself at run time, against the real target branch (#694).
#
# See vergil-project/vergil-tooling/docs/specs/worktree-convention.md
# for the adopted-convention rules.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml. See hooks/scripts/lib/managed-repo-check.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/hook-input.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"

hook_input_read gated
hook_input_scope_dir
cwd="$HOOK_SCOPE_DIR"
if ! is_managed_repo "$cwd"; then
  exit 0
fi

hook_input_command
command="$HOOK_COMMAND"
normalized=$(normalize_command_words "$command")

# Only check commands that could create commits on the current branch.
# Allow git operations that don't create commits (checkout, push, pull, etc.).
#
# `vrg-commit` is deliberately NOT matched (#694). It runs its own
# protected-branch check at run time against the branch of the directory
# it actually executes in (vergil-tooling bin/vrg_commit.py,
# _validate_commit_context), so that check is authoritative. This hook
# can only guess the target repo from the session cwd plus a parse of the
# command text; under the sandbox that cwd is reset to the project root,
# so any command shape the parse misses (e.g. `VAR=x vrg-commit`,
# `(cd <wt>; vrg-commit)`) evaluated the session-root repo and produced
# a false deny that pushed agents to disable the sandbox.
if ! printf '%s\n' "$normalized" | grep -qE "$GIT_COMMIT_RE"; then
  exit 0
fi

# deny <reason>: print the deny decision and stop.
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

# unresolved <why>: deny a commit whose repository cannot be worked out.
unresolved() {
  deny "Cannot tell which repository and branch this git commit runs in: $1. Commit with vrg-commit from inside your worktree (.worktrees/<name>/), with any directory written as a literal path."
}

# resolve_dir <base> <word>: print the directory <word> names, relative
# to <base>, or fail when it is not a literal path to an existing
# directory (a variable, a substitution, a glob, or a quoted span that
# normalize_command_words reduced to "").
resolve_dir() {
  local base="$1" word="$2"
  case "$word" in
    \~) word="$HOME" ;;
    \~/*) word="$HOME/${word#\~/}" ;;
  esac
  case "$word" in
    '' | *[\$\`\"\'\\*?\[~]*) return 1 ;;
  esac
  case "$word" in
    /*) ;;
    *) word="$base/$word" ;;
  esac
  [ -d "$word" ] || return 1
  printf '%s\n' "$word"
}

# A commit that points git at another git directory or work tree runs
# somewhere the command text does not show.
if printf '%s\n' "$normalized" \
  | grep -qE '(^|[[:space:];&|({])(GIT_DIR|GIT_WORK_TREE|GIT_COMMON_DIR)=|(^|[[:space:]])--(git-dir|work-tree)([=[:space:]]|$)'; then
  unresolved "it sets the git directory or work tree"
fi

# $cwd is the bash session's working directory, resolved above by
# hook_input_scope_dir. Two fields can carry it:
#   .tool_input.cwd  — set when the Bash tool call passes cwd explicitly.
#   .cwd             — top-level hook input field; the session CWD that
#                      Claude Code itself reports.
# The current Bash tool typically populates the top-level `.cwd` only,
# so falling back to "." (the previous behavior) misclassified every
# commit as originating from the project root.

# The base directory: the session cwd, or the target of a single `cd`
# that starts the command. Any other directory change is denied.
base_dir="$cwd"
dir_changes=$(printf '%s\n' "$normalized" \
  | { grep -oE '(^|[;&|({][[:space:]]*)(builtin[[:space:]]+)?(cd|pushd|popd)([[:space:];&|)}]|$)' || true; } \
  | wc -l | tr -d '[:space:]')
if [ "$dir_changes" -gt 0 ]; then
  first_line=$(printf '%s\n' "$normalized" | head -1)
  if [ "$dir_changes" -ne 1 ] \
    || ! printf '%s\n' "$first_line" | grep -qE '^[[:space:]]*cd([[:space:]]|$)'; then
    unresolved "it changes directory other than with one cd at its start"
  fi
  cd_target=$(printf '%s\n' "$first_line" \
    | sed -E 's/^[[:space:]]*cd([[:space:]]+([^[:space:];&|)]*))?.*$/\2/')
  [ -n "$cd_target" ] || cd_target="$HOME"
  base_dir=$(resolve_dir "$cwd" "$cd_target") \
    || unresolved "its cd target is not a literal path to an existing directory"
fi

# check_dir <dir>: deny a commit that runs in <dir> when the rules say so.
check_dir() {
  local dir="$1" toplevel git_common main_root branch
  # Resolve the effective repository root. If the dir isn't a git repo
  # at all, don't block — something else will fail or this was a
  # non-repo commit.
  toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -z "$toplevel" ]; then
    return 0
  fi
  toplevel=$(cd "$toplevel" && pwd -P)

  # When the commit is being made from inside a git worktree (not the
  # main checkout), `--show-toplevel` returns the worktree's own root,
  # not the main repo root. The worktree-convention check below needs
  # the MAIN repo root so it can match against `<main-root>/.worktrees/*`.
  # `--git-common-dir` points at the shared `.git` regardless of which
  # worktree we're in; its parent is the main repo root.
  git_common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "")
  if [ -n "$git_common" ]; then
    main_root=$(cd "$(dirname "$git_common")" && pwd -P)
  else
    main_root="$toplevel"
  fi

  # Has this repo adopted the worktree convention? Signal: a line reading
  # exactly `.worktrees/` in the repo-root .gitignore.
  if [ -f "$main_root/.gitignore" ] && grep -qxF '.worktrees/' "$main_root/.gitignore" 2>/dev/null; then
    # Enforce: the commit's work tree must be one under
    # $main_root/.worktrees/. Judging the work tree's root, not the
    # directory text, keeps `..` and symlinks from counting.
    case "$toplevel/" in
      "$main_root"/.worktrees/?*/)
        return 0
        ;;
      *)
        deny "Commits must originate from inside .worktrees/<name>/ per the worktree convention. You appear to be committing from $dir. Create a worktree for your work:
  git worktree add .worktrees/issue-<N>-<slug> -b feature/<N>-<slug> origin/develop

See docs/specs/worktree-convention.md in vergil-tooling for the full convention."
        ;;
    esac
  fi

  # Repo has not adopted the convention — fall back to the original
  # protected-branch check.
  branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "")
  if [ "$branch" = "main" ] || [ "$branch" = "develop" ]; then
    deny "Commits on protected branch \"$branch\" are blocked. Create a feature branch first: git checkout -b feature/<name>"
  fi
  return 0
}

# Each `git commit` invocation runs in the base directory, moved by any
# `-C <dir>` global options it carries (each relative to the last).
git_head_re="^([^[:space:]]*/)?git($GIT_COMMIT_GLOBAL_OPT_RE)*[[:space:]]+commit([[:space:];&|)}]|\$)"
while IFS= read -r invocation; do
  set -f
  # shellcheck disable=SC2206 # split on whitespace, globbing off
  words=($invocation)
  set +f
  count=${#words[@]}
  start=-1
  i=0
  while [ "$i" -lt "$count" ]; do
    word="${words[$i]}"
    case "$word" in
      [\;\&\|\(\{]*) word="${word#?}" ;;
    esac
    case "$word" in
      git | */git)
        rest="$word"
        j=$((i + 1))
        while [ "$j" -lt "$count" ]; do
          rest="$rest ${words[$j]}"
          j=$((j + 1))
        done
        if printf '%s\n' "$rest" | grep -qE "$git_head_re"; then
          start=$i
          break
        fi
        ;;
    esac
    i=$((i + 1))
  done
  if [ "$start" -lt 0 ]; then
    unresolved "the hook could not parse the git invocation"
  fi

  # A command wrapper before git (env, sudo and the like) can change
  # directory or root with an option of its own: -C, -D or -R in a
  # short-option word, or --chdir or --chroot.
  i=0
  while [ "$i" -lt "$start" ]; do
    case "${words[$i]}" in
      --chdir | --chdir=* | --chroot | --chroot=*)
        unresolved "a command wrapper changes directory before git runs"
        ;;
      --*) ;;
      -*[CDR]*)
        unresolved "a command wrapper changes directory before git runs"
        ;;
    esac
    i=$((i + 1))
  done

  effective_dir="$base_dir"
  i=$((start + 1))
  while [ "$i" -lt "$count" ]; do
    case "${words[$i]}" in
      commit | commit[\;\&\|\)\}]*) break ;;
      -C)
        effective_dir=$(resolve_dir "$effective_dir" "${words[$((i + 1))]:-}") \
          || unresolved "its -C directory is not a literal path to an existing directory"
        i=$((i + 2))
        ;;
      -c | --namespace | --config-env | --super-prefix | --attr-source)
        i=$((i + 2))
        ;;
      *)
        i=$((i + 1))
        ;;
    esac
  done
  check_dir "$effective_dir"
done < <(printf '%s\n' "$normalized" | grep -oE "$GIT_COMMIT_RE")
exit 0
