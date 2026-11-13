---
name: epic-implement
description: Drive a GitHub epic's tasks to their human gates as the USER agent. Use whenever the human wants to start or resume work on an epic as a whole — "implement epic #135", "pick up epic X where we left off", "drive this epic", "keep working the epic" — or on the ad-hoc tasks, org-wide or for one repo, in its adhoc mode — "work the ad-hoc tasks", "implement ad hoc", "crank through the ad-hoc queue", `/vergil:epic-implement adhoc [--repo <owner>/<repo>]`, or a repo's ad-hoc epic ref. A thin layer above the issue-* skills: it resumes from GitHub (the epic and its plan, or vrg-queue adhoc), works every runnable task (sub-agents encouraged), batches everything needing the human once, and stops. Refuses a queue epic (use epic-review) or a non-epic. It never opens PRs, never runs pr-watch, and never submits or merges the terminal retrospective PR (it drafts it via epic-retrospective; the human submits).
---

# Epic implement

Shepherd an epic from wherever it stands to its next human gate. `epic-implement`
is the **epic-level driver** above the `issue-*` skills. It is *stateless by
design*: everything authoritative lives in GitHub — the epic issue, its
sub-issues' open/closed status, and the **aligned plan** the epic references. Any
session context you accumulate is a bonus, never a requirement; if this session
is lost or compacted, re-invoking `/vergil:epic-implement <epic-ref>`
re-derives position and continues.

It has two paths: the **development path** (steps 1–6 below) works one
development epic from its plan, and the [`adhoc` mode](#the-adhoc-mode)
works the ad-hoc tasks, org-wide or for one repo, through the same
dispatch, gate and batching rules.

## Preflight

1. Confirm you are the **USER** agent: `[ "$(vrg-whoami --mode)" = user ] && echo ok || echo "not user"`
   must print `ok`. If not, stop.
2. **Read the argument.** It is a keyword or an epic ref.

   - **`adhoc`** runs the [`adhoc` mode](#the-adhoc-mode) over every
     ad-hoc epic in the current org's queue home (`<owner>/.github`).
     `adhoc --repo <owner>/<repo>` limits it to that one repo. A
     **self-homed private repo**'s ad-hoc tasks are never in the org-wide
     run: they are worked only with that repo's own `--repo`, given here
     or mapped from its ad-hoc epic ref below.
   - **`intake`, `planning` or `deferred`** is a queue: print
     `<keyword> is the <keyword> queue; review it with /vergil:epic-review <keyword>.`
     and stop.
   - **An epic ref** (`<owner>/<repo>#<N>`, `#<N>`, or a URL): read its
     labels and title, and take its kind from the labels:

     ```bash
     vrg-gh issue view <N> --repo <owner>/<repo> --json labels,title
     ```

     | Labels | Kind | What to do |
     |---|---|---|
     | no `epic` label (a task, or an `archive`) | not an epic | Print `<ref> is not an epic.` and stop. |
     | `epic` + `intake`, `planning` or `deferred` | a queue | Print `<ref> is the <kind> queue; review it with /vergil:epic-review <kind>.` and stop. |
     | `epic` + `ad-hoc` | one repo's ad-hoc epic | Run the [`adhoc` mode](#the-adhoc-mode) for that one repo (below). |
     | `epic`, none of the above | development epic | Read the epic issue and go on to step 1. |

     **Mapping an ad-hoc epic to its repo.** A live ad-hoc epic is titled
     exactly `Epic (ad hoc): <repo>`, `<repo>` a bare repo name. Any other
     title on an `epic` + `ad-hoc` issue (`Archive (ad hoc): …`, or the
     legacy `Epic (ad hoc): <repo> — <quarter>`) is an archive: print
     `<ref> is an archive, not a live ad-hoc epic.` and stop. In the org's
     `.github`, the epic's repo is `<owner>/<repo>`, under the ref's owner.
     A self-homed private repo's ad-hoc epic lives in that repo itself and
     maps to it (the ref's `<owner>/<repo>`); if its title names another
     repo, say so and stop. The mapped repo is the mode's `--repo`.

   If the labels cannot be read, say so and stop rather than guess a kind.

## 1. Emit the rename line

Read the epic title and print a paste-ready session rename for the human — the
agent cannot rename its own session:

```text
Suggested session name → run:  /rename epic-<N>-<slug>
```

In the `adhoc` mode the name is `epic-adhoc` for an org-wide run and
`epic-adhoc-<repo>` (the bare repo name) for a one-repo run.

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
[Agent prompt contract](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/worktree-convention.md#agent-prompt-contract)** (the worktree convention). Each sub-agent gets one issue (or one batch,
below), its worktree instruction, and runs the routed skill; it reports its
`report-ready` outcome back to you for the gate. Per-issue worktrees
(`.worktrees/issue-<N>-<slug>`) and branches (`feature/<N>-<slug>`) are naturally
unique, so parallel efforts never collide.

**Batching ready tasks.** You may batch independent ready code tasks of one
repo into one `issue-implement` run, on your own judgment, under the
guidelines in `issue-implement`'s
[What to batch](../issue-implement/SKILL.md#what-to-batch); the tooling
enforces the hard rules there itself. Batch only tasks on the runnable
frontier, which are independent of each other by construction, in the plan's
order. In the `adhoc` mode there is no plan to make them independent: the
confirmed [strategy](#step-3-propose-a-strategy) supplies that independence and
the order instead, and only the tasks it batches are batched. Substantial tasks keep one run and one PR each. Name each batch, with
its issues in order, in the plan of work you show the human after rebuilding
the epic's state; there is no separate approval step. Dispatch a batch to one
sub-agent with the **batch form** of the
[Agent prompt contract](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/worktree-convention.md#agent-prompt-contract),
naming every issue in order; the run starts the batch and works it as
`issue-implement`'s
[Batch mode](../issue-implement/SKILL.md#batch-mode--a-list-of-issues) says.

**Check the batch marker before every code-task dispatch**, not only when you
rebuild state in a new session. In the task repo's main clone, as the
merge-review lookup below does, reading only, run
`vrg-pr-workflow batch-show --issue '<owner>/<repo>#<N>'`. Exit 1: the task
has no marker and is dispatched on its own (or in a new batch), unless it
is the last issue of a collapsed batch: one whose work is on a batch
branch, as `issue-implement`'s
[Finding its worktree](../issue-implement/SKILL.md#a-batch-left-with-one-issue)
finds from the same main clone. Such a task, on dispatch and on re-entry,
is dispatched on its own, never in a new batch, and its prompt names no
worktree to create: the run finds the batch worktree itself. Exit 0: the
task is a member of a batch and is dispatched only as its whole batch, never
alone: the list `batch-show` prints, in its order, never a list you hold in
memory, since an extraction may have shortened it. After a ruling on a batch
item, run it for the first member still in the batch (an extracted issue has
no marker). Any other exit is a problem (step 5).

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
- every **batch stop**
  (`issue-implement`'s [Batch stops](../issue-implement/SKILL.md#batch-stops)),
  presented with its run's other non-review items. A batch stop means
  something found while working the batch shows the decision to batch these
  issues would not have been made had it been known up front; revisiting it
  is the human's call, never yours. The human **extracts** the stopped
  issue, **continues** with it, **hands off what is done**, or **unbatches**
  (extraction for every issue, each redone as its own PR). While the
  batching guidelines are new, the human also asks why the issues were
  batched together, to refine the guidelines: answer from what you knew
  when you batched them. Relay the ruling, with any comment the human
  approved for an extracted issue, in the dispatch prompt of one new run of
  the same list (the one `batch-show` prints), as the bullet above does for
  any non-review ruling;
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
interdependent tasks are never in the same batch. In the `adhoc` mode the
confirmed [strategy](#step-3-propose-a-strategy) supplies this instead: it
runs at the same time only tasks it judged not to overlap, and a task it
put after an overlapping one waits for a later pass, once that one has
merged, so a repo's ready set never holds both.

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
once under `Awaiting a ruling` in a comment on the epic issue (in the
`adhoc` mode, on the epic [its records go to](#where-an-adhoc-run-writes-its-records)),
and present
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

## The `adhoc` mode

Works the open tasks of the ad-hoc epics (`Epic (ad hoc): <repo>`, one per
repo): org-wide with `/vergil:epic-implement adhoc`, or for one repo with
`adhoc --repo <owner>/<repo>` or that repo's ad-hoc epic ref (see
[Preflight](#preflight)). Ad-hoc tasks were placed by a review already,
are small and standalone, and have no plan. The mode replaces the
development path's step 2 with the collect, summarize and strategy steps
below, and otherwise runs the development path's own text: step 1's rename
line, step 3's dispatch rules, step 4's gate and step 5's escalation. That
text is not restated here. It is stateless the same way: re-running it
re-derives everything from GitHub and the main clones.

### Step 1: Collect

```bash
vrg-queue adhoc --json [--repo <owner>/<repo>] [--root <dir> …]
```

It lists every open task under the home's live ad-hoc epics (or the one
repo's), each with its `ref`, `title`, `created_at`, `kind` (`task`,
`validation` or `deployment`), its open `blocked_by` refs, its `state`
(`ready`, `blocked` or `in-flight`), and, for an in-flight task, its
`marks` and `disposition`. The local marks are read from each repo's main
clone under the repo roots: on a cloud or Lima VM the platform default
finds them, and on a physical host pass `--root` naming the directory the
main clones live under (ask the human if you do not know it; never guess).
Any exit other than 0 is a problem (step 5): a read failure, or a repo with
open ad-hoc tasks and no main clone, stops the mode with the tool's message.
Never work from a partial list.

### Step 2: Summarize

Show the human the tasks grouped by repo: each one's ref, age, kind and a
one-line paraphrase. The **runnable frontier** is every `ready` task.
`blocked` tasks are listed with their open blockers and are not run.
**In-flight** tasks are listed apart, with their marks, and follow their
`disposition`:

- **`handed-off`** (an open PR or a ready report-ready record, whatever
  local marks remain; or only a remote branch) is left alone, as the
  development path treats a reported-ready task as finished (step 4, "Every
  reported-ready branch is frozen").
- **`resume`** (a worktree, a merge-review directory or a batch marker, and
  nothing that hands it off) stopped or was interrupted on this machine. It
  goes through the development path's existing re-entry steps in step 3:
  the batch-marker check with `batch-show` (a batch member is dispatched
  only as its whole batch) and, with a merge-review directory, the
  open-request lookup and `vrg-ruling read`. It joins the strategy when
  those steps say to dispatch it, with any ruling the gate relays; one
  waiting for a reply, or stopped on non-review items, waits at the gate.
  A task with only a `worktree` mark was interrupted before its merge
  review: its dispatch prompt names its existing worktree and branch (from
  `vrg-git worktree list` in the main clone) to continue in, never one to
  create.

### Step 3: Propose a strategy

Propose which ready tasks to batch together per repo (under
`issue-implement`'s
[What to batch](../issue-implement/SKILL.md#what-to-batch) guidelines),
which to run alone, which to leave for later, and the order: oldest first
within a repo unless there is a reason to differ. Flag any task whose state
suggests it is stale or larger than one PR, with a recommendation; moving
it is the human's call.

**Judge overlap explicitly.** A development epic's frontier is independent
by construction; ad-hoc tasks are filed one at a time and rarely carry
`Blocked-by:` links, so that argument does not carry over. For each repo,
check which tasks touch the same files or area (from the issue bodies and
the code), and either batch them or run them one after another, the later
one in a later pass once the earlier has merged. The strategy **names
which tasks run at the same time**; that confirmed judgement is what the
development path's batching, parallel dispatch and per-repo submission
rely on in this mode.

### Step 4: One confirmation

Present the whole strategy, resumed tasks included, and take one
confirmation from the human. Change it only as the human says; do not
dispatch before they confirm.

### Step 5: Dispatch

Dispatch by kind label exactly as the development path's step 3 does
(`issue-implement`, `issue-validate`, `issue-deploy`), as sub-agents under
the Agent prompt contract, with the batch-marker check before every
code-task dispatch, in the order and grouping the strategy set.

### Step 6: Gate and stop

Gate and stop exactly as the development path's step 4 does: present
everything needing the human once, relay rulings to stopped runs, hand
each repo's ready set to `vrg-submit-pr`, and stop. When the human says
continue, re-run the mode from step 1.

### Where an adhoc run writes its records

The development path writes each session follow-up, and its ruling, in a
comment on the epic issue. An ad-hoc run writes each one on the ad-hoc epic
of the repo it concerns. One that concerns several repos goes on the queue
home's own ad-hoc epic (`Epic (ad hoc): .github` in `<owner>/.github`; for
a self-homed private repo, its own ad-hoc epic).

### What the mode does not do

The development path's plan reading (step 2), plan evolution log, terminal
handoff (step 6) and retrospective drafting. Ad-hoc epics have no plan and
never close.

## Notes

- You never open a PR, never merge, and never cut a release. Those are human
  gates. You draft the retrospective but never submit or merge its PR.
- The issue's comments are the recovery record — the epic issue and its plan
  are the durable state; `paad:handoff` is available for session continuity.
