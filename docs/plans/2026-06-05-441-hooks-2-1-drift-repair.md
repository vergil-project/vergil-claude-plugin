# Hooks/2.1 Drift Repair (#441) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every hook and doc in this plugin tell the truth about
the vergil 2.1 workflow — retire the obsolete `remind-finalize` hook,
simplify `block-agent-merge` to an unconditional deny, fix two hook
messages, update the host-tool list, and add five `.gitignore`
entries.

**Architecture:** Pure drift repair per the approved spec
(`docs/specs/2026-06-05-hooks-2.1-reconciliation-design.md`, §3.2 and
§4). No new capability (#442 is separate). Each task pairs a hook
change with its documentation so every commit is self-coherent.

**Tech Stack:** bash 3.2-compatible hook scripts (no associative
arrays, no `realpath`), `jq` for hook JSON output, Markdown docs.

---

## Execution context (read first)

- **Worktree:** all work happens in
  `.worktrees/issue-441-hooks-2-1-drift/` on branch
  `bugfix/441-hooks-2-1-drift`. Use absolute paths for Read/Edit
  tools; `cd` into the worktree for Bash.
- **Git:** raw `git`/`gh` are denied. Use `vrg-git` / `vrg-gh`.
  Commits ONLY via `vrg-commit --type <t> --scope <s> --message <m>`
  (stage with `vrg-git add` first).
- **Validation:** `vrg-container-run -- vrg-validate` is the ONLY
  validation command. Run it from inside the worktree before every
  commit. Expected tail: `vrg-validate: all checks passed`.
- **Hook smoke tests:** hooks read a JSON payload on stdin and are
  gated on `is_managed_repo` (vergil.toml present at `cwd`). Run them
  from the worktree root so `"cwd": "."` resolves as managed. A deny
  prints a JSON object with `permissionDecision: "deny"`; a pass
  prints nothing and exits 0.
- **No heredocs** in CLI arguments. Multi-line content goes in a temp
  file.

---

### Task 1: Retire `remind-finalize`

The hook fires after `vrg-submit-pr` in an agent session — which no
longer happens (the human submits) — and instructs the agent to run
the nonexistent `vrg-finalize-repo`.

**Files:**
- Delete: `hooks/scripts/remind-finalize.sh`
- Modify: `hooks/hooks.json` (remove the PostToolUse entry)
- Modify: `docs/site/docs/hooks/index.md` (delete the
  `### remind-finalize` section; rewrite the stop-hook rationale that
  references it)
- Modify: `README.md` (delete the `remind-finalize` table row; fix
  the prerequisite tool list)

- [ ] **Step 1: Delete the script**

Run: `vrg-git rm hooks/scripts/remind-finalize.sh`
Expected: `rm 'hooks/scripts/remind-finalize.sh'`

- [ ] **Step 2: Remove the hooks.json entry**

In `hooks/hooks.json`, the PostToolUse Bash matcher currently lists
two hooks. Replace:

```json
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/remind-finalize.sh",
            "statusMessage": "Checking for PR submission..."
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/detect-deprecation-warnings.sh",
            "statusMessage": "Checking for deprecation warnings..."
          }
        ]
      }
```

with:

```json
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/detect-deprecation-warnings.sh",
            "statusMessage": "Checking for deprecation warnings..."
          }
        ]
      }
```

- [ ] **Step 3: Verify hooks.json is valid JSON and the script is gone**

Run: `jq -e '.hooks.PostToolUse[0].hooks | length == 1' hooks/hooks.json && ls hooks/scripts/remind-finalize.sh`
Expected: `true`, then `ls: cannot access 'hooks/scripts/remind-finalize.sh': No such file or directory`

- [ ] **Step 4: Delete the doc section**

In `docs/site/docs/hooks/index.md`, delete this entire section (under
`## PostToolUse Hooks — Bash`):

```markdown
### remind-finalize

**What.** After a successful `vrg-submit-pr` run, injects a reminder
to run `vrg-finalize-repo` once the PR merges.

**Why.** Finalization is easy to forget — the PR is created and
attention moves elsewhere. `vrg-finalize-repo` pulls the merged
change into local develop, deletes the merged feature branch, and
prunes remote refs. Without it, local state diverges from remote
and future PRs get confused.

**Alternative.** Do run `vrg-finalize-repo` once the PR merges.
There's no intent this hook blocks — it's a reminder, not a denial.
```

- [ ] **Step 5: Rewrite the stop-hook rationale that referenced it**

In the same file, the `### Stop hook for finalization` section ends
with two paragraphs that describe the pre-2.1 flow. Replace:

```markdown
**Why removed.** Under the current "humans review and merge
feature/bugfix PRs" posture, the agent submits a PR, waits for
CI green, hands off to the user, and **stops** — that's the
correct end of the work cycle. Finalization happens in a later
session, after the user reports the merge. The hook would have
fired on every correct exit, blocking the desired behavior.

**What replaces it.** The user-prompted finalize flow — the human
reports the merge, then the agent runs `vrg-finalize-repo`. The
[`remind-finalize`](#remind-finalize) PostToolUse hook still
emits a reminder after `vrg-submit-pr` so the agent knows to run
`vrg-finalize-repo` once the merge is reported.
```

with:

```markdown
**Why removed.** Under the 2.1 workflow the agent's work cycle ends
at the PR template: it writes `.vergil/pr-template.yml` and stops —
the **human** runs `vrg-submit-pr`, merges, and finalizes
(`vrg-finalize-pr`). A session-end gate keyed to agent-side
finalization has no correct trigger left.

**What replaces it.** Nothing needs to: submission, merge, and
finalization are all human actions now. The retired
`remind-finalize` PostToolUse hook (removed in #441) is gone for
the same reason — its trigger, `vrg-submit-pr` in an agent
session, no longer occurs.
```

- [ ] **Step 6: Fix the README**

In `README.md`, delete this table row:

```markdown
| `remind-finalize` | PostToolUse/Bash | After `vrg-submit-pr`, reminds to run `vrg-finalize-repo` |
```

And in the prerequisite paragraph, replace:

```markdown
`vrg-commit`, `vrg-submit-pr`, `vrg-finalize-repo`, and friends from
```

with:

```markdown
`vrg-commit`, `vrg-submit-pr`, `vrg-await`, and friends from
```

- [ ] **Step 7: Validate**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

- [ ] **Step 8: Commit**

```bash
vrg-git add -A hooks/ docs/site/docs/hooks/index.md README.md
vrg-commit --type refactor --scope hooks \
  --message "retire remind-finalize hook" \
  --body "Its trigger (vrg-submit-pr in an agent session) no longer occurs under the 2.1 workflow -- the human submits, and vrg-submit-pr emits the next one-liner itself. The hook also instructed agents to run vrg-finalize-repo, which no longer exists. Spec: docs/specs/2026-06-05-hooks-2.1-reconciliation-design.md section 3.2. Ref #441."
```

---

### Task 2: `block-agent-merge` — unconditional deny

Agents have no merge path under 2.1 (credential-enforced), so the
release-branch allow-list — and its delegation to the never-shipped
`vrg-check-pr-merge`, which today fail-closes on exit 127 with a
confusing "tool failed" message — goes away.

**Files:**
- Modify: `hooks/scripts/block-agent-merge.sh`
- Modify: `docs/site/docs/hooks/index.md` (`### block-agent-merge`)
- Modify: `README.md` (`block-agent-merge` table row)

- [ ] **Step 1: Replace the script body**

Replace the entire contents of `hooks/scripts/block-agent-merge.sh`
with:

```bash
#!/usr/bin/env bash
# block-agent-merge.sh — PreToolUse hook for Bash.
# Unconditionally denies gh pr merge / gh pr review --approve and the
# equivalent gh api calls. Under the 2.1 workflow agents have no merge
# path at all (credential-enforced); merging is the human's Phase-6
# action via vrg-finalize-pr. This hook is the ergonomic fast-fail on
# top of that hard credential gate.
# Note: vrg-gh also rejects pr merge for non-escalated contexts.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# vergil.toml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

if ! is_managed_repo "$cwd"; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

is_merge_command=false

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

if [ "$is_merge_command" = false ]; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Agents never merge or approve PRs. Merging is a human action (Phase 6 of the 2.1 workflow, via vrg-finalize-pr) -- hand the PR URL to the human. This applies to all identities and all branches, release PRs included. See issue #441."
  }
}'
```

- [ ] **Step 2: Smoke-test the deny**

Run: `echo '{"tool_input":{"command":"gh pr merge 123","cwd":"."},"cwd":"."}' | bash hooks/scripts/block-agent-merge.sh`
Expected: JSON output containing `"permissionDecision": "deny"` and
the new reason text. Exit code 0.

- [ ] **Step 3: Smoke-test the pass-through**

Run: `echo '{"tool_input":{"command":"gh pr view 123","cwd":"."},"cwd":"."}' | bash hooks/scripts/block-agent-merge.sh; echo "exit=$?"`
Expected: no JSON output, `exit=0`.

- [ ] **Step 4: Rewrite the doc section**

In `docs/site/docs/hooks/index.md`, replace the entire
`### block-agent-merge` section with:

```markdown
### block-agent-merge

**What.** Denies Bash tool invocations that call `gh pr merge`,
`gh pr review --approve`, or the equivalent `gh api` calls —
unconditionally.

**Why.** Under the 2.1 workflow agents have no merge path at all:
the per-VM GitHub App credentials cannot merge, and merging is the
human's Phase-6 action (`vrg-finalize-pr`). Skill prose saying "do
not merge" is advisory; agents rationalize past it. This hook makes
the rule mechanical — an ergonomic fast-fail on top of the hard
credential gate. The deny applies to **all identities** and all
branches, release PRs included; the pre-2.1 release-branch
allow-list (delegated to a `vrg-check-pr-merge` tool that was never
shipped) was removed in [#441](https://github.com/vergil-project/vergil-claude-plugin/issues/441).
See [#162](https://github.com/vergil-project/vergil-claude-plugin/issues/162)
for the original motivating incident.

**Alternative.** Hand the PR URL to the human, who merges and
finalizes via `vrg-finalize-pr`.
```

- [ ] **Step 5: Add the missing README row**

The README hook table has **no row** for `block-agent-merge` (verified
2026-06-05). In `README.md`, insert directly after the
`block-autoclose-linkage` row:

```markdown
| `block-agent-merge` | PreToolUse/Bash | Unconditionally blocks `gh pr merge` / `gh pr review --approve` — merging is the human's Phase-6 action |
```

- [ ] **Step 6: Validate**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

- [ ] **Step 7: Commit**

```bash
vrg-git add hooks/scripts/block-agent-merge.sh docs/site/docs/hooks/index.md README.md
vrg-commit --type fix --scope hooks \
  --message "simplify block-agent-merge to unconditional deny" \
  --body "Removes the delegation to vrg-check-pr-merge, which was never shipped -- the hook fail-closed on exit 127 with a confusing tool-failed message -- and the release-branch allow-list, since agents have no merge path under 2.1 (credential-enforced), release PRs included. The deny applies to all identities. Spec section 3.2. Ref #441."
```

---

### Task 3: `block-autoclose-linkage` — fix the deny message and docs

Policy unchanged (Ref-only linkage); only the rationale text changes —
the old message justified the rule via the dead `vrg-finalize-repo`.

**Files:**
- Modify: `hooks/scripts/block-autoclose-linkage.sh` (one string)
- Modify: `docs/site/docs/hooks/index.md`
  (`### block-autoclose-linkage`)

- [ ] **Step 1: Replace the deny reason**

In `hooks/scripts/block-autoclose-linkage.sh`, replace:

```text
        permissionDecisionReason: "Auto-close linkage keywords (Fixes, Closes, Resolves) are forbidden. Use --linkage Ref instead. Issues are closed explicitly after vrg-finalize-repo confirms the work cycle is complete. See issue #126."
```

with:

```text
        permissionDecisionReason: "Auto-close linkage keywords (Fixes, Closes, Resolves) are forbidden. Use --linkage Ref instead. Issues are closed explicitly by the human after PR finalization -- never by merge keywords. See issue #126."
```

- [ ] **Step 2: Smoke-test the deny**

Run: `echo '{"tool_input":{"command":"vrg-submit-pr --linkage Fixes","cwd":"."},"cwd":"."}' | bash hooks/scripts/block-autoclose-linkage.sh`
Expected: deny JSON containing `closed explicitly by the human`.

- [ ] **Step 3: Smoke-test the pass-through**

Run: `echo '{"tool_input":{"command":"vrg-submit-pr --linkage Ref","cwd":"."},"cwd":"."}' | bash hooks/scripts/block-autoclose-linkage.sh; echo "exit=$?"`
Expected: no JSON output, `exit=0`.

- [ ] **Step 4: Fix the doc section**

In `docs/site/docs/hooks/index.md`, in the
`### block-autoclose-linkage` section, replace the **Why** and
**Alternative** paragraphs:

```markdown
**Why.** These keywords auto-close the linked issue when the PR
merges. Our workflow has a mandatory post-merge finalization phase
(`vrg-finalize-repo`) that reconciles local state — an issue closed
at merge time signals "done" while the local environment is stale.
Using `Ref` linkage keeps the issue open until finalization
confirms the work cycle is complete, at which point the agent
closes the issue explicitly.

**Alternative.** Use `--linkage Ref` (or omit `--linkage` — `Ref`
is the intended default once `vrg-submit-pr` is updated in
`vergil-tooling`). After `vrg-finalize-repo` succeeds, close the
issue with `gh issue close <N>` — the human-prompted finalize
flow, run after the merge is reported.
```

with:

```markdown
**Why.** These keywords auto-close the linked issue when the PR
merges. Under the 2.1 workflow issues are closed **explicitly by
the human after PR finalization** (`vrg-finalize-pr`) — an issue
closed automatically at merge time signals "done" before the human
has confirmed the work cycle is complete. Closing is deliberately
manual today; agents have closed issues incorrectly, so no
automation owns it (a future close-analysis agent may).

**Alternative.** Use `--linkage Ref`. Issue closing is the human's
post-finalization action — not the agent's.
```

- [ ] **Step 5: Validate and commit**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add hooks/scripts/block-autoclose-linkage.sh docs/site/docs/hooks/index.md
vrg-commit --type fix --scope hooks \
  --message "reword autoclose-linkage rationale for the 2.1 workflow" \
  --body "The deny message justified Ref-only linkage via vrg-finalize-repo, which no longer exists. New rationale: issues are closed explicitly by the human after PR finalization, never by merge keywords. Policy unchanged. Spec section 3.2. Ref #441."
```

---

### Task 4: `block-github-contents-api` — fix the deny message

The message told the agent to "submit with vrg-submit-pr" — under 2.1
the agent never submits; it writes the PR template and the human
submits.

**Files:**
- Modify: `hooks/scripts/block-github-contents-api.sh` (header comment
  + one string)

- [ ] **Step 1: Update the header comment**

Replace:

```text
# Blocks gh api calls that write to the GitHub Contents API. File changes
# must go through the local workflow (worktree → vrg-commit → vrg-submit-pr),
# not bypass it via direct API writes to remote branches.
```

with:

```text
# Blocks gh api calls that write to the GitHub Contents API. File changes
# must go through the local workflow (worktree → vrg-commit →
# .vergil/pr-template.yml → the human runs vrg-submit-pr), not bypass it
# via direct API writes to remote branches.
```

- [ ] **Step 2: Update the deny reason**

Replace:

```text
      permissionDecisionReason: "Direct writes to the GitHub Contents API are blocked. File changes must go through the local workflow: edit files in your worktree, commit with vrg-commit, and submit with vrg-submit-pr. Note: vrg-gh denies gh api entirely.\n\nSee docs/specs/worktree-convention.md in vergil-tooling for the full convention."
```

with:

```text
      permissionDecisionReason: "Direct writes to the GitHub Contents API are blocked. File changes go through the local workflow: edit files in your worktree, commit with vrg-commit, and write .vergil/pr-template.yml -- the human submits the PR with vrg-submit-pr. Note: vrg-gh denies gh api entirely.\n\nSee docs/specs/worktree-convention.md in vergil-tooling for the full convention."
```

- [ ] **Step 3: Smoke-test the deny**

Run: `echo '{"tool_input":{"command":"gh api --method PUT repos/o/r/contents/f.md","cwd":"."},"cwd":"."}' | bash hooks/scripts/block-github-contents-api.sh`
Expected: deny JSON containing `the human submits the PR`.

- [ ] **Step 4: Smoke-test the pass-through (GET is allowed)**

Run: `echo '{"tool_input":{"command":"gh api repos/o/r/contents/f.md","cwd":"."},"cwd":"."}' | bash hooks/scripts/block-github-contents-api.sh; echo "exit=$?"`
Expected: no JSON output, `exit=0`.

- [ ] **Step 5: Add the missing doc section**

`docs/site/docs/hooks/index.md` has **no section** for this hook
(verified 2026-06-05 — undocumented drift of its own). Insert directly
after the `### block-agent-merge` section:

```markdown
### block-github-contents-api

**What.** Denies `gh api` calls that write (PUT/POST/DELETE) to the
GitHub Contents API. Reads (GET) are allowed.

**Why.** Writing files via the API bypasses the local workflow
entirely — no validation, no commit standards, no PR template. File
changes go through the worktree: edit, `vrg-commit`, write
`.vergil/pr-template.yml`; the human submits with `vrg-submit-pr`.
(`vrg-gh` denies `gh api` outright; this hook catches raw `gh`.)

**Alternative.** Make the change in your worktree and follow the
local workflow.
```

- [ ] **Step 6: Add the missing README row**

In `README.md`, insert directly after the `block-agent-merge` row
added in Task 2:

```markdown
| `block-github-contents-api` | PreToolUse/Bash | Blocks write-method `gh api` calls to the Contents API — file changes go through the local workflow |
```

- [ ] **Step 7: Validate and commit**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add hooks/scripts/block-github-contents-api.sh docs/site/docs/hooks/index.md README.md
vrg-commit --type fix --scope hooks \
  --message "contents-api deny message: template handoff, human submits" \
  --body "The deny message told the agent to submit with vrg-submit-pr; under 2.1 the agent's workflow ends at .vergil/pr-template.yml and the human submits. Also adds the missing hooks-reference section and README row for this hook -- it was entirely undocumented. Spec section 3.2. Ref #441."
```

---

### Task 5: `host-container-tools.sh` — drop dead entry, add 2.1 tools

**Files:**
- Modify: `hooks/scripts/lib/host-container-tools.sh`

- [ ] **Step 1: Update HOST_TOOLS**

Replace:

```bash
HOST_TOOLS=(
  vrg-commit
  vrg-submit-pr
  vrg-finalize-repo
  vrg-wait-until-green
  vrg-container-run
  vrg-ensure-label
  gh
  git
  git-cliff
)
```

with:

```bash
HOST_TOOLS=(
  vrg-await
  vrg-commit
  vrg-ensure-label
  vrg-finalize-pr
  vrg-pr-await
  vrg-submit-pr
  vrg-wait-until-green
  vrg-container-run
  gh
  git
  git-cliff
)
```

(`vrg-finalize-repo` is dead; `vrg-finalize-pr` is its 2.1 successor —
a human tool, but container-wrapping it is still wrong and the deny
doubles as a signal. `vrg-await` and `vrg-pr-await` are the new 2.1
blocking-wait primitives, host-side.)

- [ ] **Step 2: Smoke-test the wrapped-host-tool deny**

Run: `echo '{"tool_input":{"command":"vrg-container-run -- vrg-await .vergil/audit-feedback.yml","cwd":"."},"cwd":"."}' | bash hooks/scripts/enforce-host-container-split.sh`
Expected: deny JSON containing `vrg-await is a host command`.

- [ ] **Step 3: Smoke-test the bare host tool passes**

Run: `echo '{"tool_input":{"command":"vrg-await .vergil/audit-feedback.yml","cwd":"."},"cwd":"."}' | bash hooks/scripts/enforce-host-container-split.sh; echo "exit=$?"`
Expected: no JSON output, `exit=0`.

- [ ] **Step 4: Validate and commit**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add hooks/scripts/lib/host-container-tools.sh
vrg-commit --type fix --scope hooks \
  --message "host tool list: drop vrg-finalize-repo, add 2.1 tools" \
  --body "vrg-finalize-repo no longer exists; vrg-finalize-pr replaces it (human tool, but container-wrapping it is still wrong). Adds the 2.1 blocking-wait primitives vrg-await and vrg-pr-await as host-side tools. Spec section 3.2. Ref #441."
```

---

### Task 6: `.gitignore` — five entries

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Append the entries**

Append to `.gitignore` (after the existing
`# Parallel AI agent worktrees` block):

```text

# Vergil agent workspace (2.1 spec §6; reconciliation spec §3.2)
.vergil/
build/
.superpowers/

# Generated docs (mkdocs default output)
docs/site/site/

# Personal Claude Code state
.claude/settings.local.json
```

- [ ] **Step 2: Verify the ignore rules bite**

Run: `mkdir -p .vergil build && touch .vergil/x build/x && vrg-git status --short --untracked-files=all -- .vergil build; echo "exit=$?"; rm -rf .vergil build`
Expected: no output lines for `.vergil/x` or `build/x`, `exit=0`.

- [ ] **Step 3: Validate and commit**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add .gitignore
vrg-commit --type chore --scope config \
  --message "gitignore agent workspace, build output, local settings" \
  --body "Adds .vergil/ (gap flagged by the 2.1 spec section 6), build/ (AUDIT scratch space per the write-guard design, must never sweep into a USER commit), .superpowers/ (fleet-consistent), docs/site/site/ (mkdocs default output), and .claude/settings.local.json (personal Claude Code state). From the 2026-06-05 pushback sweep; the repo_init baseline drift is tracked as vergil-tooling#1425. Ref #441."
```

---

### Task 7: remaining doc updates

**Files:**
- Modify: `docs/development/starting-work-on-an-issue.md` (teardown
  note)
- Modify: `docs/development/skills-architecture.md` (supersession
  pointers)

- [ ] **Step 1: Fix the teardown note**

In `docs/development/starting-work-on-an-issue.md`, replace:

```markdown
- Worktree teardown after merge. That is `vrg-finalize-repo`'s job,
  run in the human-prompted finalize flow after the merge is reported.
```

with:

```markdown
- Worktree teardown after merge. That is the human's
  `vrg-finalize-pr` step — merge finalization and local cleanup are
  human actions under the 2.1 workflow.
```

- [ ] **Step 2: Add the supersession pointer to Lifecycle B**

In `docs/development/skills-architecture.md`, immediately after the
Lifecycle B table (the row ending
`| B4. Finalize | ... | → exit work cycle |`), insert:

```markdown

> **Superseded (B2–B4).** The 2.1 workflow spec
> (`docs/specs/2026-06-04-vergil-2.1-workflow-and-skill-rationalization-design.md`)
> is the living truth for develop/submit/finalize: the agent stops at
> `.vergil/pr-template.yml`, the human runs `vrg-submit-pr`, and
> finalization is the human's `vrg-finalize-pr` (`vrg-finalize-repo`
> no longer exists). This table is retained as the audit-time record.
```

- [ ] **Step 3: Add the supersession pointer to Lifecycle C**

In the same file, immediately after the Lifecycle C table, insert:

```markdown

> **Superseded (C1–C6).** Releases are cut via `vrg-publish`
> (vergil-tooling); `vrg-prepare-release` and `vrg-merge-when-green`
> no longer exist. This table is retained as the audit-time record.
```

- [ ] **Step 4: Document the live Write|Edit hook**

`docs/site/docs/hooks/index.md` line ~215 claims:

```markdown
## PreToolUse Hooks — Write|Edit

No hooks currently active in this category.
```

but `block-worktree-bypass-write` is live in `hooks.json` (verified
2026-06-05). Replace those two lines with:

```markdown
## PreToolUse Hooks — Write|Edit

### block-worktree-bypass-write

**What.** Blocks Write/Edit file modifications targeting the main
worktree when the parallel-AI-agent worktree convention is active.

**Why.** The main worktree is read-only by convention — all edits
flow through a `.worktrees/<name>/` worktree on a feature branch.
Symlinks into the main worktree are resolved best-effort and caught.
Design: `docs/specs/2026-05-09-worktree-write-guard-design.md`.

**Alternative.** Write to your assigned worktree's absolute path.
```

- [ ] **Step 5: Add the missing README row for it**

In `README.md`, insert directly after the `block-github-contents-api`
row added in Task 4:

```markdown
| `block-worktree-bypass-write` | PreToolUse/Write\|Edit | Blocks edits to the main worktree when the worktree convention is active |
```

- [ ] **Step 6: Validate and commit**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

```bash
vrg-git add docs/development/starting-work-on-an-issue.md docs/development/skills-architecture.md docs/site/docs/hooks/index.md README.md
vrg-commit --type docs --scope workflow \
  --message "repoint teardown to vrg-finalize-pr; document live hooks; mark lifecycles superseded" \
  --body "starting-work-on-an-issue.md teardown note now names the human's vrg-finalize-pr step. skills-architecture.md lifecycle B and C tables get supersession pointers to the 2.1 workflow spec rather than rewrites -- the document is an audit-time record. Also corrects the hooks reference claim that no Write|Edit hooks are active (block-worktree-bypass-write is live) and adds its missing README row. Spec section 4. Ref #441."
```

---

### Task 8: final sweep, full validation, done-signal

- [ ] **Step 1: Sweep for dead references in live surfaces**

Run: `grep -rn "vrg-finalize-repo\|vrg-check-pr-merge\|remind-finalize" hooks/ README.md docs/site/ docs/development/starting-work-on-an-issue.md`
Expected: **no output**. (Hits in `CHANGELOG.md`, `releases/`,
`docs/plans/`, `docs/specs/`, `paad/`, and the historical commentary
of `skills-architecture.md` are out of scope — historical records.)

If anything live appears, fix it with the same pattern as Tasks 1–7
and amend the relevant area before continuing.

- [ ] **Step 2: Full validation**

Run: `vrg-container-run -- vrg-validate`
Expected: `vrg-validate: all checks passed`

- [ ] **Step 3: Write the PR template (done signal)**

Write `.vergil/pr-template.yml.tmp` with exactly:

```yaml
issue: 441
title: "fix(hooks): reconcile hooks and docs with the 2.1 workflow"
summary: Retire remind-finalize, make block-agent-merge an unconditional deny (dropping the never-shipped vrg-check-pr-merge), fix autoclose-linkage and contents-api messages, refresh the host tool list, add five .gitignore entries, and update the trailing docs.
notes: Drift repair per docs/specs/2026-06-05-hooks-2.1-reconciliation-design.md. Companion tooling issues vergil-tooling#1423-#1427. The write-guard (#442) is a separate follow-up.
```

Then: `mv .vergil/pr-template.yml.tmp .vergil/pr-template.yml`

- [ ] **Step 4: Hand off**

Tell the human: the branch is ready — run `vrg-submit-pr` from
`.worktrees/issue-441-hooks-2-1-drift/`.
