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

Human judgment is spent **up front** (brainstorm → pushback → alignment)
and at the **hard gates** (PR submit, merge, release). Between those,
agents run these skills by the most efficient means available —
**sub-agents are encouraged** for research fan-out and parallel work —
and only stop mid-flight for a problem they cannot resolve. The plugin
no longer tunes agent behavior for continuous human observability; that
older "Continuous Oversight" model is retired. The never-fabricate and
never-suppress-a-gate rules are unaffected.

## Skill catalogue (at a glance)

| Skill | Purpose | Status |
|---|---|---|
| [epic-create](#epic-create) | USER agent: the run-once entry point for non-trivial work — brainstorm → spec → plan, create the epic and seed its bookend tasks | Current (2.1) |
| [epic-implement](#epic-implement) | USER agent: drive an epic's tasks to their human gates — resume from the epic issue + plan, work the runnable frontier (sub-agents encouraged), batch what needs the human; drafts the terminal retrospective for the human to submit | Current (2.1) |
| [epic-retrospective](#epic-retrospective) | USER agent: the run-once terminal finishing gate — draft the epic's backward-looking retrospective, whose docs PR closes the epic | Current (2.1) |
| [issue-implement](#issue-implement) | USER agent: implement an issue (locally or on a cloud VM), validate to green, record the PR metadata, hand off to the human | Current (2.1) |
| [issue-deploy](#issue-deploy) | USER agent: run a `deployment` task — install/sync merged changes so they're usable, then record the outcome as a comment | Current (2.1) |
| [issue-validate](#issue-validate) | USER agent: run a `validation` task — a live check whose acceptance is a recorded PASS/FAIL comment, not a code change | Current (2.1) |
| [pr-watch](#pr-watch) | USER agent: monitor the open PR through CI/review and reconcile feedback until mergeable | Current (2.1) |
| [deprecation-triage](#deprecation-triage) | Triage deprecation warnings into tracking issues | Current (reviewed 2026-04-23, no changes) |
| [summarize](#summarize) | Decision / operation / stream-of-consciousness summaries; SOC mode is the canonical capture for the fleet | Current |
| [intake-capture](#intake-capture) | Capture an uncurated idea/bug/to-do into the intake queue with `vrg-intake-create` — no kind or category step — paraphrasing voice-to-text into clean prose | Current (2.1) |
| [intake-review](#intake-review) | Review the intake queue oldest first in batches of 4 and route each item (drop, defer to the deferred queue, one-off, split, planning) with `vrg-intake-route` | Current (2.1) |
| [migrate-repo](#migrate-repo) | Migrate a repo's existing open-issue backlog into the epic/task framework — guided, resumable, human-in-the-loop | Current (2.1) |
| [deferred-review](#deferred-review) | Review the deferred queue in batches of 4 — re-check each item's revival conditions against the current state and recommend keep, refresh, revive, or drop | Current (2.1) |
| [planning-review](#planning-review) | USER agent: rank the planning queue with the human and pick what to expand next with `epic-create`; defer, drop, or leave the rest with `vrg-intake-route`. Core rule: plan only what you mean to implement soon | Current (2.1) |
| [steering-audit](#steering-audit) | Review the Claude Code steering and settings files against the ownership model: re-verify its platform facts, run mechanical checks and a findings-only `/paad:pushback`, then walk each finding with the human. `steering-audit user` reviews the user-level files read-only | Current (2.1) |

The three `epic-*` skills form the **epic lifecycle**: `epic-create` (run once) →
`epic-implement` (run N times) → `epic-retrospective` (run once — the terminal
gate that closes the epic).

## epic-create

**What it does.** USER-identity skill and the **entry point** for non-trivial
work. It opens into brainstorming, runs the front-loaded pipeline
(brainstorm → pushback → writing-plans → alignment), creates the finite epic in
its resolved home, seeds the **bookend tasks** — documentation,
documentation-review, and the terminal **retrospective** — and publishes the
spec + plan as a docs PR. Every run is tracked in a **planning issue** (an open
child of the planning epic): it is entered from a planning issue, an intake
issue (pulled into planning), a deferred issue (pulled back into planning after
its `Revisit when:` conditions are checked), a free-text idea (a new planning
issue), or with no argument (a `vrg-queue planning` summary). It labels the item `in-progress`,
records progress comments with the `Epic:` / `Docs task:` / `Tasks filed: yes`
markers, and closes the planning issue once the epic is fully expanded (docs PR
merged, tasks filed). For a `security` planning issue, it hands each advisory
to the task or tasks that fix it or, for a design-only finding, the
documentation task, with one `vrg-security-record retarget` per advisory,
before posting `Tasks filed: yes`, and the planning issue cannot close until
every advisory is handed off (see
[Security items in planning](https://vergil-project.github.io/vergil-tooling/latest/guides/security-records/#security-items-in-planning)).

**When to use.** At the start of significant work — "let's build X", "start an
epic for this" — or to resume a paused planning session. If the work collapses
to a single PR, it is a task, not an epic.

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

**When to use.** In the user-agent session, to start or resume work on an
epic as a whole rather than one issue at a time — "implement epic #N",
"pick up epic X where we left off".

**Boundaries.** It never opens PRs, never merges, and never runs `pr-watch`
(a human-triggered exception). It **drafts** the terminal retrospective via
`epic-retrospective` but never submits or merges its PR — the retrospective's
docs PR is the final gate, and PR submit/merge stays a human gate.

**Status.** Current (Vergil 2.1). First exemplar of the Front-Loaded
Judgment, Trusted Execution doctrine.

## epic-retrospective

**What it does.** USER-identity skill and the **terminal finishing gate** of the
epic lifecycle. Run once, at the end: its preflight refuses to run until every
other child of the epic is closed, then it drafts `retrospective.md` — the
backward-looking record that partners the spec and plan (spec → plan →
retrospective) — from the execution history, runs a draft → review loop with the
human, and hands off the closing docs PR whose merge **closes the epic**.

**When to use.** To finish an epic — "run the retrospective", "close out this
epic", "we're done with this epic".

**Status.** Current (Vergil 2.1).

## issue-implement

**What it does.** USER-identity skill. Implements a GitHub issue on
its feature branch, validates to green via `vrg-validate`, then records
the PR metadata (`.vergil/pr-workflow.json`) with
`vrg-pr-workflow report-ready` for `vrg-submit-pr` to consume.
`report-ready` also pushes the branch to origin, so there is no separate
push step. A run-and-done hand-off: it publishes the branch, records the
metadata, and the human opens the PR. It refuses an issue whose native parent is the intake,
planning or deferred epic (route it with `intake-review`, expand it with
`epic-create`, or revive it with `deferred-review` first), mirroring the
PR tooling's refusal.

**When to use.** In the user-agent session, to take an issue from
implementation through the point where the human opens the PR. The same
flow runs on a cloud VM: `report-ready` pushes a world-readable **relay
ref** carrying the ready-state, so the Mac no longer needs the VM's
filesystem, and the human opens the PR worktree-free with
`vrg-submit-pr <branch> [<branch> …]`. (This retired the former
`issue-localize` skill, which reconstructed the ready-state locally
before the relay existed — epic
[vergil-project/.github#148](https://github.com/vergil-project/.github/issues/148).)

**Status.** Current (Vergil 2.1). Requires the 2.1 tooling CLIs
(`vrg-pr-workflow`, etc.) at runtime.

## issue-deploy

**What it does.** USER-identity skill. Runs a `deployment`-labelled task
end to end: installs or syncs the merged change so it is actually usable
(install / sync / release-then-install), then records the result as an
`Outcome:` comment on the issue. It is *run*, not built — there is no PR,
and the deployment tooling refuses one.

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

## pr-watch

**What it does.** USER-identity post-PR loop, emitted by
`vrg-submit-pr`. Monitors the open PR via `vrg-pr-await` and
reconciles failing CI checks and human review feedback, pushing
fixes until the PR is mergeable.

**When to use.** Run the emitted `/vergil:pr-watch <PR_URL>` line in
the USER agent session after the human opens the PR.

**Status.** Current (Vergil 2.1).

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
in the current repo's queue home (the org `.github` for a public repo, the repo
itself for a private one) and links it under that home's intake epic as it is
created. There is no kind or category step: membership in the intake queue is
the item's state. Voice-to-text input is paraphrased into clean written prose.
Renamed from the triage capture skill in epic
[vergil-project/.github#176](https://github.com/vergil-project/.github/issues/176).

**When to use.** Whenever the human says "don't forget X", "capture this",
"note a todo", or riffs an idea to come back to later — especially mid-task
or via voice.

**Status.** Current (Vergil 2.1).

## intake-review

**What it does.** Reviews the intake queue and routes every item into the
epic/task model. It lists the queue with `vrg-queue intake` (oldest first),
checks each item's current state (an overlapping or closed issue, a bug that is
already fixed), and presents batches of 4 with one paragraph per item and a
recommended route. The human confirms each batch in one reply, and the agent
applies it with `vrg-intake-route`: **drop**, **defer** (move the item to the
deferred queue with a required reason and revival conditions, for
`deferred-review` to bring back), **one-off** (move into
a repo's ad-hoc or finite epic, transferring the issue or recreating it when
GitHub refuses the transfer), **split** (into tasks made with
`vrg-issue-create`), or **planning** (hand to `epic-create`). The agent closes
dropped and split items itself. Leaving an item in intake for the next review
is also an outcome, for items that will be ready within days. Renamed from the
triage review skill in the same epic.

**When to use.** For the periodic intake pass — "review intake", "groom the
backlog", "process the intake queue", "what's in intake" (and the older
"review triage" phrasings).

**Status.** Current (Vergil 2.1).

## migrate-repo

**What it does.** Migrates a repo's existing open-issue backlog into the
epic/task framework: triages the pile into epics, tasks, ad-hoc work, and
closeable issues so the roadmap and audit reflect reality. Guided,
resumable, batch-approved, human-in-the-loop.

**When to use.** When onboarding a repo's backlog into the framework —
`migrate <repo>`, `bring <repo> into the framework`, or "onboard this repo's
backlog".

**Status.** Current (Vergil 2.1).

## deferred-review

**What it does.** Reviews the deferred queue, where evaluated items wait for
their revival conditions. It lists the queue with `vrg-queue deferred` (least
recently deferred first), rereads each item's latest deferral comment, and
**actually checks** its `Revisit when:` conditions against the world — release
pages, issue and PR states, dates, upstream status. It presents batches of 4,
each item with what was checked, what was found, and one recommended outcome:
**keep** (no change), **refresh** (re-defer in place with an updated reason and
conditions), **revive** (to intake, planning, or a one-off, guided by the
`Deferred from:` line), or **drop**. The human confirms each batch in one
reply, and the agent applies it with `vrg-intake-route`. A condition it cannot
verify is reported as such, with a keep recommendation. Added in epic
[vergil-project/.github#508](https://github.com/vergil-project/.github/issues/508).

**When to use.** For the periodic deferred pass — "review deferred", "what's
deferred", "revisit the backlog", "process the deferred queue".

**Status.** Current (Vergil 2.1). Requires the deferred-queue tooling
(`vrg-queue deferred`, and `vrg-intake-route` with `defer --revisit-when` and
the `intake` route) at runtime.

## planning-review

**What it does.** Decides, with the human, **what to plan next**. It lists the
planning queue with `vrg-queue planning`, surfaces `in-progress` items first
(each with its latest progress note, offering to resume it with `epic-create`
or defer it), then ranks the waiting items by priority and importance in
conversation with the human. There is no scoring formula. Each item gets one
outcome: **pick** (hand to `epic-create <ref>`), **defer**
(`vrg-intake-route <ref> defer --reason … --revisit-when …`, refused when an
`Epic:` marker is recorded), **drop** (`vrg-intake-route <ref> drop --reason …`),
or **leave** (for items expected to be ready within days or a week).

Its core rule is the planning doctrine: **plan an epic only when you mean to
implement it soon.** A plan left sitting goes stale and needs a conceptual
rebase onto everything built since, so the skill discourages picking more than
near-term capacity allows.

**When to use.** "review planning", "what should we plan next", "prioritize the
planning queue". To work one known item, go straight to `epic-create <ref>`.

**Status.** Current (Vergil 2.1), added in epic
[vergil-project/.github#508](https://github.com/vergil-project/.github/issues/508).
It starts simple and is expected to evolve with use.

## steering-audit

**What it does.** The judgment layer of the recurring steering review, checked
against the
[Claude config ownership model](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/claude-config-ownership.md)
(the nightly `vrg-github-repo-config audit` is the mechanical layer). It
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
