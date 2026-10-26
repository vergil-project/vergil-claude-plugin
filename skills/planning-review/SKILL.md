---
name: planning-review
description: Review the planning queue with the human and decide what to plan next. Use when the human asks to "review planning", "what should we plan next", "prioritize the planning queue", "what's in planning worth planning", or wants the periodic planning pass. Lists the queue with `vrg-queue planning`, ranks it with the human by priority and importance, picks the item(s) to hand to `epic-create`, and defers, drops, or leaves the rest with `vrg-intake-route`. Core rule — plan an epic only when you mean to implement it soon.
---

# Planning review

## Overview

The planning queue (`Epic (planning): <name>`) holds items that need a full
epic. `epic-create` expands one item at a time; this skill decides **which one
to expand next**. It is a human-in-the-loop conversation that ranks the queue by
priority and importance and ends in a short pick list for `epic-create`.

## The core rule — plan only what you mean to implement soon

**Plan an epic only when you intend to implement it soon.** A plan left sitting
for months goes stale: by the time anyone builds it, it needs a conceptual
rebase onto everything built in the meantime. A pile of planned-but-unbuilt
epics is waste, not progress.

So this review is about **near-term capacity**, not about emptying the queue:

- Pick only as many items as the human will actually start implementing soon —
  usually one, rarely more than two or three.
- When the human wants to pick more than that, say so plainly, name the staleness
  cost, and ask whether the extra items should wait in the queue instead. The
  human decides; the skill only discourages.
- An item that is important but not near-term is **not** a pick. Leave it, or
  defer it if its blockers are significant.

## Per-item outcomes

| Outcome | Effect |
| --- | --- |
| **pick** | Hand the item to `epic-create <owner>/<repo>#<N>`, which starts (or resumes) its planning run. |
| **defer** | `vrg-intake-route <ref> defer --reason "<why>" --revisit-when "<conditions>"` moves it to the deferred queue with a dated deferral record. For items whose blockers are significant. |
| **drop** | `vrg-intake-route <ref> drop --reason "<why>"` comments the reason and closes it as not planned. For items no longer needed. |
| **leave** | No change. The human's call, for items expected to be ready within days or a week. It comes up again next review. |

The human can stop at any point. Unreviewed items stay in the queue, so there is
nothing to resume.

## When to use

"review planning", "what should we plan next", "prioritize the planning queue",
or the periodic planning pass. To work one specific item, go straight to
`epic-create <ref>` instead.

## Preflight

- Confirm you are the **USER** agent (`vrg-whoami --mode` is `user`). A drop
  closes issues, which the user identity may do.

## Workflow

### 1. Collect the queue

```bash
vrg-queue planning                         # the org's .github planning queue
vrg-queue planning --repo <owner>/<repo>   # a self-homed private repo's own queue
```

Without `--repo` it shows the current org's `.github` queue (the home of every
public repo). A **private** repo self-homes its queue; review it with
`--repo <owner>/<private-repo>`. Each item has one of three states — `waiting`,
`in-progress`, `ready-to-close` — and its latest note (the first line of its
latest comment). Add `--json` for a machine-readable list (`ref` and `epic` are
`{owner, repo, number}` objects).

Report the count and the one-line list to the human, grouped by state.

**No queue yet is not a failure.** If `vrg-queue` exits 1 with `no open 'Epic
(planning): <name>' planning epic in <home>`, nothing has ever been routed to
planning there. Report "no planning queue yet — nothing to review" and stop. Do
not retry, and do not create the epic. Any other error is a real failure: report
it and stop.

### 2. Surface stalled and finished in-progress items first

Before ranking, deal with the items already mid-`epic-create`:

- **`ready-to-close`** — its epic is fully expanded. Offer to finish it with
  `epic-create <ref>`, which closes the planning issue. It is not a ranking
  candidate.
- **`in-progress`** — for each, give its **latest progress note** (read the
  comments with `vrg-gh issue view <N> --repo <owner>/<repo> --comments` when
  the one-line note is not enough) and how long it has sat. A stalled one is
  the doctrine's warning sign: planning started and stopped. Offer to:
  - **resume** it with `epic-create <ref>`, which picks up at the recorded
    resume point; or
  - **defer** it with `vrg-intake-route <ref> defer --reason … --revisit-when …`
    (the tool removes the `in-progress` label as part of the defer).

  **A refusal here is information.** If the item's progress comments record an
  `Epic:` marker, a development epic already exists, and `vrg-intake-route`
  refuses to defer or drop it — that would be suspending an epic. Report the
  refusal and offer to resume it instead. Never work around it by hand.

### 3. Rank the waiting items — a conversation, not a formula

There is **no scoring formula**. For the `waiting` items, check current state
before saying anything about an item:

- Read it: `vrg-gh issue view <N> --repo <owner>/<repo> --comments`.
- Look for an overlapping, already-built, or already-planned epic:
  `vrg-gh search issues --owner <owner> "<keywords>" --json repository,number,title,state`.
- Note its blockers — open issues, upstream releases, or other epics it waits on.

Then present the waiting items as a **proposed ranking**, most important first,
with **one short paragraph per item**: what it is, why it matters now, what it
is blocked on (the state you just checked), and a **recommended outcome**
(pick, defer, drop, or leave). Paraphrase; don't just echo titles. With a long
queue, present it in batches of 4 in ranked order.

The human reorders, argues, and redirects. Iterate until the ranking and the
pick list are agreed, applying the core rule to the size of the pick list.

### 4. One confirmation, then apply

The human confirms the whole set of outcomes in one reply. Apply nothing before
it. Use the fully qualified ref (`<owner>/<repo>#<N>`):

```bash
vrg-intake-route <owner>/<repo>#<N> defer --reason "<why now is not the time>" \
  --revisit-when "<what to check to know it can come back>"
vrg-intake-route <owner>/<repo>#<N> drop --reason "<why it is no longer needed>"
```

- **defer** needs both arguments. `--reason` is why the item is waiting;
  `--revisit-when` is what to check to know it can come back — a date, events
  ("vergil-tooling#1234 ships"), or both, in free prose.
- **The agent closes dropped items itself**, through `vrg-intake-route`, once
  the human has confirmed. Do not hand the close back to the human.
- **leave** writes nothing.
- **A refusal is information, not an obstacle.** `vrg-intake-route` exits 1 with
  the reason when a route must not run (an `Epic:` marker is recorded, the item
  is not under a planning epic, a cross-org or private-to-public move). Report
  it and ask the human for a different outcome.

### 5. Hand off the picks

Report the results (deferred · dropped · left · picked), then hand the first
pick to `epic-create`:

```text
/vergil:epic-create <owner>/<repo>#<N>
```

`epic-create` labels it `in-progress` and runs the full brainstorm → spec → plan
pipeline. With more than one pick, take them one at a time, in ranked order;
the rest stay `waiting` until their turn.

## Notes

- **Start simple.** This skill is deliberately a conversation, not a scoring
  system. Expect it to evolve with use; do not invent fields, labels, or
  priority scores.
- **Do not invent planning states.** `waiting`, `in-progress`, and
  `ready-to-close` are the only ones; detail belongs in the progress comment.
- **Private work stays private.** Never route a private repo's item to a public
  repo or epic; the tool refuses it.
- Planning items are not PR-workable: `issue-implement`,
  `vrg-pr-workflow report-ready`, and `vrg-submit-pr` refuse them. Expanding the
  item with `epic-create` is what produces buildable tasks.
