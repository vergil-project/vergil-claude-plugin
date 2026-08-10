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
| [triage-capture](#triage-capture) | Capture an uncurated idea/bug/to-do into the intake queue as a triage/idea/research issue, paraphrasing voice-to-text into clean prose | Current (2.1) |
| [triage-review](#triage-review) | Groom the triage intake queue — route each uncurated issue into the epic/task model (periodic ~weekly pass) | Current (2.1) |
| [migrate-repo](#migrate-repo) | Migrate a repo's existing open-issue backlog into the epic/task framework — guided, resumable, human-in-the-loop | Current (2.1) |
| [memory-init](#memory-init) | Set up or refresh a project's memory directory — create/update `MEMORY.md` with the human-approval policy header | Current |
| [memory-audit](#memory-audit) | Review memory files collaboratively with the human — verify each entry, assess staleness, route to the correct scope | Current |
| [handoff](#handoff) | Capture work state before stopping and restore it on resume, preserving context across sessions | Current |

The three `epic-*` skills form the **epic lifecycle**: `epic-create` (run once) →
`epic-implement` (run N times) → `epic-retrospective` (run once — the terminal
gate that closes the epic).

## epic-create

**What it does.** USER-identity skill and the **entry point** for non-trivial
work. It opens into brainstorming, runs the front-loaded pipeline
(brainstorm → pushback → writing-plans → alignment), creates the finite epic in
its resolved home, seeds the **bookend tasks** — documentation,
documentation-review, and the terminal **retrospective** — and publishes the
spec + plan as a docs PR.

**When to use.** At the start of significant work — "let's build X", "start an
epic for this". If the work collapses to a single PR, it is a task, not an epic.

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
`vrg-pr-workflow report-ready` for `vrg-submit-pr` to consume. A
run-and-done hand-off: it records the metadata and the human opens the
PR.

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

## triage-capture

**What it does.** Captures an uncurated idea, bug, or to-do into the intake
queue so it is never lost, creating an intake issue — `triage` (a problem
not yet understood), `idea` (a spark), or `research` (a reproducible
investigation) — in the org `.github`, paraphrasing voice-to-text into clean
written prose.

**When to use.** Whenever the human says "don't forget X", "capture this",
"note a todo", or riffs an idea to come back to later — especially mid-task
or via voice.

**Status.** Current (Vergil 2.1).

## triage-review

**What it does.** Grooms the triage intake queue — collects every
`triage`-labelled issue across the org and walks the human through
dispositioning each one into the epic/task model.

**When to use.** For the periodic (roughly weekly) intake pass — "review
triage", "groom the backlog", "process the triage queue".

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

## memory-init

**What it does.** Sets up or refreshes a project's memory directory —
creates or updates `MEMORY.md` with the human-approval policy header.

**When to use.** When the human asks to initialize, set up, bootstrap, or
update memory ("init memory", "set up MEMORY.md", "refresh the memory
header").

**Status.** Current.

## memory-audit

**What it does.** Reviews memory files collaboratively with the human —
verifies each entry, assesses staleness, and routes it to the correct scope
(repo memory, global instructions, or a tooling issue) with human approval.

**When to use.** When the human asks to audit, review, clean up, or prune
memory ("audit my memory", "review MEMORY.md", "are these memories still
accurate").

**Status.** Current.

## handoff

**What it does.** Captures work state across sessions — preserves context
before you stop (`/handoff stop`) and restores where you left off on resume
(`/handoff start`).

**When to use.** When wrapping up and you want to preserve context for next
time, or when picking work back up in a new session.

**Status.** Current.

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
