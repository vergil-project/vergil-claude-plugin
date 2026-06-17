---
name: issue-implement
description: Implement a GitHub issue end-to-end as the USER agent. Use whenever the human asks to implement, build, fix, or start work on an issue — "implement #170", "go implement this", "let's do issue N", "build out this issue" — with or without the slash command. Drives the vrg-pr-workflow oracle loop, which writes the .vergil/pr-workflow.json + pr-template.yml that vrg-submit-pr consumes. PR creation is funneled exclusively through vrg-submit-pr (vrg-gh pr create is banned), so hand-rolling the worktree/commit/PR flow instead leaves the work stranded with no path to a PR. Runs without the local audit by default; pass `audit` to engage the local audit pair. Run as the vergil-user agent.
---

# Issue Implement

Drive the USER half of the local PR workflow. You **implement the issue
directly**, then engage the `vrg-pr-workflow` oracle to record the PR metadata
and — only when the audit is requested — run the audit handshake. Once you
signal ready you stay **dumb**: do exactly what each directive says and report
through the verb it names, until done.

## `vrg-pr-workflow` is a blocking request-reply — call it, stop, obey the reply

`vrg-pr-workflow` is **not** fire-and-forget and **not** a long-running job you
check on later. Every invocation (`next`, `report-ready`, `report-fixes`) is a
**synchronous, blocking call**: it blocks in the foreground and returns exactly
one JSON directive naming your next step. It is a request→reply exchange with the
audit counterpart (or, solo, with the oracle itself) — a blocking RPC, not a
background task.

Rules, non-negotiable:

- **One call, then STOP.** Run a single `vrg-pr-workflow` command and wait for it
  to return. Do nothing else until you have read the directive it printed and
  acted on it. The directive *is* your instruction set.
- **Never background or poll it.** No `&`, no `run_in_background`, no
  `sleep`-then-check, no "I'll look at it later." It already blocks until the
  reply is ready; backgrounding it races the protocol and corrupts the session.
- **`status` is not a driver.** `vrg-pr-workflow status` diagnoses a wedged
  session by hand — never poll it in a loop. Only the return value of a blocking
  `next` advances the workflow.
- **Init exactly once.** Call `next --issue <N>` (paired) or
  `next --issue <N> --no-audit` (solo) one time. Never re-run `next` with init
  flags again — re-initing (e.g. `--no-audit` after a paired audit has joined)
  tears the counterpart down and errors out.
- **After init, drive with bare verbs.** The loop is `vrg-pr-workflow next` →
  obey the directive → report via the verb it names → repeat, each call blocking
  for its reply.

If it seems to "hang," it is doing its job — blocking for the counterpart's
reply. Wait for it. Do not start other work, spawn helpers, or poll.

## Audit is opt-in — default is no-audit

By default this skill runs **without** the local dual-agent audit (it drives
the oracle with `--no-audit`). Engage the local audit pair **only** when the
human passes the word `audit` as an argument to this skill — e.g.
`/vergil:issue-implement <N> audit`. With no such argument, take the
[default path](#engage-the-oracle-and-signal-ready-default--no-audit) and never
emit an audit hand-off.

> **Experimental.** The local dual-agent audit mechanism is experimental at
> this time. It is implemented and available to experiment with, but it is not
> on the default path while the mechanism matures. This does **not** affect the
> PR-phase audit that runs after `vrg-submit-pr` — that always runs, regardless
> of the mode chosen here.

## Run it in the foreground — be transparent

Do all of this **inline, in the foreground**, narrating as you go: what you are
implementing, each oracle directive you receive, and — in audit mode — each
audit finding and how you address it. Never spawn a sub-agent or run the loop
silently — when the audit is engaged the human is watching this session in a
split screen next to it, and the visible back-and-forth *is* the oversight.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`. If
   not, stop — this skill runs in the user-agent session.
2. **Create the worktree for this issue** from the repo root and work inside it
   (pick a 2–4 token kebab slug):

   ```bash
   vrg-git worktree add -b feature/<N>-<slug> .worktrees/issue-<N>-<slug> origin/develop
   cd .worktrees/issue-<N>-<slug>
   ```

## Implement

**Implement the issue** here with small `vrg-commit` commits. Validate until
green — `vrg-container-run -- vrg-validate` — fixing every failure and
re-running; **never** suppress a gate.

## Engage the oracle and signal ready (default — no-audit)

When the work is green and ready, init the oracle in solo mode and report ready:

```bash
vrg-pr-workflow next --issue <N> --no-audit   # init once; blocks, returns your first directive
```

It returns an `implement` directive — you have already implemented, so go
straight to reporting ready:

```bash
vrg-pr-workflow report-ready --title "<conventional-commit title>" \
  --summary "<one substantive sentence: what changed and why>" \
  --notes "<reviewer-relevant notes>"
```

Then run [the review loop](#the-review-loop) — with no audit it goes straight to
DONE, and you tell the human to run `vrg-submit-pr`. The PR-phase audit still
runs after submission.

### Audit mode (opt-in)

When — and only when — the human passed `audit`, engage the local audit pair
instead, so the audit never sits idle on an empty worktree:

1. **Hand off to the audit.** Give the human a copy-pasteable line: *"Ready for
   audit — run `/vergil:issue-audit <absolute-worktree-path>` in the audit
   window."*
2. **Init the oracle in paired mode and report ready** — same as above but
   **without** `--no-audit`:

   ```bash
   vrg-pr-workflow next --issue <N>   # init once; BLOCKS until the audit joins and returns your first directive — do not poll or background it
   vrg-pr-workflow report-ready --title "<conventional-commit title>" \
     --summary "<one substantive sentence: what changed and why>" \
     --notes "<reviewer-relevant notes>"
   ```

Then run the review loop below — in audit mode it will surface `fix findings`
directives until the audit approves.

## The review loop

Then loop: `vrg-pr-workflow next` → act on the directive → repeat. Each `next`
blocks until its reply is ready — never background it, and never poll `status`
in its place.

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

## Resolving conflicts with the base branch

If `develop` (the base) advances while your branch is in flight — whether
mid-loop or after the PR is open — and your branch conflicts with it, resolve it
as **routine**. No human sign-off is needed:

1. `vrg-git fetch origin`
2. `vrg-git rebase origin/develop` — resolve conflicts, keeping both sides where
   each adds independent content. `ORIG_HEAD` is your undo
   (`vrg-git reset --hard ORIG_HEAD`) if the rebase goes wrong.
3. `vrg-container-run -- vrg-validate` until green — **never** suppress a gate.
4. `vrg-git push --force-with-lease` to update the branch / PR.

**Force-pushing to update your _own_ in-flight PR after a rebase is a normal,
pre-authorized part of this workflow** — not an exceptional action requiring
human approval. The general "never force-push without explicit request" rule
guards shared/protected history; it does **not** apply to rebasing your own
feature branch onto its base. Always use `--force-with-lease` (the safe form —
it refuses to overwrite if the remote moved unexpectedly), never a bare
`--force`.

## Notes

- `vrg-submit-pr` reads the PR metadata from the state file the oracle wrote
  (`.vergil/pr-workflow.json`); you never write a PR template by hand.
- You never open the PR and never post checks.
- `/vergil:handoff` remains the recovery net if a session is lost mid-loop.
