# Skills

Skills are shared workflow definitions that Claude Code loads from
the plugin. Each skill is a directory under `skills/` containing a
`SKILL.md` file with frontmatter and structured instructions. All
skills are namespaced under `vergil` and invoked as
`/vergil:<skill-name>`.

Each entry below covers what the skill does, when to use it, and
its current status — including any tracked work that will
substantially change it.

## Execution doctrine — Front-Loaded Judgment, Trusted Execution

Human judgment is spent **up front** (brainstorm → spec pushback rounds →
human spec review → plan → plan pushback rounds → alignment rounds) and at
the **hard gates** (merge review, the checks `vrg-submit-pr` and
`vrg-finalize-pr` run, CI, and the human-only release). Between those,
agents run these skills by the most efficient means available —
**sub-agents are encouraged** for research fan-out and parallel work —
and only stop mid-flight for a problem they cannot resolve. The plugin
no longer tunes agent behavior for continuous human observability; that
older "Continuous Oversight" model is retired. The never-fabricate and
never-suppress-a-gate rules are unaffected.

## paad review rounds: what a session needs

`epic-create`'s design-review rounds run paad in its unattended mode,
through paad's
unattended runner, `paad:paad-delegate`
([doctrine §1.8](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/paad-review-doctrine.md#18-the-delegate-requirement)).

- **The delegate is required.** Upstream's released paad has no
  delegate. The fleet installs paad from the vergil fork
  (`wphillipmoore/paad` at ref `develop`), which tracks upstream, runs a
  patch or two ahead of it and has one. A session without it runs no
  review round: `epic-create` stops and tells the human, and the message
  names the fix. No other agent type stands in for the delegate.
- **Getting it.** Every box, Lima or cloud, gets the delegate through the
  ordinary plugin refresh. The host's `~/.claude/settings.json` names the
  fork in its `extraKnownMarketplaces.paad` entry; `vrg-host plugins`
  installs it on the host and `vrg-vm update --all` on every running VM.
  A box without the delegate is misconfigured. The settings entry, the
  rebase process and the rules for changing the fork are in
  [paad-policy §10](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/paad-policy.md#10-paad-from-the-fork).
- **Where agent state lives.** Private review material that must outlive
  a session or a VM rebuild (security details, a kept scratch copy) is kept in
  the main clone's ignored `build/.vergil-state/`, never in a worktree
  ([doctrine §1.5](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/paad-review-doctrine.md#15-state-directories)).
  The worktree convention keeps the main worktree read-only for source
  and allows ignored scratch in its `build/`; `build/.vergil-state/` is
  the namespace for agent state there.

## Skill catalogue (at a glance)

| Skill | Purpose | Status |
|---|---|---|
| [epic-create](#epic-create) | USER agent: the run-once entry point for non-trivial work — create the epic and its documentation task → brainstorm → spec pushback rounds → human spec review → plan → plan pushback rounds → alignment rounds → file the plan's tasks and the closing bookends → docs PR, in nine checkpointed stages a fresh session resumes after `/clear` | Current (2.1) |
| [epic-implement](#epic-implement) | USER agent: drive an epic's tasks, or in its `adhoc` mode the ad-hoc tasks (org-wide or one repo), to their human gates — resume from the epic issue + plan, work the runnable frontier (sub-agents encouraged), batch what needs the human, including merge-review requests it drafts replies for; each task run submits its own PR and watches it to the merge, and after every merge it continues with the next runnable task; hands the terminal retrospective to `epic-retrospective`, which submits its PR | Current (2.1) |
| [epic-retrospective](#epic-retrospective) | USER agent: the run-once terminal finishing gate — draft the epic's backward-looking retrospective, whose docs PR closes the epic | Current (2.1) |
| [issue-implement](#issue-implement) | USER agent: implement an issue, validate to green, run `merge-review` (resuming a run stopped for a ruling), record the PR metadata with the eligibility line, then submit the PR itself and watch it to the merge; a list of issues becomes one batch PR | Current (2.1) |
| [merge-review](#merge-review) | USER agent: the pre-PR merge review `issue-implement` (and `epic-create`, `epic-retrospective` and `hoshin` for their docs PRs) runs once validation is green, on every PR — one review by the read-only `merge-reviewer`, at most one fix and check, every stop through `vrg-ruling`, every item closed before handoff, an exemption only on the human's instruction, and a closing comment posted with `vrg-merge-review-close` as the PR's merge-review record, carrying the eligibility line for report-ready's notes; also the whole-branch review `pr-watch` runs on a fix to an open PR before it pushes | Current (2.1) |
| [issue-deploy](#issue-deploy) | USER agent: run a `deployment` task — install/sync merged changes so they're usable, then record the outcome as a comment | Current (2.1) |
| [issue-validate](#issue-validate) | USER agent: run a `validation` task — a live check whose acceptance is a recorded PASS/FAIL comment, not a code change | Current (2.1) |
| [fixture-run](#fixture-run) | USER agent: file a fixture run — the change, release and validation trio that drives a language fixture repo through the full cycle against a released Vergil change; files tasks only, and refuses a run without `--after` | Current (2.1) |
| [pr-watch](#pr-watch) | USER agent: wait on a submitted PR with `vrg-pr-await` until it auto-merges (exit 0) or cannot merge (exit 1, with a reason), fix a failing check or conflict and stop for the human on any other reason, and handle review comments it reads itself; merge-review every fix but a clean rebase before pushing it, then rerun `vrg-finalize-pr` itself; on a batch PR, fold each fix into its issue's commit and run the batch check before every push | Current (2.1) |
| [deprecation-triage](#deprecation-triage) | Triage deprecation warnings into tracking issues | Current (reviewed 2026-04-23, no changes) |
| [summarize](#summarize) | Decision / operation / stream-of-consciousness summaries; SOC mode is the canonical capture for the fleet | Current |
| [intake-capture](#intake-capture) | Capture an uncurated idea/bug/to-do into the intake queue with `vrg-intake-create` — no kind or category step — paraphrasing voice-to-text into clean prose | Current (2.1) |
| [epic-review](#epic-review) | USER agent: review the intake, planning or deferred queue in batches of 4 and route each item with `vrg-intake-route`; planning mode prunes the queue and never picks what to plan next, deferred mode re-checks each item's revival conditions. Refuses an ad-hoc or development epic | Current (2.1) |
| [steering-audit](#steering-audit) | Review the Claude Code steering and settings files against the ownership model: re-verify its platform facts, run mechanical checks and a findings-only `/paad:pushback`, then walk each finding with the human. `steering-audit user` reviews the user-level files read-only | Current (2.1) |
| [hoshin](#hoshin) | USER agent: run the hōshin kanri review cadence — `start` each working day, optional `end` or `end <level>` — closing any period left open, running the reviews due with the human, and handing off one docs PR of dated logbook entries after a security screen, the human's approval and a merge review, then submitting it with `vrg-submit-pr` (never `--release`); the human's approval of the full text is the review's sign-off | Current (2.1) |

Three of the `epic-*` skills form the **epic lifecycle**: `epic-create` (run
once) → `epic-implement` (run N times) → `epic-retrospective` (run once — the
terminal gate that closes the epic). The fourth, `epic-review`, works the
queues upstream of it: it places intake, planning and deferred items, and never
implements one or starts `epic-create`.

## epic-create

**What it does.** USER-identity skill and the **entry point** for non-trivial
work. It creates the finite epic in its home, the org `.github`, with its
documentation task, opens into brainstorming, runs the front-loaded pipeline
(brainstorm → spec pushback rounds → human spec review → writing-plans →
plan pushback rounds → alignment rounds), files the plan's tasks with the
closing **bookend tasks** — documentation-review and the terminal
**retrospective** — and publishes the spec + plan as a docs PR, which closes
the documentation task. It also files the operational (deployment and
validation) tasks the plan needs, each runnable as filed: their
preconditions, procedure and acceptance are written from the plan into a
`--body-file` for `vrg-issue-create`. When an epic changes language support,
container images, shared CI workflows or release tooling, its plan seeds a
**fixture run** for each fixture whose language or shape the change affects,
filed with [fixture-run](#fixture-run) once the release that ships the change
is filed. Each design-review round is a fresh review-only
subagent; the main session walks the human through its findings and records the
round on the planning issue, and the human decides every further round. The
rules are mode 1 of the
[paad review doctrine](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/paad-review-doctrine.md#2-mode-1-human-gated-design-review),
and each round needs paad's delegate
([paad review rounds](#paad-review-rounds-what-a-session-needs)).
Every run is tracked in a **planning issue** (an open
child of the planning epic): it is entered from a planning issue, an intake
issue (pulled into planning), a deferred issue (pulled back into planning after
its `Revisit when:` conditions are checked), a free-text idea (a new planning
issue), or with no argument (a `vrg-queue planning` summary, where the human
chooses what to plan next: plan an epic only when it will be implemented soon,
usually one pick at a time). It labels the item `in-progress`,
records progress comments with the `Epic:` / `Docs task:` / `Tasks filed: yes`
markers, and files every task before it merge-reviews the docs PR and
submits it itself, since the human's review of the spec and plan already
happened in the session. That PR also
closes the planning issue: `vrg-submit-pr` adds a `Planning issue: Closes`
line for it, so the merge that publishes the spec and plan ends the planning.

A run is nine **checkpointed stages**: `bootstrap`, `brainstorm`,
`spec-pushback`, `spec-review`, `plan`, `plan-pushback`, `alignment`,
`file-tasks` and `docs-pr`. Their checklist is a block in the planning
issue's body, written only by
[`vrg-checkpoint`](https://vergil-project.github.io/vergil-tooling/latest/reference/cli-tools-overview/#vrg-checkpoint)
(tooling ≥ 2.1.340). Each stage makes its work durable, posts its progress
comment and ticks its box as its last write, then pauses with the
`/clear` and `/vergil:epic-create <planning issue>` commands ready to paste,
so a fresh session resumes at the first unticked stage with no decision or
work lost and nothing created twice. Every task `file-tasks`
files carries a `Plan task: <id>` key (`Plan task: <id> <fixture>` for a
fixture run's tasks), so a re-entry keys any task filed without one,
adding any `Blocked-by:` refs the plan gives it that it lacks, and files
only those missing. A checklist that a tooling release changed under
a run (skew) is shown to the human and rewritten with `vrg-checkpoint
reconcile`, never remapped silently. A run started before the checklist
existed is adopted: the stages its evidence shows done are proposed, and
the human confirms the ticks. An early exit from `brainstorm`, and
[epic-review](#epic-review)'s defer or drop of a planning item whose
skeleton exists, first abandons the skeleton: the epic and documentation
task are closed as not planned, the unused docs worktree removed and the
checklist reset, so a revived item starts afresh.

At step 0 it checks whether the run is a security run (the planning issue
carries the `security` label, has a `Security advisory:` line, or is tracked
by an advisory), stops on any disagreement between the three as a broken
pair, and records a `Security run: yes` marker that is never cleared, or a
`Security run: no` marker naming the signals present. A resumed run reads
the answer back, and asks the human again only when a signal the `no` did
not name has appeared since. A
security run keeps every public artifact in general terms, naming findings
by issue ref and GHSA ID alone, and puts specifics into the advisory. Once
the design is approved, it asks the human whether the item is safe to
describe in public before anything about it is published, and pauses on no.
A security run judged not worth doing is never closed by the agent: the
human either retargets each advisory to a fix task, or closes the planning
issue as not planned and then closes the advisory. Otherwise it hands each
advisory to the task or tasks that fix it or, for a design-only finding,
the documentation task, with one
`vrg-security-record retarget <GHSA> --from <planning issue> --to <task> …`
per advisory, after the last fix task is filed and before posting
`Tasks filed: yes` (or, for a single task, before closing the planning
issue). A retarget refusal stops for the human. The planning issue cannot
close while any advisory still tracks it or one it names cannot be read
(see
[Security items in planning](https://vergil-project.github.io/vergil-tooling/latest/guides/security-records/#security-items-in-planning)).
A cross-org effort has one primary epic; a task its plan files in another
org goes under that org's **proxy** epic, created with
`vrg-epic-create --proxy-for <primary ref> --repo <owner>/<repo>`, never in
an ad-hoc epic, which holds only standalone, single-issue work. A retarget
to fix tasks in another org moves the advisory there; fix tasks spanning
orgs are refused, and the human chooses between duplicating the advisory
per org and splitting the finding.

**When to use.** At the start of significant work — "let's build X", "start an
epic for this" — to resume a paused planning session, or to choose what to
plan next ("what should we plan next", "prioritize the planning queue"). If
the work collapses to a single PR, it is a task, not an epic.

**Status.** Current (Vergil 2.1).

## epic-implement

**What it does.** USER-identity skill and the **epic-level driver** above
the `issue-*` skills. Given an epic, it reconstructs state from the epic
issue and its referenced plan (the authoritative driver), works every
currently-runnable task to its gate — routing by kind to
`issue-implement` / `issue-validate` / `issue-deploy`, and **dispatching
parallel sub-agents where efficient** — then batches everything needing
the human once and stops. It is stateless by design: re-invoking after a
lost or compacted session re-derives position from GitHub.

Its frontier is built from the `children` of `vrg-epic-audit --epic`: the
epic's own sub-issues and its **proxy tasks**, the tasks of the effort
filed in another org under that org's proxy epic. A proxy task is driven
from the primary epic like any other task, through the same skills and
gates, and plan evolution that concerns it is recorded in the primary's
plan, since a proxy has no plan. An audit exit 1 is proxy link drift (a
broken or disagreeing `Primary:`/`Proxy:` link): it shows the problems and
stops rather than build a frontier without the proxy's tasks.

A code task whose [merge review](#merge-review) stopped for a ruling waits
at the gate with its request ID. `epic-implement` talks the request's items
through with the human in the terminal (a security item's details from the
task's private merge-review directory), drafts the reply with `vrg-ruling
draft`, and hands the human the `vrg-ruling-reply` command. Once the reply
is posted it re-dispatches the task saying only that a human response is
available; no merge-review ruling or security detail ever travels in a
prompt. Its ruling relay through prompts covers only `issue-implement`'s
own non-review items. A ruling there that changes a task's scope is drafted
at the gate with `vrg-ruling draft-scope`, and the human posts it as
themselves with the `vrg-scope-change` command it prints before the task is
dispatched; the agents never post scope changes themselves.

A deployment task whose `issue-deploy` run ended `waiting: human-run steps`
also waits at the gate: `epic-implement` shows each step's precondition
result and paste-ready `! <command>` line, and once the human has run them
it dispatches one new `issue-deploy` run whose prompt carries the output of
those runs, which verifies them and records the outcome.

A documentation fix that a task's run, its merge review or the main
session leaves for the epic's documentation-review sweep is recorded at
once as a comment on the epic's documentation-review bookend, with its
file and line, what is wrong and what found it. A dispatched run names
the item in its final report and `epic-implement` posts it; the sweep
then starts from that list. A sweep item is not a new issue and needs no
ruling.

It may batch independent small ready code tasks of one epic and repo into
one `issue-implement` run, under that skill's
[What to batch](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/skills/issue-implement/SKILL.md#what-to-batch) guidelines,
and dispatches the batch to one sub-agent with the batch form of the
prompt contract. Before every code-task dispatch it checks the task's batch
marker with `vrg-pr-workflow batch-show`, so a batch member is only ever
dispatched as its whole batch. A batch stop (extract, continue, hand off
what is done, unbatch) is presented at its gate like any other non-review
item. See its
[Work the runnable frontier](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/skills/epic-implement/SKILL.md#3-work-the-runnable-frontier)
section.

Its **`adhoc` mode** works the ad-hoc tasks with the same dispatch, gate
and batching rules: org-wide with `/vergil:epic-implement adhoc`, or for
one repo with `adhoc --repo <owner>/<repo>` or that repo's ad-hoc epic ref.
It collects the tasks
with `vrg-queue adhoc`, summarizes them by repo with the in-flight tasks
apart (a handed-off one is left alone; one to resume goes through the
development path's re-entry steps), proposes a strategy that judges overlap
per repo and names what runs at the same time, takes one confirmation, then
dispatches and gates as the development path does. Its records go on the
ad-hoc epic of the repo concerned. It reads no plan and drafts no
retrospective: ad-hoc epics have no plan and never close. Given an intake,
planning or deferred queue it refuses and points to `epic-review`; given
the hoshin epic it
refuses and points to [hoshin](#hoshin), whose tasks it is; given a
proxy epic it refuses and names the primary epic to drive instead; given an
issue that is not an epic it refuses. Added in epic
[vergil-project/.github#1077](https://github.com/vergil-project/.github/issues/1077).

**When to use.** In the user-agent session, to start or resume work on an
epic as a whole rather than one issue at a time — "implement epic #N",
"pick up epic X where we left off" — or on the ad-hoc tasks: "work the
ad-hoc tasks", "implement ad hoc", "crank through the ad-hoc queue".

**Boundaries.** It opens no PR itself and never merges one: each task's
`issue-implement` run submits its own PR with `vrg-submit-pr`, which
opens it with auto-merge on and finalizes it, and watches it to the
merge. After every merge it re-reads the epic and dispatches the next
runnable task, stopping for the human only on a ruling, a failure, or a
task blocked on a release or a human-gated deployment precondition. When
the human reports a PR that did not merge, or asks for one to be fixed, it
runs `pr-watch` on it at once and never hands the command back. It hands
the terminal retrospective to `epic-retrospective`, which merge-reviews
and submits the retrospective's docs PR itself. It never cuts a release:
releases and promotion stay human.

**Status.** Current (Vergil 2.1). First exemplar of the Front-Loaded
Judgment, Trusted Execution doctrine.

## epic-retrospective

**What it does.** USER-identity skill and the **terminal finishing gate** of the
epic lifecycle. Run once, at the end: its preflight refuses to run until every
other child of the epic is closed, then it sweeps the epic's tasks, their PR
reviews and the planning issue for review findings that were never tracked
(each is found, filed with `vrg-intake-create` or dropped by the human, and
the result goes in §4), then it drafts `retrospective.md` — the
backward-looking record that partners the spec and plan (spec → plan →
retrospective) — from the execution history, runs a draft → review loop with the
human, merge-reviews the closing docs PR and submits it itself; its merge
**closes the epic**.

The gate reads the `children` of `vrg-epic-audit --epic`, so it covers the
epic's **proxy tasks** (its tasks filed in other orgs under their proxy
epics) like its own children. Its refusal names each open ref in full and,
for each open proxy task, the proxy it sits under. An audit exit 1 is proxy
link drift (a broken or disagreeing `Primary:`/`Proxy:` link): it shows the
problems and stops, since the gate cannot see every proxy task until the
link is fixed.

**When to use.** To finish an epic — "run the retrospective", "close out this
epic", "we're done with this epic".

**Status.** Current (Vergil 2.1).

## issue-implement

**What it does.** USER-identity skill. Implements a GitHub issue on
its feature branch, validates to green via `vrg-validate`, runs the
[merge review](#merge-review), then records
the PR metadata (`.vergil/pr-workflow.json`) with
`vrg-pr-workflow report-ready` for `vrg-submit-pr` to consume, with the
merge review's eligibility line in the notes. A run stopped at merge review
for a ruling ends there; running the skill on the task again resumes it
from the task's private merge-review directory, which `issue-implement`
deletes once `report-ready` succeeds.
`report-ready` also pushes the branch to origin, so there is no separate
push step. The skill then submits the PR itself with `vrg-submit-pr`
(never `--release`), which opens it with auto-merge on and always
finalizes, and owns the PR until it merges or needs the human: on a PR
that does not merge it runs [pr-watch](#pr-watch), which fixes it,
merge-reviews each fix and reruns `vrg-finalize-pr` itself. Releases and
promotion stay the human's. It refuses an issue whose native parent is the intake,
planning or deferred epic (route it with `epic-review intake`, expand it with
`epic-create`, or revive it with `epic-review deferred` first), mirroring the
PR tooling's refusal. It refuses an ops issue (one under an org's
`Epic (operations): …` epic) the same way, at Preflight and before any
work, a batch that lists one included, in the tooling's words: file the
fix as a follow-up task in its own repo, and close the ops issue by hand.
It also refuses a task under the hoshin epic,
pointing to [hoshin](#hoshin), the only skill that works one. A ruling that changes the task's scope is drafted
with `vrg-ruling draft-scope` for the human to post with
`vrg-scope-change`, before the merge review starts. An epic's
documentation review whose own repo needs no change has no PR: the skill
posts the search evidence on the task and closes it as completed, with no
ruling needed.

A documentation fix a run leaves for the epic's documentation-review sweep
is recorded on that epic's documentation-review bookend. A proxy task has
no bookend of its own: its sweep items go on the **primary's** bookend, the
primary read from `vrg-epic-audit --epic <proxy ref>`, and a link-drift
exit 1 there stops the run. An ad-hoc task has no bookend at all: a
documentation gap it finds outside its scope is a follow-up for the
human's ruling.

Given a list of small same-epic issues, it implements them as one
**batch**: `vrg-pr-workflow batch-start` checks the batch's hard rules
and records the list and a fixed base, then each issue is implemented,
validated, merge-reviewed and folded to one commit in order on one
branch, and `report-ready` records them as one PR. An issue that turns
out unsuited to the batch stops it for the human, who may extract it.

**When to use.** In the user-agent session, to take an issue from
implementation to its merge into `develop`. A **cloud session** does not
submit: it stops after `report-ready`, which pushes a world-readable
**relay ref** carrying the ready-state, so the Mac does not need the
session's filesystem, and the human opens the PR worktree-free with
`vrg-submit-pr <branch> [<branch> …]`. A repo whose CLAUDE.md still
says agents never run `vrg-submit-pr`, and a push GitHub refuses for
workflow files, also stop after `report-ready` for the human's submit.
(This retired
the former `issue-localize` skill, which reconstructed the ready-state
locally before the relay existed — epic
[vergil-project/.github#148](https://github.com/vergil-project/.github/issues/148).)

**Status.** Current (Vergil 2.1). Requires the 2.1 tooling CLIs
(`vrg-pr-workflow`, etc.) at runtime.

## merge-review

**What it does.** USER-identity skill. The judgement-level review between a
green `vrg-validate` and the PR: is this change good enough to merge? It
builds a request with `vrg-merge-review-request`, dispatches the read-only
[`merge-reviewer`](../agents/index.md) agent, and acts only on a result that
passes `vrg-merge-review-check`, deciding from the findings' kinds alone.
The loop is one review, then at most one fix and check. Design questions,
out-of-scope additions, untracked pre-existing problems, disputes, more
than five blockers and a failed check all stop for the human through one
authenticated `vrg-ruling` request; the human replies with
`vrg-ruling-reply`. Every item is closed (fixed, ruled on and carried out,
filed, or recorded) before handoff. Each step posts one comment, and a
closing comment carries the eligibility line,
`Merge review: done: <eligible | not-eligible (<reason>)>; accepted-risk <w>`,
which also goes into report-ready's notes. The closing comment is posted
only with `vrg-merge-review-close`, which adds the machine-readable
record line below the eligibility line,
`Merge review record: head=<sha> fingerprint=<hex> outcome=<outcome>`,
computing the head and the change fingerprint itself. That comment is the
PR's **merge-review record**: `vrg-submit-pr`, finalize's watch and the
daily audit read it back, and a PR with no record covering its change is
refused. The fingerprint is of the branch's own changed lines, so a clean
rebase keeps the record.

The one skip is a **merge-review exemption**, requested only on the
human's instruction, before the review step comment is posted, through a
typed `vrg-ruling` request the human answers with a `Decision: approve`
or `Decision: refuse` line from `vrg-ruling-reply`. An approved exemption
stands in for the record and ends the run `exempt: request <id>`, whose
exemption line, `Merge review: exempt: request <id>`, goes into
report-ready's notes in place of the eligibility line; a refused one
runs the review. Every reviewer reply is screened against the
doctrine's security definition before its step comment is posted: a
finding that qualifies becomes a security finding, and a reply holding
anything that would help an attacker (a below-bar remark, or a
description of a security fix the branch makes) is withheld. Security
findings appear in
public only by ID or count; their details stay in the task's private state
directory, `build/.vergil-state/issue-implement/<N>/merge-review/`, and the
terminal.

In a batch, each issue is still reviewed on its own: the review and its
checks diff against the previous issue's commit (the batch marker's
`base_sha` for the first issue), and every commit the run makes for the
issue is a `vrg-commit --fixup` of the issue's first commit, which the
review never folds; `issue-implement` folds it afterwards. See its
[In a batch](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/skills/merge-review/SKILL.md#in-a-batch) section.

A fix to an open PR, which `pr-watch` reviews before it pushes, is
reviewed as the whole branch against `origin/develop`, and every step
passes `--pr <PR_URL>` to `vrg-merge-review-request`. On a batch PR the
request then carries every batch issue's scope and the issue each commit
belongs to, and the reviewer judges each commit against its own issue's
scope. See its
[Fix to an open PR](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/skills/merge-review/SKILL.md#fix-to-an-open-pr) section.

**When to use.** Run by `issue-implement` once validation is green and
before `vrg-pr-workflow report-ready`, by `epic-create`,
`epic-retrospective` and `hoshin` on their docs PRs at the same point,
and again on the same task to resume
a run stopped for a ruling. Also run by `pr-watch` on a fix to an open,
submitted PR (any fix but a rebase that resolves no conflict), before it
pushes: a whole-branch review against `origin/develop`, with
`--pr <PR_URL>` on every step. That run has no report-ready: its outcome
is the closing comment on the task issue, which adds a
`Branch as reviewed: <yes | no>` line saying whether the human's rulings
left the reviewed branch as it was. `pr-watch` pushes on `eligible`, on
`not-eligible (<reason>)` once every ruling the run asked for is
answered, and on `exempt`, reporting the eligibility or exemption line
(and the branch-as-reviewed line) with the push. The files, schemas and the result check follow
vergil-tooling's
[agent-to-agent review protocol](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/merge-review-protocol.md);
the ruling channel is its
[Human Replies](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/human-replies.md)
guide.

**Prior art.** The high-signal bar and exclusion list come from
Anthropic's `code-review` plugin, the silent-failure lens from its
`pr-review-toolkit` plugin, the crafted-context reviewer from superpowers'
`requesting-code-review`, and out-of-scope additions, spec checking and
blame-based scope from paad's `agentic-review`.

**Status.** Current (Vergil 2.1). Requires the merge-review tooling CLIs
(`vrg-merge-review-request`, `vrg-merge-review-check`) and `vrg-ruling` at
runtime.

## issue-deploy

**What it does.** USER-identity skill. Runs a `deployment`-labelled task
end to end: installs or syncs the merged change so it is actually usable
(install / sync / release-then-install), then records the result as an
`Outcome:` comment on the issue. It is *run*, not built — there is no PR,
and the deployment tooling refuses one. A step the task lists under
**Human-run steps** (one that needs a human identity, such as
`vrg-github-repo-config update`) is never run under the agent identity: the
skill checks its preconditions, hands the human the paste-ready command,
waits, then verifies the human's run and records it with the rest: from the
run's pasted output, or from the human's report when the agent's own checks
confirm the step's result independently. With no
human present, the run ends `waiting: human-run steps` rather than
`blocked`. What each human-gated release already installs, and what it
leaves over for a deployment task, is defined in the skill's
[release coverage reference](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/skills/issue-deploy/references/release-coverage.md),
which `epic-create` plans deployment tasks from. A release precondition
is confirmed from the release's own `Released:` records; where it must
stay human-attested, the run hands the human the filled-in attestation
command.

**When to use.** When the human asks to deploy, install, roll out, or sync
merged work, or when a later task needs a change deployed and usable rather
than merely merged.

**Status.** Current (Vergil 2.1).

## issue-validate

**What it does.** USER-identity skill. Runs a `validation`-labelled task
whose acceptance is a **live check**, not a code change — a cold rebuild, a
live-lab check, a post-deploy smoke test — and records PASS/FAIL as an
`Outcome:` comment. Like deployment, it is *run*, not built: no PR.

**When to use.** When the human asks to validate, verify, or run the
checklist on a validation issue.

**Status.** Current (Vergil 2.1).

## fixture-run

**What it does.** USER-identity recipe skill. Files a **fixture run** on one
or more of the language fixture repos (`vergil-fixture-python-lib`,
`vergil-fixture-python-app`, `vergil-fixture-rust-lib`,
`vergil-fixture-rust-app`, `vergil-fixture-ts-lib`,
`vergil-fixture-ts-app`): per fixture, a trio of tasks linked under the
epic that needs the run. The change task (run with `issue-implement`) is
blocked by every `--after` ref, the release or deployment task that ships
the change. The release task (`deployment`, run with `issue-deploy`) is the
human's `vrg-release` of the fixture. The validation task (`validation`,
run with `issue-validate`) checks the CI gates, ops, the release, its
evidence bundle, the dependency update, the docs site and that nothing
reached a package registry. It files tasks only and never runs them. The
skill holds the one list of fixtures, the known gaps and the learned
ready-to-start and validation conditions. Runs on one fixture are
serialized in order: a run already under way goes first, then the run filed
first, so runs that overlap proceed one after another with no ruling.

**When to use.** When an epic's plan seeds a fixture run, which
`epic-create`'s fixture-run rule asks of every epic that changes language
support, container images, shared CI workflows or release tooling:
`fixture-run <epic-ref> <fixture>[,<fixture>…] --validates <what> --after
<owner/repo#N> [--after …]`.

**Status.** Current (Vergil 2.1). Requires `vrg-issue-create` with
operational body files (vergil-tooling 2.1.309 or later).

## pr-watch

**What it does.** USER-identity post-submit loop. `vrg-submit-pr` opens
each PR with auto-merge on, so a PR lands by itself once its required
checks are green. pr-watch blocks on `vrg-pr-await <PR>`, which waits for
the merge for up to `$VRG_FINALIZE_DEADLINE` (7200s by default). It is one
wait per pass, never polled: a background command where the harness
notifies on its exit (Claude Code stops a foreground command at 600s), and
otherwise a foreground wait kept under the harness's command timeout and
repeated on `timed_out` up to the full deadline. Exit 0 means the PR merged and the watch is done; exit 1 means
it cannot merge, and the JSON's `reason` names why. A failing required
check (`check_failed`) or a conflict with `develop` (`conflict`) is fixed
and pushed, and the wait runs again. A required check cancelled with no
newer run to replace it (`check_cancelled`, or finalize's
`failed: cancelled`) is re-run with no code change, and the wait runs
again; a check cancelled by a superseding run counts as pending, so it is
never reported. Auto-merge off, a closed PR, an
orphaned check or the deadline passing (`timed_out`) stops for the human.
Any other exit is a tool error and stops it too. A new review never ends
the wait, so pr-watch reads the PR's review, conversation and inline
comments itself, before each wait and after it returns, through
`vrg-issue-read --pr` (never a raw read), which prints only the items a
trusted identity wrote, each under its role, and reports the rest as
metadata only. It acts only on the items whose role is `human`, and
`vrg-pr-review-comments` only locates the trusted inline comments. An
untrusted PR body (`vrg-issue-read` exit 3) stops it for the human,
pushing nothing. A review comment is addressed but never holds the
merge: one still unaddressed when the PR merges becomes a proposed
follow-up issue. Because every push
can merge, a clean rebase onto `origin/develop` is pushed with no review,
and every other fix is reviewed first through merge-review's
[Fix to an open PR](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/skills/merge-review/SKILL.md#fix-to-an-open-pr)
entry and pushed once that review ends `eligible`, `not-eligible` with
every ruling it asked for answered, or `exempt`. After a fix is pushed it
reruns `vrg-finalize-pr <PR>` itself, never with `--release`, which
re-checks the merge-review gate on the new head and counts the PR once it
lands. It never merges and never turns auto-merge on or off: auto-merge
off, a provenance violation, or a head the gates' re-check fails
(`failed: gates`) stops it for the human. A logbook PR (one titled
`Logbook:`) is no exception: every fix to it is merge-reviewed like any
other.

On a batch PR (one whose body has more than one `Closes` line), every fix
is a `vrg-commit --fixup` of its issue's commit, folded with
`vrg-git rebase -i --autosquash` onto the branch's merge base with
`origin/develop` (so a fold never rebases) and pushed with
`--force-with-lease`, never a new commit. Before every push, a clean
rebase included, it runs
`vrg-pr-workflow batch-check --pr <PR_URL> --head <sha>` on the head about
to be pushed, and refuses to push on a non-zero exit. A fix owned by no
single issue, or a fold that conflicts, stops for the human. See its
[Batch PRs](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/skills/pr-watch/SKILL.md#batch-prs--fold-every-fix-into-its-issues-commit)
section.

**When to use.** It is the skill the USER agent uses to repair a
submitted PR that did not merge. The agent runs it itself, at once, when
`vrg-finalize-pr` reports a PR as not merged, when the human reports a red
check or a conflict, or when the human asks for a PR to be fixed or
watched; it never hands the `/vergil:pr-watch <PR_URL>` command back to the
human. It does not start while `vrg-submit-pr` or `vrg-finalize-pr` is
still watching the PR; `issue-implement` runs it after its own submit
reports the PR not merged, and on one that merged to read the review
comments posted during the wait.

**Status.** Current (Vergil 2.1). Requires `vrg-pr-await`'s merge
contract: exit 0 merged, 1 cannot merge, 2 any other error
(vergil-tooling#4648, in vergil-tooling 2.1.323 or later).

<!-- dependency-update retired (#427): dependency updates are now a
deterministic vergil-tooling utility, not a skill. -->

## deprecation-triage

**What it does.** Applies the deprecation-warning triage policy:
search for an existing issue matching the warning, create a
tracking issue if none exists using the standard template,
attempt a code-only fix, decide fix-now vs defer-to-next-cycle,
and document any suppression with removal criteria. Paired with
the `detect-deprecation-warnings` PostToolUse hook.

**When to use.** When a deprecation warning surfaces during test
output, CI, or regular work. The partner hook triggers this
flow automatically when it catches warnings.

**Status.** Current. Reviewed for currency on 2026-04-23 as part
of [plugin#59](https://github.com/vergil-project/vergil-claude-plugin/issues/59);
no changes needed.

## summarize

**What it does.** Produces a concise, structured summary in one of
three modes:

- **decisions** — summary of decisions made during a session
  (what, why, alternatives considered, next step)
- **operations** — summary of operations performed (what was
  touched, what happened, what remains)
- **soc** — stream-of-consciousness capture for context offloading
  between sessions (triggered by `Enter SOC` / `End SOC`)

**When to use.** When the user explicitly asks for a structured
summary, invokes SOC capture, or the skill is invoked via
handoff protocols.

**Status.** Current. Decision A from
[plugin#58](https://github.com/vergil-project/vergil-claude-plugin/issues/58):
this skill's SOC mode is the canonical SOC capture mechanism for
the fleet. Repo-local references to `soc-capture` or
`summarize-soc` as skill names are stale pointers — splitting
SOC into its own skill was rejected because capture and summary
are intertwined here (`End SOC` triggers the structured summary).
The cross-repo references in `the-infrastructure-mindset` are
tracked for cleanup in
[the-infrastructure-mindset#165](https://github.com/wphillipmoore/the-infrastructure-mindset/issues/165).

## intake-capture

**What it does.** Captures an uncurated idea, bug, or to-do into the intake
queue so it is never lost. It runs `vrg-intake-create`, which files one issue
in the current repo's queue home, the org `.github`, and links it under that
home's intake epic as it is created. There is no kind or category step: membership in the intake queue is
the item's state. Voice-to-text input is paraphrased into clean written prose.
Renamed from the triage capture skill in epic
[vergil-project/.github#176](https://github.com/vergil-project/.github/issues/176).

**When to use.** Whenever the human says "don't forget X", "capture this",
"note a todo", or riffs an idea to come back to later — especially mid-task
or via voice.

**Status.** Current (Vergil 2.1).

## epic-review

**What it does.** Reviews one of the three queues of the epic/task model,
intake, planning or deferred, putting each item in the right state and
place with the human. It replaces the three per-queue review skills
with one shared procedure: the USER-agent check, collect
the queue with `vrg-queue <mode>` (a missing queue epic is an empty queue),
check each item's current state and present batches of 4 with one paragraph
and one recommended outcome per item, take one confirmation per batch, and
apply it with `vrg-intake-route`. The agent closes dropped and split items
itself. A refusal from the tool is reported and the human asked for another
outcome, never worked around. When a ruling narrows or widens a routed
one-off's scope, the agent drafts the change with `vrg-ruling draft-scope`
and the human posts it as themselves with `vrg-scope-change`. Each mode ends
with its tallies.

The modes differ only in order, check and outcomes:

- **intake** (oldest first; for a bug, is it already fixed?): **drop**,
  **defer** (to the deferred queue, with a required reason and revival
  conditions), **one-off** (into a repo's ad-hoc or finite epic,
  transferring the issue or recreating it when GitHub refuses the transfer),
  **split** (into tasks made with `vrg-issue-create`), **planning**, or
  **leave** for the next review.
- **planning** (oldest first; is it still valid and still in need of a full
  epic, and what blocks it?) **prunes the queue and never picks what to plan
  next**: **leave** (most items), **defer**, **drop**, or, unusually,
  **one-off** for an item small enough for one PR or whose scope can be cut
  until it is. Items `epic-create` is expanding (`in-progress`) are shown
  with their latest note and offered only leave; the review never resumes
  them and never offers them one-off. The exception is a skeleton, an item
  whose `bootstrap` is done and whose spec is not yet written: it may also
  be deferred or dropped, and the review first abandons the skeleton
  through `epic-create`'s shared step, then routes it. A finished item that nothing closed
  (`ready-to-close`) is offered **close**, unless its epic was abandoned
  (closed as not planned), which means it needs planning again.
  It ends with the surviving queue sorted oldest first. Choosing what to
  plan is the human's act, through [epic-create](#epic-create)'s
  no-argument summary.
- **deferred** (least recently deferred first) **actually checks** every
  `Revisit when:` condition against its source (release pages, issue and PR
  states, dates, upstream status) and reports what it checked: **keep**,
  **refresh** (re-defer in place), **revive** (to intake, planning or a
  one-off, guided by the `Deferred from:` line), or **drop**. A condition it
  cannot verify is reported as such, with a keep recommendation.

A one-off, and a revival of an item deferred from an ad-hoc epic, never
sends work of another org's epic to an ad-hoc epic: it goes under that
epic's proxy in the target repo's org (created with
`vrg-epic-create --proxy-for` if it does not exist).

Planning and deferred items carry an estimated **epic size** (`epic-size:S`
to `XL`, derived from an estimated task count), which the review writes only
through `vrg-intake-route … size` or `planning --tasks … --reason …`: intake
mode sizes every item it routes to planning, planning mode sizes each
waiting item that is unsized or in error, and deferred mode sizes an unsized
item it revives to planning. A one-off clears the item's size: it removes
the `epic-size:*` labels and posts a `Size cleared <date>: …` marker, and
only sizing comments after the latest such marker count, so an item that
later returns to planning starts unsized. An item whose sizing is in error
shows as `!`
and gets a recommended `size` re-run; `vrg-queue`'s exit 2 for such items is
a complete listing, not a failure.

Drop is an outcome in every mode. A planning item's drop or defer is refused
only while one of its development epics is open. A review only places items:
it never implements one or starts `epic-create`. Given an ad-hoc epic or a
development epic, it prints a one-line refusal pointing to the right command
and stops; with no argument, it shows the three queue counts and asks which
to review. Added in epic
[vergil-project/.github#1077](https://github.com/vergil-project/.github/issues/1077).

**When to use.** For the periodic pass of any queue: "review intake", "groom
the backlog", "process the intake queue", "what's in intake" and the older
"review triage" phrasings (intake mode); "review planning", "clean up the
planning queue" (planning mode); "review deferred", "what's deferred",
"revisit the backlog" (deferred mode). To choose what to plan next, use
`epic-create` with no argument.

**Status.** Current (Vergil 2.1). The planning mode's one-off route needs
the `vrg-intake-route` release that allows one-off from planning.

## steering-audit

**What it does.** The judgment layer of the recurring steering review, checked
against the
[Claude config ownership model](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/claude-config-ownership.md)
(the nightly `vrg-github-repo-config update` is the mechanical layer). It
inventories the files, re-verifies the model's platform facts against the live
Claude Code docs and reports any drift first, then runs its own mechanical
checks: the config audit (repo scope), every named path exists, every named
command resolves, the `CLAUDE.md` line count, and the ownership rules. It runs
`/paad:pushback` on each steering file as a findings-only review (no edits, no
report files), then walks every finding one at a time. The human picks one
disposition for each: **keep**, **edit**, **move** to a named managed home,
**delete**, or (repo scope only) **file to intake**.

It has two scopes:

- **repo** (`/vergil:steering-audit`, the default): the repo's `CLAUDE.md`,
  `.claude/rules/`, `.claude/settings.json`, any `AGENTS.md`, and the
  `.claude/settings.local.json` copies Claude Code may load. Edits go through
  the normal worktree and PR flow.
- **user** (`/vergil:steering-audit user`): `~/.claude/CLAUDE.md` and
  `~/.claude/settings.json`, once per cycle. Read-only and interactive only:
  the skill writes no file of any kind, the human makes every change on the
  host, and findings never go to GitHub or intake. The only public record is
  the date and counts.

It does not read or depend on memory, and it does not run `/doctor
prompt-audit`, which stays an optional check the human can run by hand.

**When to use.** At least quarterly, and whenever a Claude Code release changes
settings or instruction-file behavior — "audit steering files", "review
CLAUDE.md", "review Claude settings", "steering audit".

**Status.** Current (Vergil 2.1), added in epic
[vergil-project/.github#558](https://github.com/vergil-project/.github/issues/558).

## hoshin

**What it does.** USER-identity skill that runs the fleet's 方針管理 hōshin
kanri review cadence and writes its public logbook, the
`docs/site/docs/logbook/` tree of `vergil-project/docs`.
`/vergil:hoshin start` works out from the date (in the time zone the
logbook records) and the logbook which reviews are due: it closes any
period left open, by a late `end` review or a "not performed" entry, runs
the daily 朝礼 chōrei, then opens any new year, quarter, month or week from
the largest level down, and names any week or longer period with no
entries. `/vergil:hoshin end` closes the day (終礼 shūrei), and
`end <week|month|quarter|year>` closes that period with every smaller one
still open. Each review runs its level's checklist with the human, ends
with a kaizen prompt, and leaves one dated entry. The daily review's
failed and cancelled runs check reads each org's operations queue, the
ops issues under `Epic (operations): <org>` in `<org>/.github` that the
reporter (`vrg-ops-report`) files and comments on for each unattended
job's failures, cancels and recoveries. GitHub Actions run history is a
backstop, for runs that never reported, shown under a separate
"Not reported" heading; the security-signal jobs of the `ops.yml` audit
file no ops issue, so their runs are their only source. An org with no
operations epic, or with more than one, is flagged rather than shown as
clean. The daily review also
shows two trust checks, in the terminal only: the outsider report
(`vrg-epic-audit --untrusted`), which lists what accounts outside the
trusted roles did in each Vergil org since the last daily review, by
metadata and links only and with possible tampering first; and the
trusted-authors configuration audit, which reports each org's latest
nightly `trusted-authors-check` job and compares its
`trusted-authors-values` artifact with `vrg-trusted-authors render` of the
host configuration, naming any drifted org variable. Follow-ups are filed in
the run: a security finding as a security record, and any other only
after the security screen and the human's approval of its text.

Each run hands off one docs PR: a `Logbook: <date> <mode>` task for the docs
repo under the org's hoshin epic, a worktree, the entries and index lines, `vrg-validate`,
a mechanical security screen of the final text, the human's approval of the
full text, a `docs(logbook)` commit, a [merge review](#merge-review) and
`vrg-pr-workflow report-ready`, with fixed wording that names only the
files written, then its own `vrg-submit-pr`. A run that stops
before its commit offers edit (back through validation, the screen and the
approval) or abandon (the task closed, the worktree removed). The rules are
in its `references/`: the calendar, the logbook and its wording, and the
security rules with the screen's patterns.

**The logbook PR runs merge review like every PR**, after the commit and
before `report-ready`, and its eligibility line goes into report-ready's
notes. The gates that keep
security content out of the public logbook still run inside the skill
before anything is pushed. The run then submits the logbook PR itself
with `vrg-submit-pr`, never with `--release`, like the other docs PRs: the
human's approval of the full text is the review's sign-off, and releases
stay human actions. Its task closes through the `vrg-finalize-pr` that
submit always runs; a PR that does not merge is watched and fixed by
[pr-watch](#pr-watch), which merge-reviews each fix like any other. A logbook task lives under the hoshin epic, which
[epic-implement](#epic-implement) and [issue-implement](#issue-implement)
refuse.

**When to use.** At the start of each working day, `/vergil:hoshin start`
("start the day", "hoshin start"); and, when the human chooses,
`/vergil:hoshin end` ("end of day") or `/vergil:hoshin end <level>`
("close the week", "close the month"). Run it from one dedicated, reused
session.

**Status.** Current (Vergil 2.1), added in epic
[vergil-project/.github#1318](https://github.com/vergil-project/.github/issues/1318).

## How skills work — technical

Each skill is a directory under `skills/` containing:

- **`SKILL.md`** — required. Frontmatter with `name` and
  `description`, followed by the skill's body (context, workflow,
  templates, etc.).
- Optional supporting files (templates, examples) referenced from
  `SKILL.md`.

The plugin's `skills/` directory is loaded on session start. The
skill `name` in the frontmatter plus the plugin's namespace
(`vergil`) determines the invocation: a skill named
`issue-implement` in this plugin is invoked as
`/vergil:issue-implement`.

Skills are documentation-as-config, not executable scripts. They
tell Claude Code *how* to run a workflow; Claude Code executes
the flow using whatever tools the user has granted.
