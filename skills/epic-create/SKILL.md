---
name: epic-create
description: Use as the DEFAULT entry point for non-trivial work — building a feature, a cross-cutting or multi-PR initiative, or promoting a brainstorm into the epic/task framework. epic-create is the outer workflow that runs brainstorming, creates the epic and its bookend tasks in the org .github, and drives spec → pushback → plan → alignment → docs PR. Triggers: "let's build X", "start an epic for this", "save this spec as an epic", "this is an epic, not a task", or deciding whether a spec is an epic or a single task. If the work reduces to one PR, it is a task, not an epic.
---

# Epic create

## Overview

`epic-create` is the **outer, orchestrating workflow** for non-trivial work. It
runs the brainstorm → design → plan pipeline, creates the **finite epic** in its
resolved home (the org `.github` by default; a **private** repo self-homes its
epics — see Preflight), seeds the epic's **bookend tasks**, and publishes the
spec and plan as the epic's docs. This is where significant work *starts* — not a
step reached at the end.

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
     understanding the system and tend to drift behind the code. Treat this as a
     **sweep, not a single edit**: an epic's documentation usually spans
     **multiple repositories** — per-repo docs in each member repo, the
     higher-level summary docs in the `docs` repo, and occasionally
     correction/plan notes in `.github`. So it does **not** assume one docs PR
     closes it. Where a repo's docs need work, the review **spawns a per-repo doc
     task** (born linked under the epic), each closed by a **same-repo** PR — the
     only linkage that respects the placement law (see Notes). File the review
     task itself in the repo where the bulk of its own sweep lands (usually the
     member repo holding the site docs, e.g. `vergil-tooling/docs/site`); it
     spawns siblings for the other repos rather than forcing one cross-repo PR to
     close it.

This rides the **existing auto-close rollup**: an epic rolls up only when all its
tasks close, so the closing tasks *gate* closure. The **documentation review is
the final gate** — an epic is not done until the docs comprehensively describe
what it changed. Seed these bookend tasks at epic-creation time (step 2 below)
and fill in the specifics per epic.

## Operational tasks — gating on more than merge

Some steps in an epic are proven not by merging a PR but by *running* something
after merge and recording the result as a comment. These are **operational
tasks** — a family of not-PR-workable task types. Two kinds today:

- **`validation`** — *verify* prior work is correct (a cold rebuild, a live-lab
  check, a deploy smoke test). Run with `issue-validate`.
- **`deployment`** — *make merged work usable*: install/sync/deploy it into the
  environment so the next step can actually run against it. Run with
  `issue-deploy`.

They share one mechanism; each kind supplies its own label, scaffold, and run
skill.

**Why deployment matters — merged vs deployed.** An implementation task closes
when its PR merges to develop. But the next step sometimes needs the change not
just *merged* but *deployed and usable*. A deployment task makes that explicit,
and its closure **is** the "deployed" signal:

```text
impl task(s) ──Blocked-by──▶ deployment ──Blocked-by──▶ validation / next impl
   merged                      deployed (= task closed)     runs against deployed
```

A downstream task that needs the thing deployed depends on the **deployment
task**; one that only needs it merged depends on the **impl task**. The existing
`Blocked-by` + runnable-vs-blocked machinery does the rest — no special
precondition mechanism.

**Shared operational-task rules (both kinds):**

- **Not PR-workable.** No code PR; `vrg-submit-pr` and `vrg-pr-workflow
  report-ready` refuse an operational-labelled task. Run it via its run skill
  (`issue-validate` / `issue-deploy`), never `issue-implement`.
- **Closes only on `Outcome: SUCCESS`**, recorded as a comment. On failure it
  stays open (like a PR that cannot merge), and its epic stays open.
- **Gates rollup** by staying open — an ordinary open child.
- **Blocked-by its dependencies** (merge-first / deploy-first), recorded as
  `Blocked-by:` reflinks so `vrg-epic-audit` reports each runnable vs blocked,
  tagged by kind.

**When to add which (judgment).**

- **Validation** — when acceptance needs a check the pipeline's own tests cannot
  do (cold rebuild, live-lab, deploy smoke test). Infra/provisioning epics carry
  a cold-rebuild validation by default. Not for docs or pipeline-covered code.
- **Deployment** — when the next step (a later task, or a validation) needs the
  change **deployed and usable**, not merely merged. If everything downstream
  only needs develop, you don't need one.

**Granularity is your call:** 1:1, N:1 (one operational task over a group/epoch,
blocked-by all of them), or an epic-level closing bookend. At planning time you
can often *see* where a deploy or a batch validation belongs and seed it up
front — the common shape is **impl → deploy → validate**.

**Create it** with the sanctioned path (never hand-roll the body):

```bash
vrg-issue-create --epic <org>/.github#N --repo <org>/<repo> \
  --kind {validation|deployment} --title "<what>" --blocked-by <org>/<repo>#<TASK> [--blocked-by …]
```

This stamps the kind's label and an **executable scaffold**: a generic,
author-defined **precondition self-check** (a machine probe *or* a human-attested
statement; the framework prescribes no mechanism — run it first and, if unmet,
comment "blocked: preconditions not met" and stop, never fabricating), the
procedure, the acceptance criteria, and a **SUCCESS/FAILURE results template**.

**Deployment autonomy boundary.** A deployment task owns only the **agent-safe**
deploy steps (install/sync/restart). Where deploying needs a **release**
(bump/tag/publish), that release is a **human-gated precondition** — attested,
never performed by the agent — the same policy that keeps PR submission and merge
in human hands. `issue-deploy` never cuts a release.

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
- Confirm the **resolved** epic home for the target repo. The home is derived
  from visibility (`epics.resolve_epic_home`, epic #130): a **public** repo homes
  its epics centrally in `<owner>/.github`; a **private** repo (with a public
  `.github`) self-homes them in its own issue list, so nothing about private work
  reaches the public `.github`. The create and report commands take an explicit
  `--repo <owner>/<repo>` target (default: current repo) and echo the resolved
  home before acting. See convention `#40` §3.2.

## Workflow

1. **Brainstorm.** Run `superpowers:brainstorming` to converge on an approved
   design. (If it reduces to a single-PR task, stop — file a task, not an epic.)
2. **Create the epic and seed its bookend tasks.**
   - `vrg-epic-create --repo <owner>/<repo> --title "Epic: <name>" --body-file
     <tmp>` creates the issue in the target's **resolved home** with the `epic`
     label (`--repo` defaults to the current repo; the command echoes the home —
     `<org>/.github` for a public target, the repo itself when private); note the
     number **N**.
   - Create the **documentation task** and the **closing tasks** (follow-on
     brainstorm task(s) + the **documentation-review** task), each linked under
     N. **File each in the repo where its closing PR will land** (the placement
     law — see Notes): the documentation and follow-on-brainstorm tasks live in
     `.github` (`--repo <org>/.github`), but the **documentation-review** task
     usually lands its PR in the **member repo** holding the site docs
     (e.g. `vergil-tooling/docs/site`), so file it there
     (`--repo <owner>/<repo>`) — never blanket `.github`:
     `vrg-issue-create --epic <org>/.github#N --repo <owner>/<repo> --title … `.
     The documentation-review task is a **multi-repo sweep**: at review time it
     may **spawn additional per-repo doc tasks** (each `--repo <that-repo>`,
     linked under N, closed by a same-repo PR) for documentation that lives in
     other repos. Seed only the review task here; its siblings are filed as the
     sweep discovers where docs actually need to change.
   - **Seed operational tasks the epic will need** — see "Operational tasks"
     above. Infra/provisioning-shaped epics carry a cold-rebuild **validation**
     by default (`--kind validation`); seed a **deployment** task
     (`--kind deployment`) wherever a later step needs the change *deployed*, not
     just merged. Add more here or at plan time as the judgment calls for.
3. **Write the spec** on a worktree of the documentation task's branch in the
   epic's **home repo** (`.github` for a public target, the repo itself when
   private), at `epics/<N>-<slug>/spec.md` (`<slug>` = 2–4 kebab tokens).
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

- **Placement law — a task lives in the repo where its closing PR lands, and a
  PR only `Closes` an issue in its own repo.** Cross-repo relationships are
  `Ref` or comments — **never** `Closes`. So file each task in the repo whose PR
  will close it. The epic issue and its `spec.md`/`plan.md` belong in
  `<owner>/.github`; the **documentation task** lives there too, because its PR
  publishes the spec/plan into `.github`. But a bookend whose PR lands in a
  **member repo** — most often the **documentation-review** task, since the
  versioned site docs live in a member repo (e.g. `vergil-tooling/docs/site`) —
  is filed in **that member repo**, not blanket `.github`. Filing it in `.github`
  forces the illegal cross-repo close that produced a `vergil-tooling` PR
  closing `vergil-project/.github#127`. The same law is **why the
  documentation-review is a sweep that spawns per-repo tasks**: when an epic's
  docs span several repos, you do not point one docs PR at the review issue
  across a repo boundary — you spawn a same-repo doc task in each affected repo,
  each closed by its own same-repo PR.
- **Cross-org is out of scope:** each org has its own `.github`; never link epics
  or tasks across orgs.
- Reconstructing epics from an existing backlog is a different job — use
  `migrate-repo`. Capturing an uncurated idea is `triage-capture`.
