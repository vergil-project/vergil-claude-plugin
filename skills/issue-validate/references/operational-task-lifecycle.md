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
     That fix task is the one issue this lifecycle files without the human's
     approval: list it under `Filed without a ruling` in the result comment
     and the final report, so the human sees it at the next gate.

## Out of band

Creating any other issue needs the human's approval
([doctrine §1.7](../../../docs/paad-review-doctrine.md#17-creating-issues)).
Do not fold a discovered problem into this task's result, and do not file
it: list it under `Awaiting a ruling` in the result comment (or a comment of
its own, at once, if you find it before then) and in your final report, and
file it only as the human approves, in the form approved.

A **security item** appears in any comment only as a count. Write its
details to `build/.vergil-state/operational/<N>/` in the main clone of the
repo the task is filed in, under the state-directory rules
([doctrine §1.5](../../../docs/paad-review-doctrine.md#15-state-directories)),
and present it in the terminal only (under `epic-implement`, in your final
message to the main session, never posted). On a `record` ruling, record it
with `vrg-security-record`
([doctrine §3.6](../../../docs/paad-review-doctrine.md#36-security-findings));
on `reject`, record nothing. Delete its details once the ruling is carried
out.

The issue's comments are the recovery record if a session is lost mid-run;
`paad:handoff` is available for session continuity.
