---
name: migrate-repo
description: Migrate a repo's existing open-issue backlog into the epic/task framework. Use when the human asks to "migrate <repo>", "bring <repo> into the framework", "onboard this repo's backlog", "do the migration for <repo>", or wants the existing pile of open issues triaged into epics/tasks/standing/closed so the roadmap and audit reflect reality. Guided, resumable, batch-approved, human-in-the-loop; closes the done ones, buckets ad-hoc into the standing epic, and reconstructs the obvious epics.
---

# Migrate repo

## Overview

Bring one repo's pre-framework backlog into the epic/task model at **middle
ambition**: close what's already done, drop clear ad-hoc work into the repo's
standing `Ad-hoc maintenance` epic, and reconstruct a finite epic only where a
cluster of related open issues obviously forms an in-flight project. The skill is
**resumable** (re-running only touches the not-yet-migrated remainder) and
**batch-approved** (you approve dispositions in groups, never one issue at a
time — essential for large repos). Run it per repo; it is the same procedure for
every repo and every org.

## When to use

"migrate `<repo>`", "bring `<repo>` into the framework", "onboard the backlog",
"do the migration for `<repo>`". Run on one repo at a time.

## Preflight

- Confirm you are the **USER** agent (`vrg-whoami --mode` is `user`) — this skill
  closes issues, which only the user agent may do.
- Confirm the target `<owner>/<repo>` and the org's epic home (`<owner>/.github`).

## Workflow

### 1. Setup

- Seed the canonical labels: `vrg-ensure-label sync <owner>/<repo>`.
- Ensure the repo's standing epic exists — search for an open issue titled
  `Epic (standing): Ad-hoc maintenance` labelled `epic`+`standing`. If missing,
  create it (`vrg-gh issue create … --label epic --label standing`). Record its
  number; tasks routed to "standing" link under it.

### 2. Collect (resumable)

List the repo's open issues
(`vrg-gh issue list --repo <owner>/<repo> --state open --limit 500 --json number,title,labels,body,createdAt`).
**Skip any already in the model**: `epic`-labelled, already carrying a
`Parent: <owner>/.github#<N>` line or a native sub-issue parent, or already
`triage`-labelled. Report how many remain to classify.

### 3. Pass 1 — done detection

Run `vrg-epic-audit` and take its **task-drift** entries for this repo (a merged
PR whose `Ref`'d task is still open). These are *done* — they go to the **close**
disposition with reason "done (PR #N merged)".

### 4. Pass 2 — classify the remainder

Read each remaining open issue (title, body, labels, age, any linked PRs) and
assign exactly **one** disposition. Propose them grouped by disposition (and one
group per proposed epic) so the human approves in batches:

| Disposition | Meaning | Action on approval |
| --- | --- | --- |
| **retro-epic** | A cluster of related issues that is really one in-flight initiative | create a finite epic in `<owner>/.github` (label `epic`), then `vrg-epic-link` each member as a task |
| **standing** | Small, standalone ad-hoc work | `vrg-epic-link` under the repo's standing epic |
| **triage** | Genuinely uncertain / deserves its own brainstorm | label `triage`; defer to `/vergil:triage-review` |
| **close** | Done (Pass 1), stale, duplicate, or obsolete | close with a reason |
| **keep** | Looks actively in-progress right now | leave as-is; the human decides whether to fold it under an epic |

Prefer attaching an issue to an **existing or proposed epic** over the standing
bucket ("a forgotten to-do in *that* project"). Flag anything ambiguous as
`triage` rather than guessing. Paraphrase issue intent in your proposals; don't
just echo titles.

### 5. Approve, batch by batch

Present, and get the human's go-ahead for, each batch in turn:

1. the **done** closes (from Pass 1),
2. each **proposed epic** with its member tasks (name + members — the human can
   rename, split, merge, or move members),
3. the **standing** batch,
4. the **triage** batch,
5. the **stale/dup** closes (each with its reason).

The human can edit any proposal before approving it.

### 6. Execute (on approval)

For each approved batch, in this order:

- **Create retro-epics** in `<owner>/.github`
  (`vrg-gh issue create --repo <owner>/.github --title "Epic: <name>" --body-file <tmp> --label epic`).
  The body is lightweight — a member list and "retro-created during migration".
  **No spec/plan doc** (reconstructed epics are not brainstormed ones).
- **Native-link tasks**:
  `vrg-epic-link --epic <owner>/.github#<EPIC> --task <owner>/<repo>#<TASK>`
  (also for standing: `--epic <owner>/<repo>#<STANDING>`).
- **Label** kinds (`bug`, `feature`, `docs`, …) where obvious; set `triage` on
  the triage batch.
- **Close** the approved done/stale/dup issues:
  `vrg-gh issue close <N> --repo <owner>/<repo> --comment "<reason>"`. Only the
  set the human approved this run — never autonomously.

### 7. Report

Summarize: closed N · epics created M · tasks linked · standing K · triage T ·
kept J. Then: "run `vrg-roadmap` and `vrg-epic-audit` — `<repo>` is now in the
framework." If any open issue went unclassified, list it.

## Notes

- **Resumable.** Stop any time; re-run to continue — step 2 skips what's done.
- **No disruption.** `keep` leaves active work untouched; issues created during
  migration already follow the model; enforcement only binds new-taxonomy issues.
- **One repo at a time.** Prove the procedure on a small repo before a large one.
- Cross-org is out of scope: each org has its own `.github` and epics; never link
  across orgs.
