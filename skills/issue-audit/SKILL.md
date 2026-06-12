---
name: issue-audit
description: Review a paired USER agent's implementation as the AUDIT agent. Use whenever you are acting as the audit half of the dual-agent loop — typically launched from the issue-implement hand-off line ("run /vergil:issue-audit <worktree>"), or when the human asks you to audit or review the paired implementation. Reviews the USER agent's delta read-only, running one judgment check per round-trip via vrg-pr-workflow and reporting each verdict. Never edits code. Run as the vergil-audit agent.
---

# Issue Audit

Drive the AUDIT half of the local PR workflow. You stay **dumb**: the
`vrg-pr-workflow` oracle hands you one judgment check at a time and owns the
workflow. You call `next`, run the single check it gives you against the delta,
report the result, and repeat until it tells you you are done.

> **Experimental.** The local dual-agent audit mechanism this skill drives is
> experimental at this time. It is implemented and available to experiment with,
> but it is not on the default path — `/vergil:issue-implement` runs *without*
> the local audit unless the human explicitly passes `audit`. You reach this
> skill only when that opt-in hand-off has happened. The PR-phase audit on the
> open PR is separate and unaffected.

## Input

You are launched with the **worktree path** the implement session handed off —
e.g. `/vergil:issue-audit /abs/path/.worktrees/issue-1234-slug` — not an issue
number. The implement session has already created that worktree and engaged the
workflow; your job is to review what is there.

## Preflight

1. Confirm you are the **AUDIT** agent: `vrg-whoami --mode` must print `audit`.
   If not, stop.
2. **`cd` into the worktree path you were given** and stay there for the whole
   session — it is the shared worktree where the workflow state and the delta
   live. **You are read-only by discipline:** never edit code, never commit,
   never push. You report verdicts only through `vrg-pr-workflow`.

## Run it in the foreground — be transparent

Drive this loop **inline, in the foreground**, narrating as you go: announce each
check you receive, what you inspected, and the verdict you submit (with the
reason). Never spawn a sub-agent or run it silently — the human is watching this
session in a split screen, and the visible back-and-forth *is* the oversight.
While `next` blocks waiting for your turn it heartbeats ("still waiting for the
user to report ready…"); that is normal — let it wait, it is being patient by
design.

## The loop

Start (and re-enter) the loop with:

```bash
vrg-pr-workflow next      # you are in the worktree; the issue is taken from the state
```

`next` blocks until it is your turn, then prints **one** directive as JSON for a
single check:

- `check` — the check id.
- `prompt` — the full instructions for performing that check (inlined).
- `range` — the cumulative delta to review (`<base>..<head>`).
- `then: { verb: "submit-check", schema: "check.v1" }`.

Do this, then call `next` again:

1. Read the `prompt`. Perform **only** that one check against the `range`
   (`vrg-git diff <range>`, `vrg-git log <range>`, read files as needed).
2. Produce the `check.v1` JSON the prompt asks for and write it to a temp file:

   ```json
   { "id": "<check>", "status": "pass" | "fail" | "escalate",
     "findings": [ { "file": "<path>", "line": 1, "severity": "warning", "note": "<…>" } ],
     "reason": "<why a human is needed, if escalate>" }
   ```

3. Submit it:

   ```bash
   vrg-pr-workflow submit-check --payload <temp-file>
   ```

The oracle hands you the next check, or — once every check for the round is in —
rolls up and hands control back to the USER. When the workflow is approved,
`next` returns `{ "done": true, ... }`; stop.

If `next` **errors** (the counterpart aborted), or you cannot proceed at all,
surface it to the human and stop. Do not loop. (A single check that *needs* a
human is reported as that check's `status: "escalate"` with a `reason` — not by
giving up.)

## Notes

- The CLI resolves your role from `vrg-whoami` — never pass `--as`.
- One check per round-trip keeps your working set small; you never hold all the
  checks at once.
- Posting the `vergil-audit/approved` merge check happens later, on the PR (the
  post-PR phase), not here.
