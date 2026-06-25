---
name: pr-watch
description: Monitor and reconcile an open PR after vrg-submit-pr. Use whenever a PR has just been opened and needs watching — vrg-submit-pr emits the `/vergil:pr-watch <PR_URL>` line, or the human asks to watch, monitor, or babysit the PR through CI and review. Runs in the USER agent session: block on PR state with vrg-pr-await, reconcile failing CI and human review feedback, push fixes, and tell the human when the PR is mergeable.
---

# PR watch

Drive the post-PR loop. `vrg-submit-pr` prints `/vergil:pr-watch <PR_URL>`; run
it in the USER agent session to monitor the open PR through CI and human review,
reconcile feedback, and tell the human when the PR is ready to merge.

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

## Preflight

This skill runs in the **USER** agent session. Confirm with
`vrg-whoami --mode` (`user`). If `human`, stop — this skill is for the agent.

## Monitor & reconcile

Loop:

1. **Wait for the PR to settle:**

   ```bash
   vrg-pr-await <PR_URL> --since-sha <last-head-sha> --since-reviews <last-review-count>
   ```

   (Omit the `--since-*` flags on the first call.) It prints PR state as JSON —
   parse the checks, reviews, and head SHA.
2. **Stop condition:** all required checks are green → tell the human the PR is
   mergeable. Done.
3. Otherwise **reconcile both sources:** failing CI checks + human review
   comments. Patch the code, `vrg-commit`, and push (`vrg-git push`). The new
   commit re-triggers CI.
   - **Base-branch conflicts are routine here.** If the base (`develop`)
     advanced and the PR now conflicts, rebase onto it and force-push — no human
     sign-off needed: `vrg-git fetch origin`, `vrg-git rebase origin/develop`
     (resolve, validate green), then `vrg-git push --force-with-lease`.
     Force-pushing your _own_ in-flight PR after a rebase is pre-authorized; see
     *Resolving conflicts with the base branch* in `issue-implement`.
4. If you cannot get a check green or cannot satisfy a comment, **stop and ask
   the human** rather than thrashing.
5. Loop with the updated `--since-sha` / `--since-reviews`.

## Notes

- You never merge the PR. When the checks are green, the **human** reviews and
  merges (auto-merge is disabled fleet-wide).
