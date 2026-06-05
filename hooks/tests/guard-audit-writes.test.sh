#!/usr/bin/env bash
# guard-audit-writes.test.sh — table-driven tests for the AUDIT
# write-guard hook (#442).
#
# Feeds JSON payloads (identity x path x tool field) to the hook and
# asserts the decision. bash 3.2-compatible: parallel indexed arrays,
# no associative arrays. Run from anywhere; paths resolve relative to
# the repo this script lives in.
#
# Usage: bash hooks/tests/guard-audit-writes.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/guard-audit-writes.sh"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parallel arrays: one test per index.
#   T_NAME     — label
#   T_IDENTITY — value for VRG_IDENTITY_MODE ("" = unset/empty)
#   T_FIELD    — payload path field: file_path | notebook_path | none
#   T_PATH     — the path value ("" with T_FIELD=none)
#   T_EXPECT   — deny | allow
T_NAME=(
  "non-audit identity is never constrained (empty)"
  "non-audit identity is never constrained (user)"
  "audit may write its feedback artifact"
  "audit may write its atomic temp file"
  "audit must not touch the USER pr-template"
  "audit may scribble in build/"
  "audit may create nested build/ paths"
  "audit must not write repo files"
  "audit must not write hook scripts"
  "lexical dot-dot escape is caught"
  "outside any managed repo the guard is gated off"
  "missing path field fails closed"
  "NotebookEdit path is checked too (deny)"
  "NotebookEdit path is checked too (allow)"
)
T_IDENTITY=(
  ""
  "user"
  "audit"
  "audit"
  "audit"
  "audit"
  "audit"
  "audit"
  "audit"
  "audit"
  "audit"
  "audit"
  "audit"
  "audit"
)
T_FIELD=(
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "none"
  "notebook_path"
  "notebook_path"
)
T_PATH=(
  "$ROOT/README.md"
  "$ROOT/README.md"
  "$ROOT/.vergil/audit-feedback.yml"
  "$ROOT/.vergil/audit-feedback.yml.tmp"
  "$ROOT/.vergil/pr-template.yml"
  "$ROOT/build/notes.md"
  "$ROOT/build/sub/dir/aid.json"
  "$ROOT/README.md"
  "$ROOT/hooks/scripts/block-heredoc.sh"
  "$ROOT/.vergil/../README.md"
  "/tmp/guard-audit-writes-test-scratch.txt"
  ""
  "$ROOT/.vergil/pr-template.yml"
  "$ROOT/build/review-aid.ipynb"
)
T_EXPECT=(
  "allow"
  "allow"
  "allow"
  "allow"
  "deny"
  "allow"
  "allow"
  "deny"
  "deny"
  "deny"
  "allow"
  "deny"
  "deny"
  "allow"
)

pass=0
fail=0
i=0
total=${#T_NAME[@]}

while [ "$i" -lt "$total" ]; do
  name="${T_NAME[$i]}"
  identity="${T_IDENTITY[$i]}"
  field="${T_FIELD[$i]}"
  path="${T_PATH[$i]}"
  expect="${T_EXPECT[$i]}"

  if [ "$field" = "none" ]; then
    payload=$(jq -n --arg cwd "$ROOT" \
      '{tool_input: {cwd: $cwd}, cwd: $cwd}')
  else
    payload=$(jq -n --arg fp "$path" --arg cwd "$ROOT" --arg f "$field" \
      '{tool_input: {($f): $fp, cwd: $cwd}, cwd: $cwd}')
  fi

  out=$(printf '%s' "$payload" \
    | VRG_IDENTITY_MODE="$identity" bash "$HOOK" 2>&1) || true

  verdict="allow"
  if printf '%s' "$out" | grep -q '"permissionDecision": "deny"'; then
    verdict="deny"
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
echo "guard-audit-writes: $pass passed, $fail failed, $total total"
[ "$fail" -eq 0 ]
