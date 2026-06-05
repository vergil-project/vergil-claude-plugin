# AUDIT Write-Guard Hook (#442) Implementation Plan

> **Execution contract (vergil):** this plan implements exactly ONE
> issue (#442) and produces exactly ONE PR, under the vergil 2.1
> implement contract: work in
> `.worktrees/issue-442-audit-write-guard/` on
> `feature/442-audit-write-guard`, commit via `vrg-commit`, validate
> via `vrg-container-run -- vrg-validate`, finish by writing
> `.vergil/pr-template.yml` — the human submits the PR. Superpowers
> execution skills (subagent-driven-development / executing-plans) may
> drive the task loop *within* this issue only. Never open or merge a
> PR. (Plan-header convention trial per #443.)

**Goal:** A PreToolUse hook that denies the AUDIT identity any
Write/Edit/NotebookEdit outside `.vergil/audit-*` and `build/`,
turning the 2.1 spec's "read-only by discipline" into a mechanical
(soft) gate.

**Architecture:** One new hook script + one table-driven test script,
TDD (test first). Identity check first (`VRG_IDENTITY_MODE` ≠ `audit`
→ no-op), then managed-repo gating, then path normalization
(python3 `realpath`/`normpath` idiom shared with
`block-worktree-bypass-write`), then worktree-root-relative allowlist
check. Fail-closed inside the audit identity, fail-open outside it.
Design: `docs/specs/2026-06-05-hooks-2.1-reconciliation-design.md`
§3.3 + §2.

**Tech Stack:** bash 3.2-compatible (indexed arrays OK, NO associative
arrays), `jq`, `python3` for path normalization (existing hook
precedent), `git -C` for worktree-root discovery (hooks may call raw
git — they are not agent Bash commands).

---

## Execution context (read first)

- **Worktree:** `.worktrees/issue-442-audit-write-guard/`, branch
  `feature/442-audit-write-guard`. Absolute paths for Read/Edit;
  `cd` into the worktree for Bash.
- **Commits:** `vrg-git add` + `vrg-commit` only.
- **Validation:** `vrg-container-run -- vrg-validate`, from inside the
  worktree, before every commit.
- **Smoke/test runs:** the test script sets `VRG_IDENTITY_MODE`
  per-case itself; run it from the worktree root.
- **No heredocs in CLI args.** The committed test script uses
  `printf | bash` internally, which is fine.

---

### Task 1: failing test script (RED)

**Files:**
- Create: `hooks/tests/guard-audit-writes.test.sh`

- [ ] **Step 1: Write the test script**

Create `hooks/tests/guard-audit-writes.test.sh` with exactly:

```bash
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
```

- [ ] **Step 2: Run it to verify it fails (RED)**

Run: `bash hooks/tests/guard-audit-writes.test.sh; echo "exit=$?"`
Expected: **all 14 cases FAIL** (the hook script does not exist, so
`bash` errors on every invocation and even allow-cases report
`error`) and `exit=1`.

- [ ] **Step 3: Validate and commit the red test**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add hooks/tests/guard-audit-writes.test.sh
vrg-commit --type test --scope hooks \
  --message "add failing table-driven tests for the audit write-guard" \
  --body "Fourteen cases across identity (unset/user/audit), allowlist (.vergil/audit-*, build/), the protected pr-template, dot-dot escapes, unmanaged-path gating, the missing-path fail-closed rule, and the NotebookEdit notebook_path field. RED: the hook does not exist yet. Spec section 3.3. Ref #442."
```

---

### Task 2: implement the hook (GREEN)

**Files:**
- Create: `hooks/scripts/guard-audit-writes.sh`

- [ ] **Step 1: Write the hook**

Create `hooks/scripts/guard-audit-writes.sh` with exactly:

```bash
#!/usr/bin/env bash
# guard-audit-writes.sh — PreToolUse hook for Write|Edit|NotebookEdit.
#
# Enforces the AUDIT identity's write discipline from the 2.1 workflow
# spec: AUDIT may write only its own artifacts (.vergil/audit-*) and
# scratch space (build/). Everything else in a managed repo is denied —
# including .vergil/pr-template.yml, which is the USER agent's artifact.
#
# SOFT GATE (by design): identity comes from VRG_IDENTITY_MODE, which a
# misbehaving agent can unset. Every in-VM guard is soft; it steers a
# correctly behaving agent. Hard enforcement lives outside the VM
# (per-identity GitHub App credentials, the pinned vergil-audit/approved
# required check, the VM sandbox). Keeping the guard simple is the
# accepted trade-off. See the reconciliation design spec sections 2-3.3.
#
# Fail-closed inside the audit identity (unresolvable path -> deny),
# fail-open outside it. Bash-command writes are out of scope (documented
# gap). Gated on managed-repo detection (#87).
set -euo pipefail

# Identity gate first — this guard constrains only the AUDIT identity.
if [ "${VRG_IDENTITY_MODE:-}" != "audit" ]; then
  exit 0
fi

input=$(cat)
file_path=$(echo "$input" \
  | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

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

# Fail-closed: a write with no checkable target cannot be allowed.
if [ -z "$file_path" ]; then
  deny "AUDIT write-guard: this tool call has no file path to check, so it is denied for the audit identity. AUDIT may write only .vergil/audit-* and build/ inside the worktree. See issue #442."
fi

# Resolve to an absolute candidate path (relative paths resolve against
# the payload cwd; a relative cwd resolves against the hook's PWD).
case "$file_path" in
  /*) candidate="$file_path" ;;
  *) candidate="$cwd/$file_path" ;;
esac
case "$candidate" in
  /*) ;;
  *) candidate="$PWD/$candidate" ;;
esac

# Best-effort symlink resolution for existing files; lexical
# normalization (.. resolution) otherwise. Same python3 idiom as
# block-worktree-bypass-write.
if [ -e "$candidate" ]; then
  resolved=$(python3 -c \
    "import os,sys; print(os.path.realpath(sys.argv[1]))" \
    "$candidate" 2>/dev/null || echo "")
else
  resolved=$(python3 -c \
    "import os,sys; print(os.path.normpath(sys.argv[1]))" \
    "$candidate" 2>/dev/null || echo "")
fi
if [ -z "$resolved" ]; then
  deny "AUDIT write-guard: could not normalize the path '$file_path'; denied for the audit identity (fail-closed). See issue #442."
fi

# Nearest existing ancestor (the target may be a new file in a new dir).
check_dir="$resolved"
while [ -n "$check_dir" ] && [ "$check_dir" != "/" ] && [ ! -d "$check_dir" ]; do
  check_dir="${check_dir%/*}"
done
if [ -z "$check_dir" ]; then
  check_dir="/"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"

# Outside managed repos the guard does not apply (standard gating —
# scratch in /tmp etc. is not repo content).
if ! is_managed_repo "$check_dir"; then
  exit 0
fi

# The worktree root is the checkout the target lives in (git resolves
# .worktrees/<name>/ members to their own toplevel).
toplevel=$(git -C "$check_dir" rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$toplevel" ]; then
  deny "AUDIT write-guard: cannot determine the worktree root for '$file_path'; denied for the audit identity (fail-closed). See issue #442."
fi

case "$resolved" in
  "$toplevel"/*)
    rel="${resolved#"$toplevel"/}"
    ;;
  *)
    deny "AUDIT write-guard: '$file_path' resolves outside the worktree root; denied for the audit identity. See issue #442."
    ;;
esac

case "$rel" in
  .vergil/audit-* | build | build/*)
    exit 0
    ;;
esac

deny "AUDIT write-guard: the audit identity may write only .vergil/audit-* (its feedback artifacts) and build/ (scratch space). '$rel' is outside that allowlist — in particular, .vergil/pr-template.yml belongs to the USER agent. This is a soft gate per the 2.1 soft-gate doctrine; the hard gates are the credentials and the merge check. See issue #442."
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x hooks/scripts/guard-audit-writes.sh && ls -l hooks/scripts/guard-audit-writes.sh`
Expected: mode `-rwxr-xr-x`.

- [ ] **Step 3: Run the tests (GREEN)**

Run: `bash hooks/tests/guard-audit-writes.test.sh; echo "exit=$?"`
Expected: `14 passed, 0 failed, 14 total`, `exit=0`.

- [ ] **Step 4: Validate and commit**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add hooks/scripts/guard-audit-writes.sh
vrg-commit --type feat --scope hooks \
  --message "add AUDIT identity write-guard" \
  --body "PreToolUse guard for Write/Edit/NotebookEdit: when VRG_IDENTITY_MODE=audit, writes are allowed only to .vergil/audit-* and build/ within the worktree; everything else is denied, including the USER agent's .vergil/pr-template.yml. Identity-gate first, managed-repo gated, python3 path normalization shared with block-worktree-bypass-write, fail-closed inside the audit identity and fail-open outside it. Soft gate by design per the spec's soft-gate doctrine. GREEN: all 14 table-driven tests pass. Spec sections 2 and 3.3. Ref #442."
```

---

### Task 3: register the hook

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 1: Add the matcher entry**

In `hooks/hooks.json`, the PreToolUse array currently ends with the
`Write|Edit` matcher entry:

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

Replace it with:

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
      },
      {
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/guard-audit-writes.sh",
            "statusMessage": "Checking audit write allowlist..."
          }
        ]
      }
```

- [ ] **Step 2: Verify the JSON**

Run: `jq -e '.hooks.PreToolUse | length == 3' hooks/hooks.json && jq -r '.hooks.PreToolUse[2].matcher' hooks/hooks.json`
Expected: `true` then `Write|Edit|NotebookEdit`.

- [ ] **Step 3: Validate and commit**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add hooks/hooks.json
vrg-commit --type feat --scope hooks \
  --message "register guard-audit-writes for Write/Edit/NotebookEdit" \
  --body "Separate matcher entry so NotebookEdit is covered without changing block-worktree-bypass-write's matcher. Ref #442."
```

---

### Task 4: documentation

**Files:**
- Modify: `docs/site/docs/hooks/index.md`
- Modify: `README.md`

- [ ] **Step 1: Add the hooks-reference section**

In `docs/site/docs/hooks/index.md`, directly after the
`### block-worktree-bypass-write` section (before
`## PostToolUse Hooks — Bash`), insert:

```markdown
### guard-audit-writes

**What.** When `VRG_IDENTITY_MODE=audit`, denies Write/Edit/
NotebookEdit calls targeting anything other than `.vergil/audit-*`
(the audit's own artifacts) or `build/` (scratch space) inside the
worktree. Other identities are never constrained by this hook.

**Why.** The 2.1 workflow spec makes the AUDIT identity "read-only
by discipline, not by sandbox" — this hook turns the discipline into
a mechanical gate per the no-honor-system principle. The allowlist
deliberately excludes `.vergil/pr-template.yml`: that file is the
USER agent's artifact and the human's `vrg-submit-pr` input.

**Soft gate, by design.** Identity comes from an environment
variable a misbehaving agent can unset; every in-VM guard is soft.
It steers a correctly behaving agent — hard enforcement lives at
the per-identity GitHub App credentials, the pinned
`vergil-audit/approved` required check, and the VM sandbox. Keeping
the guard simple is the accepted trade-off. Bash-command writes
(`>`, `tee`, `sed -i` …) are a documented gap for the same reason.

**Failure mode.** Fail-closed inside the audit identity (no path,
unresolvable path, or path escaping the worktree → deny);
fail-open outside it.

**Alternative.** Write audit findings to
`.vergil/audit-feedback.yml`; use `build/` for scratch. Tests:
`hooks/tests/guard-audit-writes.test.sh`.
```

- [ ] **Step 2: Add the README row**

In `README.md`, insert directly after the `block-worktree-bypass-write`
row:

```markdown
| `guard-audit-writes` | PreToolUse/Write\|Edit\|NotebookEdit | AUDIT identity may write only `.vergil/audit-*` and `build/` — soft gate on the audit's read-only discipline |
```

- [ ] **Step 3: Validate and commit**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add docs/site/docs/hooks/index.md README.md
vrg-commit --type docs --scope hooks \
  --message "document guard-audit-writes" \
  --body "Hooks-reference section (including the soft-gate framing from the reconciliation spec section 2) and README table row. Ref #442."
```

---

### Task 5: final verification and done-signal

- [ ] **Step 1: Full test run**

Run: `bash hooks/tests/guard-audit-writes.test.sh; echo "exit=$?"`
Expected: `14 passed, 0 failed`, `exit=0`.

- [ ] **Step 2: Confirm the live session is unaffected**

Run: `echo '{"tool_input":{"file_path":"/tmp/x","cwd":"."},"cwd":"."}' | bash hooks/scripts/guard-audit-writes.sh; echo "exit=$?"`
Expected: no output, `exit=0` (this session has no
`VRG_IDENTITY_MODE`, so the guard is a no-op — confirming USER/human
sessions cannot be disrupted).

- [ ] **Step 3: Full validation**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

- [ ] **Step 4: Write the PR template (done signal)**

Write `.vergil/pr-template.yml.tmp` with exactly:

```yaml
issue: 442
title: "feat(hooks): add AUDIT identity write-guard"
summary: New PreToolUse hook denying the audit identity any Write/Edit/NotebookEdit outside .vergil/audit-* and build/, with 14 table-driven tests; registered for Write|Edit|NotebookEdit and documented with the soft-gate framing.
notes: Implements spec sections 2 and 3.3 of docs/specs/2026-06-05-hooks-2.1-reconciliation-design.md (pushback-reviewed). Fail-closed inside the audit identity, fail-open outside. Bash-write coverage deliberately deferred.
```

Then: `mv .vergil/pr-template.yml.tmp .vergil/pr-template.yml`

- [ ] **Step 5: Hand off**

Tell the human: branch ready — run `vrg-submit-pr` from
`.worktrees/issue-442-audit-write-guard/`.
