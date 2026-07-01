---
name: triage-capture
description: Capture an uncurated idea, bug, or to-do into the triage queue so it is never lost. Use whenever the human says "don't forget X", "capture this", "note a todo", "file an issue for…", or riffs an idea they want to come back to later — especially mid-task or via voice. Creates a `triage`-labelled GitHub issue in the most-relevant repo (or the org `.github` for project-level seeds), paraphrasing voice-to-text into clean written prose.
---

# Triage capture

## Overview

The formal path (brainstorm → spec → epic → tasks) is the preferred on-ramp, but
most work arrives uncurated — a dog-walk epiphany, a "we should probably…", an
"oh, don't forget". This skill is the **lossless net**: it turns that raw input
into a `triage`-labelled issue with near-zero friction, so nothing is dropped.
The issue sits in the triage queue until `triage-review` routes it into the
epic/task model.

## When to use

Fire whenever the human wants to record something without stopping to plan it:
"don't forget to…", "capture this idea", "note a todo", "file an issue for…",
"remind me to…", or a stream-of-consciousness riff on an idea to revisit.

## Workflow

1. **Pick the repo.** Choose the repo the item most belongs to:
   - The repo currently being worked on, or a repo the human names.
   - If it is cross-cutting, project-level, or you cannot tell → the org repo
     `vergil-project/.github`.
2. **Paraphrase.** If the input was voice-to-text (run-on, casual, transcription
   glitches), rewrite the substance into clean prose for the title and body —
   never paste the raw transcript into a durable issue.
3. **Write the body to a temp file** (no heredocs) — a one-line problem
   statement and any context the human gave. Add a `## Why` line if the intent
   isn't obvious from the title.
4. **Create the issue:**

   ```bash
   vrg-triage-create --repo <owner>/<repo> \
     --title "<concise, specific title>" \
     --body-file <tmpfile>
   ```

   `vrg-triage-create` adds the `triage` label and leaves the issue unlinked
   (no parent epic) — `triage-review` routes it to an epic later. Add a `kind`
   label too with `--label` if it's obvious (`bug`, `idea`, `docs`, …).
5. **Report** the new issue URL and stop. Do **not** plan, scope, or start work
   — that is what `triage-review` and the formal path are for.

## Notes

- `triage` means "not yet in the formal model" — the issue is intentionally
  exempt from the every-task-needs-an-epic rule until it is reviewed.
- The queue is a label, not a place: capture wherever the item arises; the
  cross-repo view is `label:triage`, surfaced by `triage-review`.
- Keep it fast. One issue, correctly labelled, is the whole job.
