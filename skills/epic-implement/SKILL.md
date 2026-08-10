---
name: epic-implement
description: Drive a GitHub epic's tasks to their human gates as the USER agent. Use whenever the human wants to start or resume work on an epic as a whole — "implement epic #135", "pick up epic X where we left off", "drive this epic", "keep working the epic" — with or without the slash command. A thin layer above the issue-* skills: it resumes from the epic issue and its referenced plan, works every currently-runnable task (sub-agents encouraged), batches everything needing the human once, and stops. It never opens PRs, never runs pr-watch, and never submits or merges the terminal retrospective PR (it drafts it via epic-retrospective; the human submits).
---

# Epic implement

Shepherd an epic from wherever it stands to its next human gate. `epic-implement`
is the **epic-level driver** above the `issue-*` skills. It is *stateless by
design*: everything authoritative lives in GitHub — the epic issue, its
sub-issues' open/closed status, and the **aligned plan** the epic references. Any
session context you accumulate is a bonus, never a requirement; if this session
is lost or compacted, re-invoking `/vergil:epic-implement <epic-ref>`
re-derives position and continues.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`. If
   not, stop.
2. Resolve the epic ref (`<org>/.github#N`, `#N`, or a URL). Read the epic issue.

## 1. Emit the rename line

Read the epic title and print a paste-ready session rename for the human — the
agent cannot rename its own session:

```text
Suggested session name → run:  /rename epic-<N>-<slug>
```

## 2. Reconstruct state from GitHub, starting at the epic issue

Do **not** rely on any single tool as a state engine. Reconstruct position by:

1. Reading the epic issue and its **referenced plan** (`epics/<N>-<slug>/plan.md`
   in the epic's home repo) — the plan is the **authoritative execution driver**:
   the intended task sequence and the terminal bookends live there.
2. Reading each sub-issue's **open/closed** status.
3. Reconciling the two: the **runnable frontier** is every task the plan says is
   ready whose dependencies (per the plan) are closed, and which is itself open.

`vrg-epic-audit` may be consulted as a **consistency check** (linking, drift) but
is never the source of position. Where the plan's ordering is informal (no
`Blocked-by` links), infer it from the plan text plus issue state.

## 3. Work the runnable frontier

Drive **every** currently-runnable task to its gate. **Use sub-agents wherever
they make this efficient** — independent tasks should run in parallel. Route each
task by its kind label:

| Task kind | Run via |
|---|---|
| code (default `task`) | `issue-implement` |
| `validation` | `issue-validate` |
| `deployment` | `issue-deploy` |

**Dispatch parallel efforts as sub-agents using the "Agent prompt contract" in
`CLAUDE.md`** (the worktree convention). Each sub-agent gets one issue, its
worktree instruction, and runs the routed skill; it reports its
`report-ready` outcome back to you for the batch. Per-issue worktrees
(`.worktrees/issue-<N>-<slug>`) and branches (`feature/<N>-<slug>`) are naturally
unique, so parallel efforts never collide.

## 4. Batch at the gate, then stop

The **gate** is the general boundary where you can no longer proceed without the
human — not merely "a PR is ready." When the runnable frontier is worked,
present everything needing the human:

- PRs ready to submit (each recorded via `vrg-pr-workflow report-ready`);
- operational tasks needing a human-gated release;
- any problems you got stuck on (see step 5).

**Batch PRs per repository, not across repos.** `vrg-submit-pr` operates on one
repo at a time — it takes a branch list *within a single repo* — so the unit of
submission is a repo's ready set. As soon as **all currently-ready tasks for a
single repo** have reached `report-ready`, hand that repo's branches off as one
`vrg-submit-pr` invocation, **independently of other repos** whose tasks are
still in flight. Don't hold a finished repo's PRs hostage to a slower repo's
work. This is always safe: concurrently-runnable tasks are non-interdependent by
construction (an unmerged dependency keeps its dependent off the runnable
frontier), so a per-repo ready set can always be submitted together — and
interdependent tasks are never in the same batch.

Batch each repo **once** and stop. Your responsibility **ends here.** The human
takes each batch through `vrg-submit-pr` → merge/finalize. **Do not run `pr-watch`** — it is
a rare, human-triggered exception the human invokes only if a gate goes red. When
the human returns and says continue (or re-invokes this skill), re-run steps 2–4:
re-derive state and advance to the next frontier.

**Every reported-ready branch is frozen — do not reopen it on re-entry.** Once a
sub-agent records `report-ready`, that branch is done: `vrg-commit` and the
`vrg-git` push path refuse further commits until the human submits. When you
re-derive state, treat a reported-ready (or already-merged) task as finished —
advance the frontier, do not re-run its issue or add commits to its branch. More
work on a landed task is a **new follow-up issue**, never a mutation of that
branch.

## 5. Escalate on problems — don't thrash

The only reason to pull the human in mid-flight is a **problem you cannot
resolve.** Stop and ask, with what you tried and where you're stuck. Never thrash,
never fabricate, never suppress a validation gate.

## 6. Terminal handoff (hybrid)

When only the closing bookends remain, drive them **in order**:

- **Documentation-review task (first)** — drive the sweep: verify the epic's
  changes are reflected in the docs across every repo it touched, especially
  `docs/site`. Its own same-repo doc edits are mechanical; where **other** repos'
  docs need work it **spawns a per-repo doc task** (linked under the epic, closed
  by a same-repo PR) rather than reaching across a repo boundary. See
  `epic-create`'s bookend convention. This runs **before** the retrospective.
- **Retrospective task (terminal — the final gate)** — hand off into
  **`epic-retrospective`**, the run-once finishing skill. Its preflight refuses
  to run until every other child of the epic is closed, so you reach it only once
  the documentation-review sweep (and any siblings it spawned) have landed. The
  skill drafts `retrospective.md` from the execution record, runs a
  draft → review loop with the human, and its closing docs PR **closes the
  epic**. You prepare and draft; **the human reviews and submits** the
  retrospective PR — PR submit/merge stays a human gate.
- **Follow-on brainstorm — semi-optional, never the end.** A forward-looking
  brainstorm, when warranted, is a separate forward-axis concern (usually accrued
  as its own task during implementation); its outcomes are *recorded* in the
  retrospective's §5. It **no longer defines the terminal gate** — the
  retrospective does.

## Notes

- You never open a PR, never merge, and never cut a release. Those are human
  gates. You draft the retrospective but never submit or merge its PR.
- `/vergil:handoff` remains the recovery net, but is not required — the epic
  issue and its plan are the durable state.
