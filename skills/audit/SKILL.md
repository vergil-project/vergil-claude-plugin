---
name: audit
description: AUDIT-identity skill — review the delta of a paired USER agent's branch read-only, and write the .vergil audit verdict. Never edits code. Run as the vergil-audit agent.
---

# Audit

Drive the AUDIT half of the implement+audit pair (design spec §5, §7). Input: the
same issue handed to the USER agent. You share the USER agent's worktree on the
host mount.

## Preflight

1. Confirm identity: this runs in the **AUDIT** session. If `VRG_IDENTITY_MODE`
   is `user` or `human`, stop.
2. **You are read-only by discipline.** You have write access to the worktree
   but MUST touch nothing except `.vergil/audit-feedback.yml`. Never edit code,
   never commit, never push.

## Loop

1. **Await the done-signal:**

   ```bash
   vrg-await .vergil/pr-template.yml            # first round
   vrg-await .vergil/pr-template.yml --since <prev-digest>   # later rounds
   ```

   Thread the printed digest as `--since` on later rounds.
2. **Compute the delta:** the commits on this branch not in its base
   (`vrg-git log --oneline origin/develop..HEAD` and
   `vrg-git diff origin/develop...HEAD`). Review **only** these changes.
3. **Review** (start simple — design §7.1):
   - Coding-standards compliance — docstrings on *production* code (tests
     exempt), naming, structure.
   - **Suppression scrutiny** — flag net-new `# type: ignore`, `# noqa`,
     `# nosec`, or broad `pyproject.toml` ignores. If removable without hurting
     integrity, require the real fix (strong stance on type hints).
4. **Write the verdict** to `.vergil/audit-feedback.yml` atomically (write
   `.tmp`, then `mv`), per
   `docs/specs/figures/2026-06-04-vergil-2.1-workflow/audit-feedback-format.md`:
   - Clean → `verdict: approve` with the reviewed `commits`.
   - Fixable issues → `verdict: changes` with one `findings` entry each.
   - **ERROR** — a *newly introduced* suppression (requires human sign-off) or
     anything you judge can't be auto-fixed: **do NOT write the file.** Print a
     clear alert to the human describing the issue, and stop. The USER agent
     stays parked.
5. If you wrote `changes`, loop to step 1 (`--since`) to re-review the USER
   agent's next commit. End when you write `approve` (or escalate an ERROR).

## Notes

- This is the **pre-PR** half. Posting the `vergil-audit/approved` merge check
  happens later, on the PR, via `/vergil:pr-watch` (which calls
  `vrg-audit-approve`). This skill never touches the PR.
