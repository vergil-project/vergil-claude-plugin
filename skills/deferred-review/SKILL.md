---
name: deferred-review
description: Review the deferred queue — re-check every deferred item's revival conditions against the current state of the world and recommend keep, refresh, revive, or drop. Use when the human asks to "review deferred", "what's deferred", "revisit the backlog", "process the deferred queue", or wants the periodic deferred pass. Lists the queue with `vrg-queue deferred`, actually checks each item's `Revisit when:` conditions (release pages, issue states, dates, upstream status), presents items in batches of 4 with what was checked and one recommended outcome, takes one confirmation per batch, and applies it with `vrg-intake-route`.
---

# Deferred review

## Overview

`intake-review` and `planning-review` park items that were evaluated but are not
ready yet: `vrg-intake-route <ref> defer` moves each one under its queue home's
**deferred epic** (`Epic (deferred): <name>`) with a deferral comment:

```text
Deferred <YYYY-MM-DD>: <reason>
Revisit when: <conditions>
Deferred from: <owner>/<repo>#<N>
```

This skill works that queue. It is a human-in-the-loop pass that rereads each
item's latest deferral, **actually checks the `Revisit when:` conditions against
the world**, and recommends exactly one of four outcomes:

| Outcome | Effect |
| --- | --- |
| **keep** | No command. The conditions are not met yet; the item stays as it is. |
| **refresh** | Re-defers in place with an updated reason and conditions. A new dated deferral comment, no move. |
| **revive** | Moves the item out of the deferred queue: back to **intake** (needs a fresh look), to **planning** (needs a full epic), or as a **one-off** under a repo's ad-hoc or finite epic. |
| **drop** | Comments the reason and closes the item as not planned. Closed stays searchable. |

The human can stop at any point. Unreviewed items simply stay deferred, so
there is nothing to resume.

## When to use

"review deferred", "what's deferred", "revisit the backlog", "process the
deferred queue" — or the periodic deferred pass.

## Preflight

- Confirm you are the **USER** agent (`vrg-whoami --mode` is `user`). This skill
  closes issues, which the user identity may do.

## Workflow

### 1. Collect the queue

```bash
vrg-queue deferred                         # the org's .github deferred queue
vrg-queue deferred --repo <owner>/<repo>   # a self-homed private repo's own queue
```

Without `--repo` it shows the current org's `.github` queue (the home of every
public repo). A **private** repo self-homes its queue; review it with
`--repo <owner>/<private-repo>`. Every item is `waiting`, and the note on each
line is the item's **latest deferral** — its reason and `Revisit when:`
conditions. Items come **least recently deferred first**: a refreshed item sinks
to the bottom, while a kept item writes nothing and stays near the top. The
order is a reading aid; a review normally goes through the whole queue. Add
`--json` for a machine-readable list.

Report the count and the one-line list to the human.

**No queue yet is not a failure.** If `vrg-queue` reports that there is no open
`Epic (deferred): <name>` epic in the home, nothing has ever been deferred
there. Report "no deferred queue yet — nothing to review" and stop. Do not
retry, and do not create the epic. Any other error is a real failure: report it
and stop.

### 2. Present a batch of 4

Take the next 4 items in queue order. For each:

1. **Read the issue and its latest deferral:**
   `vrg-gh issue view <N> --repo <owner>/<repo> --comments`. The latest
   `Deferred <date>:` comment carries the reason, the `Revisit when:`
   conditions, and (when the item moved) the `Deferred from:` container epic.
2. **Actually check the conditions.** The conditions are free prose — a date,
   an event, or both — so check each one against its real source:
   - **dates:** compare against today's date.
   - **issue and PR states:** `vrg-gh issue view <ref> --json state,closedAt`,
     `vrg-gh pr view <ref> --json state,mergedAt`.
   - **releases:** `vrg-gh release list --repo <owner>/<repo>` for a GitHub
     project; the project's release page or changelog otherwise.
   - **upstream status:** the upstream issue, roadmap, or announcement the
     condition names.
   Also look for anything that overtook the item — an overlapping issue or epic
   that already landed the work:
   `vrg-gh search issues --owner <owner> "<keywords>" --json repository,number,title,state`.
3. **Report what was checked and what was found** — each condition, the source
   you checked, and the result (met, not met, or could not be verified). The
   human trusts the recommendation because they can see the evidence.
4. **Recommend exactly one outcome:**
   - **keep** — the conditions are not met and still describe the right
     trigger.
   - **refresh** — the item should keep waiting, but the reason or conditions
     are stale (a date passed without the event, the trigger moved, a better
     signal exists). Draft the new reason and conditions.
   - **revive** — the conditions are met. Choose the destination with the
     `Deferred from:` line: an item deferred from an **ad-hoc** epic usually
     returns via **one-off** to that repo; one from **planning** returns to
     **planning**; one from **intake** returns to **intake** when it needs a
     fresh look, or straight to one-off or planning when its destination is
     already clear.
   - **drop** — the item is no longer needed: overtaken, obsolete, or "good
     idea, not feasible for years".

Write **one short paragraph per item**: what it is, why it was deferred, what
you checked and found, and the recommended outcome with its target where it
needs one. Paraphrase; don't just echo titles.

**Never fabricate a check.** If a condition cannot be verified — the source is
unreachable, the condition is too vague to test, or the evidence is ambiguous —
say so plainly and recommend **keep** (or a **refresh** with sharper conditions,
if the vagueness is the problem). Never report a condition as met or unmet
without having looked.

### 3. One confirmation per batch

The human confirms or redirects the **whole batch in one reply**. Do not gate
each item separately, and apply nothing before the reply.

### 4. Apply the batch

Use the fully qualified item ref (`<owner>/<repo>#<N>`), since items come from
many repos:

```bash
# keep: no command
vrg-intake-route <owner>/<repo>#<N> defer --reason "<why it still waits>" --revisit-when "<updated conditions>"
vrg-intake-route <owner>/<repo>#<N> intake
vrg-intake-route <owner>/<repo>#<N> planning
vrg-intake-route <owner>/<repo>#<N> one-off --repo <owner>/<target-repo> [--epic adhoc|#<E>|<owner>/<repo>#<E>]
vrg-intake-route <owner>/<repo>#<N> drop --reason "<why>"
```

- **keep** runs nothing. A kept item stays near the top of the queue, which is
  intended: it comes up again next pass until its conditions change or it is
  refreshed.
- **refresh** is a `defer` on an item that is already deferred: it posts a new
  dated deferral comment (with no `Deferred from:` line) and does not move the
  item.
- **revive** to **one-off** uses the same transfer-or-reparent mechanics as
  `intake-review`: `--epic` defaults to `adhoc`, a cross-repo move transfers the
  issue (or recreates it with a `Moved from <url>` line when GitHub refuses the
  transfer). Report the new ref from the `Routed …, now <ref>` line.
- **The agent closes dropped items itself**, through `vrg-intake-route`, once
  the human has confirmed the batch. Do not hand the close back to the human.
- **A refusal is information, not an obstacle.** `vrg-intake-route` exits 1 with
  the reason when a route must not run (for example, a cross-org target, or a
  private repo's item headed to a public repo or epic). Report it with the batch
  results and ask the human for a different outcome — never work around it by
  hand.

### 5. Next batch, then report

Report the batch's results (including any new refs and any transfer→recreate
fallbacks), then present the next batch. Stop when the queue is exhausted or the
human stops. Finish with the tallies: kept · refreshed · revived to intake ·
revived to planning · revived as one-off · dropped · remaining unreviewed.

## Notes

- **Checking is the point.** A deferred queue reviewed from the comments alone
  is just a reread. The value of this skill is that it looks at the world — the
  release, the issue, the date — before recommending.
- **No per-item label.** Membership in the deferred epic is the state. Never
  add or remove labels to express deferral.
- **In and out only through the route.** Do not move items into or out of the
  deferred epic with `vrg-epic-move` or `vrg-issue-create`; they refuse it, so
  that no item is deferred without its deferral comment or revived silently.
- **Private work stays private.** Never route a private repo's item to a public
  repo or epic; the tool refuses it.
- Deferred items are not PR-workable: `issue-implement`,
  `vrg-pr-workflow report-ready`, and `vrg-submit-pr` refuse them. Reviving an
  item is what makes it workable again.
