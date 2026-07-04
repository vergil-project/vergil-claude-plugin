---
name: triage-capture
description: Capture an uncurated idea, bug, or to-do into the intake queue so it is never lost. Use whenever the human says "don't forget X", "capture this", "note a todo", "file an issue for…", or riffs an idea they want to come back to later — especially mid-task or via voice. Creates an intake issue — `triage` (a problem not yet understood), `idea` (a spark), or `research` (a reproducible investigation) — in the org `.github`, paraphrasing voice-to-text into clean written prose.
---

# Triage capture

## Overview

The formal path (brainstorm → spec → epic → tasks) is the preferred on-ramp, but
most work arrives uncurated — a dog-walk epiphany, a "we should probably…", an
"oh, don't forget". This skill is the **lossless net**: it turns that raw input
into an intake issue with near-zero friction, so nothing is dropped. The issue
sits in the org `.github` intake queue until `triage-review` routes it into the
epic/task model.

## When to use

Fire whenever the human wants to record something without stopping to plan it:
"don't forget to…", "capture this idea", "note a todo", "file an issue for…",
"remind me to…", or a stream-of-consciousness riff on an idea to revisit.

## Workflow

1. **Pick the kind.** All intake is filed in the org `.github` (one org-wide
   queue — no per-repo choice); choose the `--kind`:
   - `triage` — a problem, bug, or to-do not yet understood; needs diagnosis.
   - `idea` — a spark or "what if we…"; a seed to expand into a feature/epic.
   - `research` — an investigation meant to produce a reproducible result.
   - When unsure, use `triage`.
2. **Paraphrase.** If the input was voice-to-text (run-on, casual, transcription
   glitches), rewrite the substance into clean prose for the title and body —
   never paste the raw transcript into a durable issue.
3. **Write the body to a temp file** (no heredocs) — a one-line problem
   statement and any context the human gave. Add a `## Why` line if the intent
   isn't obvious from the title.
4. **Create the issue:**

   ```bash
   vrg-triage-create --kind <triage|idea|research> \
     --title "<concise, specific title>" \
     --body-file <tmpfile>
   ```

   `vrg-triage-create` applies the `--kind` label, files the issue in the org
   `.github` by default, and leaves it unlinked (no parent epic) —
   `triage-review` routes it into the epic/task model later. Extra labels are
   optional via `--label`.
5. **Report** the new issue URL and stop. Do **not** plan, scope, or start work
   — that is what `triage-review` and the formal path are for.

## Notes

- `triage` means "not yet in the formal model" — the issue is intentionally
  exempt from the every-task-needs-an-epic rule until it is reviewed.
- All intake lives in the org `.github`, so the whole queue is one filtered view
  (`label:triage`, `label:idea`, `label:research`), surfaced by `triage-review`.
  This keeps every other repo's issue list to single-PR tasks only.
- Keep it fast. One issue, correctly labelled, is the whole job.
