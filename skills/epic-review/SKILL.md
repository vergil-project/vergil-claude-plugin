---
name: epic-review
description: Review a queue of the epic/task model (intake, planning or deferred) with the human, in batches of 4 with one confirmation per batch, routing each item with `vrg-intake-route`. Use for "review intake", "process the intake queue", "what's in intake", "groom the backlog", "let's do intake", or the older "review triage", "process the triage queue", "what's in triage" (intake mode); "review planning", "clean up the planning queue" (planning mode, which prunes and never picks what to plan next); "review deferred", "what's deferred", "revisit the backlog", "process the deferred queue" (deferred mode, which checks every revival condition); or any periodic queue pass. `/vergil:epic-review <intake|planning|deferred|epic-ref>` names the queue; with no argument it shows the three counts and asks which. Refuses an ad-hoc or development epic. It only places items; it never implements one or starts epic-create.
---

# Epic review

## Overview

Work enters the epic/task model through three **queues**, each a standing
epic in its queue home:

- **intake** (`Epic (intake): <name>`): uncurated captures from
  `intake-capture`, whose destination is still unknown;
- **planning** (`Epic (planning): <name>`): items that need a full epic;
- **deferred** (`Epic (deferred): <name>`): evaluated items parked until
  their revival conditions are met.

This skill reviews one queue at a time with the human, putting each item in
the right state and the right place. It is the only review skill: one shared
procedure, written once below, with a short section per mode for what
differs.

**A review only places items; it never processes them.** An intake item
routed to ad hoc is not implemented here, and a planning review never starts
`epic-create`. Buildable work lives in a development epic, worked by
`epic-implement <epic>`, or in a repo's ad-hoc epic. Expanding a planning item
into a development epic is the human's own act: they choose the item and run
`epic-create <ref>` on it.

The human can stop at any point. Unreviewed items stay where they are, so
there is nothing to resume.

## Choosing the mode

```text
/vergil:epic-review intake|planning|deferred [--repo <owner>/<repo>]
/vergil:epic-review <epic-ref>
/vergil:epic-review
```

- **A keyword** selects its mode for the current org's queue home,
  `<owner>/.github`. `--repo <owner>/<repo>` selects another queue home
  exactly as `vrg-queue --repo` does: a **self-homed private repo** keeps
  its own queues, and they are reviewed only with its own `--repo`.
- **A trigger phrase** selects its mode directly, like the keyword: the
  intake and triage phrases select `intake`, the planning phrases
  `planning`, and the deferred phrases `deferred`. Do not ask which queue
  the human meant.
- **An epic ref** (`<owner>/<repo>#<N>`, `#<N>` in the current repo, or an
  issue URL) selects its mode from the issue's labels:

  ```bash
  vrg-gh issue view <N> --repo <owner>/<repo> --json labels
  ```

  | Labels | Kind | What to do |
  |---|---|---|
  | `epic` + `intake` | intake queue | Review it in intake mode, with `--repo <owner>/<repo>` (the ref's repo is its queue home). |
  | `epic` + `planning` | planning queue | Planning mode, the same way. |
  | `epic` + `deferred` | deferred queue | Deferred mode, the same way. |
  | `epic` + `ad-hoc` | a repo's ad-hoc epic | Refuse (see [Refusals](#refusals)). |
  | `epic`, none of the above | development epic | Refuse. |
  | no `epic` label (a task, or an `archive`) | not an epic | Refuse. |

  If the labels cannot be read, say so and stop rather than guess a mode.
- **No argument** is the only path that asks. Show the three queue counts:

  ```bash
  vrg-queue                         # all three queues of the org's .github
  vrg-queue --repo <owner>/<repo>   # a self-homed private repo's queues
  ```

  Report each queue's count (a queue whose epic does not exist yet is
  empty), then ask the human which queue to review. Never pick one
  yourself, even when only one queue has items.

### Refusals

Given anything that is not a queue, print the one line and stop. Do nothing
else: no queue read, no comment, no route.

- An ad-hoc epic: `<ref> is an ad-hoc epic; it holds placed work, not a queue.`
- A development epic: `<ref> is a development epic; it is worked with /vergil:epic-implement <ref>.`
- Not an epic: `<ref> is not an epic; review a queue with /vergil:epic-review intake, planning or deferred.`

## The shared procedure

Every mode runs these six steps. The [per-mode sections](#intake-mode) give
each mode's order, check, outcomes and tallies.

### 1. Preflight

Confirm you are the **USER** agent:
`[ "$(vrg-whoami --mode)" = user ] && echo ok || echo "not user"` must print
`ok`. Every mode can close issues, which the user identity may do. If it
prints anything else, stop.

### 2. Collect the queue

```bash
vrg-queue <intake|planning|deferred>                         # the org's .github queue
vrg-queue <intake|planning|deferred> --repo <owner>/<repo>   # a self-homed private repo's own queue
```

The text output is a header line (`<kind> queue for <name> in <home>: N open
item(s)`) and one line per item in the mode's order:
`<owner>/<repo>#<N>  <age>  <state>  <title>  — <latest note>`. Add `--json`
for a machine-readable list (`ref`, and for planning `epic`, are
`{owner, repo, number}` objects; also `title`, `created_at`, `state`,
`note`). Report the count and the one-line list to the human.

**A missing queue is an empty queue, not a failure.** If `vrg-queue` exits 1
with `no open 'Epic (<kind>): <name>' <kind> epic in <home>`, nothing has
ever been placed in that queue (its epic is created on first use). Report
"no <kind> queue yet — nothing to review" and stop. Do not retry, and do not
create the epic. Any other error is a real failure: report it and stop.

### 3. Present a batch of 4

Take the next 4 items in the mode's order. For each, **check its current
state before recommending anything**:

- Read the item and its comments:
  `vrg-gh issue view <N> --repo <owner>/<repo> --comments`.
- Look for an overlapping or already-closed issue or epic:
  `vrg-gh search issues --owner <owner> "<keywords>" --json repository,number,title,state`.
- Do the mode's own check (in its section below).

Then write **one short paragraph per item**: what it is, why it matters,
where it stands now (the state you just checked), and **one recommended
outcome**, with its target where the outcome needs one (repo and epic for a
one-off, the task list for a split, the reason and conditions for a defer).
Paraphrase; don't just echo titles.

### 4. One confirmation per batch

The human confirms or redirects the **whole batch in one reply**. Do not
gate each item separately, and apply nothing before the reply.

### 5. Apply the batch

Apply each confirmed outcome with `vrg-intake-route`, using the fully
qualified item ref (`<owner>/<repo>#<N>`), since items come from many repos:

```bash
vrg-intake-route <owner>/<repo>#<N> drop --reason "<why>"
vrg-intake-route <owner>/<repo>#<N> defer --reason "<why now is not the time>" \
  --revisit-when "<what to check to know it can come back>"
vrg-intake-route <owner>/<repo>#<N> one-off --repo <owner>/<target-repo> [--epic adhoc|#<E>|<owner>/<repo>#<E>]
vrg-intake-route <owner>/<repo>#<N> planning
vrg-intake-route <owner>/<repo>#<N> intake
vrg-intake-route <owner>/<repo>#<N> split --into <ref> [--into <ref> …] --reason "<why>"
```

Which routes a mode offers is in its section. Rules for every mode:

- **The agent closes dropped and split items itself**, through
  `vrg-intake-route`, once the human has confirmed the batch. Closing is not
  a human-only action (`vrg-gh issue close` works for the user identity), so
  do not hand the close back to the human.
- **defer** needs both `--reason` and `--revisit-when`. `--revisit-when` is
  free prose: a date ("re-research by 2027-01-26"), events ("Zensical 1.0
  ships", "`<owner>/<repo>#<N>` merges"), or both. Write conditions that a
  later `epic-review deferred` can actually check. The tool moves the item
  under the deferred epic of the same queue home and records a dated
  comment with a `Deferred from:` line naming the queue it left (it removes
  an `in-progress` label as it goes). `--date YYYY-MM-DD` overrides the
  stamped date; an ordinary review leaves it off.
- **one-off** moves the item to the repo where its work lands and links it
  under that repo's ad-hoc epic (`--epic adhoc`, the default, created if
  absent) or an existing finite epic (`#<E>` reads against the target
  repo's epic home). **Prefer an existing finite epic** over the ad-hoc
  bucket when the item clearly belongs to one. A move to another repo
  **transfers** the issue to keep its history; if GitHub refuses the
  transfer, the tool **recreates** the item in the target repo with a
  `Moved from <url>` line, closes the original with a pointer, and says so
  on stderr. Either way it re-links the resulting issue under the epic.
  Report the new ref from the `Routed …, now <ref> (by transfer|recreate).`
  line. A one-off whose work lands in the item's own repo is just
  reparented.
- **leave** and **keep** run nothing.
- **A scope change goes to the human.** When the human's ruling narrows or
  widens what a routed one-off must deliver (or settles a question its body
  leaves open), it is put on the issue by the human, never as a comment you
  post and never by editing its body
  ([doctrine §1.7, "Scope changes"](../../docs/paad-review-doctrine.md#17-creating-issues)):
  merge review counts only the human's own comments as amending a task's
  scope. After the route, write the change to a scratch file and, from a
  clone of the repo the issue now lives in (its `origin` must push there),
  run `vrg-ruling draft-scope --issue <owner>/<repo>#<N> --text-file <file>`
  with the issue's ref after the route. It posts nothing; give the human the
  `vrg-scope-change` command it prints, with the batch results. A split's
  tasks need none, since their bodies carry their scope, and neither does an
  item routed into another queue, since that queue's review re-scopes it.
- **A refusal is information, not an obstacle.** `vrg-intake-route` exits 1
  with the reason when a route must not run: for example the item is not in
  the queue the route expects, the target is cross-org, a one-off names a
  queue epic, a private repo's item is headed to a public repo or epic, or a
  planning item still has an open development epic (see
  [Drop in every mode](#drop-in-every-mode)). Report it with the batch
  results and ask the human for a different outcome. Never work around it by
  hand.

### 6. Next batch, then the tallies

Report the batch's results (including any new refs and any
transfer→recreate fallbacks), then present the next batch. Stop when the
queue is done or the human stops, and finish with the mode's tallies line.

## Drop in every mode

**drop** is an outcome in every mode: it comments the reason and closes the
item as not planned. Closed stays searchable, so "good idea, not feasible for
years" is a drop.

For a **planning** item, drop and defer are refused only **while one of its
development epics is open**, and allowed once every one is closed. That is
the rule `vrg-intake-route` enforces (since
vergil-project/vergil-tooling#4170), and it guards one-off from planning the
same way. A recorded `Epic:` marker alone does not block a drop. When the
tool refuses, the item's epic is still being built: report it, and
recommend leave.

## Intake mode

**Order:** oldest first. **Mode check:** when the item describes a bug, read
the code (and recent history) to see whether it is already fixed.

Each item gets one of six outcomes:

| Outcome | Effect (applied by `vrg-intake-route`) |
| --- | --- |
| **drop** | Comments the reason and closes the item as not planned. |
| **defer** | Moves the item out of intake into the deferred queue with a dated `Deferred <date>: <reason>` / `Revisit when: <conditions>` comment. `epic-review deferred` brings it back when its conditions are met. |
| **one-off** | Moves the item into its target repo and links it under that repo's ad-hoc epic (default) or an existing finite epic. |
| **split** | The replacement tasks already exist; comments links to them with the reason, then closes the item. |
| **planning** | Reparents the item from the intake epic to the planning epic, where the human can later choose it for `epic-create`. |
| **leave** | No route. The item stays in intake and comes up again next review. |

**leave** is the human's call, and it fits an item that will be ready within
days or a week. An item parked on an outside condition that will take longer
is a **defer**, not a leave.

**split mechanics.** Create each replacement task **first**, each with a body
line linking back to the original (e.g. `Split from <owner>/<repo>#<N>`), in
the repo where its PR will land:

```bash
vrg-issue-create --epic <adhoc|<owner>/.github#E> --repo <owner>/<repo> \
  --title "<task>" --body-file <tmpfile>
```

Then route the original with one `--into` per new task. A bare `#N` in
`--into` reads against the item's repo, so qualify cross-repo tasks.

**planning** keeps the item in its repo and moves it under the planning epic
of the same queue home. It is not a request to plan it now.

**Tallies:** dropped · deferred · one-off · split · planning · left in intake
· remaining unreviewed.

## Planning mode

**Planning mode prunes; it never picks.** Its job is to keep the planning
queue correct, not to choose what to expand next. It never runs, resumes or
recommends `epic-create`.

**Order:** oldest first. **Mode check:** is the item still valid, and does it
still need a full epic, or has it shrunk (or can its scope be cut) to one
PR? What blocks it: open issues, upstream releases, or other epics it waits
on? Items come in three states, `waiting`, `in-progress` and
`ready-to-close`, the only planning states there are; do not invent others.

For a **waiting** item, one of four outcomes:

| Outcome | Effect |
| --- | --- |
| **leave** | No route. The item is still valid and stays in the queue. Most items end here. |
| **defer** | `vrg-intake-route <ref> defer …` moves it to the deferred queue with a dated deferral record. For an item whose blockers will take a while. |
| **drop** | `vrg-intake-route <ref> drop --reason …` closes it as not planned. For an item no longer needed or overtaken. |
| **one-off** | `vrg-intake-route <ref> one-off --repo …` moves it to a repo's ad-hoc or finite epic. Unusual but legitimate: the item is small enough for one PR, or its scope can be cut until it is. A cut in scope goes to the human as a scope change through `vrg-ruling draft-scope` (step 5). |

**`in-progress` and `ready-to-close` items belong to `epic-create`.** An
`in-progress` item is being expanded; a `ready-to-close` one has been fully
expanded and waits for `epic-create` to close it. Show each with its latest
note and how long it has sat (read its comments when the one-line note is
not enough), and offer only **leave**. Offer defer or drop only where the
tool allows them, that is when every development epic of the item is
closed. **Never offer one-off for them**, and never resume or finish them
here: the human does that with `epic-create <ref>`.

**At the end of the pass**, show the surviving queue as a sorted list,
oldest first, with each item's state and latest note (run
`vrg-queue planning` again for it), to help the human choose what to plan.
Choosing an item and running `epic-create` on it is the human's act, outside
the review.

**Tallies:** left · deferred · dropped · one-off · remaining unreviewed.

## Deferred mode

**Order:** least recently deferred first. The note on each line is the
item's **latest deferral**, its reason and `Revisit when:` conditions. A
refreshed item sinks to the bottom, while a kept item writes nothing and
stays near the top. The order is a reading aid; a review normally goes
through the whole queue.

**Mode check: actually check every `Revisit when:` condition against its
source.** Read the latest `Deferred <date>:` comment, which carries the
reason, the conditions and (when the item moved) the `Deferred from:`
queue. The conditions are free prose, so check each one against its real
source:

- **dates:** compare against today's date.
- **issue and PR states:** `vrg-gh issue view <ref> --json state,closedAt`,
  `vrg-gh pr view <ref> --json state,mergedAt`.
- **releases:** `vrg-gh release list --repo <owner>/<repo>` for a GitHub
  project; the project's release page or changelog otherwise.
- **upstream status:** the upstream issue, roadmap, or announcement the
  condition names.

Report **what was checked and what was found** in each item's paragraph:
each condition, the source you checked, and the result (met, not met, or
could not be verified). The human trusts the recommendation because they
can see the evidence.

**Never fabricate a check.** If a condition cannot be verified (the source
is unreachable, the condition is too vague to test, or the evidence is
ambiguous), say so plainly and recommend **keep**, or a **refresh** with
sharper conditions if the vagueness is the problem. Never report a
condition as met or unmet without having looked.

Each item gets one of four outcomes:

| Outcome | Effect |
| --- | --- |
| **keep** | No route. The conditions are not met and still describe the right trigger. |
| **refresh** | `vrg-intake-route <ref> defer --reason … --revisit-when …` on the already-deferred item: a new dated deferral comment (with no `Deferred from:` line) and no move. For conditions gone stale: a date passed without the event, the trigger moved, or a better signal exists. Draft the new reason and conditions. |
| **revive** | The conditions are met. Move the item out with `intake` (it needs a fresh look), `planning` (it needs a full epic) or `one-off` (it is ready work). The `Deferred from:` line guides the choice: an item deferred from an ad-hoc epic usually returns as a one-off to that repo, one from planning returns to planning, and one from intake returns to intake, or straight to one-off or planning when its destination is already clear. |
| **drop** | The item is no longer needed: overtaken, obsolete, or not feasible for years. |

**Checking is the point.** A deferred queue reviewed from the comments alone
is just a reread. The value of this mode is that it looks at the world (the
release, the issue, the date) before recommending.

**Tallies:** kept · refreshed · revived to intake · revived to planning ·
revived as one-off · dropped · remaining unreviewed.

## Notes

- **Oldest first is the pressure.** There is no stale flag or auto-close; the
  oldest item always comes up first. A left or kept item comes up again next
  time.
- **Never apply a retired label.** `triage` / `idea` / `research` are
  retired, and there is no per-item queue label: the parent epic is the
  state. A recreated item does not carry them over.
- **In and out of deferred only through the route.** Do not move items into
  or out of the deferred epic with `vrg-epic-move` or `vrg-issue-create`;
  they refuse it, so that no item is deferred without its deferral comment
  or revived silently.
- **Private work stays private.** A self-homed private repo's queues are
  reviewed only with its own `--repo`. Never route a private repo's item to
  a public repo or epic; the tool refuses it, and GitHub refuses private →
  public transfers anyway.
- **Queue items are not PR-workable.** `issue-implement`,
  `vrg-pr-workflow report-ready` and `vrg-submit-pr` refuse an intake,
  planning or deferred item. Routing an intake or deferred item out as a
  one-off or split makes it buildable; a planning item becomes buildable
  through the development epic the human expands it into with
  `epic-create`.
- **Start simple.** This is a conversation, not a scoring system. Do not
  invent fields, labels or priority scores.
