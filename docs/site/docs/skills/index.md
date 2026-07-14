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
| [epic-implement](#epic-implement) | USER agent: drive an epic's tasks to their human gates — resume from the epic issue + plan, work the runnable frontier (sub-agents encouraged), batch what needs the human, hand off the closing brainstorm | Current (2.1) |
| [issue-implement](#issue-implement) | USER agent: implement an issue, validate to green, record the PR metadata, hand off to the human | Current (2.1) |
| [issue-localize](#issue-localize) | USER agent: reconstruct a remotely-completed branch's submit-ready state locally for `vrg-submit-pr` | Current (2.1) |
| [pr-watch](#pr-watch) | USER agent: monitor the open PR through CI/review and reconcile feedback until mergeable | Current (2.1) |
| [deprecation-triage](#deprecation-triage) | Triage deprecation warnings into tracking issues | Current (reviewed 2026-04-23, no changes) |
| [summarize](#summarize) | Decision / operation / stream-of-consciousness summaries; SOC mode is the canonical capture for the fleet | Current |

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

**Boundaries.** It never opens PRs, never merges, never runs `pr-watch`
(a human-triggered exception), and never runs or closes the closing
brainstorm — the final human gate.

**Status.** Current (Vergil 2.1). First exemplar of the Front-Loaded
Judgment, Trusted Execution doctrine.

## issue-implement

**What it does.** USER-identity skill. Implements a GitHub issue on
its feature branch, validates to green via `vrg-validate`, then records
the PR metadata (`.vergil/pr-workflow.json`) with
`vrg-pr-workflow report-ready` for `vrg-submit-pr` to consume. A
run-and-done hand-off: it records the metadata and the human opens the
PR.

**When to use.** In the user-agent session, to take an issue from
implementation through the point where the human opens the PR.

**Status.** Current (Vergil 2.1). Requires the 2.1 tooling CLIs
(`vrg-pr-workflow`, etc.) at runtime.

## issue-localize

**What it does.** USER-identity skill. Takes a **remotely-completed**
branch — implemented on a cloud VM and pushed to origin — and makes it
**submit-ready on the local host**. It is the tail of `issue-implement`
applied to work done elsewhere: it skips implementation and does the
same validate → `report-ready` → hand off. Because `.vergil/` is
gitignored, the PR-ready state never rides the push and is stranded on
the cloud VM's volume; rather than fetch it, this skill **regenerates**
the PR metadata locally from the durable inputs (the pushed branch + the
issue), so it stays fully decoupled from the cloud with no new
infrastructure. Accepts an issue number or a branch name (one branch per
issue, so it is unambiguous).

**When to use.** In the user-agent session, when a remote/cloud agent
already pushed an issue's branch but the local worktree has no
`.vergil/pr-workflow.json` for `vrg-submit-pr` to read.

**Status.** Current (Vergil 2.1). Requires the 2.1 tooling CLIs
(`vrg-pr-workflow`, etc.) at runtime.

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
