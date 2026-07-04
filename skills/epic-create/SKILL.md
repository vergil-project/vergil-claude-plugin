---
name: epic-create
description: Use as the DEFAULT entry point for non-trivial work — building a feature, a cross-cutting or multi-PR initiative, or promoting a brainstorm into the epic/task framework. epic-create is the outer workflow that runs brainstorming, creates the epic and its bookend tasks in the org .github, and drives spec → pushback → plan → alignment → docs PR. Triggers: "let's build X", "start an epic for this", "save this spec as an epic", "this is an epic, not a task", or deciding whether a spec is an epic or a single task. If the work reduces to one PR, it is a task, not an epic.
---

# Epic create

## Overview

`epic-create` is the **outer, orchestrating workflow** for non-trivial work. It
runs the brainstorm → design → plan pipeline, creates the **finite epic** in the
org `.github`, seeds the epic's **bookend tasks**, and publishes the spec and
plan as the epic's docs. This is where significant work *starts* — not a step
reached at the end.

Canonical convention: `vergil-project/.github#40`; worked example (this skill's
own redesign): `vergil-project/.github#85`.

## Default entry point

**Start here, not in `brainstorming`.** A solution worth thinking through is
worth recording as work, so there is little value in brainstorming a design and
then walking away from it untracked. `epic-create` opens *into* brainstorming and
lets the process play out.

- Most work at this scale is a significant feature or change → an **epic**.
- If the design collapses to a trivial, **single-PR** change → it is a **task**,
  not an epic. File it in the member repo under an existing finite epic or the
  repo's **ad-hoc epic** (`vrg-issue-create --epic adhoc`) and stop. Do **not**
  mint an epic.

When unsure, it is a task. Epics are for initiatives, not individual changes.

## The epic architecture — bookend tasks

**An epic is never closed until you have decided what comes next AND confirmed
the docs reflect what changed.** Almost no real problem is 100% closed by one
epic; you deliver a tangible subset and acknowledge the follow-on. So every epic
carries these bookend tasks:

- **First task — documentation.** The spec + plan for the epic; this task's PR
  publishes them into `.github` (see the workflow below).
- **Closing tasks — two kinds:**
  1. **Follow-on brainstorm task(s)** — review what shipped (successes,
     failures, mid-flight changes, new problems and opportunities in both the
     tooling and the target) and brainstorm + create the follow-on epic(s). If
     the answer is the rare "nothing," you are done — but you always ask.
  2. **Documentation-review task** — verify the epic's changes are
     comprehensively reflected in the human-facing docs, **especially the
     versioned site docs** (`docs/site/…`), which are the primary interface for
     understanding the system and tend to drift behind the code.

This rides the **existing auto-close rollup**: an epic rolls up only when all its
tasks close, so the closing tasks *gate* closure. The **documentation review is
the final gate** — an epic is not done until the docs comprehensively describe
what it changed. Seed these bookend tasks at epic-creation time (step 2 below)
and fill in the specifics per epic.

## The four-stage interaction doctrine

`epic-create`'s core is a front-loaded analytical pipeline. Getting the
agent↔human interaction right here is what makes downstream implementation
near-bulletproof (target: 90–99% of tasks green on first implementation).

| Stage | Mode | Contract |
|---|---|---|
| `superpowers:brainstorming` | **interactive** | Explore intent, one question at a time. |
| `paad:pushback` | **interactive** | Guide the human through suspicious findings; the human makes the judgment calls. |
| `superpowers:writing-plans` | **automated** | Crank through and produce the plan; no gating. |
| `paad:alignment` | **interactive** | Agent + human review the plan against the spec and correct it. |

**Human-judgment principle (every interactive stage):** stop and ask *only* for
ambiguities or judgment calls that **materially affect** the outcome. Handle
minor, obvious corrections by **batching them to the end** as a single "here are
the no-brainers — correct me if I'm wrong" review, not by gating each one.

## Preflight

- Confirm you are the **USER** agent (`vrg-whoami --mode` is `user`).
- Confirm the org's epic home (`<owner>/.github`).

## Workflow

1. **Brainstorm.** Run `superpowers:brainstorming` to converge on an approved
   design. (If it reduces to a single-PR task, stop — file a task, not an epic.)
2. **Create the epic and seed its bookend tasks.**
   - `vrg-epic-create --title "Epic: <name>" --body-file <tmp>` creates the issue
     in `<org>/.github` with the `epic` label (org auto-detected); note the
     number **N**.
   - Create the **documentation task** and the **closing tasks** (follow-on
     brainstorm task(s) + the **documentation-review** task), each linked under
     N and living in `.github`:
     `vrg-issue-create --epic <org>/.github#N --repo <org>/.github --title … `.
3. **Write the spec** on a worktree of the documentation task's branch in the
   `.github` repo, at `epics/<N>-<slug>/spec.md` (`<slug>` = 2–4 kebab tokens).
4. **`paad:pushback`** on the spec → commit its revisions to the same worktree.
5. **Human review** of the spec.
6. **`superpowers:writing-plans`** → `epics/<N>-<slug>/plan.md` on the same
   worktree.
7. **`paad:alignment`** → reconcile the plan (and spec) with the human.
8. **Docs PR.** Validate (`vrg-container-run -- vrg-validate`) and hand off the
   single spec + plan PR against `.github` — agents record it via
   `vrg-pr-workflow report-ready`; the human runs `vrg-submit-pr`. Merging it
   closes the documentation task.
9. **File the implementation tasks** from the plan, each in the repo where its PR
   lands and linked under the epic: born linked via `vrg-issue-create --epic
   <org>/.github#N --repo <owner>/<repo> …`, or linked after the fact with
   `vrg-epic-link --epic <org>/.github#N --task <owner>/<repo>#<TASK>`.

## Notes

- **Epics live in `.github`; tasks live where their PR lands.** The epic issue
  and its `spec.md`/`plan.md` belong in `<owner>/.github`. Most tasks live in the
  member repo whose PR closes them; the bookend and self-referential tasks (docs,
  follow-on brainstorm, doc review) live in `.github` because their PRs land
  there.
- **Cross-org is out of scope:** each org has its own `.github`; never link epics
  or tasks across orgs.
- Reconstructing epics from an existing backlog is a different job — use
  `migrate-repo`. Capturing an uncurated idea is `triage-capture`.
