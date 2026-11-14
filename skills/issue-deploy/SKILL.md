---
name: issue-deploy
description: Run a deployment task end-to-end as the USER agent — a `deployment`-labelled issue that installs/syncs merged changes so they are usable, then records the result as a comment. Use when the human asks to deploy, install, roll out, or sync merged work ("deploy #129", "run the deployment", "sync the labels"), or when issue-implement redirects a deployment-labelled issue here. You run the agent-safe deploy steps, hand each human-run step (one that needs a human identity) to the human and verify it, record SUCCESS/FAILURE, and close only on SUCCESS — no worktree, no commits, no PR, and never a release. Run as the vergil-user agent.
---

# Issue Deploy

Run a **deployment task** to completion and record the result — the act of
taking merged changes and getting them *deployed and usable* in the environment,
the step between an implementation task (merged) and a validation task
(verified). Deployment is one **operational task** kind: it follows the shared
[operational-task lifecycle](../issue-validate/references/operational-task-lifecycle.md)
(preflight → preconditions gate → run → record `Outcome:` → close-on-success /
hold-open-on-failure). Below is the deployment-specific detail.

Sibling skills, deliberately different:

| | `issue-implement` | `issue-validate` | `issue-deploy` (this) |
|---|---|---|---|
| Goal | Write code | *Verify* it works | *Make it usable* (deploy) |
| Workspace | Worktree + PR | None | None — touches no code |
| Terminal state | PR handoff | SUCCESS/FAILURE comment | SUCCESS/FAILURE comment |
| On failure | Fix in place | File a fix task | **Retry** (idempotent), then fix task |

If the issue is **not** `deployment`-labelled, stop: a `validation` issue goes to
`issue-validate`; anything non-operational goes to `issue-implement`.

## Never fabricate a result

If you cannot actually run a step, say so and stop — **never fabricate or
partially fake a result.** A step the issue lists as human-run is the
exception: hand it to the human as
[below](#hand-the-human-run-steps-to-the-human-then-verify-them). Use whatever means are efficient to run it (sub-agents
encouraged); oversight is front-loaded and at the hard gates, not in a live
transcript (the **Front-Loaded Judgment, Trusted Execution** doctrine; see the
[execution doctrine](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/site/docs/skills/index.md#execution-doctrine--front-loaded-judgment-trusted-execution)). If you hit a problem you cannot resolve, stop and ask.

## Preflight

1. Confirm you are the **USER** agent: `[ "$(vrg-whoami --mode)" = user ] && echo ok || echo "not user"`
   must print `ok`.
2. Confirm the issue carries the **`deployment`** label
   (`vrg-gh issue view <N> --json labels`). If not, this is the wrong skill.
   If it carries `epic` or `archive`, stop: it is an umbrella, not a task
   (`<ref> is an epic, not a task` / `<ref> is an archive, not a task`); to
   drive an epic's tasks, use `epic-implement`. If the labels cannot be read,
   say so and stop.
3. Read the issue body — a self-contained scaffold: **preconditions**, **deploy
   steps**, any **human-run steps**, **acceptance criteria**, and a **results
   template**.

## Preconditions gate — release is a precondition, not your job

Work the issue's **Preconditions** first. Deployment has one that matters
especially:

- **A required release is a human-gated precondition.** Where deploying needs a
  release (bump → main → tag → publish), that release is performed by a human —
  the same policy that makes agents hand off `vrg-submit-pr` and never merge or
  finalize. **`issue-deploy` never cuts a release.** Confirm (attest) the release
  is published; do not perform it.
- Confirm the target is reachable.

**If any precondition is unmet:** comment `blocked: preconditions not met —
<which>` and **stop** — do not run the deploy, do not close. Never fabricate.

## Run the deploy steps (agent-safe, idempotent)

Run the issue's **Deploy steps** against the target — install, sync, restart, and
the like. They are idempotent by design, so a re-run is safe. Capture the real
output for evidence. You touch no code and open no PR.

## Hand the human-run steps to the human, then verify them

Some deploy steps cannot run under an agent identity. The scaffold lists them
in a **Human-run steps (need a human identity)** section; with no such section,
every step is agent-safe. For example, `vrg-github-repo-config apply` needs
`administration=read` and refuses under an agent identity.

**Never run a human-run step under the agent identity**, not even to show that
it fails, and never report the task `blocked` because the agent cannot run
one. That the agent cannot run it is why it is listed; it is not an unmet
precondition. Work the human-run steps in the order the issue gives them,
after the agent-safe deploy steps. For each one:

1. **Check its preconditions** with agent-runnable checks: the merged change
   is present, the target is reachable, and whatever else the step names. If
   one is unmet, handle it as the [preconditions gate](#preconditions-gate--release-is-a-precondition-not-your-job)
   says.
2. **Hand it to the human.** Give the exact, paste-ready command, filled in
   for this task with no placeholder left, as a `! <command>` line the human
   runs in the session so its output reaches you. Say what it needs (the
   human identity, the scope) and what a good result looks like.
3. **Wait** for the human to run it. Do not go on to the next step, and do
   not post the result, until they have.
4. **Verify it** with the step's check, as the issue names it, against the
   real output: the exit status and output of the human's run, and any
   agent-runnable check the step adds. Record which evidence came from the
   human's run and which from your own.

For repo config, the check is the human's `vrg-github-repo-config apply`
exiting 0: `apply` refuses, exiting 2 and writing nothing, when it cannot read
every setting first. A `vrg-github-repo-config diff` you run afterwards is
informational only. Under the agent identity `diff` exits 2, because it does
not check the admin-scoped settings. That is expected and is not a failure of
the apply: never treat `diff`'s exit code as the verdict on an apply.

The human's run is then evidence like any other step's: judge it against the
acceptance criteria and [record the result](#record-the-result-and-close). A
human-run step that fails is a FAILURE, handled as below, and its retry is the
human's to run. If the human declines a step or cannot run it, record no
outcome: say so and stop, leaving the task open.

**With no human to hand a step to** (a run that `epic-implement` dispatches,
or any run where the human is not answering you in the session), run the
agent-safe steps and check each human-run step's preconditions, then post no
outcome and no `blocked` comment. End the run `waiting: human-run steps`,
giving in your final report each step's precondition result and its
paste-ready command. The human runs them at the gate. A later run, with the
human present or given the output of the human's runs in its prompt, checks
the preconditions again, verifies each step from that output, and records the
result. Never record a human-run step from a bare claim that it ran, without
its output.

## Record the result and close

Judge the run against the **Acceptance criteria**. On FAILURE, do the
FAILURE steps below (retry, and any fix task) **before** posting; then post
the result as a comment. The outcome line is load-bearing — `vrg-epic-audit` reads it — so it
MUST contain `Outcome: SUCCESS` or `Outcome: FAILURE`, plus evidence:

```bash
vrg-gh issue comment <N> --body "- Outcome: SUCCESS
- Evidence: <command output / observations>"
```

For a failure screened as security-class, the comment gives `Outcome:
FAILURE`, neutral evidence that does not describe the weakness, and the
security count only; the details go to `operational/<N>/`, with a `Kept:`
line
([lifecycle step 4](../issue-validate/references/operational-task-lifecycle.md#lifecycle)).

- **SUCCESS →** close the issue, citing the result; closing lets the epic (and
  any downstream validation) proceed:

  ```bash
  vrg-gh issue close <N> --comment "Deployed — see the SUCCESS result above."
  ```

- **FAILURE →** do **not** close. Because the deploy is idempotent, **retry
  first** — a failure is often transient (network, a not-yet-ready target). Only
  if it cannot succeed without a code change do you file a fix task (a normal
  implementation task) and re-deploy once it lands:

  ```bash
  vrg-issue-create --epic <org>/.github#N --repo <org>/<repo> \
    --title "fix: <what blocks the deploy>" --body "<from the FAILURE evidence>"
  ```

  This fix task is exempt from approval, under the conditions of the
  [lifecycle's step 4](../issue-validate/references/operational-task-lifecycle.md#lifecycle):
  screen the failure first (a security-class one is not filed), search for
  an existing open fix task, and post the result even if filing fails. List
  it in the result comment under `Filed without a ruling` (an existing one
  as `existing: <ref>`, one that failed to file as `not filed: <reason>`)
  and in your final report, so the human sees it at the next gate. A failed
  deployment is a
  gate that holds — the task and its epic stay open until it succeeds.

## Boundaries

- **No worktree, no commits, no PR, and no release.** A deployment task changes
  the environment, not the code; the PR tooling refuses it, and cutting a release
  is a human action. If you find yourself wanting to open a PR or run a release,
  you are outside this skill's remit — stop.
- **Discovered problems need the human's approval to file.** When a
  follow-up surfaces — a concern a sub-agent reports, a gap you hit, a "we
  should also…" — do not fold it into this task's result and do not file it:
  list it under `Awaiting a ruling` in the result comment (or a comment of
  its own if you find it before then), and in your final report; file it
  only as the human approves. A security item appears there only as a
  count, its details in `build/.vergil-state/operational/<N>/`. See the
  [lifecycle's "Out of band"](../issue-validate/references/operational-task-lifecycle.md#out-of-band)
  and [doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues).
- **A run given rulings only** (dispatched by `epic-implement`) stops after
  Preflight and follows the
  [lifecycle's rulings-only entry](../issue-validate/references/operational-task-lifecycle.md#lifecycle)
  instead of the steps above.
- The issue's comments are the recovery record if a session is lost mid-run;
  `paad:handoff` is available for session continuity.
