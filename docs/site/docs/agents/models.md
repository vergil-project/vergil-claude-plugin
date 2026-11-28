# Model map

This page is the single source for the model each of the plugin's skills
and agents runs on, and why. The models are chosen by design, by
judgment rather than measurement: each piece runs on the smallest model
that can do its hardest part. Opus stays where the design thinking is,
Sonnet drives most of the work, and Haiku writes the changes. The design
is epic
[vergil-project/.github#1823](https://github.com/vergil-project/.github/issues/1823)
(model-tiering).

Every change to a pin updates this page in the same PR.
`scripts/bin/validate-custom` checks the agents table below against the
`model:` line of every file in `agents/`.

## How a model can be pinned

These are facts from the Claude Code documentation for
[skills](https://code.claude.com/docs/en/skills) and
[sub-agents](https://code.claude.com/docs/en/sub-agents), checked on
2026-11-27:

- **A skill's frontmatter `model:` is weak.** It sets the model only for
  the turn when the human runs the skill with `/name`. When Claude runs
  the skill, the session keeps its model, so a skill invoked by another
  skill, or inside a subagent, ignores it. No skill in this plugin sets
  one.
- **A skill with `context: fork`** runs in a new subagent, and its
  `model:` becomes that subagent's model. The subagent has no
  conversation history and runs in the background by default, so it
  cannot hold a conversation with the human.
- **An agent definition's `model:`** (an alias such as `sonnet`, `opus`
  or `haiku`, a full model ID, or `inherit`) pins the subagent reliably.
- **Precedence**, first match wins: the Agent call's per-invocation
  `model` parameter, then the agent definition's `model:`, then the
  `CLAUDE_CODE_SUBAGENT_MODEL` environment variable, then the parent's
  model.
- **Nesting.** A subagent may spawn subagents up to three levels below
  the main conversation, so main session, task driver, then writer or
  reviewer fits.

So a model can be pinned only on a piece that runs as a subagent.
Interactive skills run in the human's session and keep its model.

## Agents

| Agent | Model | Reason |
| --- | --- | --- |
| `vergil:bootstrap` | `haiku` | Runs fixed, read-only checks and prints a status report. |
| `vergil:implementer` | `haiku` | Writes a task's changes, code and prose alike, from a detailed issue and plan, and validates them to green; the driver checks its result and merge review gates every change. |
| `vergil:merge-reviewer` | `sonnet` | Judges whether a change is good enough to merge. It stays a tier above the Haiku writer whose work it reviews, for every PR, the docs PRs of `epic-create`, `epic-retrospective` and `hoshin` included. |
| `vergil:task-runner` | `sonnet` | Drives one task run of `issue-implement`, `issue-validate` or `issue-deploy`: the long procedure, the gates and the rulings, which Sonnet follows reliably. |
| `paad:paad-delegate` | `opus`, passed by the dispatch | Runs adversarial design-review rounds, where the big thinking is. The paad fork pins no model, so each design-review dispatch passes a per-invocation `model: opus`. |
| `paad:paad-analyst` | `inherit` | Dispatched by `paad:paad-delegate`, so it inherits Opus from it; its analysis is part of the design review. |

`vergil:task-runner` has no `tools:` line, so it inherits the full tool
set (it needs Agent and Skill). `vergil:implementer` has Read, Edit,
Write, Glob, Grep and Bash, and never Agent; `validate-custom` pins that
list, as it pins the merge reviewer's.

## The helper model rule

Every helper a skill dispatches carries an explicit per-invocation
`model`, named in the skill's text:

- a read-only search or exploration helper: `haiku`;
- a design-review delegate: `opus`;
- any other helper: `sonnet`.

The one exception is `issue-validate`'s subagent that loads a skill to
check it: it runs on the skill's validation alias from the table below,
passed per invocation, so the check sees the skill as it runs in
production.

## Skills

A skill runs on the model of wherever it runs. Skills the human runs
stay on the session's model (Opus by default). A skill that runs in more
than one place has one row per place. Its **validation alias** is the
model `issue-validate` checks it on: the smallest model it runs on in
any production path, or `opus`, the session's default, for a skill that
runs only on the session's model.

| Skill | Where it runs | Model there | Validation alias |
| --- | --- | --- | --- |
| `issue-implement` | a task run, as `vergil:task-runner` | `sonnet` | `sonnet` |
| `issue-implement` | the human's session, run with `/issue-implement` | session | `sonnet` |
| `merge-review` | inside an `issue-implement` driver | `sonnet` | `sonnet` |
| `merge-review` | the human's session, under `issue-implement` or a docs-PR skill (`epic-create`, `epic-retrospective`, `hoshin`) | session | `sonnet` |
| `pr-watch` | inside an `issue-implement` driver | `sonnet` | `sonnet` |
| `pr-watch` | the human's session, standalone or under a docs-PR skill | session | `sonnet` |
| `issue-deploy` | a task run, as `vergil:task-runner` | `sonnet` | `sonnet` |
| `issue-deploy` | the human's session | session | `sonnet` |
| `issue-validate` | a task run, as `vergil:task-runner` | `sonnet` | `sonnet` |
| `issue-validate` | the human's session | session | `sonnet` |
| `epic-implement` | the human's session | session | `opus` |
| `fixture-run` | its caller's session | caller's model | `opus` |
| `epic-create` | the human's session | session | `opus` |
| `epic-retrospective` | the human's session | session | `opus` |
| `epic-review` | the human's session | session | `opus` |
| `hoshin` | the human's session | session | `opus` |
| `steering-audit` | the human's session | session | `opus` |
| `summarize` | the human's session | session | `opus` |
| `deprecation-triage` | the human's session | session | `opus` |
| `intake-capture` | the human's session | session | `opus` |

Under an `issue-implement` driver, every change to the task's tracked
files is written by `vergil:implementer` on Haiku, whatever the driver's
model, the human-run path included.

`epic-implement`'s own session mostly waits on the task runs it
dispatches, so it costs little on any model and is not pinned. The human
may run it on Sonnet by switching the session's model with `/model`.

## Changing or reverting a pin

Each pin is a one-line change:

- an agent's pin is the `model:` line of its file in `agents/`;
- a dispatch's pin is the `model` the skill's text passes on the Agent
  call.

Change the pin and the matching row on this page in the same PR.
`validate-custom` fails if an agent's `model:` and its row here differ.
A `vergil:task-runner` dispatch never passes a per-invocation `model`,
since it would outrank the agent's pin. Likewise a `vergil:implementer`
dispatch passes no `model` on its first try, and only the escalation
retry passes `model: "sonnet"`. The
[`guard-task-dispatch` hook](../hooks/index.md#guard-task-dispatch)
refuses a `vergil:implementer` dispatch with any other model.

## Not verified

Two paths cannot be triggered on demand, so they are recorded here as
not verified until a real run shows them:

- **The writer's escalation.** When the writer fails (a `stuck` result,
  or a `green` that fails the driver's check), the driver dispatches it
  once more with a per-invocation `model: "sonnet"`, the one form the
  `guard-task-dispatch` hook allows for the writer. No transcript has yet
  shown that retry running on Sonnet.
- **`epic-implement`'s re-entries.** When a task's PR needs fixing or
  watching after its run, `epic-implement` dispatches a task run of
  `issue-implement` rather than working in its own session. This path is
  not verified until the epic's validation task observes one.

## Wave 2

The follow-on candidates, each proposed as a planning item and filed as
the human approves:

- **A pipeline of pinned phases for `issue-implement`**: preflight,
  write, merge review, handoff and watch, each its own pinned subagent,
  once the driver-and-writer split has proved itself.
- **`issue-deploy` and `issue-validate`**: split their mechanical steps
  onto Haiku.
- **`pr-watch`**: separate the wait-and-report loop from the diagnosis.
- **`fixture-run`**: move its rule-following filing to a pinned agent or
  a forked skill, on Haiku or Sonnet.
- **Human-run skills judged below Opus** (`epic-review`, `hoshin`,
  `summarize`, `epic-retrospective`, `intake-capture`): which parts can
  run as forked or agent pieces without losing the conversation with the
  human.
- **`epic-implement`**: whether its orchestration can run in a pinned
  subagent.
