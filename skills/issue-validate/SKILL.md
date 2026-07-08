---
name: issue-validate
description: Run a validation task end-to-end as the USER agent — a `validation`-labelled issue whose acceptance is a live check, not a code change. Use when the human asks to validate, verify, or run the checklist on a validation issue ("validate #120", "run the validation", "verify the deployed lab"), or when issue-implement redirects a validation-labelled issue here. You execute the issue's recorded checklist, record PASS/FAIL as a comment, and close only on PASS — no worktree, no commits, no PR. Run as the vergil-user agent.
---

# Issue Validate

Run a **validation task** to completion and record the result — the execution
half of the post-merge validation framework (epic `vergil-project/.github#115`).
A validation task's acceptance is proven by *running* its checklist and recording
PASS/FAIL as a comment; it has no code PR and closes only on PASS.

This is the sibling of `issue-implement`, and deliberately different:

| | `issue-implement` | `issue-validate` (this) |
|---|---|---|
| Goal | Write code, solve a problem | Run a recorded check, observe reality |
| Workspace | Worktree + branch + commits | None — touches no code |
| Terminal state | PR handoff (`vrg-submit-pr`) | PASS/FAIL **comment** + close |
| On failure | Fix in place, iterate | Record FAIL, file fix task(s), leave open |

If you were sent here for an issue that is **not** `validation`-labelled, stop —
that is code-implementation; use `issue-implement`.

## Run it in the foreground — be transparent

Do everything **inline, in the foreground**, narrating as you go. Never fabricate
or partially fake a result — if you cannot actually run a check, say so and stop.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`.
2. Confirm the issue carries the **`validation`** label:

   ```bash
   vrg-gh issue view <N> --json labels
   ```

   If it does not, this is the wrong skill — hand it to `issue-implement`.
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
`Outcome: PASS` or `Outcome: FAIL`, plus the evidence:

```bash
vrg-gh issue comment <N> --body "- Outcome: PASS
- Evidence: <command output / observations>"
```

- **PASS →** close the issue, citing the result; closing it lets the epic roll
  up:

  ```bash
  vrg-gh issue close <N> --comment "Validated — see the PASS result above."
  ```

- **FAIL →** do **not** close. Leave this task — and its epic — open, and file
  follow-on fix task(s) under the same epic:

  ```bash
  vrg-issue-create --epic <org>/.github#N --repo <org>/<repo> \
    --title "fix: <what failed>" --body "<from the FAIL evidence>"
  ```

  A failed validation is a gate that holds, exactly like a PR that cannot merge.
  The fix task lands its own PR; a re-run of this validation confirms the fix.

## Boundaries

- **No worktree, no commits, no PR.** A validation task touches no code, and the
  PR tooling (`vrg-submit-pr`, `vrg-pr-workflow report-ready`) refuses it. If you
  find yourself wanting to open a PR, you are on the wrong issue.
- **Triage is out of band.** If you discover unrelated problems while running,
  capture them as their own issues (`triage-capture` / `vrg-issue-create`) — do
  not fold them into this task's result.
- `/vergil:handoff` remains the recovery net if a session is lost mid-run.
