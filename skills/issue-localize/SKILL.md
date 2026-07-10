---
name: issue-localize
description: Localize a remotely-completed branch into a locally submit-ready state as the USER agent. Use when a cloud/remote agent already implemented an issue and pushed its `feature/<N>-<slug>` branch, but the PR-ready state is missing locally — because `.vergil/pr-workflow.json` is gitignored and never rides the push, so it is stranded on the cloud VM's volume that macOS cannot see (and the VM may already be reaped). Triggers — "localize #611", "localize this branch", "bring the cloud branch home", "finish the remotely-completed PR locally", "prep the pushed branch so I can vrg-submit-pr" — with or without the slash command. Accepts an issue number OR a branch name (one branch per issue, so it is unambiguous). It checks out the branch locally, re-validates, and reconstructs the ready-state by regenerating the PR metadata from the issue + branch diff, then hands off — you never open the PR. Run as the vergil-user agent.
---

# Issue Localize

Take a **remotely-completed** branch — implemented on a cloud VM and pushed to
origin — and make it **submit-ready on the local host**, so the human can run
`vrg-submit-pr`. This is the tail of `issue-implement` applied to work done
elsewhere: it **skips implementation** (a remote agent already did that) and does
the same validate → `report-ready` → hand off.

**Why this skill exists.** The PR-ready state that `vrg-submit-pr` reads lives in
`.vergil/pr-workflow.json`. `.vergil/` is **gitignored**, so that file never
rides the push to origin — the branch arrives "naked." In the cloud model the
ready-state is stranded on a volume macOS cannot see, and the VM may already be
reaped by the stale-session lifecycle. So we do **not** try to fetch that file;
we **regenerate** the metadata locally from the two inputs that are always
durable — the pushed branch and the issue.

## Execute efficiently — trust and escalate

Work by the most efficient means available; **sub-agents are encouraged** where
they help. You need not narrate every step — oversight is front-loaded and at the
hard gates, per the **Front-Loaded Judgment, Trusted Execution** doctrine (see
`CLAUDE.md`). If you hit a problem you cannot resolve, stop and ask. Never
fabricate the reconstructed metadata: if you cannot actually localize the branch
or run validation, say so and stop.

## Preflight

1. Confirm you are the **USER** agent: `vrg-whoami --mode` must print `user`. If
   not, stop — this skill runs in the user-agent session.
2. **Not an operational task.** If the issue carries an operational label, stop —
   there is no branch to localize. A `validation` issue goes to
   **`issue-validate`**; a `deployment` issue goes to **`issue-deploy`**.

## Resolve the input → branch

The argument is either an **issue number** (`611`) or a **branch name**
(`feature/611-finish-remote-pr`). There is exactly one branch per issue, so this
is unambiguous.

- **If the argument is a branch name** (contains `/`), use it directly. Derive
  the issue number `N` from the `<type>/<N>-<slug>` prefix — you need it for
  `report-ready --issue`.
- **If the argument is an issue number** `N`, find the pushed branch on origin:

  ```bash
  vrg-git fetch origin --quiet
  remote_branch=$(vrg-git branch -r --list \
    "origin/feature/${N}-*" "origin/bugfix/${N}-*" \
    "origin/chore/${N}-*" "origin/hotfix/${N}-*" \
    | head -1 | sed 's|.*origin/||')
  ```

  - **No match:** the branch is not on origin — it was never pushed, or was
    already merged and deleted. **Stop and tell the human**; do not fabricate a
    ready-state.
  - **Multiple matches:** ambiguous (should not happen under one-branch-per-
    issue). **Stop and ask** which branch to localize.

See [`starting-work-on-an-issue.md`](../../docs/development/starting-work-on-an-issue.md)
for the full input-resolution reference (URLs, project boards, cross-repo
sub-issues).

## Check out the branch locally

Reuse an existing worktree if one is already checked out for this issue
(`ls -d ".worktrees/issue-${N}-"*`); otherwise add one from the pushed branch
using the canonical existing-remote-branch invocation:

```bash
slug="${remote_branch#*/${N}-}"
vrg-git worktree add ".worktrees/issue-${N}-${slug}" \
  -B "${remote_branch}" "origin/${remote_branch}"
cd ".worktrees/issue-${N}-${slug}"
```

Do all further work from inside the worktree.

## Re-validate

Re-run the full pipeline on the local host — a green cloud run does not prove a
green local/cold rebuild:

```bash
vrg-container-run -- vrg-validate
```

**If validation fails, stop and surface it.** The branch is not submit-ready; do
**not** reconstruct a ready-state on red, and do **not** silently patch the
remote agent's implementation — a local failure is a real signal (a genuine
break, or a cold-rebuild gap). The human decides whether to fix it here or bounce
the work back. This skill localizes *ready* work; it does not re-implement.

## Reconstruct the PR-ready state (regenerate — do not transfer)

Regenerate the PR metadata from the durable inputs. Read the issue and the
branch's delta against the base:

```bash
vrg-gh issue view <N> --json title,body
vrg-git diff origin/develop...HEAD
```

Synthesize a conventional-commit title, a one-sentence substantive summary, and
reviewer-relevant notes from what the diff actually does (grounded in the code,
not just the issue's intent), then record the ready-state:

```bash
vrg-pr-workflow report-ready --issue <N> \
  --title "<conventional-commit title>" \
  --summary "<one substantive sentence: what changed and why>" \
  --notes "<reviewer-relevant notes>"
```

This writes `.vergil/pr-workflow.json` in the local worktree — the file
`vrg-submit-pr` reads. It is run-and-done: it records the metadata and exits.
Re-run `report-ready` to correct the title/summary/notes before the human
submits — it overwrites.

**Why regenerate rather than transfer the cloud file.** The exact PR prose has
little value to protect — the human reviews post-deploy via high-level
integration tests, not individual branches — while the pushed branch and the
issue are always available even after the VM is reaped. Regenerating keeps this
skill fully decoupled from the cloud, with no new infrastructure.

## Hand off

Tell the human: *"Ready — run `vrg-submit-pr` to open the PR."* Stop. Only the
human opens the PR — the control gate stays with the human.

## Resolving conflicts with the base branch

If `develop` advanced while the branch sat on the cloud VM and the branch now
conflicts, resolve it as **routine** — rebase onto `origin/develop`, re-validate
green, and `vrg-git push --force-with-lease` to update the pushed branch. No
human sign-off is needed; force-pushing your own not-yet-submitted feature branch
after a rebase is pre-authorized. See *Resolving conflicts with the base branch*
in [`issue-implement`](../issue-implement/SKILL.md) for the full procedure.

## Notes

- You never open the PR and never post checks. `vrg-submit-pr` (human) mints the
  PR from the `.vergil/pr-workflow.json` this skill wrote; after that, run the
  emitted `/vergil:pr-watch <PR_URL>` in the USER agent session.
- This skill does not re-implement. A branch that fails local validation is
  surfaced, not silently fixed.
- `/vergil:handoff` remains the recovery net if a session is lost mid-run.
