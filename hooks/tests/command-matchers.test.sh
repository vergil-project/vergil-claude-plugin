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
)
T_CWD=(
  "" "" "" "" "" "" "" "" "" "" "" ""
)
T_RESPONSE=(
  "" "" "" "" "" "" "" "" "" "" "" ""
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
