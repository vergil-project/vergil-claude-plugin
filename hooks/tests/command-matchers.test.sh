#!/usr/bin/env bash
# command-matchers.test.sh — table-driven allow/deny tests for the
# hook command matchers (#450).
#
# Encodes the canonical case table from
# docs/specs/2026-06-05-450-command-matcher-quoting-design.md §6.1
# (rows 11-12 excluded: the bash -c recheck lives in vrg-hook-guard,
# not the plugin scripts), plus per-script cases. bash
# 3.2-compatible: parallel indexed arrays.
#
# Usage: bash hooks/tests/command-matchers.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$SCRIPT_DIR/../scripts"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

NL='
'

# block-raw-git-commit.sh delegates to vrg-hook-guard when it is on
# PATH; mask it so the fallback regex path is what's tested.
CLEAN_PATH=""
old_ifs="$IFS"
IFS=':'
for dir in $PATH; do
  if [ -x "$dir/vrg-hook-guard" ]; then
    continue
  fi
  CLEAN_PATH="${CLEAN_PATH:+$CLEAN_PATH:}$dir"
done
IFS="$old_ifs"

# Scratch managed repo that has adopted the worktree convention, for
# block-protected-branch-work.sh rows. Using a scratch repo keeps
# those rows deterministic whether this suite runs from the main
# checkout or from inside a worktree.
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
git -C "$SCRATCH" init --quiet
printf '[project]\n' > "$SCRATCH/vergil.toml"
printf '.worktrees/\n' > "$SCRATCH/.gitignore"

# Parallel arrays: one case per index.
#   T_NAME     — label
#   T_SCRIPT   — hook script under hooks/scripts/
#   T_COMMAND  — tool_input.command payload value
#   T_CWD      — payload cwd: "" = $ROOT, "SCRATCH" = $SCRATCH
#   T_RESPONSE — tool_response payload value ("" = omit)
#   T_EXPECT   — deny | allow | context
T_NAME=(
  "rgc row 1: plain invocation"
  "rgc row 2: separator"
  "rgc row 3: subshell separator"
  "rgc row 4: brace-group separator"
  "rgc row 5: multi-line quoted body (#450 repro)"
  "rgc row 6: dot-git path"
  "rgc row 7: double-quoted span"
  "rgc row 8: single quotes nesting double quotes"
  "rgc row 9: escaped double quotes"
  "rgc row 10: unbalanced quote, separator in span (accepted FP)"
  "rgc row 13: keyword position (accepted FN gap)"
  "rgc row 14: unbalanced quote, no separator"
  "pr-create: plain invocation"
  "pr-create: quoted body prose (#450 shape)"
  "pr-create: gh api POST to /pulls"
  "agent-merge: gh pr merge"
  "agent-merge: gh pr review --approve"
  "agent-merge: quoted body prose (#450 shape)"
  "agent-merge: gh api PUT merge"
  "host-split: wrapped host tool denied"
  "host-split: quoted body mentioning wrapped host tool (#450 shape)"
  "host-split: bare container tool warns"
  "host-split: quoted body mentioning container tool (#450 shape)"
  "deprecation: pytest with warning in output"
  "deprecation: quoted body mentioning pytest (#450 shape)"
  "deprecation: pytest with clean output"
  "protected: real commit at convention-repo root"
  "protected: non-commit with quoted commit prose (#450 over-blocking)"
  "protected: non-commit git operation"
  "autoclose: forbidden linkage keyword"
  "autoclose: Ref linkage allowed"
  "autoclose: quoted body mentioning the rule (#450 shape)"
  "contents-api: write method denied"
  "contents-api: GET allowed"
  "contents-api: quoted body citing the blocked call (#450 shape)"
)
T_SCRIPT=(
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-git-commit.sh"
  "block-raw-gh-pr-create.sh"
  "block-raw-gh-pr-create.sh"
  "block-raw-gh-pr-create.sh"
  "block-agent-merge.sh"
  "block-agent-merge.sh"
  "block-agent-merge.sh"
  "block-agent-merge.sh"
  "enforce-host-container-split.sh"
  "enforce-host-container-split.sh"
  "enforce-host-container-split.sh"
  "enforce-host-container-split.sh"
  "detect-deprecation-warnings.sh"
  "detect-deprecation-warnings.sh"
  "detect-deprecation-warnings.sh"
  "block-protected-branch-work.sh"
  "block-protected-branch-work.sh"
  "block-protected-branch-work.sh"
  "block-autoclose-linkage.sh"
  "block-autoclose-linkage.sh"
  "block-autoclose-linkage.sh"
  "block-github-contents-api.sh"
  "block-github-contents-api.sh"
  "block-github-contents-api.sh"
)
T_COMMAND=(
  'git commit -m x'
  'cd foo && git commit'
  'x=$(git commit -m x)'
  '{ git commit -m x; }'
  "vrg-commit --type docs --scope x --message y --body \"line one${NL}git commit mentioned here\""
  'find . -path ./.git -prune'
  'echo "git commit"'
  "echo 'say \"git commit\"'"
  'echo "he said \"git commit\""'
  'echo "; git commit'
  'if git commit; then :; fi'
  'echo "git commit'
  'gh pr create --title x'
  "vrg-commit --type docs --scope x --message y --body \"docs say${NL}gh pr create is blocked\""
  'gh api repos/o/r/pulls -X POST'
  'gh pr merge 5'
  'gh pr review 5 --approve'
  "vrg-gh issue create --title t --body \"policy:${NL}gh pr merge 5 is forbidden\""
  'gh api repos/o/r/pulls/5/merge -X PUT'
  'vrg-container-run -- git status'
  "vrg-commit --type docs --scope x --message y --body \"never do this:${NL}vrg-container-run -- gh pr list\""
  'shellcheck hooks/scripts/lib/command-match.sh'
  "vrg-commit --type docs --scope x --message y --body \"container tools:${NL}shellcheck runs in the container\""
  'pytest -q'
  "vrg-commit --type docs --scope x --message y --body \"test notes:${NL}pytest emitted warnings\""
  'pytest -q'
  'git commit -m x'
  "vrg-gh issue create --title t --body \"repro:${NL}git commit -m x was blocked\""
  'git push origin HEAD'
  'vrg-submit-pr --issue 450 --linkage Fixes'
  'vrg-submit-pr --issue 450 --linkage Ref'
  "vrg-commit --type docs --scope x --message y --body \"policy reminder:${NL}vrg-submit-pr --linkage Fixes is forbidden\""
  'gh api --method PUT repos/o/r/contents/f.md'
  'gh api repos/o/r/contents/f.md'
  "vrg-commit --type docs --scope x --message y --body \"blocked example:${NL}gh api --method PUT repos/o/r/contents/f.md\""
)
T_CWD=(
  "" "" "" "" "" "" "" "" "" "" "" ""
  "" "" ""
  "" "" "" ""
  "" "" "" ""
  "" "" ""
  "SCRATCH" "SCRATCH" "SCRATCH"
  "" "" ""
  "" "" ""
)
T_RESPONSE=(
  "" "" "" "" "" "" "" "" "" "" "" ""
  "" "" ""
  "" "" "" ""
  "" "" "" ""
  "DeprecationWarning: old API"
  "DeprecationWarning: old API"
  "2 passed"
  "" "" ""
  "" "" ""
  "" "" ""
)
T_EXPECT=(
  "deny"
  "deny"
  "deny"
  "deny"
  "allow"
  "allow"
  "allow"
  "allow"
  "allow"
  "deny"
  "allow"
  "allow"
  "deny"
  "allow"
  "deny"
  "deny"
  "deny"
  "allow"
  "deny"
  "deny"
  "allow"
  "context"
  "allow"
  "context"
  "allow"
  "allow"
  "deny"
  "allow"
  "allow"
  "deny"
  "allow"
  "allow"
  "deny"
  "allow"
  "allow"
)

pass=0
fail=0
i=0
total=${#T_NAME[@]}

while [ "$i" -lt "$total" ]; do
  name="${T_NAME[$i]}"
  script="${T_SCRIPT[$i]}"
  cmd="${T_COMMAND[$i]}"
  case_cwd="${T_CWD[$i]}"
  resp="${T_RESPONSE[$i]}"
  expect="${T_EXPECT[$i]}"

  if [ "$case_cwd" = "SCRATCH" ]; then
    case_cwd="$SCRATCH"
  elif [ -z "$case_cwd" ]; then
    case_cwd="$ROOT"
  fi

  payload=$(jq -n --arg cmd "$cmd" --arg cwd "$case_cwd" --arg resp "$resp" \
    '{tool_input: {command: $cmd, cwd: $cwd}, cwd: $cwd}
     + (if $resp == "" then {} else {tool_response: $resp} end)')

  out=$(printf '%s' "$payload" \
    | PATH="$CLEAN_PATH" bash "$SCRIPTS/$script" 2>&1) || true

  verdict="allow"
  if printf '%s' "$out" | grep -q '"permissionDecision": "deny"'; then
    verdict="deny"
  elif printf '%s' "$out" | grep -q '"additionalContext"'; then
    verdict="context"
  elif [ -n "$out" ]; then
    # Any other output (errors, partial JSON) is a test failure.
    verdict="error"
  fi

  if [ "$verdict" = "$expect" ]; then
    echo "PASS [$i] $name"
    pass=$((pass + 1))
  else
    echo "FAIL [$i] $name — expected $expect, got $verdict"
    if [ -n "$out" ]; then
      printf '%s\n' "$out" | head -5 | sed 's/^/       /'
    fi
    fail=$((fail + 1))
  fi
  i=$((i + 1))
done

echo "----------------------------------------"
echo "command-matchers: $pass passed, $fail failed, $total total"
[ "$fail" -eq 0 ]
