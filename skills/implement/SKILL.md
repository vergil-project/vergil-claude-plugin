---
name: implement
description: USER-identity skill — implement a GitHub issue by driving the vrg-pr-workflow oracle loop, then hand off to the human for PR submission. Run as the vergil-user agent.
---

# Implement

Drive the USER half of the local PR workflow. You stay **dumb**: the
`vrg-pr-workflow` oracle owns the workflow. You call `next`, do exactly what the
one directive says, report your result through the verb it names, and repeat
until it tells you you are done. You hold no workflow logic of your own.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`. If
   not, stop — this skill runs in the user-agent session.
2. Be in the feature-branch worktree for this issue, not the repo root.

## The loop

Start (and re-enter) the loop with:

```bash
vrg-pr-workflow next --issue <N>      # add --no-audit to skip the local audit
```

`next` blocks until it is your turn, then prints **one** directive as JSON with
a `do` (what to do) and a `then` (the verb to report with). Do the `do` exactly,
run the `then` verb, then call `vrg-pr-workflow next` again. Repeat.

- The CLI resolves your role from `vrg-whoami` — never pass `--as`.
- `--issue <N>` is required only on the **first** `next` (it initializes the
  workflow); omit it afterward.
- `--no-audit` (solo mode) skips the *local* audit for small, high-confidence
  work — quick one-liners, doc or config tweaks — trusting the CI gates as the
  backstop. The PR-phase audit still runs after submission.

### Directives you will see

- **implement** — `then: { verb: "report-ready" }`. Implement the issue on the
  branch with small `vrg-commit` commits. Validate until green
  (`vrg-container-run -- vrg-validate`); fix every failure and re-run — **never**
  suppress a gate. Then:

  ```bash
  vrg-pr-workflow report-ready \
    --title "<conventional-commit title>" \
    --summary "<one substantive sentence: what changed and why>" \
    --notes "<reviewer-relevant notes>"
  ```

- **fix findings** — `then: { verb: "report-fixes" }`. The directive's
  `findings` are the audit's requested changes. Address every one, validate
  green, `vrg-commit`, then:

  ```bash
  vrg-pr-workflow report-fixes --note "<what you changed>"
  ```

- **DONE** — `{ "done": true, "reason": "approved", ... }`. Tell the human:
  *"Approved — run `vrg-submit-pr` to open the PR."* Stop. Only the human opens
  the PR.

If `next` (or any verb) **errors** — the audit escalated to the human, or the
counterpart aborted — surface the message to the human and stop. Do not loop.

## Notes

- `vrg-submit-pr` reads the PR metadata from the state file the oracle wrote
  (`.vergil/pr-workflow.json`); you never write a PR template by hand.
- You never open the PR and never post checks.
- `/vergil:handoff` remains the recovery net if a session is lost mid-loop.
