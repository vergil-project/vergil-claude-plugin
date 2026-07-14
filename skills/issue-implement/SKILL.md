---
name: issue-implement
description: Implement a GitHub issue end-to-end as the USER agent. Use whenever the human asks to implement, build, fix, or start work on an issue — "implement #170", "go implement this", "let's do issue N", "build out this issue" — with or without the slash command. You implement directly in a worktree, then record the PR metadata with `vrg-pr-workflow report-ready`, which writes the `.vergil/pr-workflow.json` that vrg-submit-pr consumes. PR creation is funneled exclusively through vrg-submit-pr (vrg-gh pr create is banned), so hand-rolling the worktree/commit/PR flow instead leaves the work stranded with no path to a PR. Run as the vergil-user agent.
---

# Issue Implement

Implement a GitHub issue end-to-end as the USER agent, then hand the PR off to
the human. You **implement the issue directly** in a worktree, validate it
green, record the PR metadata through `vrg-pr-workflow report-ready`, and tell
the human to open the PR with `vrg-submit-pr`. You never open the PR yourself.

## Execute efficiently — trust and escalate

Implement by the most efficient means at your disposal. **Sub-agents are
encouraged** wherever they make the work faster or keep your context clean —
research fan-out, parallel sub-tasks, isolated exploration. You need not narrate
every step for the human to watch: oversight lives in the front-loaded plan and
at the hard gates (PR submit, merge, release), not in a live transcript. This is
the **Front-Loaded Judgment, Trusted Execution** doctrine (see `CLAUDE.md`).

The one thing that pulls the human back mid-flight is a **problem you cannot
resolve**: stop and ask rather than thrash or guess. Never fabricate a result and
never suppress a validation gate.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`. If
   not, stop — this skill runs in the user-agent session.
2. **Not an operational task.** If the issue carries an operational label, stop —
   it is **not** code-implementation. An operational task is *run*, not built:
   its acceptance is a recorded `Outcome:` comment, not a PR (and the PR tooling
   refuses it). Hand a `validation` issue to **`issue-validate`** and a
   `deployment` issue to **`issue-deploy`**.
3. **Create the worktree for this issue** from the repo root and work inside it
   (pick a 2–4 token kebab slug):

   ```bash
   vrg-git worktree add -b feature/<N>-<slug> .worktrees/issue-<N>-<slug> origin/develop
   cd .worktrees/issue-<N>-<slug>
   ```

## Implement

**Implement the issue** here with small `vrg-commit` commits. Validate until
green — `vrg-container-run -- vrg-validate` — fixing every failure and
re-running; **never** suppress a gate.

## Discovering an operational need (deployment or validation)

Merging the code is sometimes not the finish line. While implementing, you may
find a follow-on **operational task** is needed — visible only once you are deep
in the code:

- **Deployment** — the next step (a later task, or a validation) needs this
  change **deployed and usable**, not merely merged (install/sync/release-then-
  install). Mint a deployment follow-on:

  ```bash
  vrg-issue-create --epic <org>/.github#N --repo <org>/<repo> --kind deployment \
    --title "Deploy: <what>" --blocked-by <this-task-ref>
  ```

- **Validation** — acceptance needs a check the pipeline's tests cannot do (a
  cold rebuild, a live-lab check, a deploy smoke test after merge). Mint a
  validation follow-on:

  ```bash
  vrg-issue-create --epic <org>/.github#N --repo <org>/<repo> --kind validation \
    --title "Validate: <what>" --blocked-by <this-task-ref>
  ```

Attach the need to an existing epoch operational task where that fits (one over
several tasks) rather than minting a redundant one. See `epic-create`'s
"Operational tasks" section for the full doctrine and the scaffolds it stamps.

**Never declare the task or its epic done while a paired or epoch operational
task is still open** — it gates the epic's closure and closes only on a recorded
`Outcome: SUCCESS`.

## Record the PR metadata and hand off

When the work is green and ready, record the PR metadata in a single call:

```bash
vrg-pr-workflow report-ready --issue <N> \
  --title "<conventional-commit title>" \
  --summary "<one substantive sentence: what changed and why>" \
  --notes "<reviewer-relevant notes>"
```

This writes `.vergil/pr-workflow.json` — the file `vrg-submit-pr` reads. It is a
plain run-and-done command: it records the metadata and exits. There is no loop
to drive, nothing to poll, and no second agent to wait for. If you need to
correct the title/summary/notes before the human submits, just run
`report-ready` again — it overwrites.

Then tell the human: *"Ready — run `vrg-submit-pr` to open the PR."* Stop. Only
the human opens the PR.

## The branch is frozen once you report it ready

Reporting ready is a one-way handoff. From the moment `report-ready` records the
metadata until the human runs `vrg-submit-pr`, the branch is **frozen** —
`vrg-commit` and the `vrg-git` push path refuse any new commit or
branch-advancing push to it, and the enforcement flags "drift" if HEAD has
already moved past the reported commit. This is the tooling stopping the
reused-branch straggler at source: the PR merges at the reported commit, so any
extra commit stranded past it leaves a worktree cleanup can never delete.

The contract:

- **A task is exactly one PR. Once you report it ready, you are done with that
  branch — hands off.** Do not commit to it, rebase-advance it, or "just tweak
  one more thing." Once the branch is in `develop` it is finished, and any later
  change is a **new follow-up issue**, never a mutation of the merged branch.
- **Correcting the PR prose is still fine.** Re-running `report-ready` to fix the
  title/summary/notes overwrites the metadata — that is data, not code, and stays
  allowed. It does **not** license new commits.
- **Genuinely reopening the branch for more commits before submit is rare and
  deliberate.** It requires explicitly running `vrg-pr-workflow unfreeze` first
  (which drops the state back to `implementing` while keeping the recorded
  metadata). There is no silent default — if you are not sure you should reopen,
  you should not.

## Resolving conflicts with the base branch

If `develop` (the base) advances **while you are still implementing** (before you
report ready) and your branch conflicts with it, resolve it as **routine**. No
human sign-off is needed:

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

If the base only advances **after** you have reported ready, do **not** rebase
the frozen branch — the push path refuses it. Leave it: a conflict that surfaces
between report-ready and submit is resolved after the human submits, in
`pr-watch` (submitting lifts the freeze, so the post-submit rebase/force-push
there is legitimate). Reopening earlier requires a deliberate
`vrg-pr-workflow unfreeze`.

## Notes

- `vrg-submit-pr` reads the PR metadata from the state file `report-ready` wrote
  (`.vergil/pr-workflow.json`); you never write a PR template by hand.
- You never open the PR and never post checks.
- `/vergil:handoff` remains the recovery net if a session is lost mid-task.
