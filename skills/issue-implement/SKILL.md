---
name: issue-implement
description: USER-identity skill — implement a GitHub issue by driving the vrg-pr-workflow oracle loop, then hand off to the human for PR submission. Run as the vergil-user agent. (The issue/pre-PR phase; the legacy `implement` skill remains for rolled-back tooling.)
---

# Issue Implement

Drive the USER half of the local PR workflow. You **implement the issue
directly**, then engage the `vrg-pr-workflow` oracle only to run the audit
handshake — so the audit never sits idle on an empty worktree. Once you signal
ready you stay **dumb**: do exactly what each directive says and report through
the verb it names, until done.

## Run it in the foreground — be transparent

Do all of this **inline, in the foreground**, narrating as you go: what you are
implementing, each oracle directive you receive, each audit finding, and how you
address it. Never spawn a sub-agent or run the loop silently — the human is
watching this session in a split screen next to the audit, and the visible
back-and-forth *is* the oversight.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`. If
   not, stop — this skill runs in the user-agent session.
2. **Create the worktree for this issue** from the repo root and work inside it
   (pick a 2–4 token kebab slug):

   ```bash
   vrg-git worktree add -b feature/<N>-<slug> .worktrees/issue-<N>-<slug> origin/develop
   cd .worktrees/issue-<N>-<slug>
   ```

## Implement, then hand off to the audit

1. **Implement the issue** here with small `vrg-commit` commits. Validate until
   green — `vrg-container-run -- vrg-validate` — fixing every failure and
   re-running; **never** suppress a gate.
2. **Hand off to the audit.** When the work is green and ready, give the human a
   copy-pasteable line: *"Ready for audit — run
   `/vergil:issue-audit <absolute-worktree-path>` in the audit window."*
3. **Engage the oracle and signal ready:**

   ```bash
   vrg-pr-workflow next --issue <N>   # inits; heartbeats while waiting for the audit to join
   ```

   It returns an `implement` directive — you have already implemented, so go
   straight to reporting ready:

   ```bash
   vrg-pr-workflow report-ready --title "<conventional-commit title>" \
     --summary "<one substantive sentence: what changed and why>" \
     --notes "<reviewer-relevant notes>"
   ```

   *Solo / no-audit:* for small, high-confidence work (one-liners, docs, config),
   add `--no-audit` to that first `next`, skip the hand-off, and report ready —
   the PR-phase audit still runs after submission.

## The review loop

Then loop: `vrg-pr-workflow next` → act on the directive → repeat.

- **fix findings** — `then: { verb: "report-fixes" }`. Address every finding,
  validate green, `vrg-commit`, then:

  ```bash
  vrg-pr-workflow report-fixes --note "<what you changed>"
  ```

  When a finding is about the PR description itself, revise it on the same call
  with `--summary` / `--notes` / `--title`.

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
