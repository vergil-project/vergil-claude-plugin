---
name: triage-review
description: Groom the triage intake queue — review uncurated issues and route each into the epic/task model. Use when the human asks to "review triage", "groom the backlog", "process the triage queue", "what's in triage", or wants the periodic (roughly weekly) intake pass. Collects every `triage`-labelled issue across the org and walks the human through dispositioning them one at a time.
---

# Triage review

## Overview

`triage-capture` fills a lossless net of `triage`-labelled issues. This skill
empties it: a human-in-the-loop pass that routes each uncurated issue into the
epic/task model, so the queue stays small and nothing rots. Run it on a cadence
(weekly-ish) or whenever the queue feels heavy.

## When to use

"review triage", "groom the backlog", "process the triage queue", "what's in
triage", "let's do intake".

## Workflow

1. **Collect the queue (cross-repo).** Gather every `triage` issue across the
   org's managed repos and `vergil-project/.github`:

   ```bash
   vrg-gh issue list --repo <owner>/<repo> --label triage \
     --json number,title,url,body
   ```

   Run per repo (or via search) and assemble one list. Report the count.
2. **Disposition each issue, one at a time.** Present the issue, recommend a
   disposition, and let the human confirm before acting. Pick exactly one:

   | Disposition | Action |
   | --- | --- |
   | **Drop** | Duplicate / wontfix / already done → close it. |
   | **Assign to an existing epic** | It's a task in an initiative → native-link it under that epic. |
   | **Route to the standing epic** | Small ad-hoc work → native-link under the repo's `Ad-hoc maintenance` standing epic. |
   | **Promote to a new epic** | A real seed → start `superpowers:brainstorming` to create a finite epic; this issue becomes/links to it. |

   Prefer assigning to an **existing** epic over the standing bucket ("a
   forgotten to-do in *that* project").
3. **Apply the disposition:**
   - **Link** (assign / route): `vrg-epic-link --epic <owner>/.github#<EPIC> --task <owner>/<repo>#<N>` to create the native sub-issue link.
   - **Remove the `triage` label** (it has entered the model):
     `vrg-gh issue edit <N> --repo <owner>/<repo> --remove-label triage`
     (add a `kind` label if missing).
   - **Drop**: closing an issue is a **human action** — agents are denied
     `issue close`. Tell the human to close it (or do it via `! vrg-gh issue
     close …`).
4. **Stop when the queue is empty** (or the human calls it). Report what was
   assigned, routed, promoted, and dropped.

## Notes

- Deeper automation of this grooming (batch auto-close, stale detection) is
  tracked separately; this skill is the human-in-the-loop version.
- "Promote to a new epic" is the on-ramp into the formal path — it's how a
  dog-walk seed becomes a planned initiative.
- Removing `triage` is what moves an issue *into* the model; until then it stays
  exempt from the every-task-needs-an-epic rule.
