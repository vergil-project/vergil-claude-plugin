# Command-Matcher Quoting Fix (#450) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop PreToolUse hook matchers from false-positive-matching
tool names that appear inside quoted multi-line arguments, per
`docs/specs/2026-06-05-450-command-matcher-quoting-design.md`.

**Architecture:** One shared bash helper (`strip_quoted_segments` in
`hooks/scripts/lib/command-match.sh`) removes quoted spans from the
command text; each hook script's existing tool-name regex then runs
against the stripped text with the hardened anchor
`(^|[;&|({]\s*)`. Argument-content predicates (URLs, method flags,
`--linkage` values, `cd`/`git -C` path extraction) keep matching raw
text. The vergil-tooling half (`vrg-hook-guard`) is a separate
sub-issue filed in Task 13 and implemented in that repo.

**Tech Stack:** bash 3.2-compatible shell, jq (Oniguruma regex,
already a hard dependency of every hook script), `grep -E`,
table-driven bash tests per the `guard-audit-writes.test.sh`
convention.

---

## Execution rules for this repo (read first)

1. **Worktree.** All paths below are relative to the worktree root:
   `/Users/pmoore/dev/projects/vergil-project/vergil-claude-plugin/.worktrees/issue-450-matcher-quoted-args/`
   Use absolute worktree paths for Read/Edit/Write; `cd` into the
   worktree for every Bash command. Never edit the project root.
2. **Commits.** Never raw `git commit` — always `vrg-git add …` then
   `vrg-commit --type … --scope … --message … [--body …]`. Never raw
   `gh` — always `vrg-gh`.
3. **Live-fire hazard.** The hooks this plan fixes scan *your* Bash
   command strings, and until the fix ships they still have the
   #450 bug. Practical consequences while executing this plan:
   - Never start a line inside a quoted `--body` argument with a
     tool name (`git commit`, `gh pr create`, `vrg-submit-pr`,
     `pytest`, `declare -A`, …). Keep commit bodies to a single
     paragraph.
   - `vrg-hook-guard` (host) additionally denies commands containing
     bare `git`/`gh` tokens even mid-word after `.`/`/` (e.g.
     `find . -path ./.git`). Avoid such tokens in your commands; use
     the Read/Write/Edit tools instead of shell text processing.
   - Heredocs are blocked repo-wide. Multi-line content goes through
     the Write tool into a file, passed via `--body-file`.
4. **Validation.** `vrg-container-run -- vrg-validate` is the only
   validation command. The bash test suites can also be run directly
   (`bash hooks/tests/<name>.test.sh`) for fast TDD loops — they
   need only jq, grep, and git.
5. **Spec.** The authoritative design, canonical case table, and
   accepted gaps:
   `docs/specs/2026-06-05-450-command-matcher-quoting-design.md`.

## File structure

| File | Responsibility |
| --- | --- |
| Create `hooks/scripts/lib/command-match.sh` | the `strip_quoted_segments` helper — the single seam where the fix lives |
| Create `hooks/tests/command-match.test.sh` | stripper unit tests (spec §6.2) |
| Create `hooks/tests/command-matchers.test.sh` | per-script allow/deny integration tests (spec §6.3) |
| Modify 9 scripts under `hooks/scripts/` | point tool-name predicates at stripped text (spec §3.2 table) |
| Create `scripts/bin/validate-custom` | wires `hooks/tests/*.test.sh` into `vrg-validate` (spec §6.5) |
| Modify `docs/site/docs/hooks/index.md` | document quote-stripped matching |
| Modify `docs/specs/2026-06-05-450-command-matcher-quoting-design.md` | record the filed vergil-tooling sub-issue number |

`block-heredoc.sh` is intentionally untouched (spec §3.2: stripping
would break quoted-delimiter heredoc detection).

---

### Task 1: Stripper helper + unit tests

**Files:**
- Create: `hooks/tests/command-match.test.sh`
- Create: `hooks/scripts/lib/command-match.sh`

- [ ] **Step 1: Write the failing test**

Write `hooks/tests/command-match.test.sh` with exactly this content:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run (from the worktree root):
`bash hooks/tests/command-match.test.sh`
Expected: a source error
(`…/lib/command-match.sh: No such file or directory`), then every
case FAILs with `strip_quoted_segments: command not found` noise,
and the suite exits non-zero. (The suite uses `set -u`, not
`set -e`, so the failed `source` does not abort the run.)

- [ ] **Step 3: Commit the red test**

```bash
vrg-git add hooks/tests/command-match.test.sh
vrg-commit --type test --scope hooks \
  --message "add failing stripper tests for command matchers" \
  --body "Table-driven tests for strip_quoted_segments encoding the stripping-relevant canonical vectors from spec section 6.1 (rows 5, 7-10, 14) plus the empty command. RED: the lib does not exist yet. Ref vergil-project/vergil-claude-plugin#450."
```

- [ ] **Step 4: Write the implementation**

Write `hooks/scripts/lib/command-match.sh` with exactly this content
(tabs for indentation, matching `managed-repo-check.sh`):

```bash
#!/usr/bin/env bash
# command-match.sh — shared quote-stripping helper for the plugin's
# command matchers (#450).
#
# Tool-name matchers scan the Bash tool's raw command string. A tool
# name at the start of a line inside a quoted multi-line argument
# (vrg-commit --body, vrg-gh issue create --body) is
# indistinguishable from a tool name in command position, producing
# false denies. Stripping quoted spans first removes argument
# content from the matcher's view; what remains is command
# structure.
#
# Canonical rule and accepted gaps:
#   docs/specs/2026-06-05-450-command-matcher-quoting-design.md §2
#
# This file is meant to be `source`d, not executed directly.
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/command-match.sh"
#   stripped=$(strip_quoted_segments "$command")
#   if echo "$stripped" | grep -qE '(^|[;&|({]\s*)git\s+commit(\s|$)'; then

# strip_quoted_segments <command-text>
#
# Prints the command text with single- and double-quoted spans
# replaced by the placeholder "" in one left-to-right pass (leftmost
# match wins, mirroring how the shell scans). Double-quoted spans
# honor backslash escapes; single-quoted spans do not (shell
# semantics). Multi-line spans are handled: jq's gsub operates on
# the whole string, unlike line-oriented sed/grep. jq is already a
# hard dependency of every hook script.
#
# Unbalanced quotes leave the remainder unstripped — a
# false-positive (over-blocking) direction only; see spec §2.1.
strip_quoted_segments() {
	printf '%s' "$1" | jq -Rsr 'gsub("\"(\\\\.|[^\"\\\\])*\"|'\''[^'\'']*'\''"; "\"\"")'
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash hooks/tests/command-match.test.sh`
Expected: `command-match: 7 passed, 0 failed, 7 total`, exit 0.

- [ ] **Step 6: Commit**

```bash
vrg-git add hooks/scripts/lib/command-match.sh
vrg-commit --type feat --scope hooks \
  --message "add shared quote-stripping helper for command matchers" \
  --body "strip_quoted_segments replaces quoted spans with a placeholder in one leftmost-wins jq gsub pass, multi-line aware, escape-aware for double quotes. Single seam for the false-positive fix; spec section 3.1. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 2: Matcher test harness + `block-raw-git-commit.sh`

**Files:**
- Create: `hooks/tests/command-matchers.test.sh`
- Modify: `hooks/scripts/block-raw-git-commit.sh`

- [ ] **Step 1: Write the failing harness**

Write `hooks/tests/command-matchers.test.sh` with exactly this
content. It encodes the canonical table rows 1–10, 13, 14 against
`block-raw-git-commit.sh` (rows 11–12 are vrg-hook-guard-only);
later tasks append per-script rows to the same arrays.

```bash
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
```

- [ ] **Step 2: Run to verify the expected failures**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 3 FAILs —
- `[2] rgc row 3` (subshell — `(` not yet a separator → got allow)
- `[3] rgc row 4` (brace group — `{` not yet a separator → got allow)
- `[4] rgc row 5` (#450 repro — quoted body still matched → got deny)

All other rows PASS. If a different set fails, stop and debug
before proceeding.

- [ ] **Step 3: Commit the red harness**

```bash
vrg-git add hooks/tests/command-matchers.test.sh
vrg-commit --type test --scope hooks \
  --message "add failing matcher tests encoding the canonical case table" \
  --body "Allow/deny harness feeding hook JSON to the matcher scripts, starting with the spec section 6.1 table against block-raw-git-commit (rows 11-12 excluded as vrg-hook-guard-only). RED: rows 3, 4, 5 fail until the script is migrated. Ref vergil-project/vergil-claude-plugin#450."
```

- [ ] **Step 4: Migrate `block-raw-git-commit.sh`**

In `hooks/scripts/block-raw-git-commit.sh`, make two edits.

Edit A — source the helper (after the existing
`managed-repo-check.sh` source):

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B — match against stripped text with the hardened anchor:

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')

if echo "$command" | grep -qE '(^|[;&|]\s*)git\s+commit(\s|$)'; then
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")

if echo "$stripped" | grep -qE '(^|[;&|({]\s*)git\s+commit(\s|$)'; then
```

- [ ] **Step 5: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 12 passed, 0 failed, 12 total`, exit 0.

- [ ] **Step 6: Commit**

```bash
vrg-git add hooks/scripts/block-raw-git-commit.sh
vrg-commit --type fix --scope hooks \
  --message "match raw-git-commit fallback against quote-stripped text" \
  --body "The fallback regex now runs on strip_quoted_segments output with the hardened anchor, so tool names at line start inside quoted multi-line arguments no longer deny legitimate commands. Spec section 3.2. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 3: `block-raw-gh-pr-create.sh`

**Files:**
- Modify: `hooks/tests/command-matchers.test.sh` (append rows)
- Modify: `hooks/scripts/block-raw-gh-pr-create.sh`

- [ ] **Step 1: Append failing rows**

Append to the END of each array in
`hooks/tests/command-matchers.test.sh` (keep array positions aligned
across all six arrays; same pattern in every later task):

To `T_NAME`:

```bash
  "pr-create: plain invocation"
  "pr-create: quoted body prose (#450 shape)"
  "pr-create: gh api POST to /pulls"
```

To `T_SCRIPT`:

```bash
  "block-raw-gh-pr-create.sh"
  "block-raw-gh-pr-create.sh"
  "block-raw-gh-pr-create.sh"
```

To `T_COMMAND`:

```bash
  'gh pr create --title x'
  "vrg-commit --type docs --scope x --message y --body \"docs say${NL}gh pr create is blocked\""
  'gh api repos/o/r/pulls -X POST'
```

To `T_CWD`:

```bash
  "" "" ""
```

To `T_RESPONSE`:

```bash
  "" "" ""
```

To `T_EXPECT`:

```bash
  "deny"
  "allow"
  "deny"
```

- [ ] **Step 2: Run to verify the expected failure**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 1 FAIL — `pr-create: quoted body prose` (got deny).

- [ ] **Step 3: Migrate the script**

In `hooks/scripts/block-raw-gh-pr-create.sh`:

Edit A — source the helper:

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B — compute stripped text and point the two tool-name
predicates at it (the HTTP-method check stays on `$command`, spec
§2.3):

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")
```

Edit C:

```bash
# old
if echo "$command" | grep -qE '(^|[;&|]\s*)gh\s+pr\s+create(\s|$)'; then
```

```bash
# new
if echo "$stripped" | grep -qE '(^|[;&|({]\s*)gh\s+pr\s+create(\s|$)'; then
```

Edit D:

```bash
# old
elif echo "$command" | grep -qE 'gh\s+api\s+.*(/pulls)(\s|$)' \
```

```bash
# new
elif echo "$stripped" | grep -qE 'gh\s+api\s+.*(/pulls)(\s|$)' \
```

(The following line — `grep -qiE '(-X\s+POST|--method\s+POST|-XPOST)'`
on `$command` — is intentionally unchanged.)

- [ ] **Step 4: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 15 passed, 0 failed, 15 total`.

- [ ] **Step 5: Commit**

```bash
vrg-git add hooks/scripts/block-raw-gh-pr-create.sh hooks/tests/command-matchers.test.sh
vrg-commit --type fix --scope hooks \
  --message "match pr-create tool-name predicates against stripped text" \
  --body "Both invocation predicates now run on quote-stripped text with the hardened anchor; the HTTP-method flag check stays on raw text per spec section 2.3. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 4: `block-agent-merge.sh`

**Files:**
- Modify: `hooks/tests/command-matchers.test.sh` (append rows)
- Modify: `hooks/scripts/block-agent-merge.sh`

- [ ] **Step 1: Append failing rows**

Append (same array-alignment rule):

To `T_NAME`:

```bash
  "agent-merge: gh pr merge"
  "agent-merge: gh pr review --approve"
  "agent-merge: quoted body prose (#450 shape)"
  "agent-merge: gh api PUT merge"
```

To `T_SCRIPT`:

```bash
  "block-agent-merge.sh"
  "block-agent-merge.sh"
  "block-agent-merge.sh"
  "block-agent-merge.sh"
```

To `T_COMMAND`:

```bash
  'gh pr merge 5'
  'gh pr review 5 --approve'
  "vrg-gh issue create --title t --body \"policy:${NL}gh pr merge 5 is forbidden\""
  'gh api repos/o/r/pulls/5/merge -X PUT'
```

To `T_CWD`:

```bash
  "" "" "" ""
```

To `T_RESPONSE`:

```bash
  "" "" "" ""
```

To `T_EXPECT`:

```bash
  "deny"
  "deny"
  "allow"
  "deny"
```

- [ ] **Step 2: Run to verify the expected failure**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 1 FAIL — `agent-merge: quoted body prose`
(got deny).

- [ ] **Step 3: Migrate the script**

In `hooks/scripts/block-agent-merge.sh`:

Edit A — source the helper:

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B:

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")
```

Edit C — the three tool-name predicates move to `$stripped`; the
case-insensitive method-flag greps stay on `$command` (spec §2.3):

```bash
# old
if echo "$command" \
     | grep -qE '(^|[;&|]\s*)gh\s+pr\s+(merge(\s|$)|review\s+.*--approve)'; then
  is_merge_command=true
fi

if echo "$command" | grep -qE 'gh\s+api\s+.*/pulls/[0-9]+/merge(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+PUT|--method\s+PUT|-XPUT)'; then
  is_merge_command=true
fi

if echo "$command" | grep -qE 'gh\s+api\s+.*/pulls/[0-9]+/reviews(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+POST|--method\s+POST|-XPOST)'; then
  is_merge_command=true
fi
```

```bash
# new
if echo "$stripped" \
     | grep -qE '(^|[;&|({]\s*)gh\s+pr\s+(merge(\s|$)|review\s+.*--approve)'; then
  is_merge_command=true
fi

if echo "$stripped" | grep -qE 'gh\s+api\s+.*/pulls/[0-9]+/merge(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+PUT|--method\s+PUT|-XPUT)'; then
  is_merge_command=true
fi

if echo "$stripped" | grep -qE 'gh\s+api\s+.*/pulls/[0-9]+/reviews(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+POST|--method\s+POST|-XPOST)'; then
  is_merge_command=true
fi
```

- [ ] **Step 4: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 19 passed, 0 failed, 19 total`.

- [ ] **Step 5: Commit**

```bash
vrg-git add hooks/scripts/block-agent-merge.sh hooks/tests/command-matchers.test.sh
vrg-commit --type fix --scope hooks \
  --message "match agent-merge tool-name predicates against stripped text" \
  --body "All three merge/approve invocation predicates now run on quote-stripped text with the hardened anchor; method-flag greps stay on raw text per spec section 2.3. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 5: `enforce-host-container-split.sh`

**Files:**
- Modify: `hooks/tests/command-matchers.test.sh` (append rows)
- Modify: `hooks/scripts/enforce-host-container-split.sh`

- [ ] **Step 1: Append failing rows**

To `T_NAME`:

```bash
  "host-split: wrapped host tool denied"
  "host-split: quoted body mentioning wrapped host tool (#450 shape)"
  "host-split: bare container tool warns"
  "host-split: quoted body mentioning container tool (#450 shape)"
```

To `T_SCRIPT`:

```bash
  "enforce-host-container-split.sh"
  "enforce-host-container-split.sh"
  "enforce-host-container-split.sh"
  "enforce-host-container-split.sh"
```

To `T_COMMAND`:

```bash
  'vrg-container-run -- git status'
  "vrg-commit --type docs --scope x --message y --body \"never do this:${NL}vrg-container-run -- gh pr list\""
  'shellcheck hooks/scripts/lib/command-match.sh'
  "vrg-commit --type docs --scope x --message y --body \"container tools:${NL}shellcheck runs in the container\""
```

To `T_CWD`:

```bash
  "" "" "" ""
```

To `T_RESPONSE`:

```bash
  "" "" "" ""
```

To `T_EXPECT`:

```bash
  "deny"
  "allow"
  "context"
  "allow"
```

- [ ] **Step 2: Run to verify the expected failures**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 2 FAILs — both `#450 shape` rows (got deny and
context respectively).

- [ ] **Step 3: Migrate the script**

In `hooks/scripts/enforce-host-container-split.sh`:

Edit A — source the helper (this script sources two libs already;
add after them):

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/host-container-tools.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/host-container-tools.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B:

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")
```

Edit C — DENY loop:

```bash
# old
  if echo "$command" | grep -qE "(^|[;&|]\s*)vrg-container-run\s+--\s+$tool(\s|$)"; then
```

```bash
# new
  if echo "$stripped" | grep -qE "(^|[;&|({]\s*)vrg-container-run\s+--\s+$tool(\s|$)"; then
```

Edit D — WARN loop:

```bash
# old
  if echo "$command" | grep -qE "(^|[;&|]\s*)(vrg-container-run\s+--\s+)?$tool(\s|$)"; then
```

```bash
# new
  if echo "$stripped" | grep -qE "(^|[;&|({]\s*)(vrg-container-run\s+--\s+)?$tool(\s|$)"; then
```

- [ ] **Step 4: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 23 passed, 0 failed, 23 total`.

- [ ] **Step 5: Commit**

```bash
vrg-git add hooks/scripts/enforce-host-container-split.sh hooks/tests/command-matchers.test.sh
vrg-commit --type fix --scope hooks \
  --message "match host-container-split loops against stripped text" \
  --body "Both routing loops now run on quote-stripped text with the hardened anchor, so tool names mentioned in quoted prose no longer deny or warn. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 6: `detect-deprecation-warnings.sh`

**Files:**
- Modify: `hooks/tests/command-matchers.test.sh` (append rows)
- Modify: `hooks/scripts/detect-deprecation-warnings.sh`

- [ ] **Step 1: Append failing rows**

To `T_NAME`:

```bash
  "deprecation: pytest with warning in output"
  "deprecation: quoted body mentioning pytest (#450 shape)"
  "deprecation: pytest with clean output"
```

To `T_SCRIPT`:

```bash
  "detect-deprecation-warnings.sh"
  "detect-deprecation-warnings.sh"
  "detect-deprecation-warnings.sh"
```

To `T_COMMAND`:

```bash
  'pytest -q'
  "vrg-commit --type docs --scope x --message y --body \"test notes:${NL}pytest emitted warnings\""
  'pytest -q'
```

To `T_CWD`:

```bash
  "" "" ""
```

To `T_RESPONSE`:

```bash
  "DeprecationWarning: old API"
  "DeprecationWarning: old API"
  "2 passed"
```

To `T_EXPECT`:

```bash
  "context"
  "allow"
  "allow"
```

- [ ] **Step 2: Run to verify the expected failure**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 1 FAIL — `deprecation: quoted body mentioning
pytest` (got context).

- [ ] **Step 3: Migrate the script**

In `hooks/scripts/detect-deprecation-warnings.sh`:

Edit A — source the helper:

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B — the command matcher moves to stripped text; the
`tool_response` scan is output, not a command, and is intentionally
unchanged:

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')
response=$(echo "$input" | jq -r '.tool_response // ""')

# Only trigger after test commands
is_test_command=false
if echo "$command" | grep -qE '(^|[;&|]\s*)(pytest|cargo\s+test|go\s+test|bundle\s+exec\s+rspec|ruby\s+-e|rake\s+test|mvn\s+test|uv\s+run\s+pytest)(\s|$)'; then
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")
response=$(echo "$input" | jq -r '.tool_response // ""')

# Only trigger after test commands
is_test_command=false
if echo "$stripped" | grep -qE '(^|[;&|({]\s*)(pytest|cargo\s+test|go\s+test|bundle\s+exec\s+rspec|ruby\s+-e|rake\s+test|mvn\s+test|uv\s+run\s+pytest)(\s|$)'; then
```

- [ ] **Step 4: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 26 passed, 0 failed, 26 total`.

- [ ] **Step 5: Commit**

```bash
vrg-git add hooks/scripts/detect-deprecation-warnings.sh hooks/tests/command-matchers.test.sh
vrg-commit --type fix --scope hooks \
  --message "match deprecation test-command predicate against stripped text" \
  --body "The test-runner matcher now runs on quote-stripped text with the hardened anchor; the deprecation scan of tool output is unchanged. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 7: `block-protected-branch-work.sh`

**Files:**
- Modify: `hooks/tests/command-matchers.test.sh` (append rows)
- Modify: `hooks/scripts/block-protected-branch-work.sh`

- [ ] **Step 1: Append failing rows**

These rows use the scratch repo (`T_CWD` = `SCRATCH`), whose root is
outside `.worktrees/` and whose `.gitignore` adopts the convention,
so commits from its root are denied.

To `T_NAME`:

```bash
  "protected: real commit at convention-repo root"
  "protected: non-commit with quoted commit prose (#450 over-blocking)"
  "protected: non-commit git operation"
```

To `T_SCRIPT`:

```bash
  "block-protected-branch-work.sh"
  "block-protected-branch-work.sh"
  "block-protected-branch-work.sh"
```

To `T_COMMAND`:

```bash
  'git commit -m x'
  "vrg-gh issue create --title t --body \"repro:${NL}git commit -m x was blocked\""
  'git push origin HEAD'
```

To `T_CWD`:

```bash
  "SCRATCH" "SCRATCH" "SCRATCH"
```

To `T_RESPONSE`:

```bash
  "" "" ""
```

To `T_EXPECT`:

```bash
  "deny"
  "allow"
  "allow"
```

- [ ] **Step 2: Run to verify the expected failure**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 1 FAIL — `protected: non-commit with quoted commit
prose` (got deny — the over-blocking direction from spec §3.2).

- [ ] **Step 3: Migrate the script**

In `hooks/scripts/block-protected-branch-work.sh`:

Edit A — source the helper:

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B — the gating matcher moves to stripped text. The `cd` /
`git -C` directory-extraction greps further down stay on
`$command` — they extract paths, which are legitimately quoted
(spec §2.3):

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')

# Only check commands that could create commits on the current branch.
# Allow git operations that don't create commits (checkout, push, pull, etc.).
if ! echo "$command" | grep -qE '(^|[;&|]\s*)(git\s+commit|vrg-commit)(\s|$)'; then
  exit 0
fi
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")

# Only check commands that could create commits on the current branch.
# Allow git operations that don't create commits (checkout, push, pull, etc.).
if ! echo "$stripped" | grep -qE '(^|[;&|({]\s*)(git\s+commit|vrg-commit)(\s|$)'; then
  exit 0
fi
```

- [ ] **Step 4: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 29 passed, 0 failed, 29 total`.

- [ ] **Step 5: Commit**

```bash
vrg-git add hooks/scripts/block-protected-branch-work.sh hooks/tests/command-matchers.test.sh
vrg-commit --type fix --scope hooks \
  --message "match protected-branch gating predicate against stripped text" \
  --body "The commit-detection gate now runs on quote-stripped text with the hardened anchor, so non-commit commands with commit-looking quoted prose are no longer subjected to the worktree check. Directory-extraction greps stay on raw text per spec section 2.3. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 8: `block-autoclose-linkage.sh`

**Files:**
- Modify: `hooks/tests/command-matchers.test.sh` (append rows)
- Modify: `hooks/scripts/block-autoclose-linkage.sh`

- [ ] **Step 1: Append failing rows**

To `T_NAME`:

```bash
  "autoclose: forbidden linkage keyword"
  "autoclose: Ref linkage allowed"
  "autoclose: quoted body mentioning the rule (#450 shape)"
```

To `T_SCRIPT`:

```bash
  "block-autoclose-linkage.sh"
  "block-autoclose-linkage.sh"
  "block-autoclose-linkage.sh"
```

To `T_COMMAND`:

```bash
  'vrg-submit-pr --issue 450 --linkage Fixes'
  'vrg-submit-pr --issue 450 --linkage Ref'
  "vrg-commit --type docs --scope x --message y --body \"policy reminder:${NL}vrg-submit-pr --linkage Fixes is forbidden\""
```

To `T_CWD`:

```bash
  "" "" ""
```

To `T_RESPONSE`:

```bash
  "" "" ""
```

To `T_EXPECT`:

```bash
  "deny"
  "allow"
  "allow"
```

- [ ] **Step 2: Run to verify the expected failure**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 1 FAIL — `autoclose: quoted body mentioning the
rule` (got deny — the loose `\b` matcher hits prose).

- [ ] **Step 3: Migrate the script**

In `hooks/scripts/block-autoclose-linkage.sh`:

Edit A — source the helper:

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B — the loose `\b` matcher becomes the canonical anchor on
stripped text; the `--linkage` value check stays on `$command`
(spec §3.2):

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')

if echo "$command" | grep -qE 'vrg-submit-pr\b'; then
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")

if echo "$stripped" | grep -qE '(^|[;&|({]\s*)vrg-submit-pr(\s|$)'; then
```

- [ ] **Step 4: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 32 passed, 0 failed, 32 total`.

- [ ] **Step 5: Commit**

```bash
vrg-git add hooks/scripts/block-autoclose-linkage.sh hooks/tests/command-matchers.test.sh
vrg-commit --type fix --scope hooks \
  --message "anchor autoclose-linkage tool predicate on stripped text" \
  --body "Replaces the loose word-boundary match with the canonical command-position anchor on quote-stripped text; the linkage-value check stays on raw text. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 9: `block-github-contents-api.sh`

**Files:**
- Modify: `hooks/tests/command-matchers.test.sh` (append rows)
- Modify: `hooks/scripts/block-github-contents-api.sh`

- [ ] **Step 1: Append failing rows**

To `T_NAME`:

```bash
  "contents-api: write method denied"
  "contents-api: GET allowed"
  "contents-api: quoted body citing the blocked call (#450 shape)"
```

To `T_SCRIPT`:

```bash
  "block-github-contents-api.sh"
  "block-github-contents-api.sh"
  "block-github-contents-api.sh"
```

To `T_COMMAND`:

```bash
  'gh api --method PUT repos/o/r/contents/f.md'
  'gh api repos/o/r/contents/f.md'
  "vrg-commit --type docs --scope x --message y --body \"blocked example:${NL}gh api --method PUT repos/o/r/contents/f.md\""
```

To `T_CWD`:

```bash
  "" "" ""
```

To `T_RESPONSE`:

```bash
  "" "" ""
```

To `T_EXPECT`:

```bash
  "deny"
  "allow"
  "allow"
```

- [ ] **Step 2: Run to verify the expected failure**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 1 FAIL — `contents-api: quoted body citing the
blocked call` (got deny).

- [ ] **Step 3: Migrate the script**

In `hooks/scripts/block-github-contents-api.sh`:

Edit A — source the helper:

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B — only the `gh api` invocation detection moves to stripped
text. The contents-URL grep and the method grep stay on `$command`:
URLs and flags are legitimately quoted arguments (spec §2.3, §3.2):

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")
```

Edit C:

```bash
# old
if echo "$command" | grep -qE 'gh\s+api\s' && echo "$command" | grep -qE '(repos/[^[:space:]]*/contents/|https://api\.github\.com/repos/[^[:space:]]*/contents/)'; then
```

```bash
# new
if echo "$stripped" | grep -qE 'gh\s+api\s' && echo "$command" | grep -qE '(repos/[^[:space:]]*/contents/|https://api\.github\.com/repos/[^[:space:]]*/contents/)'; then
```

- [ ] **Step 4: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 35 passed, 0 failed, 35 total`.

- [ ] **Step 5: Commit**

```bash
vrg-git add hooks/scripts/block-github-contents-api.sh hooks/tests/command-matchers.test.sh
vrg-commit --type fix --scope hooks \
  --message "match contents-api invocation detection against stripped text" \
  --body "Only the api-invocation predicate moves to quote-stripped text; the contents-URL and method greps stay on raw text because those targets are legitimately quoted arguments. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 10: `block-associative-arrays.sh`

**Files:**
- Modify: `hooks/tests/command-matchers.test.sh` (append rows)
- Modify: `hooks/scripts/block-associative-arrays.sh`

- [ ] **Step 1: Append failing rows**

To `T_NAME`:

```bash
  "assoc: declare -A denied"
  "assoc: indexed array allowed"
  "assoc: quoted body citing the rule (#450 shape)"
```

To `T_SCRIPT`:

```bash
  "block-associative-arrays.sh"
  "block-associative-arrays.sh"
  "block-associative-arrays.sh"
```

To `T_COMMAND`:

```bash
  'declare -A map'
  'declare -a list'
  "vrg-commit --type docs --scope x --message y --body \"bash policy:${NL}declare -A needs bash 4 and is blocked\""
```

To `T_CWD`:

```bash
  "" "" ""
```

To `T_RESPONSE`:

```bash
  "" "" ""
```

To `T_EXPECT`:

```bash
  "deny"
  "allow"
  "allow"
```

- [ ] **Step 2: Run to verify the expected failure**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: exactly 1 FAIL — `assoc: quoted body citing the rule`
(got deny).

- [ ] **Step 3: Migrate the script**

In `hooks/scripts/block-associative-arrays.sh`:

Edit A — source the helper:

```bash
# old
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
```

```bash
# new
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/command-match.sh"
```

Edit B — this matcher keeps its existing regex shape (it
deliberately matches `declare` in any position, since `declare` is
valid mid-pipeline); only the text it scans changes:

```bash
# old
command=$(echo "$input" | jq -r '.tool_input.command')

# Match declare with -A flag in any position (e.g., -A, -Ag, -rA, -gA).
if echo "$command" | grep -qE 'declare\s+-[a-zA-Z]*A'; then
```

```bash
# new
command=$(echo "$input" | jq -r '.tool_input.command')
stripped=$(strip_quoted_segments "$command")

# Match declare with -A flag in any position (e.g., -A, -Ag, -rA, -gA).
if echo "$stripped" | grep -qE 'declare\s+-[a-zA-Z]*A'; then
```

- [ ] **Step 4: Run to verify green**

Run: `bash hooks/tests/command-matchers.test.sh`
Expected: `command-matchers: 38 passed, 0 failed, 38 total`.

- [ ] **Step 5: Commit**

```bash
vrg-git add hooks/scripts/block-associative-arrays.sh hooks/tests/command-matchers.test.sh
vrg-commit --type fix --scope hooks \
  --message "match associative-array predicate against stripped text" \
  --body "Prose about declare -A inside quoted arguments no longer denies the command; the regex shape is unchanged. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 11: Wire hook tests into validation

**Files:**
- Create: `scripts/bin/validate-custom`

- [ ] **Step 1: Write the custom validator**

Write `scripts/bin/validate-custom` with exactly this content
(`vrg-validate` discovers and runs this path; spec §6.5):

```bash
#!/usr/bin/env bash
# validate-custom — repo-local validation hook discovered by
# vrg-validate. Runs the hook test suites under hooks/tests/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

status=0
for t in "$ROOT"/hooks/tests/*.test.sh; do
	echo "Running: $t"
	bash "$t" || status=1
done
exit "$status"
```

- [ ] **Step 2: Make it executable and verify it runs both suites**

```bash
chmod +x scripts/bin/validate-custom
bash scripts/bin/validate-custom
```

Expected: all three suites run (`command-match`,
`command-matchers`, `guard-audit-writes`), all green, exit 0.

- [ ] **Step 3: Run full validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: exit 0, with the custom validator's output included. If
shellcheck flags the new files, fix the findings before committing
(do not suppress). If the container image lacks `jq` or `git` (the
test suites need both), stop and surface that to the human — do not
work around it by skipping suites.

- [ ] **Step 4: Commit**

```bash
vrg-git add scripts/bin/validate-custom
vrg-commit --type build --scope validate \
  --message "wire hook test suites into vrg-validate via validate-custom" \
  --body "Adds the repo-local custom validator that vrg-validate discovers at scripts/bin/validate-custom; it runs every hooks/tests/*.test.sh, bringing the matcher and audit-guard suites into the validation pipeline. Spec section 6.5. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 12: Document quote-stripped matching

**Files:**
- Modify: `docs/site/docs/hooks/index.md`

- [ ] **Step 1: Add the section**

In `docs/site/docs/hooks/index.md`, insert the following new section
immediately after the `## Managed-repo gating` section (i.e., before
`## PreToolUse Hooks — Bash`):

```markdown
## Command matching: quote-stripping

Every Bash-command matcher below (except `block-heredoc`) tests
tool names against a **quote-stripped** copy of the command string:
single- and double-quoted spans are replaced with `""` first, then
the tool name must appear in command position
(`(^|[;&|({]\s*)<tool>(\s|$)`, applied per line).

This is why a commit body or issue body that *mentions* a blocked
command — even at the start of a line inside a multi-line `--body`
argument — does not trigger a false deny, while the same text in
command position still does.

`block-heredoc` matches raw text: its regex must see the quoted
delimiter in `<<'EOF'`, which stripping would remove.

Canonical rule, accepted gaps, and the shared test vectors:
[`docs/specs/2026-06-05-450-command-matcher-quoting-design.md`](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/specs/2026-06-05-450-command-matcher-quoting-design.md).
See [issue #450](https://github.com/vergil-project/vergil-claude-plugin/issues/450).
```

- [ ] **Step 2: Verify docs build and validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: exit 0 (markdownlint passes on the new section).

- [ ] **Step 3: Commit**

```bash
vrg-git add docs/site/docs/hooks/index.md
vrg-commit --type docs --scope hooks \
  --message "document quote-stripped command matching" \
  --body "Adds a hooks-page section explaining that matchers test quote-stripped text at command position, why prose mentions of blocked commands no longer false-deny, and why block-heredoc is exempt. Ref vergil-project/vergil-claude-plugin#450."
```

---

### Task 13: File the vergil-tooling sub-issue and link it in the spec

**Files:**
- Create: `/tmp/vt-450-subissue-body.md` (scratch, not committed)
- Modify: `docs/specs/2026-06-05-450-command-matcher-quoting-design.md`

- [ ] **Step 1: Write the issue body**

Write `/tmp/vt-450-subissue-body.md` with exactly this content:

```markdown
Sub-issue of vergil-project/vergil-claude-plugin#450 — the
`vrg-hook-guard` half.

The guard's `_RAW_GIT_RE` / `_RAW_GH_RE` use the lookbehind
`(?<![a-zA-Z0-9_-])`, which matches tool names preceded by `.` or
`/`, producing false denies on commands like
`find . -path ./.git -prune` (observed live 2026-06-05).

The canonical rule (quote-strip, then anchor at command position)
and the shared test vectors are defined in the plugin spec:
`docs/specs/2026-06-05-450-command-matcher-quoting-design.md`
(sections 2, 4, and 6.1).

Changes for this repo (spec section 4):

1. `_QUOTED_STR_RE` becomes the single alternation
   `"(\\.|[^"\\])*"|'[^']*'` (escape-aware for double quotes).
2. The lookbehind becomes the canonical anchor
   `(^|[;&|({]\s*)git(\s|$)` (resp. `gh`) with `re.MULTILINE`.
3. The `bash -c` recheck is confined to the extracted quoted
   argument instead of the whole raw command (spec section 4.3).
4. `tests/vergil_tooling/test_vrg_hook_guard.py` encodes the spec
   section 6.1 table verbatim, including rows 11-12.
```

- [ ] **Step 2: Create the issue**

```bash
vrg-gh issue create \
  --repo vergil-project/vergil-tooling \
  --title "vrg-hook-guard: adopt canonical quote-strip + command-position matcher (vergil-claude-plugin#450)" \
  --body-file /tmp/vt-450-subissue-body.md
```

Record the issue number `<N>` printed in the output URL.

- [ ] **Step 3: Link it in the spec header**

In `docs/specs/2026-06-05-450-command-matcher-quoting-design.md`,
replace the header clause:

```markdown
(this repo) · vergil-tooling sub-issue to be filed for the
`vrg-hook-guard` half (linked here once created)
```

with (substituting the real `<N>`):

```markdown
(this repo) ·
[vergil-tooling#<N>](https://github.com/vergil-project/vergil-tooling/issues/<N>)
(the `vrg-hook-guard` half)
```

- [ ] **Step 4: Commit**

```bash
vrg-git add docs/specs/2026-06-05-450-command-matcher-quoting-design.md
vrg-commit --type docs --scope specs \
  --message "link the filed vergil-tooling sub-issue in the matcher spec" \
  --body "Records the vrg-hook-guard companion issue number in the spec header now that it exists. Ref vergil-project/vergil-claude-plugin#450."
```

Note: formal GitHub sub-issue linkage uses `gh api`, which `vrg-gh`
denies; if the human wants the parent/child relation recorded in
GitHub's sub-issue graph, surface that as a one-line ask at handoff.

---

### Task 14: Final validation and handoff

**Files:**
- Create: `.vergil/pr-template.yml` (via `.tmp` + `mv`, not committed)

- [ ] **Step 1: Run the full suite one last time**

```bash
bash scripts/bin/validate-custom
vrg-container-run -- vrg-validate
```

Expected: both exit 0. If anything fails, fix it before proceeding —
never hand off red.

- [ ] **Step 2: Verify the worktree is clean and pushed state is known**

```bash
vrg-git status
vrg-git log --oneline origin/develop..HEAD
```

Expected: clean tree; the log lists every commit from Tasks 1–13
plus the two spec commits and the plan commit made during design.

- [ ] **Step 3: Write the PR handoff template**

Write `.vergil/pr-template.yml.tmp` with this content, then
`mv .vergil/pr-template.yml.tmp .vergil/pr-template.yml` (atomic,
per the implement-skill contract):

```yaml
issue: 450
title: "fix(hooks): stop command matchers false-matching quoted multi-line arguments"
summary: "Quote-strip command text before tool-name matching across nine hook scripts; shared lib + canonical test vectors; vrg-hook-guard companion issue filed in vergil-tooling"
notes: "Spec: docs/specs/2026-06-05-450-command-matcher-quoting-design.md. Consumers need a plugin refresh after merge."
```

- [ ] **Step 4: Hand off**

Tell the human:

- the branch (`bugfix/450-matcher-quoted-args`) is validated green
  and ready for `vrg-submit-pr` (use `--linkage Ref` — auto-close
  keywords are blocked);
- the vergil-tooling sub-issue number from Task 13, and that the
  parent/child sub-issue linkage (if wanted) needs a human `gh api`
  call;
- after merge to develop, consumers refresh with
  `/plugin marketplace update vergil-marketplace` then
  `/reload-plugins`.
