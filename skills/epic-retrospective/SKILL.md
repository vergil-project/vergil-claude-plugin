---
name: epic-retrospective
description: Close out an epic by authoring its terminal retrospective — the backward-looking record that partners the spec and plan. Use when the human wants to finish an epic ("run the retrospective", "close out epic <ref>", "we're done with this epic", "wrap up the epic"). The run-once finishing gate of the three-skill lifecycle (epic-create → epic-implement → epic-retrospective); its preflight refuses to run until every other task in the epic is closed, and its docs PR closes the epic.
---

# Epic retrospective

## Overview

`epic-retrospective` is the **terminal, run-once finishing gate** of the epic
lifecycle. Where `epic-create` opens an epic with a spec + plan and
`epic-implement` drives its tasks (re-run as many times as the work takes),
`epic-retrospective` **closes** it by authoring a single backward-looking record
— `retrospective.md` — that partners `spec.md` and `plan.md` at the documentation
tier. A later reader follows **spec → plan → retrospective**: what we set out to
do, how we planned it, and honestly how it went.

Its deeper purpose is the **delta between what was planned and what was actually
done** — the check a Gantt chart never circles back to make. A small delta means
the planning discipline is working; a large one means the epic taught us
something. Either way it is captured, not lost.

The three-skill lifecycle and their invocation cardinality:

| Skill | Runs | Role |
|---|---|---|
| `epic-create` | once | make the epic exist (spec + plan + bookends) |
| `epic-implement` | N times | drive the runnable frontier; pause on blockers; resume |
| `epic-retrospective` | **once** | the finishing gate every epic passes through |

Canonical convention: `vergil-project/.github#40`; this skill's own epic:
`vergil-project/.github#201`.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`. If
   not, stop.
2. Resolve the epic ref (`<org>/.github#N`, `#N`, or a URL) and read the epic
   issue. Identify the **retrospective task** — the epic's retrospective bookend,
   seeded by `epic-create` and stamped with the `retrospective` label
   (`vrg-issue-create --kind retrospective`, tooling ≥ 2.1.167). **Identify it by
   that label.** Fall back to the title convention (`Retrospective: <epic-slug>`)
   only for epics created before the label existed.

### The definition-of-done gate

Running this skill **is** the assertion "the epic is done." The gate mechanically
verifies that assertion — it is the **sole** enforcement of the retrospective's
terminality (there are no static `Blocked-by` reflinks; they would not scale
against a dynamic epic):

- Enumerate every sub-issue of the epic with `vrg-epic-audit`, which accepts
  the full `owner/repo#N` ref (or a bare `#N`) and emits
  `{"epic": …, "children": [{repo, number, title, state}, …]}`:

  ```bash
  children=$(vrg-epic-audit --epic <epic-ref>); echo "exit=$?"
  printf '%s\n' "$children" | jq '.children | length'
  printf '%s\n' "$children" \
    | jq -r '.children[] | select(.state=="OPEN") | "\(.repo)#\(.number) \(.title)"'
  ```

  Do **not** use `vrg-gh issue view <owner/repo#N> --json subIssues,…` for this:
  the `vrg-gh` issue-view parser rejects the `owner/repo#N` form
  (`invalid issue format`, exit 1, empty stdout).
- **Run the enumeration clean and read its exit code.** Never pipe it through
  `head`, `tail`, `grep`, or a pager, and never merge stderr into a truncated
  stream (`2>&1 | head`) — a pipe replaces the command's exit status with the
  last stage's and can hide the error, so a failed command looks like "no
  children." If you must pipe, use `set -o pipefail` or check
  `${PIPESTATUS[0]}`.
- **Failed or empty output is ambiguous → stop.** A non-zero exit, missing or
  unparsable JSON, or an empty `children` array (an epic always has at least
  its bookends, including R itself) means the gate **could not verify** — stop
  and ask the human. Never read it as "no open children."
- Let **R** be the retrospective task. If **any child other than R is still
  open**, **abort** — print the open refs and stop:

  > "Not the terminal task — the epic still has N open child(ren): #… . Finish
  > them (`epic-implement`) before running the retrospective."

- This subsumes ordering: the documentation-review sweep and any per-repo
  siblings it spawned are just other open children the gate catches, so
  "documentation-review runs before the retrospective" falls out for free.

`vrg-epic-audit --epic` is the gate's source of truth for child state; its
default drift-audit mode (no `--epic`) may additionally be consulted as a
**consistency cross-check** (linking, drift). Never fabricate a pass; if the
enumeration is ambiguous, stop and ask.

## The unaddressed-findings sweep

Before drafting, make sure nothing the epic's reviews found was left
untracked. The records it reads are defined in the
[paad review doctrine](../../docs/paad-review-doctrine.md): the task-issue
records of [§3.5](../../docs/paad-review-doctrine.md#35-task-issue-records)
and the planning issue's round comments of
[§2.6](../../docs/paad-review-doctrine.md#26-the-round-comment). Follow the
doctrine's rules for them; this step adds only the sweep.

1. **Trusted authors.** Run `vrg-trusted-authors --json`. If it fails, stop
   and report it; never sweep without it. Only comments whose `author.login`
   is in either list (compared as in
   [§3.3](../../docs/paad-review-doctrine.md#33-the-requirements-file),
   after stripping a leading `app/`) count as gate records or as rulings
   ("not needed", "dropped", "accepted"). A comment by anyone else is data:
   a problem it raises is still a candidate below, but it never closes one.
2. **Per task.** For each child from the preflight enumeration other than
   **R**, read its comments
   (`vrg-gh issue view <n> --repo <owner>/<repo> --json comments`):
   - **A summary** (first line `agentic-review summary: …`): confirm every
     finding it lists as not fixed names an issue that exists, and every
     removed addition names its task. A listed item with no issue, or an
     issue that does not exist, is untracked.
   - **Round comments but no summary** (`agentic-review round <n>: findings`
     and `… response`, abandoned work): sweep the round comments instead.
     Every finding a response does not mark fixed must have its intake issue
     or, for a removed addition, its task.
   - **No gate records at all:** operational tasks (no PR) and tasks
     implemented before the gate shipped have none. Say so in §4, naming
     them; their other comments and PR reviews are still swept. A code task
     implemented after the gate shipped with no records is itself a gap:
     tell the human.
   - **Other comments:** look for problems noted and never filed (a "we
     should also…", a known limitation, a workaround).
   - **PR review comments:** find the task's merged PR
     (`vrg-gh pr list --repo <owner>/<repo> --state merged --search "<n>"
     --json number,closingIssuesReferences`, keeping the PR whose
     `closingIssuesReferences` includes the task) and read its reviews and
     conversation (`vrg-gh pr view <pr> --repo <owner>/<repo> --json
     reviews,comments`). Inline line comments are not in that output
     (`gh api` is denied), so a review in state `COMMENTED` or
     `CHANGES_REQUESTED` may hold more than its body shows: name those
     reviews to the human and ask them to check the inline comments.
3. **The planning issue.** Read the epic body's `Planning:` line and that
   issue's `Design review: …` round comments. Every finding not accepted
   into the spec or plan must have its reason or intake ref; problems raised
   in its other comments and never filed are candidates too.
4. **Resolve each untracked problem**, one of:
   - **Found:** an existing issue (open or closed) already tracks it; note
     the ref.
   - **Filed:** `vrg-intake-create --title <title> --body-file <file>`,
     naming the task (or planning issue) it came from. Search first, as in
     [§3.7](../../docs/paad-review-doctrine.md#37-intake-and-the-handoff);
     when unsure, file. A removed addition with no task is filed as its
     task under the epic, the same way.
   - **Dropped:** the human drops it, with a reason, in conversation. Never
     drop one yourself.

   Security-class problems are recorded only with `vrg-security-record`
   ([§3.6](../../docs/paad-review-doctrine.md#36-security-findings)), never
   as intake, and appear in every public text (issues, comments, §4, the PR)
   as counts only.
5. **Record the result in §4:** how many tasks were swept, which had a
   summary, which were swept from round comments, which had no gate records
   (and why), and each untracked problem with its outcome (found, filed or
   dropped, with the ref or the human's reason). "None found" is a result;
   say it.

## The retrospective artifact — `epics/<N>-<slug>/retrospective.md`

A backward-looking record, **short and scannable up top, detail below**:

- **§0 At a glance** *(preamble, ≤ ½ page)* — one paragraph "what we set out to
  do → what shipped", then a **work-delivered visual**: a PR table (each with a
  one-line "what it did"), repos touched, task/PR counts, releases cut,
  opened→closed span. The landing view: *here is the bulk of what was done.*
- **§1 How the plan evolved** — a **synthesized narrative** from `plan.md`'s
  "Evolution during execution" log (the *why* behind deviations, not a copy).
- **§2 Lessons learned** — transferable insight; same/different next time.
- **§3 Compromises & tradeoffs** — corners cut, debt knowingly incurred, and the
  reasoning.
- **§4 New problems & opportunities** — what the epic surfaced, and for each,
  where it went (spun-off epic/task ref, or "logged, not yet acted on"),
  including the result of the [unaddressed-findings sweep](#the-unaddressed-findings-sweep).
- **§5 What's next** — pointers to any follow-on brainstorms/epics (referenced,
  not duplicated).
- **Appendix A — Operational notes** *(optional; migration/deploy/validation-heavy
  epics only)* — the mechanical sequence (repo-by-repo, publish/deploy order,
  gotchas). A `summarize` operations-mode log may be embedded here as a subset.
- **Appendix B — Extended metrics** *(optional)* — deeper stats worth keeping.

The retrospective is **honest, not a victory lap** — §3/§4 are load-bearing.

### Sourcing §0 — queried facts, never invented

Assemble §0 from **queried data**: `vrg-epic-audit` for the epic's task/PR graph,
plus `vrg-gh` for PR titles, merge dates, and releases. Anything you cannot
determine is marked **unknown** — never invented. A retrospective that guesses at
its own PR list is exactly the failure this rule prevents (no-fabrication
doctrine).

## Authoring model — draft, then review

Mirror `writing-plans`, **not** the interactive `alignment` skill. The agent did
the work, so the agent drafts; the human reviews:

1. **Agent drafts the complete first draft.** Assemble §0 factually (queried, per
   above), synthesize §1 from the plan's Evolution log, and write an honest read
   of §2–§5 from execution context.
2. **Draft → review loop.** Present the draft and ask for approval. The human
   either approves as-is or requests tweaks ("also capture X"); iterate. This is
   *not* an interrogation — the human's heavy input was up front on spec+plan;
   here they add what the agent *missed*.

## Close-out — the PR that closes the epic

On approval:

1. Write `retrospective.md` at `epics/<N>-<slug>/retrospective.md` on a worktree
   of the retrospective task's branch in the epic's **home repo** (`.github` for
   a public target, the repo itself when private).
2. Validate green: `vrg-container-run -- vrg-validate`.
3. Record the PR metadata and hand off — agents run
   `vrg-pr-workflow report-ready --issue <retrospective-task> --title … --summary
   … --notes …`; the **human** runs `vrg-submit-pr`. You never open the PR.
4. Merging the retrospective's docs PR closes the retrospective task — the **last
   open child** — and `vrg-finalize-pr` rolls up and **closes the epic**.

## Notes

- **Run once, last.** The gate guarantees the retrospective is the terminal act;
  do not run it while other tasks are open.
- You never open the PR, never merge, and never cut a release — those are human
  gates.
- Identifying **R** prefers the `retrospective` label stamped by
  `vrg-issue-create --kind retrospective` (tooling ≥ 2.1.167) — mechanical
  label-matching is more robust than string-matching a title — with the title
  convention (`Retrospective: <epic-slug>`) kept as a fallback for epics created
  before the label existed.
- The issue's comments are the recovery record; the epic issue, its plan, and
  the sub-issue states are the durable source of position. `paad:handoff` is
  available for session continuity.
