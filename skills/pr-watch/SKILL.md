---
name: pr-watch
description: Monitor and reconcile an open PR that `vrg-submit-pr` opened with auto-merge on. Use whenever a submitted PR needs watching or fixing — `vrg-submit-pr` emits the `/vergil:pr-watch <PR_URL>` line, `vrg-finalize-pr` reports a PR not merged, or the human asks to watch, monitor, babysit or fix the PR through CI and review. Runs in the USER agent session: block on PR state with vrg-pr-await, reconcile failing CI, conflicts and human review feedback, merge-review every fix but a clean rebase before pushing it, run the batch check before any push to a batch PR, and tell the human to rerun `vrg-finalize-pr` once a fix is pushed.
---

# PR watch

Drive the post-submit loop. `vrg-submit-pr` opens each PR against `develop`
with GitHub **auto-merge on**, pinned to the pushed head, so the PR lands by
itself as soon as its required checks are green. Submitting is the human's
consent to merge. This skill's job is to get a PR that did not land to
green: it fixes failing CI, resolves conflicts and addresses review
comments, and it guards every push, because a pushed fix that turns CI
green merges with no further human step.

You run it when `vrg-submit-pr` prints `/vergil:pr-watch <PR_URL>`, when
`vrg-finalize-pr`'s report names a PR as not merged (see
[Finalize's reasons](#finalizes-reasons--what-to-do-for-each)), or when the
human asks.

## `vrg-pr-await` is a blocking wait — run it in the foreground, don't poll

The loop is driven by `vrg-pr-await`, which **blocks** until the PR state
changes (a new commit, a new review, or a check result) and then prints the
current state as JSON. It is a single blocking call — not something to background
or poll around:

- **Run one `vrg-pr-await`, then wait for it to return.** CI and reviews can take
  minutes; that wait *is* the call doing its job. Do not background it (`&` /
  `run_in_background`), do not `sleep`-and-retry, and do not poll GitHub
  separately in a loop.
- **It returns once per state change.** Act on what it returns (reconcile), push
  your commit, then call `vrg-pr-await` again with updated `--since-*` flags. The
  blocking call is the loop's clock — do not start other work while it waits.
- **A merged PR ends it with exit 1.** `vrg-pr-await` refuses to watch a
  merged PR: it exits 1 with `error: PR <pr> is already merged; aborting
  watch`. Under auto-merge that is the normal way a PR lands, not a fault.
  On that message, confirm with `vrg-gh pr view <PR_URL> --json state`; if
  it is `MERGED`, go to [The PR merged](#the-pr-merged). Any other exit 1
  is an error: show it to the human and stop.

(This is about correctly consuming the blocking `vrg-pr-await` call — not the
retired continuous-oversight framing; sub-agents remain fine elsewhere.)

## Preflight

1. This skill runs in the **USER** agent session. Confirm with
   `[ "$(vrg-whoami --mode)" = user ] && echo ok || echo "not user"`,
   which must print `ok`. If not, stop — this skill is for the agent.
2. **Read the PR:**

   ```bash
   vrg-gh pr view <PR_URL> --json state,body,baseRefName,headRefName,headRefOid,autoMergeRequest
   ```

   - `MERGED`: go to [The PR merged](#the-pr-merged).
   - `CLOSED`: stop and tell the human. Never reopen it.
   - A base other than `develop`, or a `release/*` head: stop and tell the
     human. Submit opens PRs against `develop` only, and a release goes
     through `vrg-release`, not this skill.
   - `OPEN` with `autoMergeRequest` null: auto-merge is off, which is an
     exception. Stop at once, as
     [Auto-merge off](#auto-merge-off-or-a-provenance-violation--stop)
     says.
3. **Find the task issues.** The body's `Closes` lines name them. One line
   makes a single-issue PR, whose task issue is that ref. More than one
   makes a **batch PR**: see [Batch PRs](#batch-prs--fold-every-fix-into-its-issues-commit).
4. **Enter the branch's worktree.** `vrg-git worktree list` from the main
   clone shows the worktree on `headRefName`; `cd` into it and
   `vrg-git fetch origin`. Its `HEAD` must be the PR's `headRefOid`, or,
   on a rerun that resumes a stopped merge review, a fix not yet pushed on
   top of it (or a rebase of it onto `origin/develop`). If there is no
   such worktree, or its `HEAD` is anything else, stop and ask the human.
   A rerun with a merge review under way resumes it at
   [Before every push](#before-every-push) step 2.

## Monitor & reconcile

Loop:

1. **Wait for the PR to settle:**

   ```bash
   vrg-pr-await <PR_URL> --since-sha <last-head-sha> --since-reviews <last-review-count>
   ```

   (Omit the `--since-*` flags on the first call.) It prints PR state as JSON —
   parse the checks, reviews, `merge_state_status` and head SHA. A merged
   PR ends it with exit 1, as above.
2. **Re-read auto-merge and the state:**
   `vrg-gh pr view <PR_URL> --json state,autoMergeRequest`. `MERGED` goes to
   [The PR merged](#the-pr-merged); `CLOSED` stops and tells the human; an
   open PR with auto-merge off stops at once
   ([Auto-merge off](#auto-merge-off-or-a-provenance-violation--stop)).
3. **Green, with nothing left to address:** every required check is green,
   auto-merge is on and no human review comment is still unaddressed. The
   PR is GitHub's to merge now. Tell the human it is green with auto-merge
   on and will land by itself, and stop.
4. Otherwise **reconcile every source:** failing CI checks, a conflict
   with `develop` (`merge_state_status` `DIRTY`), and human review
   comments. Make each change as [Kinds of fix](#kinds-of-fix) says, then
   push it only through [Before every push](#before-every-push). The new
   head re-triggers CI.
5. If you cannot get a check green or cannot satisfy a comment, **stop and ask
   the human** rather than thrashing.
6. Loop with the updated `--since-sha` / `--since-reviews`.

### Review comments do not hold the merge

A human review comment posted after submit is still addressed: make the
change it asks for, as a fix like any other. It is advisory, not a gate,
so it never holds the merge. Do not wait on it, and never try to stop
auto-merge for it. If the PR merges before the change is pushed, the
branch is done: the change becomes a follow-up issue, which needs the
human's approval before it is filed
([doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues)).
Propose it to the human and file it only as they approve.

## Kinds of fix

- **A routine rebase.** `develop` moved, often because another PR in the
  same submit merged first, and the PR conflicts with it or needs its
  changes. Rebase onto it: `vrg-git fetch origin`, then
  `vrg-git rebase origin/develop`. A rebase that applies with **no
  conflict** changes none of the branch's own code: it is routine, needs
  no merge review and no human sign-off, and goes straight to the
  validate, batch check and push of
  [Before every push](#before-every-push). Force-pushing your *own*
  in-flight PR after a rebase is pre-authorized; see *Resolving conflicts
  with the base branch* in `issue-implement`.
- **A resolved conflict.** A rebase that stops on a conflict you then
  resolve has changed the branch's code. It is a fix, merge-reviewed
  before it is pushed. If the rebase goes wrong while still in progress,
  `vrg-git rebase --abort` returns the branch to where it was; once it has
  completed, do not undo it yourself: stop and ask the human.
- **A CI fix or a review-comment change.** Any other code change. Commit
  it with `vrg-commit` on a single-issue PR, or as a fixup on a batch PR
  ([Batch PRs](#batch-prs--fold-every-fix-into-its-issues-commit)). It is
  merge-reviewed before it is pushed.

## Before every push

Every push to the PR goes through these steps in order. A push that skips
one can merge unreviewed or unchecked code, because auto-merge stays on.

1. **Validate** on the committed branch until green:
   `vrg-container-run -- vrg-validate`. Never suppress a gate.
2. **Merge-review every fix but a routine rebase.** Run the
   **`merge-review`** skill (`vergil:merge-review`) through its
   [Fix to an open PR](../merge-review/SKILL.md#fix-to-an-open-pr) entry,
   from the worktree, giving it the task issue `<ref>` and the PR's URL. On
   a single-issue PR `<ref>` is the PR's one `Closes` ref; on a batch PR it
   is the issue whose commit the fix changes. It reviews the whole branch
   against `origin/develop`, and every step passes `--pr <PR_URL>` to
   `vrg-merge-review-request`. Its outcome decides what follows:

   | Outcome | Then |
   | --- | --- |
   | `eligible` | Go on to the next step. |
   | `not-eligible (<reason>)` | **Do not push.** Tell the human the eligibility line and the branch's head, and stop; the human decides what happens to the fix. |
   | `stopped: request <id>` | Do not push. Stop, giving the request ID. The human replies with `vrg-ruling-reply`, and running this skill again resumes the review. |
   | `waiting: non-review items` | Do not push. Stop and list the items. |
   | `fatal` or `error` | Do not push. Stop with the outcome or the error shown. |

   Only a routine rebase skips this step. Any resolved conflict is a fix
   and is reviewed, even one resolved by taking `develop`'s side whole.
3. **On a batch PR, run the batch check** on the exact head about to be
   pushed:

   ```bash
   vrg-pr-workflow batch-check --pr <PR_URL> --head "$(vrg-git rev-parse HEAD)"
   ```

   It checks that the branch holds one commit per issue since `develop`,
   in the body's order, and that the body's `Closes` refs match the PR's
   closing references. It does not re-check the batch's hard rules, which
   submit already checked. **A non-zero exit refuses the push:** show the
   human its message and stop. A routine rebase is checked too. On a
   single-issue PR it prints that the PR is not a batch PR and exits 0,
   so running it there is harmless but not needed.
4. **Push.** After a rebase or a fold, `vrg-git push --force-with-lease`;
   otherwise `vrg-git push`. Never a bare `--force`.
5. **Tell the human** to rerun `vrg-finalize-pr <PR>`, not to merge: the
   fix lands by itself once CI is green, and finalize then counts the PR
   as merged and settles `develop`. Then loop.

## Batch PRs — fold every fix into its issue's commit

A PR whose body has more than one `Closes` line is a **batch PR**
(`vrg-gh pr view <PR_URL> --json body,baseRefName`). It carries exactly one
commit per issue, in its listed order, each subject ending in `(#<N>)`, and
auto-merge rebase-merges it, so each commit lands on `develop` as it is.
Nothing re-checks that shape at merge time: the
[batch check](#before-every-push) before each push is what holds it. So
on a batch PR a CI or review fix is never a new commit. Handle each fix
like this:

1. **Find the owning issue.** Decide which single issue the fix belongs to,
   then find that issue's commit:
   `vrg-git log --format='%H %s' origin/develop..HEAD`. It is the commit
   whose subject ends in `(#<N>)`. If the fix belongs to no single issue
   (it spans several, or none), **stop and ask the human**, naming the fix
   and the issues it touches. Do not guess an owner and do not add a
   commit. A conflict resolved during a rebase belongs to the commit the
   rebase stopped on; if resolving it means changing more than one
   issue's commit, stop and ask the human the same way.
2. **Commit it as a fixup** of that commit:
   `vrg-commit --fixup <owning issue's commit SHA>`.
3. **Fold it:** `vrg-git rebase -i --autosquash origin/develop`. vrg-git
   keeps the rebase non-interactive. If the fold conflicts, run
   `vrg-git rebase --abort` and **stop and ask the human**, naming the fixup
   and the commit it conflicted on. Never resolve a fold conflict by moving
   the change to another issue's commit.
4. **Check the shape:** `vrg-git log --format='%s' origin/develop..HEAD`
   must again show exactly one commit per issue, in order, with no
   `fixup!` subject left. If it does not, stop and ask the human.
5. **Then [Before every push](#before-every-push)**, with the owning
   issue as the merge review's `<ref>`. The review's own commits are
   fixups of that issue's commit, and the review never folds: once it has
   ended `eligible`, fold again as in step 3 and check the shape as in
   step 4, before the batch check. The fold changes no tree, so nothing
   is re-validated or re-reviewed.

Several fixes found in one pass may each go to their own issue's commit
before the single fold, review and push, so long as they belong to one
issue; fixes to several issues' commits are reviewed one issue at a time,
each review before the next fix is made. A routine rebase is unchanged on
a batch PR: it rewrites every commit but keeps one per issue, and the
batch check confirms that before it is pushed.

A **single-issue PR** commits each fix as a new commit, and squash-merges.

## Finalize's reasons — what to do for each

`vrg-finalize-pr` watches the submitted PRs and never merges one. Its
report lists each PR as merged or *not merged*, with one of these reasons.
Auto-merge stays on for a failed PR, so a fix that turns CI green lands by
itself.

| Reason | What to do |
| --- | --- |
| `failed: CI` | Fix the named check, as a CI fix in [Kinds of fix](#kinds-of-fix), through [Before every push](#before-every-push). |
| `failed: conflict` | Rebase onto `origin/develop`: a clean rebase is routine; a resolved conflict is merge-reviewed. Then push through [Before every push](#before-every-push). |
| `timed out` | The batch deadline passed with the PR still pending. Watch it with `vrg-pr-await` and reconcile whatever it settles on; it may still land by itself. |
| `failed: auto-merge off` | Stop: see [Auto-merge off](#auto-merge-off-or-a-provenance-violation--stop). |
| `failed: provenance` | Stop: see [Auto-merge off](#auto-merge-off-or-a-provenance-violation--stop). |
| `failed: closed` | Stop and tell the human. Never reopen it. |
| `failed: not a develop PR` | Stop and tell the human. Finalize does not watch it, and neither does this skill. |
| merged, with a provenance violation flagged | Nothing to fix on the branch. Tell the human, who investigates it; push nothing. |

After any fix is pushed, the human reruns `vrg-finalize-pr <PR>`, which
counts the PR as merged once it lands.

### Auto-merge off or a provenance violation — stop

Auto-merge off on an open PR is an exception, never repaired here. The one
time our tooling turns it off on purpose is a provenance violation, which
is a stop-everything event for the human to investigate. Any other off is
an exception too. Either way: **stop at once**, push nothing, and tell the
human loudly, naming the PR and its head. Never turn auto-merge on or off
yourself, and never merge the PR.

## The PR merged

A merged PR is finished: the branch is done for good, and any further
change is a new follow-up issue, proposed to the human first. Tell the
human it merged, and whether any fix was pushed since finalize last ran:
if so, they rerun `vrg-finalize-pr <PR>` so finalize counts it and settles
`develop`.

## Why pushing here is allowed (the freeze lifts at submit)

Between `report-ready` and submit the branch is **frozen** — `vrg-commit` and the
`vrg-git` push path refuse commits and branch-advancing pushes to it (the tooling
stopping the reused-branch straggler). `vrg-submit-pr` marks the workflow
`submitted`, which **lifts that freeze**. So by the time this skill runs the
branch is already unfrozen, and the reconcile commits and post-submit
rebase/force-push above are legitimate — they act on an open PR, not on a frozen
pre-submit branch.

That distinction is the whole point: this skill is the *only* place a
reported-ready branch is touched again, and only because the human's submit
reopened it. It is not a license to reopen a branch that has not been submitted —
that still requires a deliberate `vrg-pr-workflow unfreeze`. And once the PR
merges the branch is done for good: any further change is a new follow-up issue,
never a mutation of the merged branch.

## Notes

- **The human's submit turned auto-merge on.** `vrg-submit-pr` enables it
  on every PR it opens, squash for a single-issue PR and rebase for a
  batch PR, so the PR merges once its required checks are green. That is
  the merge: the human consented to it by submitting.
- **You never merge the PR, and never turn auto-merge on or off.** You
  never run `vrg-submit-pr` or `vrg-finalize-pr` either; you tell the
  human when to rerun finalize. Repositories also let the automation
  App's mechanized PRs merge on CI alone; that path is not this skill's.
- **Every push can merge.** That is why a fix other than a clean rebase is
  merge-reviewed first, and why a batch PR is checked before every push.
