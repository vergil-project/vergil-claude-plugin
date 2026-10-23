---
name: intake-capture
description: Capture an uncurated idea, bug, or to-do into the intake queue so it is never lost. Use whenever the human says "don't forget X", "capture this", "note a todo", "file an issue for…", "remind me to…", or riffs an idea they want to come back to later — especially mid-task or via voice. Creates one intake issue with `vrg-intake-create`, linked under its home's intake epic, with no kind or category decision; paraphrases voice-to-text into clean written prose.
---

# Intake capture

## Overview

The formal path (brainstorm → spec → epic → tasks) is the preferred on-ramp, but
most work arrives uncurated — a dog-walk epiphany, a "we should probably…", an
"oh, don't forget". This skill is the **lossless net**: it turns that raw input
into an **intake issue** with near-zero friction, so nothing is dropped.

An intake item is any issue whose parent is an **intake epic** (`Epic (intake):
<name>`, labelled `epic` + `intake`). Its membership in the intake queue *is* its
state — there is no kind label and no category to choose. The item waits there
until `intake-review` routes it (drop, defer, one-off, split, or planning).

## When to use

Fire whenever the human wants to record something without stopping to plan it:
"don't forget to…", "capture this idea", "note a todo", "file an issue for…",
"remind me to…", or a stream-of-consciousness riff on an idea to revisit.

## Workflow

1. **Paraphrase.** If the input was voice-to-text (run-on, casual, transcription
   glitches), rewrite the substance into clean prose for the title and body —
   never paste the raw transcript into a durable issue.
2. **Write the body to a temp file** (no heredocs) — a one-line problem
   statement and any context the human gave. Add a `## Why` line if the intent
   isn't obvious from the title. A one-line "don't forget X" is a valid capture.
3. **Create the issue:**

   ```bash
   vrg-intake-create --title "<concise, specific title>" --body-file <tmpfile>
   ```

   With no `--repo`, the issue is filed in the **current repo's queue home**:
   the org `<owner>/.github` for a public repo, or the repo itself for a
   self-homed **private** repo — so a private repo's capture lands in its own
   intake queue automatically and never reaches the public `.github`. Pass
   `--repo <owner>/<repo>` only to file somewhere else. The tool links the new
   issue under that repo's intake epic as it creates it (creating the epic on
   first use). Extra labels are optional via `--label`.
4. **Report** the new issue URL (the tool prints `Created <url> (intake, under
   <epic>).`) and stop. Do **not** plan, scope, or start work — that is what
   `intake-review` and `epic-create` are for.

## Failure handling

- If `vrg-intake-create` exits 1 after printing `created <url> but it is not
  linked under intake epic …`, the issue **exists** but is unlinked. Do **not**
  re-run the create (that duplicates it). Report the URL and the `vrg-epic-move`
  command the error names to the human. The scheduled orphan sweep would attach
  it later, but the human should know now.
- Any other non-zero exit created nothing (the intake epic is resolved before
  the issue). Report the error; do not fall back to another creation path.

## Notes

- **No kind step.** The retired `triage` / `idea` / `research` labels are never
  applied, and `vrg-intake-create` has no `--kind` flag. The pre-rename capture
  command survives for one release as a deprecated alias that warns and
  forwards here; do not use it.
- Every intake item is born linked. There is no unlinked "capture now, link
  later" state, so the every-issue-has-an-epic invariant holds from creation.
- Keep it fast. One issue, correctly worded, is the whole job.
