---
name: intake-review
description: Review the intake queue — route every uncurated intake item into the epic/task model, oldest first. Use when the human asks to "review intake", "process the intake queue", "what's in intake", "groom the backlog", "let's do intake", or the old phrasings "review triage", "process the triage queue", "what's in triage", or wants the periodic intake pass. Lists the queue with `vrg-queue intake`, presents items in batches of 4 (each checked against current state first, with a recommended route), takes one confirmation per batch, and applies it with `vrg-intake-route` — closing dropped and split items itself.
---

# Intake review

## Overview

`intake-capture` fills a lossless net: every capture is an open child of an
**intake epic** (`Epic (intake): <name>`). This skill empties it. It is a
human-in-the-loop pass that reviews each intake item, oldest first, and routes
it to exactly one of five ends:

| Route | Effect (applied by `vrg-intake-route`) |
| --- | --- |
| **drop** | Comments the reason and closes the item as not planned. Closed stays searchable. "Good idea, not feasible for years" is a drop. |
| **defer** | Adds a dated `Deferred <date>: <reason>` comment and leaves the item in intake. It keeps its age, so it comes up first next time. |
| **one-off** | Moves the item into its target repo and links it under that repo's ad-hoc epic (default) or an existing finite epic. |
| **split** | The replacement tasks already exist; comments links to them with the reason, then closes the item. |
| **planning** | Reparents the item from the intake epic to the planning epic, where `epic-create` expands it into a full epic. |

The human can stop at any point. Unreviewed items simply stay in intake, so
there is nothing to resume.

## When to use

"review intake", "process the intake queue", "what's in intake", "groom the
backlog", "let's do intake" — and the pre-rename phrasings "review triage",
"process the triage queue", "what's in triage".

## Preflight

- Confirm you are the **USER** agent (`vrg-whoami --mode` is `user`). This skill
  closes issues, which the user identity may do.

## Workflow

### 1. Collect the queue

```bash
vrg-queue intake                         # the org's .github intake queue
vrg-queue intake --repo <owner>/<repo>   # a self-homed private repo's own queue
```

Without `--repo` it shows the current org's `.github` queue (the home of every
public repo). A **private** repo self-homes its queue; review it with
`--repo <owner>/<private-repo>`. The text output is a header line (`intake queue
for <name> in <home>: N open item(s)`) and one line per item, oldest first:
`<owner>/<repo>#<N>  <age>  waiting  <title>  — <latest comment's first line>`.
Add `--json` for a machine-readable list (`ref` is an `{owner, repo, number}`
object; also `title`, `created_at`, `state`, `note`).

Report the count and the one-line list to the human.

**No queue yet is not a failure.** If `vrg-queue` exits 1 with `no open 'Epic
(intake): <name>' intake epic in <home>`, nothing has ever been captured there
(the epic is created by the first capture). Report "no intake queue yet —
nothing to review" and stop. Do not retry, and do not create the epic. Any other
error is a real failure: report it and stop.

### 2. Present a batch of 4

Take the next 4 items, oldest first. For each, **check current state before
recommending anything**:

- Read the item: `vrg-gh issue view <N> --repo <owner>/<repo> --comments`.
- Look for an overlapping or already-closed issue or epic:
  `vrg-gh search issues --owner <owner> "<keywords>" --json repository,number,title,state`.
- When it describes a bug, read the code (and recent history) to see whether it
  is already fixed.

Then write **one short paragraph per item**: what it is, why it matters, where
it stands now (the state you just checked), and the **recommended route** —
with its target where the route needs one (repo and epic for a one-off, the task
list for a split). Prefer an **existing finite epic** over the ad-hoc bucket
when the item clearly belongs to one. Paraphrase; don't just echo titles.

### 3. One confirmation per batch

The human confirms or redirects the **whole batch in one reply**. Do not gate
each item separately, and apply nothing before the reply.

### 4. Apply the batch

Use the fully qualified item ref (`<owner>/<repo>#<N>`), since items come from
many repos:

```bash
vrg-intake-route <owner>/<repo>#<N> drop --reason "<why>"
vrg-intake-route <owner>/<repo>#<N> defer --reason "<why now is not the time>"
vrg-intake-route <owner>/<repo>#<N> one-off --repo <owner>/<target-repo> [--epic adhoc|#<E>|<owner>/<repo>#<E>]
vrg-intake-route <owner>/<repo>#<N> planning
vrg-intake-route <owner>/<repo>#<N> split --into <ref> [--into <ref> …] --reason "<why>"
```

- **The agent closes dropped and split items itself**, through
  `vrg-intake-route`, once the human has confirmed the batch. Closing is not a
  human-only action — `vrg-gh issue close` works for the user identity — so do
  not hand the close back to the human.
- **one-off** `--epic` defaults to `adhoc` (the target repo's ad-hoc epic, created
  if absent); `#<E>` reads against the target repo's epic home. A move to
  another repo **transfers** the issue to keep its history. If GitHub refuses
  the transfer, the tool **recreates** the item in the target repo with a
  `Moved from <url>` line, closes the original with a pointer, and says so on
  stderr. Either way it re-links the resulting issue under the epic. Report the
  new ref from the `Routed …, now <ref> (by transfer|recreate).` line. A one-off
  whose work lands in the item's own repo is just reparented.
- **split**: create each replacement task **first**, each with a body line
  linking back to the original (e.g. `Split from <owner>/<repo>#<N>`), in the
  repo where its PR will land:

  ```bash
  vrg-issue-create --epic <adhoc|<owner>/.github#E> --repo <owner>/<repo> \
    --title "<task>" --body-file <tmpfile>
  ```

  Then route the original with one `--into` per new task. A bare `#N` in
  `--into` reads against the item's repo, so qualify cross-repo tasks.
- **planning** keeps the item in its repo and moves it under the planning epic
  of the same queue home. `epic-create <ref>` picks it up from there.
- **A refusal is information, not an obstacle.** `vrg-intake-route` exits 1 with
  the reason when a route must not run: the item is not under an intake epic,
  the target is cross-org, a one-off names a queue epic, or a private repo's
  item is headed to a public repo or epic. Report it with the batch results and
  ask the human for a different route — never work around it by hand.

### 5. Next batch, then report

Report the batch's results (including any new refs and any transfer→recreate
fallbacks), then present the next batch. Stop when the queue is empty or the
human stops. Finish with the tallies: dropped · deferred · one-off · split ·
planning · remaining in intake.

## Notes

- **Oldest first is the pressure.** There is no stale flag or auto-close; the
  oldest item always comes up first, and a deferred item keeps its age.
- **Never apply a retired label.** `triage` / `idea` / `research` are retired;
  the parent epic is the state. A recreated item does not carry them over.
- **Private work stays private.** Never route a private repo's item to a public
  repo or epic; the tool refuses it, and GitHub refuses private → public
  transfers anyway.
- Intake and planning items are not PR-workable: `issue-implement`,
  `vrg-pr-workflow report-ready`, and `vrg-submit-pr` refuse them. Routing an
  item out of intake (one-off or split) is what makes it buildable.
