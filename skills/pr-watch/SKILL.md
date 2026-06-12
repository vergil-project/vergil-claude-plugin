---
name: pr-watch
description: Monitor and reconcile an open PR after vrg-submit-pr. Use whenever a PR has just been opened and needs watching — vrg-submit-pr emits the invocation line to paste into both agent sessions, or the human asks to watch, monitor, or babysit the PR through CI and review. As USER, monitor the PR and reconcile CI/audit/human feedback; as AUDIT, re-review and post the vergil-audit/approved check. Identity-keyed: paste the same line into both agent sessions.
---

# PR watch

Drive the post-PR loop (design spec §9). `vrg-submit-pr` prints
`/vergil:pr-watch <PR_URL>`; paste it into **both** agent sessions. Read your
own identity and run the matching half.

## Determine identity

Check `VRG_IDENTITY_MODE`: `user` → the **Monitor** half; `audit` → the
**Review** half. If `human`, stop — this skill is for the agents.

## USER half — Monitor & reconcile

Loop:

1. **Wait for the PR to settle:**

   ```bash
   vrg-pr-await <PR_URL> --since-sha <last-head-sha> --since-reviews <last-review-count>
   ```

   (Omit the `--since-*` flags on the first call.) It prints PR state as JSON —
   parse the checks, reviews, and head SHA.
2. **Stop condition:** all required checks are green **and** the
   `vergil-audit/approved` check is success → tell the human the PR is
   mergeable. Done.
3. Otherwise **reconcile all three sources:** failing CI checks + audit review
   comments + human comments. Patch the code, `vrg-commit`, and push
   (`vrg-git push`). The new commit re-triggers CI and the audit's re-review.
   - **Base-branch conflicts are routine here.** If the base (`develop`)
     advanced and the PR now conflicts, rebase onto it and force-push — no human
     sign-off needed: `vrg-git fetch origin`, `vrg-git rebase origin/develop`
     (resolve, validate green), then `vrg-git push --force-with-lease`.
     Force-pushing your _own_ in-flight PR after a rebase is pre-authorized; see
     *Resolving conflicts with the base branch* in `issue-implement`.
4. If you cannot get a check green or cannot satisfy a comment, **stop and ask
   the human** rather than thrashing.
5. Loop with the updated `--since-sha` / `--since-reviews`.

## AUDIT half — Review & gate

Loop:

1. **Wait for a new commit:**

   ```bash
   vrg-pr-await <PR_URL> --since-sha <last-head-sha>
   ```
2. Re-review the delta of the new head commit (read-only — design §7.1).
3. **Post the verdict on the PR:**
   - Findings → post review comments with `vrg-gh`, then
     `vrg-audit-approve <PR_URL> --conclusion failure` (the gate stays red).
   - Clean → `vrg-audit-approve <PR_URL>` (conclusion `success` — the
     `vergil-audit/approved` gate goes green).

   `vrg-audit-approve` refuses to run as USER, so only this session can move the
   gate.
4. **Stop** when you have approved and all checks are green. For an ERROR that
   needs the human, post `--conclusion failure` and alert them.

## Notes

- **Per-commit gate:** the `vergil-audit/approved` check is bound to the head
  SHA, so every USER push invalidates the prior approval and the AUDIT half must
  re-post. That is by design — it forces re-review of new commits.
