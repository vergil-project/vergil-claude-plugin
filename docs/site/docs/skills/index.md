# Skills

Skills are shared workflow definitions that Claude Code loads from
the plugin. Each skill is a directory under `skills/` containing a
`SKILL.md` file with frontmatter and structured instructions. All
skills are namespaced under `vergil` and invoked as
`/vergil:<skill-name>`.

Each entry below covers what the skill does, when to use it, and
its current status — including any tracked work that will
substantially change it.

## Skill catalogue (at a glance)

| Skill | Purpose | Status |
|---|---|---|
| [issue-implement](#issue-implement) | USER agent: implement an issue, validate to green, drive the PR-workflow oracle, hand off to the human (local audit opt-in) | Current (2.1) |
| [issue-audit](#issue-audit) | AUDIT agent: review the change delta read-only via the oracle loop, report verdicts (opt-in; experimental) | Current (2.1) |
| [pr-watch](#pr-watch) | Post-PR loop — monitor/reconcile (USER) or re-review and gate (AUDIT) | Current (2.1) |
| [deprecation-triage](#deprecation-triage) | Triage deprecation warnings into tracking issues | Current (reviewed 2026-04-23, no changes) |
| [summarize](#summarize) | Decision / operation / stream-of-consciousness summaries; SOC mode is the canonical capture for the fleet | Current |

## issue-implement

**What it does.** USER-identity skill. Implements a GitHub issue on
its feature branch, validates to green via `vrg-validate`, then drives
the `vrg-pr-workflow` oracle to record the PR metadata
(`.vergil/pr-workflow.json`) that `vrg-submit-pr` consumes. Runs
without the local dual-agent audit by default; passing `audit` engages
the paired audit handshake.

**When to use.** In the user-agent session, to take an issue from
implementation through the point where the human opens the PR.

**Status.** Current (Vergil 2.1). Requires the 2.1 tooling CLIs
(`vrg-pr-workflow`, etc.) at runtime.

## issue-audit

**What it does.** AUDIT-identity skill. Reviews a paired USER agent's
delta read-only, running one judgment check per round-trip via
`vrg-pr-workflow` and reporting each verdict. Never edits code.

**When to use.** In the audit-agent session, paired with
`issue-implement` when the user opted into the local audit — an
experimental mechanism that is off by default.

**Status.** Current (Vergil 2.1); experimental, off the default path.

## pr-watch

**What it does.** Identity-keyed post-PR loop, emitted by
`vrg-submit-pr`. As USER, monitors the PR via `vrg-pr-await` and
reconciles CI/audit/human feedback; as AUDIT, re-reviews and posts
the `vergil-audit/approved` gate via `vrg-audit-approve`.

**When to use.** Paste the emitted one-liner into both agent
sessions after the human opens the PR.

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
