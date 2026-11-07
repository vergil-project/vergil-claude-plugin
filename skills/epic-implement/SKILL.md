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

1. Confirm you are the **USER** agent: `[ "$(vrg-whoami --mode)" = user ] && echo ok || echo "not user"`
   must print `ok`. If not, stop.
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

**Plans evolve append-only once execution starts.** The plan is frozen when its
first task ships. From then on, do not rewrite its task list: record each change
— a new or dropped task, a discovered dependency, a scope shift — as a dated
entry saying what changed and why, appended to an `## Evolution during
execution` section at the bottom of `plan.md` (create the section on the first
entry). The epic's sub-issues stay the authoritative live task list; the log
is the *why* behind any gap between them and the plan, and `epic-retrospective`
builds its "How the plan evolved" section from it. Before the first task ships,
edit the plan freely.

## 3. Work the runnable frontier

Drive **every** currently-runnable task to its gate. **Use sub-agents wherever
they make this efficient** — independent tasks should run in parallel. Route each
task by its kind label:

| Task kind | Run via |
|---|---|
| code (default `task`) | `issue-implement` |
| `validation` | `issue-validate` |
| `deployment` | `issue-deploy` |

**Dispatch parallel efforts as sub-agents using the
[Agent prompt contract](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/worktree-convention.md#agent-prompt-contract)** (the worktree convention). Each sub-agent gets one issue, its
worktree instruction, and runs the routed skill; it reports its
`report-ready` outcome back to you for the batch. Per-issue worktrees
(`.worktrees/issue-<N>-<slug>`) and branches (`feature/<N>-<slug>`) are naturally
unique, so parallel efforts never collide.

Before dispatching any `issue-validate` or `issue-deploy` run whose task
has an `operational/<N>/` state directory, show the human its listing for
confirmation and pass the answer in the prompt
([§1.5](../../docs/paad-review-doctrine.md#15-state-directories)).

**Code tasks at merge review.** `issue-implement` runs the `merge-review`
skill before `report-ready`, and a run can end there instead: `stopped:
request <id>` (a ruling request open on the task issue), `waiting:
non-review items`, `fatal` or `error`. Keep each such outcome for the gate.
On re-entry, find them from the task's merge-review directory,
`build/.vergil-state/issue-implement/<N>/merge-review/` in the task repo's
main clone, reading only: an `open-request.json` without `"responded"`
names the open request (`"request"`) and its step. Check for a reply with
`vrg-ruling read --issue <ref> --request <id> >/dev/null`, discarding its
output (the run reads the reply itself): exit 3, no reply yet, so the task
waits at the gate and is **not** dispatched; exit 0, dispatch it as below;
exit 4, the task is `fatal`; exit 1, a problem (step 5). A task whose
merge-review directory holds no such request (no `open-request.json`, or
one marked `"responded"`) stopped on non-review items or on an error, and
is dispatched again only as the gate below says. Never
dispatch a task alongside another run of the same task.

## 4. Batch at the gate, then stop

The **gate** is the general boundary where you can no longer proceed without the
human — not merely "a PR is ready." When the runnable frontier is worked,
present everything needing the human:

- PRs ready to submit (each recorded via `vrg-pr-workflow report-ready`);
- operational tasks needing a human-gated release;
- every task **stopped at merge review**, with its request ID. Talk each
  item of the request through with the human in the terminal: the items
  are in the task's `merge-review/ruling-<step>.json` and its step comment,
  and a security item's details are in its `merge-review/security-<ID>.md`,
  shown only here. Once the human has decided, run
  `vrg-merge-review-request --issue '<ref>' --ensure-dir` and write the
  reply items (889's `text` for an ordinary item, `decision` for a security
  item) to `draft-<step>.json` in the directory it prints, then, from the
  task's worktree (whose `origin` is the task repo, as `vrg-ruling draft`
  requires), run
  `vrg-ruling draft --issue '<ref>' --request <id> --items <dir>/draft-<step>.json`
  and give the human the `vrg-ruling-reply --issue '<ref>' --request <id>`
  command it prints. Once the human has posted the reply, dispatch one new
  run of the task's `issue-implement` whose prompt says only that a human
  response is available: **no ruling text and no security detail ever goes
  in a prompt** for a merge-review item
  ([doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues),
  "One channel per kind of item"). The run reads the reply from the issue
  and resumes;
- every task whose merge review ended `fatal`: it never reaches
  report-ready, and the human recovers on a new issue (epic 889's spec,
  §10). Its merge-review directory stays until the human deletes it;
- every run's **non-review** items **awaiting a ruling**, as its final
  report gives them, security details included and shown only here.
  Merge-review items are never among them: they go only through the
  request above. File
  and post none of them: pass a task's rulings with no trusted author's
  ruling or `Recorded:` line yet
  together, with each
  item's text, the approved form, any security details and the human's
  confirmation of the listing of any `operational/<N>/` state directory the
  task has ([§1.5](../../docs/paad-review-doctrine.md#15-state-directories)),
  to one new run of that task's skill, never alongside another run of the
  same task, which carries out those
  rulings and nothing else, even on a reported-ready or closed task
  ([doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues)).
  A ruling that changes a task's scope (work the issue does not ask for, a
  part of it dropped or split off, an open question settled) is put on the
  task issue by the human, never as a comment you post (§1.7, "Scope
  changes"): write the change to a
  scratch file and, from a clone of the task's repo (its main clone or
  worktree), run
  `vrg-ruling draft-scope --issue '<ref>' --text-file <file>`, give the
  human the `vrg-scope-change --issue '<ref>'` command it prints, and
  dispatch the run only once they have run it, so the task's merge review
  judges against it. Never draft one for a task with a ruling request open
  (a task stopped at merge review, above): `vrg-scope-change` refuses until
  the resumed run has posted its response, and the reply is that request's
  ruling.
  A `fix` ruling on
  a reported-ready task cannot be carried out this way: ask the human to
  rule `file` instead. For a task whose run ended `waiting: non-review
  items`, that one new run carries out the rulings (a `fix` included,
  since the task is still being implemented) before merge review posts
  anything, then continues the merge review, which may stop again at the
  next gate;
- every fix task an operational run **filed without a ruling** on a FAILURE
  outcome, so the human sees it;
- any problems you got stuck on (see step 5), including a merge review
  that ended `error`: once the cause is fixed, dispatching the task again
  resumes it.

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
advance the frontier, do not re-run its issue (a run given rulings only, above,
is the one exception) or add commits to its branch. Its merge review is
over and its merge-review directory was deleted at `report-ready`: expect
none, and look for none. More
work on a landed task is a **new follow-up issue**, never a mutation of that
branch.

## 5. Escalate on problems — don't thrash

The only reason to pull the human in mid-flight is a **problem you cannot
resolve.** Stop and ask, with what you tried and where you're stuck. Never thrash,
never fabricate, never suppress a validation gate.

**Creating an issue needs the human's approval**
([doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues)).
When a follow-up surfaces in this session — a gap you hit, a "we should
also…" — screen it against
[§1.6](../../docs/paad-review-doctrine.md#16-security-findings), list it at
once under `Awaiting a ruling` in a comment on the epic issue, and present
it at the gate with the runs' items; file it only as the human approves,
then record the ruling in that comment as §1.7 says. A
security item is posted only as a count, its details kept in this
conversation, and is ruled on in this session; its ruling is recorded only
as §1.7's counts line (`Human ruling: security: <k> findings: …`). The
per-repo doc tasks the
documentation-review sweep spawns (step 6) are exempt.

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
- The issue's comments are the recovery record — the epic issue and its plan
  are the durable state; `paad:handoff` is available for session continuity.
