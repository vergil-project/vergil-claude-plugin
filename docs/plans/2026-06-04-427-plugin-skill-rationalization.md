# Plugin Skill Rationalization (#427) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the obsolete `pr-workflow` and `dependency-update` skills with
three new identity-aware skills (`implement`, `audit`, `pr-watch`) that drive the
Vergil 2.1 agent/human workflow, and reconcile the rest of the collection.

**Architecture:** Skills are single `skills/<name>/SKILL.md` markdown files
(frontmatter `name` + `description`, then instructions), auto-discovered and
invoked as `/vergil:<name>`. The new skills wrap the already-shipped
`vergil-tooling` 2.1 CLIs and communicate through `.vergil/` files. Retirements
follow the v2.0.8 (`#356`) precedent: delete the `SKILL.md`, update *active*
cross-references, and leave historical docs (CHANGELOG, `releases/`, old
`specs/`, `plans/`, `paad/`) intact.

**Tech Stack:** Markdown skills; `vergil-tooling` 2.1 CLIs (`vrg-await`,
`vrg-pr-await`, `vrg-submit-pr`, `vrg-audit-approve`, `vrg-commit`,
`vrg-validate`, `vrg-git`, `vrg-gh`); validation via
`vrg-container-run -- vrg-validate`.

**Note on verification:** these are documentation artifacts, not code — there is
no unit-test harness for skills. Per-task verification is (1)
`vrg-container-run -- vrg-validate` (markdownlint/yamllint/actionlint) passing,
(2) an explicit acceptance checklist, and (3) for retirements, a `grep` proving
no *active* references remain. All git ops use `vrg-git` / `vrg-commit` from
inside the worktree `.worktrees/issue-427-skill-rationalization`.

**Confirmed tool contracts (read from `vergil-tooling` source):**

- `vrg-await <path> [--since <sha256>]` — block until the file appears, or (with
  `--since`) until its SHA-256 differs; prints the current digest.
- `vrg-pr-await <pr> [--since-sha <sha>] [--since-reviews <n>]` — block until the
  PR settles (checks terminal, or new commit/review); prints PR state as JSON.
- `vrg-submit-pr` — **human-only** (blocks agents); template mode reads
  `.vergil/pr-template.yml`, opens the PR, deletes the template, and prints
  `    /vergil:pr-watch <pr_url>`.
- `vrg-audit-approve <pr> [--conclusion success|failure|neutral] [--summary <s>]`
  — posts the `vergil-audit/approved` check-run; **refuses to run as USER**.
- `.vergil/pr-template.yml` fields: `issue`, `title`, `summary` (required),
  `linkage` (default `Ref`), `notes`. Minimal YAML subset.
- `.vergil/audit-feedback.yml` — **not implemented in tooling; this plan defines
  it** (Task 0).

---

## Task 0: Define the `audit-feedback.yml` channel format

**Files:**

- Create: `docs/specs/figures/2026-06-04-vergil-2.1-workflow/audit-feedback-format.md`
  (a short reference both new skills link to)

This is documentation-only — it pins the contract the `audit` and `implement`
skills share. ERROR is signalled by **absence** of the file (the audit withholds
it and alerts the human), so the file only ever holds `approve` or `changes`.

- [ ] **Step 1: Write the format reference**

````markdown
# `.vergil/audit-feedback.yml` format

Written by the `audit` skill, read by the `implement` skill. Minimal YAML
subset (flat keys, `key: |` blocks), atomic temp+rename write. Sibling of
`pr-template.yml`; never folded into it.

```yaml
verdict: approve            # approve | changes  (ERROR = file withheld, human alerted)
commits:                    # SHAs reviewed this round (the audit trail on approve)
  - <full-sha>
findings:                   # present only when verdict: changes
  - severity: warning       # warning (fix & re-update) | info
    file: path/to/file.py
    line: 42
    note: |
      Removable `# type: ignore` — add the real return type instead of
      suppressing MyPy.
```

- `verdict: approve` → all listed `commits` are signed off; the loop ends.
- `verdict: changes` → the USER agent fixes every `findings` entry, re-validates,
  rewrites `pr-template.yml`, and the audit re-reviews.
- **ERROR (new unapproved suppression, or unfixable needing human):** the audit
  does **not** write this file. It alerts the human and stops; the USER agent
  stays parked on its `vrg-await`.
````

- [ ] **Step 2: Validate**

Run: `cd .worktrees/issue-427-skill-rationalization && vrg-container-run -- vrg-validate`
Expected: `all checks passed`.

- [ ] **Step 3: Commit**

```bash
vrg-git add docs/specs/figures/2026-06-04-vergil-2.1-workflow/audit-feedback-format.md
vrg-commit --type docs --scope specs --message "define .vergil/audit-feedback.yml channel format"
```

---

## Task 1: Create the `implement` skill (USER, local loop)

**Files:**

- Create: `skills/implement/SKILL.md`

- [ ] **Step 1: Write `skills/implement/SKILL.md`**

````markdown
---
name: implement
description: USER-identity skill — implement a GitHub issue on a feature branch, validate until green, then hand off to the local audit pair via the .vergil PR template. Run as the vergil-user agent.
---

# Implement

Drive the USER half of the Vergil 2.1 implement+audit pair (design spec
`docs/specs/2026-06-04-vergil-2.1-workflow-and-skill-rationalization-design.md`,
§5). Input: a GitHub issue (number or URL).

## Preflight

1. Confirm identity: `vrg-await`, `vrg-commit`, etc. assume the **USER**
   identity. If `VRG_IDENTITY_MODE` is `audit` or `human`, stop and tell the
   user this skill runs in the user-agent session.
2. Confirm you are in a feature-branch worktree for this issue (see
   `docs/development/starting-work-on-an-issue.md`). Do not work at the repo root.

## Loop

1. **Implement** the issue on the branch, following repo standards. Make small,
   focused commits with `vrg-commit`.
2. **Validate until green:** `vrg-container-run -- vrg-validate`. Fix every
   failure and re-run until it passes. Never suppress a gate to make it pass —
   the audit will reject that.
3. **Write the PR template = the "done" signal.** Write
   `.vergil/pr-template.yml` atomically (write `.vergil/pr-template.yml.tmp`,
   then `mv` it into place) with:

   ```yaml
   issue: <N>
   title: <conventional PR title>
   summary: <one line>
   notes: <optional>
   ```

   Its appearance tells the paired audit agent you are done. (`vrg-submit-pr`
   later consumes and deletes this same file.)
4. **Await the audit verdict.** Record the feedback file's digest if it exists,
   then block:

   ```bash
   vrg-await .vergil/audit-feedback.yml            # first round (or --since <digest>)
   ```

   `vrg-await` prints the new digest — thread it as `--since` on the next round.
5. **Act on the verdict** (`.vergil/audit-feedback.yml`, format:
   `docs/specs/figures/2026-06-04-vergil-2.1-workflow/audit-feedback-format.md`):
   - `verdict: approve` → tell the human: *"Approved — run `vrg-submit-pr` to
     open the PR."* Stop. (Only the human opens the PR.)
   - `verdict: changes` → fix every `findings` entry, re-validate (step 2),
     `vrg-commit`, **rewrite** `.vergil/pr-template.yml` (atomic), then return to
     step 4 with `--since`.
   - **File never appears** (audit withheld it) → the audit has escalated an
     ERROR to the human. Surface this to the human and wait; do not loop.

## Notes

- **Resumability** is not yet built in (design §13). If this session is lost
  mid-loop, re-invoking `/vergil:implement <issue>` is the intended recovery;
  meanwhile `/handoff` is the safety net for unsaved in-flight state.
- This skill never opens the PR and never posts checks — those are the human's
  and the audit's jobs respectively.
````

- [ ] **Step 2: Validate**

Run: `vrg-container-run -- vrg-validate`
Expected: `all checks passed`.

- [ ] **Step 3: Acceptance checklist**

- Frontmatter has `name: implement` and a one-line `description`.
- Body covers: identity preflight, validate-until-green, atomic template write,
  `vrg-await` with `--since` threading, the three verdict branches.
- Calls only real tools (`vrg-commit`, `vrg-container-run`, `vrg-await`); never
  calls `vrg-submit-pr` or `vrg-audit-approve`.

- [ ] **Step 4: Commit**

```bash
vrg-git add skills/implement/SKILL.md
vrg-commit --type feat --scope skills --message "add implement skill (USER local loop)"
```

---

## Task 2: Create the `audit` skill (AUDIT, local loop)

**Files:**

- Create: `skills/audit/SKILL.md`

- [ ] **Step 1: Write `skills/audit/SKILL.md`**

````markdown
---
name: audit
description: AUDIT-identity skill — review the delta of a paired USER agent's branch read-only, and write the .vergil audit verdict. Never edits code. Run as the vergil-audit agent.
---

# Audit

Drive the AUDIT half of the implement+audit pair (design spec §5, §7). Input: the
same issue handed to the USER agent. You share the USER agent's worktree on the
host mount.

## Preflight

1. Confirm identity: this runs in the **AUDIT** session. If `VRG_IDENTITY_MODE`
   is `user` or `human`, stop.
2. **You are read-only by discipline.** You have write access to the worktree but
   MUST touch nothing except `.vergil/audit-feedback.yml`. Never edit code,
   never commit, never push.

## Loop

1. **Await the done-signal:**

   ```bash
   vrg-await .vergil/pr-template.yml               # first round (or --since <digest>)
   ```

   Thread the printed digest as `--since` on later rounds.
2. **Compute the delta:** the commits on this branch not in its base
   (`vrg-git log --oneline origin/develop..HEAD` and
   `vrg-git diff origin/develop...HEAD`). Review **only** these changes.
3. **Review** (start simple — design §7.1):
   - Coding-standards compliance — docstrings on *production* code (tests
     exempt), naming, structure.
   - **Suppression scrutiny** — flag net-new `# type: ignore`, `# noqa`,
     `# nosec`, or broad `pyproject.toml` ignores. If removable without hurting
     integrity, require the real fix.
4. **Write the verdict** to `.vergil/audit-feedback.yml` atomically (tmp +
   `mv`), per
   `docs/specs/figures/2026-06-04-vergil-2.1-workflow/audit-feedback-format.md`:
   - Clean → `verdict: approve` with the reviewed `commits`.
   - Fixable issues → `verdict: changes` with one `findings` entry each.
   - **ERROR** — a *newly introduced* suppression (requires human sign-off) or
     anything you judge can't be auto-fixed: **do NOT write the file.** Print a
     clear alert to the human describing the issue, and stop. The USER agent
     stays parked.
5. If you wrote `changes`, loop to step 1 (`--since`) to re-review the USER
   agent's next commit. End when you write `approve` (or escalate an ERROR).
````

- [ ] **Step 2: Validate**

Run: `vrg-container-run -- vrg-validate`
Expected: `all checks passed`.

- [ ] **Step 3: Acceptance checklist**

- Frontmatter `name: audit` + description.
- States read-only-by-discipline and "only writes audit-feedback.yml".
- Covers: identity preflight, `vrg-await` template with `--since`, delta-only
  review, the three verdict outcomes (approve / changes / withhold-on-ERROR).
- Never calls `vrg-audit-approve` (that's post-PR, Task 3) and never edits code.

- [ ] **Step 4: Commit**

```bash
vrg-git add skills/audit/SKILL.md
vrg-commit --type feat --scope skills --message "add audit skill (AUDIT local loop)"
```

---

## Task 3: Create the `pr-watch` skill (identity-keyed, post-PR)

**Files:**

- Create: `skills/pr-watch/SKILL.md`

- [ ] **Step 1: Write `skills/pr-watch/SKILL.md`**

````markdown
---
name: pr-watch
description: Identity-keyed post-PR skill emitted by vrg-submit-pr. As USER, monitor the PR and reconcile CI/audit/human feedback; as AUDIT, re-review and post the vergil-audit/approved check. Paste the same line into both agent sessions.
---

# PR watch

Drive the post-PR loop (design spec §9). `vrg-submit-pr` prints
`/vergil:pr-watch <PR_URL>`; paste it into **both** agent sessions. Read your own
identity and run the matching half.

## Determine identity

Check `VRG_IDENTITY_MODE`: `user` → the **Monitor** half; `audit` → the
**Review** half. If `human`, stop — this skill is for the agents.

## USER half — Monitor & reconcile

Loop:

1. **Wait for the PR to settle:**

   ```bash
   vrg-pr-await <PR_URL> --since-sha <last-head-sha> --since-reviews <last-review-count>
   ```

   (Omit the `--since-*` flags on the first call.) It prints PR state as JSON —
   parse the checks, reviews, and head SHA.
2. **Stop condition:** all required checks are green **and** the
   `vergil-audit/approved` check is success → tell the human the PR is mergeable.
   Done.
3. Otherwise **reconcile all three sources:** failing CI checks + audit review
   comments + human comments. Patch the code, `vrg-commit`, and push
   (`vrg-git push`). The new commit re-triggers CI and the audit's re-review.
4. If you cannot get a check green or cannot satisfy a comment, **stop and ask
   the human** rather than thrashing.
5. Loop with the updated `--since-sha` / `--since-reviews`.

## AUDIT half — Review & gate

Loop:

1. **Wait for a new commit:**

   ```bash
   vrg-pr-await <PR_URL> --since-sha <last-head-sha>
   ```
2. Re-review the delta of the new head commit (read-only — design §7.1).
3. **Post the verdict on the PR:**
   - Findings → post review comments with `vrg-gh` and run
     `vrg-audit-approve <PR_URL> --conclusion failure` (gate stays red).
   - Clean → `vrg-audit-approve <PR_URL>` (conclusion `success` — this is the
     `vergil-audit/approved` gate going green).
   `vrg-audit-approve` refuses to run as USER, so only this session can move the
   gate.
4. **Stop** when you have approved and all checks are green. For an ERROR that
   needs the human, post `--conclusion failure` and alert them.

## Notes

- Per-commit gate: the `vergil-audit/approved` check is bound to the head SHA, so
  every USER push invalidates the prior approval and you must re-post. That is by
  design.
````

- [ ] **Step 2: Validate**

Run: `vrg-container-run -- vrg-validate`
Expected: `all checks passed`.

- [ ] **Step 3: Acceptance checklist**

- Frontmatter `name: pr-watch` + description; the description mentions pasting
  into both sessions.
- Branches on `VRG_IDENTITY_MODE`; USER half uses `vrg-pr-await` +
  `vrg-commit`/push; AUDIT half uses `vrg-pr-await` + `vrg-gh` +
  `vrg-audit-approve`.
- States the per-commit gate invalidation and that `vrg-audit-approve` refuses
  USER.

- [ ] **Step 4: Commit**

```bash
vrg-git add skills/pr-watch/SKILL.md
vrg-commit --type feat --scope skills --message "add pr-watch skill (post-PR loop)"
```

---

## Task 4: Retire the `pr-workflow` skill

**Files:**

- Delete: `skills/pr-workflow/SKILL.md`
- Modify: `README.md`, `CLAUDE.md`, `docs/development/starting-work-on-an-issue.md`,
  `docs/repository-standards.md`, `docs/site/docs/skills/index.md`,
  `docs/site/docs/hooks/index.md`, `skills/dependency-update/SKILL.md:196`
- **Leave intact (historical):** `CHANGELOG.md`, `releases/*`,
  `docs/specs/v2-*.md`, `docs/specs/block-agent-merge.md`,
  `docs/plans/block-agent-merge.md`, `paad/*`.

- [ ] **Step 1: Delete the skill**

```bash
vrg-git rm skills/pr-workflow/SKILL.md
```

- [ ] **Step 2: Update `README.md`**

In the Skills table (≈line 142), remove the `pr-workflow` row and add the three
new skills. Replace the `/vergil-tooling:pr-workflow` examples (≈lines 164, 203)
and the "Development and deployment" usage (≈lines 199–203) with the 2.1 model:
the human runs `vrg-submit-pr`; agents use `/vergil:implement`, `/vergil:audit`,
`/vergil:pr-watch`. (Also correct the stale `/vergil-tooling:` prefix to
`/vergil:` on the lines you touch.)

- [ ] **Step 3: Update `CLAUDE.md`**

At ≈line 206 (Development and deployment), replace the "`pr-workflow` skill for
shipping a change" reference with: implement via `/vergil:implement`, then the
human runs `vrg-submit-pr`, then `/vergil:pr-watch` in both agent sessions.

- [ ] **Step 4: Update `docs/development/starting-work-on-an-issue.md`**

Line 9 and the "What does *not* belong here" section (≈lines 253–261): replace
`pr-workflow` (PR submission / finalization) references with the new model —
submission is the human's `vrg-submit-pr`; the post-PR loop is `/vergil:pr-watch`.

- [ ] **Step 5: Update remaining active references**

- `docs/repository-standards.md:23` — reword "the `pr-workflow` skill reads this
  section" to "the `pr-watch` skill / post-merge verification reads this section"
  (or drop if no longer applicable).
- `docs/site/docs/skills/index.md` — remove the `pr-workflow` table row + section
  (≈lines 17, 22, 120–121); add `implement`, `audit`, `pr-watch`; fix
  `/vergil-tooling:` → `/vergil:`.
- `docs/site/docs/hooks/index.md:182,299` — repoint `pr-workflow` references to
  `pr-watch` (the post-PR issue-closure context).
- `skills/dependency-update/SKILL.md:196` — n/a once Task 5 deletes that file;
  no action.

- [ ] **Step 6: Verify no active references remain**

```bash
grep -rIn "pr-workflow" . | grep -vE "\.git/|CHANGELOG|releases/|docs/specs/v2-|docs/specs/block-agent-merge|docs/plans/block-agent-merge|paad/|docs/specs/2026-06-04"
```

Expected: no output (only historical references remain, which are excluded).

- [ ] **Step 7: Validate and commit**

```bash
vrg-container-run -- vrg-validate
vrg-git add -A
vrg-commit --type refactor --scope skills --message "retire pr-workflow skill; repoint active refs to the 2.1 model"
```

---

## Task 5: Retire the `dependency-update` skill

**Files:**

- Delete: `skills/dependency-update/SKILL.md`
- Modify: `README.md` (skills table row), `docs/site/docs/skills/index.md`
  (rows ≈18, 41, 43), `docs/development/skills-architecture.md` (catalog entry
  ≈line 223 — note it is now a mechanized `vergil-tooling` utility).
- **Leave intact (historical):** `CHANGELOG.md`, `releases/*`, `docs/specs/v2-*`.

- [ ] **Step 1: Delete the skill**

```bash
vrg-git rm skills/dependency-update/SKILL.md
```

- [ ] **Step 2: Update active references**

- `README.md:143` — remove the `dependency-update` row.
- `docs/site/docs/skills/index.md` — remove its table row and section (≈18, 41,
  43).
- `docs/development/skills-architecture.md:223` — replace the catalog entry with
  a one-line note that dependency updates are now a deterministic
  `vergil-tooling` utility (no skill).

- [ ] **Step 3: Verify no active references remain**

```bash
grep -rIn "dependency-update" . | grep -vE "\.git/|CHANGELOG|releases/|docs/specs/v2-|docs/specs/2026-06-04|paad/"
```

Expected: no output.

- [ ] **Step 4: Validate and commit**

```bash
vrg-container-run -- vrg-validate
vrg-git add -A
vrg-commit --type refactor --scope skills --message "retire dependency-update skill (mechanized in vergil-tooling)"
```

---

## Task 6: Reconcile the kept skills

**Files:**

- Modify: `skills/deprecation-triage/SKILL.md`, `skills/handoff/SKILL.md`

- [ ] **Step 1: `deprecation-triage` — add the role-permission check**

Near its issue-creation step, insert:

```markdown
> **Identity check.** Creating issues requires write access. If the acting
> identity (USER / AUDIT) cannot create the issue, prepare the issue title and
> body and hand them to the human to create — do not fail silently.
```

- [ ] **Step 2: `handoff` — disambiguate from the PR handoff**

Add one line under its overview:

```markdown
> **Not the PR handoff.** This is session-continuity state, distinct from the
> `.vergil/pr-template.yml` PR handoff used by the implement/audit pair.
```

- [ ] **Step 3: Validate and commit**

```bash
vrg-container-run -- vrg-validate
vrg-git add skills/deprecation-triage/SKILL.md skills/handoff/SKILL.md
vrg-commit --type docs --scope skills --message "reconcile deprecation-triage and handoff with the 2.1 model"
```

---

## Task 7: Final sweep — collection consistency

**Files:**

- Modify (if present): `README.md` Skills table, `docs/site/docs/skills/index.md`
  — confirm the three new skills are listed and counts are right.

- [ ] **Step 1: Confirm the collection lists exactly the live skills**

```bash
ls -1 skills/    # expect: audit, deprecation-triage, handoff, implement, memory-audit, memory-init, pr-watch, summarize
grep -rIn "implement\|audit\|pr-watch" README.md docs/site/docs/skills/index.md | head
```

Expected: all three new skills appear in both catalogs; no `pr-workflow` or
`dependency-update` rows remain.

- [ ] **Step 2: Full validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: `all checks passed`.

- [ ] **Step 3: Commit any catalog fixes**

```bash
vrg-git add -A
vrg-commit --type docs --scope skills --message "finalize skill catalog for the 2.1 collection"
```

---

## Out of scope / follow-ups

- The stale `vergil-tooling:` skill-namespace prefix appears throughout
  `README.md` and `docs/site/`; this plan only corrects the lines it touches. A
  full namespace sweep (plugin.json `name` is `vergil`) is a separate cleanup.
- `docs/development/skills-architecture.md` is a large architecture/audit
  document with many `pr-workflow`/`dependency-update` mentions; this plan
  updates its live catalog entries only. A fuller rewrite to describe the 2.1
  collection is a follow-up.
- Deployment is gated on `vergil-tooling` 2.1 being installed site-wide (design
  §12); these skills are authored now but ship with 2.1.
