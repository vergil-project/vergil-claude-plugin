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

# normalize_command_words (#1405): a quoted span holding one plain word
# and a backslash before a plain character read as the shell reads
# them; any other span still becomes "".
# norm_case <name> <input> <expect>
norm_case() {
  local name="$1" input="$2" expect="$3" got
  got=$(normalize_command_words "$input")
  total=$((total + 1))
  if [ "$got" = "$expect" ]; then
    echo "PASS [norm] $name"
    pass=$((pass + 1))
  else
    echo "FAIL [norm] $name"
    printf '       expected: %s\n' "$expect"
    printf '       got:      %s\n' "$got"
    fail=$((fail + 1))
  fi
}

norm_case "single-quoted word" "git 'commit' -m x" 'git commit -m x'
norm_case "double-quoted word" '"git" commit' 'git commit'
norm_case "quotes inside a word" "g\"i\"t c'omm'it" 'git commit'
norm_case "backslash before a word" '\git commit' 'git commit'
norm_case "quoted path" 'cd "/a/b-c.d" && x' 'cd /a/b-c.d && x'
norm_case "span with a space still stripped" 'echo "git commit"' 'echo ""'
norm_case "span with a variable still stripped" "cd \"\$WT\"" 'cd ""'
norm_case "multi-line span still stripped" \
  "vrg-commit --body \"a${NL}git commit\"" 'vrg-commit --body ""'
norm_case "single-quoted span inside a double-quoted one" \
  "vrg-commit --body \"env git 'commit'\"" 'vrg-commit --body ""'
norm_case "escaped quote left alone" 'echo \"x' 'echo \"x'
norm_case "empty command" "" ""

echo "----------------------------------------"
echo "command-match: $pass passed, $fail failed, $total total"
[ "$fail" -eq 0 ]
