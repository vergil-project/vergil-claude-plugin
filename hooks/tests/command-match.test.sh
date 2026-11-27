#!/usr/bin/env bash
# command-match.test.sh — table-driven tests for
# strip_quoted_segments (#450).
#
# Encodes the stripping-relevant vectors of the canonical case
# table: docs/specs/2026-06-05-450-command-matcher-quoting-design.md
# §6.1 (rows 5, 7–10, 14) plus the empty command. bash
# 3.2-compatible: parallel indexed arrays.
#
# Usage: bash hooks/tests/command-match.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../scripts/lib/command-match.sh"

NL='
'

T_NAME=(
  "row 5: multi-line quoted body (#450 repro)"
  "row 7: double-quoted span"
  "row 8: single quotes nesting double quotes"
  "row 9: escaped double quotes inside a span"
  "row 10: unbalanced quote stays unstripped (separator in span)"
  "row 14: unbalanced quote stays unstripped (no separator)"
  "empty command"
)
T_INPUT=(
  "vrg-commit --body \"line one${NL}git commit mentioned here\""
  'echo "git commit"'
  "echo 'say \"git commit\"'"
  'echo "he said \"git commit\""'
  'echo "; git commit'
  'echo "git commit'
  ""
)
T_EXPECT=(
  'vrg-commit --body ""'
  'echo ""'
  'echo ""'
  'echo ""'
  'echo "; git commit'
  'echo "git commit'
  ""
)

pass=0
fail=0
i=0
total=${#T_NAME[@]}

while [ "$i" -lt "$total" ]; do
  name="${T_NAME[$i]}"
  got=$(strip_quoted_segments "${T_INPUT[$i]}")
  expect="${T_EXPECT[$i]}"

  if [ "$got" = "$expect" ]; then
    echo "PASS [$i] $name"
    pass=$((pass + 1))
  else
    echo "FAIL [$i] $name"
    printf '       expected: %s\n' "$expect"
    printf '       got:      %s\n' "$got"
    fail=$((fail + 1))
  fi
  i=$((i + 1))
done

echo "----------------------------------------"
echo "command-match: $pass passed, $fail failed, $total total"
[ "$fail" -eq 0 ]
