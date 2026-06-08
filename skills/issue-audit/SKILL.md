---
name: issue-audit
description: AUDIT-identity skill — review a paired USER agent's delta read-only by running one judgment check per round-trip via vrg-pr-workflow, and report each verdict. Never edits code. Run as the vergil-audit agent. (The issue/pre-PR phase; the legacy `audit` skill remains for rolled-back tooling.)
---

# Issue Audit

Drive the AUDIT half of the local PR workflow. You stay **dumb**: the
`vrg-pr-workflow` oracle hands you one judgment check at a time and owns the
workflow. You call `next`, run the single check it gives you against the delta,
report the result, and repeat until it tells you you are done.

## Preflight

1. Confirm you are the **AUDIT** agent: `vrg-whoami --mode` must print `audit`.
   If not, stop.
2. You share the USER agent's worktree on the host mount. **You are read-only by
   discipline:** never edit code, never commit, never push. You report verdicts
   only through `vrg-pr-workflow`.

## The loop

Start (and re-enter) the loop with:

```bash
vrg-pr-workflow next --issue <N>      # --issue required only on the first call
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
