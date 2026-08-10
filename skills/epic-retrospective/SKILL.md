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

- Enumerate every sub-issue of the epic:
  `vrg-gh issue view <epic-ref> --json subIssues,subIssuesSummary`.
- Let **R** be the retrospective task. If **any child other than R is still
  open**, **abort** — print the open refs and stop:

  > "Not the terminal task — the epic still has N open child(ren): #… . Finish
  > them (`epic-implement`) before running the retrospective."

- This subsumes ordering: the documentation-review sweep and any per-repo
  siblings it spawned are just other open children the gate catches, so
  "documentation-review runs before the retrospective" falls out for free.

`vrg-epic-audit` may be consulted as a **consistency cross-check** (linking,
drift) but is never the gate's source of truth. Never fabricate a pass; if the
enumeration is ambiguous, stop and ask.

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
  where it went (spun-off epic/task ref, or "logged, not yet acted on").
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
- `/vergil:handoff` remains the recovery net; the epic issue, its plan, and the
  sub-issue states are the durable source of position.
