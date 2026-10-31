---
name: issue-validate
description: Run a validation task end-to-end as the USER agent — a `validation`-labelled issue whose acceptance is a live check, not a code change. Use when the human asks to validate, verify, or run the checklist on a validation issue ("validate #120", "run the validation", "verify the deployed lab"), or when issue-implement redirects a validation-labelled issue here. You execute the issue's recorded checklist, record SUCCESS/FAILURE as a comment, and close only on SUCCESS — no worktree, no commits, no PR. Run as the vergil-user agent.
---

# Issue Validate

Run a **validation task** to completion and record the result. Validation is one
**operational task** kind — it follows the shared
[operational-task lifecycle](references/operational-task-lifecycle.md)
(preflight → preconditions gate → run → record `Outcome:` → close-on-success /
hold-open-on-failure); below is the validation-specific detail. A validation
task's acceptance is proven by *running* its checklist and recording
SUCCESS/FAILURE as a comment; it has no code PR and closes only on SUCCESS.

This is the sibling of `issue-implement`, and deliberately different:

| | `issue-implement` | `issue-validate` (this) |
|---|---|---|
| Goal | Write code, solve a problem | Run a recorded check, observe reality |
| Workspace | Worktree + branch + commits | None — touches no code |
| Terminal state | PR handoff (`vrg-submit-pr`) | SUCCESS/FAILURE **comment** + close |
| On failure | Fix in place, iterate | Record FAILURE, file fix task(s), leave open |

If you were sent here for an issue that is **not** `validation`-labelled, stop —
that is code-implementation; use `issue-implement`.

## Never fabricate a result

If you cannot actually run a check, say so and stop — **never fabricate or
partially fake a result.** Use whatever means are efficient to run it (sub-agents
encouraged); oversight is front-loaded and at the hard gates, not in a live
transcript (the **Front-Loaded Judgment, Trusted Execution** doctrine; see the
[execution doctrine](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/site/docs/skills/index.md#execution-doctrine-front-loaded-judgment-trusted-execution)). If you hit a problem you cannot resolve, stop and ask.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`.
2. Confirm the issue carries the **`validation`** label:

   ```bash
   vrg-gh issue view <N> --json labels
   ```

   If it does not, this is the wrong skill — hand it to `issue-implement`. If
   it carries `epic` or `archive`, stop: it is an umbrella, not a task (`<ref>
   is an epic, not a task` / `<ref> is an archive, not a task`); to drive an
   epic's tasks, use `epic-implement`. If the labels cannot be read, say so and
   stop.
3. Read the issue body. It is a self-contained scaffold: **preconditions**,
   **commands**, **acceptance criteria**, and a **results template**.

## Gate on the preconditions FIRST

Before running anything, work the issue's **Preconditions** self-check — whatever
form it declares (a machine probe *or* a human-attested statement; the framework
prescribes no mechanism). This includes confirming the target is reachable and
that the dependency change is actually deployed (the issue's `Blocked-by:` deps
should be closed/merged).

**If any precondition is unmet:** post a comment and **stop** — do not run the
checklist and do not close the issue:

```bash
vrg-gh issue comment <N> --body "blocked: preconditions not met — <which>"
```

Never fabricate a result to move past a failed precondition.

## Run the checklist

Run the issue's **Commands** exactly as recorded, against the live target.
Capture the real output — you will paste it into the result as evidence.

## Record the result and close

Judge the run against the issue's **Acceptance criteria**, then post the result
as a comment following the scaffold's Results template. The outcome line is
load-bearing — `vrg-epic-audit` reads it — so it MUST contain a line
`Outcome: SUCCESS` or `Outcome: FAILURE`, plus the evidence:

```bash
vrg-gh issue comment <N> --body "- Outcome: SUCCESS
- Evidence: <command output / observations>"
```

- **SUCCESS →** close the issue, citing the result; closing it lets the epic roll
  up:

  ```bash
  vrg-gh issue close <N> --comment "Validated — see the SUCCESS result above."
  ```

- **FAILURE →** do **not** close. Leave this task — and its epic — open, and file
  follow-on fix task(s) under the same epic:

  ```bash
  vrg-issue-create --epic <org>/.github#N --repo <org>/<repo> \
    --title "fix: <what failed>" --body "<from the FAILURE evidence>"
  ```

  These fix tasks are exempt from approval, but list each under `Filed
  without a ruling` in the result comment and your final report, so the
  human sees it at the next gate.
  A failed validation is a gate that holds, exactly like a PR that cannot merge.
  The fix task lands its own PR; a re-run of this validation confirms the fix.

## Boundaries

- **No worktree, no commits, no PR.** A validation task touches no code, and the
  PR tooling (`vrg-submit-pr`, `vrg-pr-workflow report-ready`) refuses it. If you
  find yourself wanting to open a PR, you are on the wrong issue.
- **Discovered problems need the human's approval to file.** When a
  follow-up surfaces — a concern a sub-agent reports, a gap you hit, a "we
  should also…" — do not fold it into this task's result and do not file it:
  list it under `Awaiting a ruling` in the result comment (or a comment of
  its own if you find it before then), and in your final report; file it
  only as the human approves. A security item appears there only as a
  count, its details in `build/.vergil-state/operational/<N>/`. See the
  [lifecycle's "Out of band"](references/operational-task-lifecycle.md#out-of-band)
  and [doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues).
- The issue's comments are the recovery record if a session is lost mid-run;
  `paad:handoff` is available for session continuity.
