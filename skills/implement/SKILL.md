---
name: implement
description: USER-identity skill — implement a GitHub issue on a feature branch, validate until green, then hand off to the local audit pair via the .vergil PR template. Run as the vergil-user agent.
---

# Implement

Drive the USER half of the Vergil 2.1 implement+audit pair (design spec
`docs/specs/2026-06-04-vergil-2.1-workflow-and-skill-rationalization-design.md`,
§5). Input: a GitHub issue (number or URL).

## Preflight

1. Confirm identity: this skill assumes the **USER** identity. If
   `VRG_IDENTITY_MODE` is `audit` or `human`, stop and tell the user this skill
   runs in the user-agent session.
2. Confirm you are in a feature-branch worktree for this issue (see
   `docs/development/starting-work-on-an-issue.md`). Do not work at the repo
   root.

## Loop

1. **Implement** the issue on the branch, following repo standards. Make small,
   focused commits with `vrg-commit`.
2. **Validate until green:** `vrg-container-run -- vrg-validate`. Fix every
   failure and re-run until it passes. Never suppress a gate to make it pass —
   the audit will reject that.
3. **Write the PR template = the "done" signal.** Write
   `.vergil/pr-template.yml` atomically (write `.vergil/pr-template.yml.tmp`,
   then `mv` it into place) with:

   ```yaml
   issue: <N>
   title: <conventional PR title>
   summary: <one line>
   notes: <optional>
   ```

   Its appearance tells the paired audit agent you are done. (`vrg-submit-pr`
   later consumes and deletes this same file.)
4. **Await the audit verdict.** If `.vergil/audit-feedback.yml` already exists,
   note its digest, then block:

   ```bash
   vrg-await .vergil/audit-feedback.yml            # first round
   vrg-await .vergil/audit-feedback.yml --since <prev-digest>   # later rounds
   ```

   `vrg-await` prints the new digest — thread it as `--since` next round.
5. **Act on the verdict** (`.vergil/audit-feedback.yml`; format:
   `docs/specs/figures/2026-06-04-vergil-2.1-workflow/audit-feedback-format.md`):
   - `verdict: approve` → tell the human: *"Approved — run `vrg-submit-pr` to
     open the PR."* Stop. Only the human opens the PR.
   - `verdict: changes` → fix every `findings` entry, re-validate (step 2),
     `vrg-commit`, **rewrite** `.vergil/pr-template.yml` (atomic), then return
     to step 4 with `--since`.
   - **File never appears** (the audit withheld it) → the audit has escalated an
     ERROR to the human. Surface this to the human and wait; do not loop.

## Notes

- **Resumability** is not yet built in (design §13). If this session is lost
  mid-loop, re-invoking `/vergil:implement <issue>` is the intended recovery;
  meanwhile `/vergil:handoff` is the safety net for unsaved in-flight state.
- This skill never opens the PR and never posts checks — those are the human's
  and the audit's jobs respectively.
