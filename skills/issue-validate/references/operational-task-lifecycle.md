# Operational-task lifecycle

The shared run contract for **operational tasks** — the not-PR-workable task
kinds whose acceptance is proven by *running* a procedure and recording an
`Outcome:` comment, not by merging a PR. Both `issue-validate` (validation) and
`issue-deploy` (deployment) follow this lifecycle; each adds only its
kind-specific concerns.

## Invariants (every operational kind)

- **Not PR-workable.** No worktree, no commits, no PR; `vrg-submit-pr` and
  `vrg-pr-workflow report-ready` refuse an operational-labelled issue.
- **Closes only on success**, recorded as an `Outcome: SUCCESS` comment.
- **Gates the epic** by staying open — an open operational child holds the epic
  until it succeeds.
- **Self-contained scaffold** in the issue body: preconditions, the procedure,
  acceptance criteria, and a `SUCCESS` / `FAILURE` results template.

## Lifecycle

1. **Preflight.** Confirm you are the **USER** agent (`vrg-whoami --mode` is
   `user`) and the issue carries the expected operational label
   (`vrg-gh issue view <N> --json labels`). If the label is wrong for this
   skill, hand it to the right one (`issue-validate` / `issue-deploy`), or to
   `issue-implement` if it is not operational at all.
2. **Preconditions gate — first, and honestly.** Work the issue's
   **Preconditions** self-check (a machine probe *or* a human-attested
   statement; the framework prescribes no mechanism). If any is unmet, comment
   `blocked: preconditions not met — <which>` and **stop** — do not run the
   procedure, do not close. **Never fabricate or partially fake a result.**
3. **Run the recorded procedure** against the live target; capture the real
   output for evidence.
4. **Record the result** as a comment following the scaffold's Results template.
   The outcome line is load-bearing (`vrg-epic-audit` reads it), so it MUST
   contain `Outcome: SUCCESS` or `Outcome: FAILURE`, plus evidence.
5. **Close on SUCCESS / hold open on FAILURE.**
   - **SUCCESS →** close the issue citing the result; closing lets the epic roll
     up.
   - **FAILURE →** do **not** close. Leave the task — and its epic — open. Each
     kind handles the failure its own way (validation files a fix task;
     deployment retries first, then files a fix task only for a genuine defect).

## Out of band

Triage discovered problems as their own issues (`triage-capture` /
`vrg-issue-create`) — do not fold them into this task's result.
`/vergil:handoff` is the recovery net if a session is lost mid-run.
