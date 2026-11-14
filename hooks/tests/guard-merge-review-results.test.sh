#!/usr/bin/env bash
# guard-merge-review-results.test.sh — table-driven tests for the guard
# that keeps agents from writing stored merge-review results (#1065).
#
# bash 3.2-compatible: parallel indexed arrays, no associative arrays.
#
# Usage: bash hooks/tests/guard-merge-review-results.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/guard-merge-review-results.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TMP=$(cd "$TMP" && pwd -P)
M="$TMP/main"
DIR="$M/build/.vergil-state/issue-implement/7/merge-review"
mkdir -p "$DIR"
git -C "$M" init --quiet
printf '[project]\n' >"$M/vergil.toml"
# A link from the scratch area into the private directory.
ln -s "$DIR" "$M/build/link"
# The same layout with no vergil.toml above it.
mkdir -p "$TMP/unmanaged/build/.vergil-state/issue-implement/7/merge-review"

#   T_FIELD  — file_path | notebook_path | none
#   T_PATH   — the path value
#   T_EXPECT — deny | allow | blocked (exit 2, fail-closed)
T_NAME=(
  "a review result is denied"
  "a check result is denied"
  "a capture record is denied"
  "a publishable reply copy is denied"
  "a result reached through a symlink is denied"
  "a relative path to a result is denied"
  "NotebookEdit on a result is denied"
  "the request file is allowed"
  "a security details file is allowed"
  "a step comment body is allowed"
  "a file named like a result elsewhere is allowed"
  "the same layout outside a managed repo is allowed"
  "a call with no path is refused in a managed repo"
)
T_FIELD=(
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "notebook_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "file_path"
  "none"
)
T_PATH=(
  "$DIR/result-review.md"
  "$DIR/result-check-2.md"
  "$DIR/capture-review.json"
  "$DIR/reply-check.md"
  "$M/build/link/result-review.md"
  "build/.vergil-state/issue-implement/7/merge-review/result-check.md"
  "$DIR/result-review.md"
  "$DIR/request-review.json"
  "$DIR/security-R1.md"
  "$DIR/comment-review.md"
  "$M/docs/result-review.md"
  "$TMP/unmanaged/build/.vergil-state/issue-implement/7/merge-review/result-review.md"
  ""
)
T_EXPECT=(
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
  "allow"
  "blocked"
)

pass=0
fail=0
i=0
total=${#T_NAME[@]}

while [ "$i" -lt "$total" ]; do
  name="${T_NAME[$i]}"
  field="${T_FIELD[$i]}"
  path="${T_PATH[$i]}"
  expect="${T_EXPECT[$i]}"

  if [ "$field" = "none" ]; then
    payload=$(jq -n --arg cwd "$M" '{tool_input: {}, cwd: $cwd}')
  else
    payload=$(jq -n --arg fp "$path" --arg cwd "$M" --arg f "$field" \
      '{tool_input: {($f): $fp}, cwd: $cwd}')
  fi

  out=$(printf '%s' "$payload" | bash "$HOOK" 2>&1)
  rc=$?

  verdict="allow"
  if [ "$rc" -eq 2 ]; then
    verdict="blocked"
  elif [ "$rc" -ne 0 ]; then
    verdict="error"
  elif printf '%s' "$out" | grep -q '"permissionDecision": "deny"'; then
    verdict="deny"
  elif [ -n "$out" ]; then
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
echo "guard-merge-review-results: $pass passed, $fail failed, $total total"
[ "$fail" -eq 0 ]
