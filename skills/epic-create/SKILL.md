---
name: epic-create
description: Use when a brainstormed or approved spec represents a finite epic — a cross-cutting, multi-PR initiative — and should enter the epic/task framework rather than be saved as a plain docs/specs file. Triggers: "save this spec as an epic", "create an epic for this brainstorm", "this is an epic, not a task", promoting a brainstorming design into a finite epic, or deciding whether a spec is an epic or a single task.
---

# Epic create

## Overview

Promote an approved brainstorm spec into a **finite epic** under the epic/task
convention: create the epic issue in the org `.github` repo, publish its
spec/plan into the epic's doc home, and hand back the task-linkage path. This is
where a brainstorming session sends a spec **instead of** writing it to
`docs/superpowers/specs/` — the spec for a cross-cutting initiative *is* an epic.

Canonical convention: `vergil-project/.github#40` (spec §3.2).

## When to use — is this an epic or a task?

Run this gate first; it is the call most often gotten wrong:

- **Epic** — a cross-cutting / multi-PR initiative (several tasks, often across
  repos). The brainstorm produced a real *project*. → use this skill.
- **Task** — a single change that lands in **one PR**. → it is **not** an epic.
  File it in the member repo under an existing finite epic or the repo's
  standing `Ad-hoc maintenance` epic and link it with `vrg-epic-link`. Do **not**
  mint a new epic.

When unsure, it is a task. Epics are for initiatives, not individual changes.

## Preflight

- Confirm you are the **USER** agent (`vrg-whoami --mode` is `user`).
- Confirm the org's epic home (`<owner>/.github`).
- Have the **approved** spec in hand (and the plan, if `writing-plans` produced
  one). This skill publishes a decided design, not a draft.

## Workflow

1. **Create the epic issue** in `<owner>/.github`:
   `vrg-epic-create --title "Epic: <name>" --body-file <tmp>`. Run it from a repo
   in the target org — it creates the issue in `<org>/.github` (org auto-detected
   from the remote) and adds the `epic` label automatically. Body: a short
   summary of the initiative. Note the issue number **N**.
2. **Publish the docs.** On a worktree of the `<owner>/.github` repo, write the
   spec to `epics/<N>-<slug>/spec.md` and the plan (if any) to
   `epics/<N>-<slug>/plan.md` (`<slug>` is 2–4 kebab tokens). Validate
   (`vrg-container-run -- vrg-validate`) and open the PR with `vrg-submit-pr`.
3. **Link tasks as they are filed.** Each implementation task lives in its member
   repo (1:1 with a PR) and links to the epic natively:
   `vrg-epic-link --epic <owner>/.github#N --task <owner>/<repo>#<TASK>`. Tasks
   are filed when implemented, not created here.
4. **Report:** epic `#N` created, spec/plan PR opened, and the `vrg-epic-link`
   template for its tasks.

## Notes

- **Epics live in `.github`; tasks live in member repos.** The epic issue and
  its `spec.md`/`plan.md` belong in `<owner>/.github`, never the member repo's
  `docs/specs/`.
- **This skill does not create the task issues** — it establishes the epic and
  its docs; tasks are filed and linked at implementation time.
- **Cross-org is out of scope:** each org has its own `.github`; never link
  epics or tasks across orgs.
- Reconstructing epics from an existing backlog is a different job — use
  `migrate-repo`. Capturing an uncurated idea is `triage-capture`.
