# Design: Dual-agent audit test kit

- **Tracking issue:** vergil-project/vergil-tooling#1563
- **Prerequisites:** vergil-tooling#1564 (revise PR metadata mid-workflow) ·
  vergil-tooling#1566 (`vrg-reword` a branch-local commit)
- **Lives here, deliberately:** this repo (`vergil-claude-plugin`), **not**
  vergil-tooling — see *Blindness hygiene* below.
- **Date:** 2026-06-09
- **Status:** Approved (brainstorm + pushback review)

## Purpose

Establish a working — if interactive and manual — **methodology** for verifying
the dual-agent local PR workflow: the `issue-implement` (USER) and
`issue-audit` (AUDIT) skills running in two Claude Code windows, with the audit
agent sanity-checking the user agent's work through the `vrg-pr-workflow`
oracle. The kit demonstrates, repeatably, that each of the six judgment checks
fires correctly and that the fail → fix → re-audit → approve loop converges.
That demonstration is the marquee goal.

A continuous audit session *could* in principle let an earlier check or round
colour a later verdict. We **note that possibility** and the human stays loosely
alert to it, but it is a second-order concern: with Sonnet doing the audits
(judgmental, not over-clever), no memory beyond this single PR's own iterations,
and only a handful of rounds of data, it is a long shot and not separately
measurable. It is not a goal of this kit.

## Validity invariant: blindness and knowledge asymmetry

The test is valid only if the audit agent judges as it would in production —
blind to being tested.

- **The dummy issue reads as an ordinary feature request.** No test markers.
- **The AUDIT agent gets a bare `/vergil:issue-audit <N>`** and nothing else.
- **The USER agent holds all test knowledge** via the runbook (see below).
- **The human** opens both windows, kicks each off, watches, records verdicts.

### Blindness hygiene (critical)

The `issue-audit` skill shares the USER agent's worktree and reads files freely.
If this spec or the runbook lived in the worktree the audit browses, one `cat`
would blow the test. Therefore:

- **All test artifacts (this spec, the runbook) live in `vergil-claude-plugin`,
  never in vergil-tooling.** The test *runs* in a vergil-tooling fixture
  worktree; that worktree contains only the vanilla fixture, so the audit never
  sees the plan. (The judgment-check *prompts* live in vergil-tooling and are
  fine for the audit to see — they are its own check definitions, part of the
  system under test.)
- **The runbook is delivered to the USER agent via its launch prompt**, not as a
  tracked file — and specifically **not** as an auto-loaded `SKILL.md`, so the
  plugin loader never pulls it into the audit's context.

## Actors and granularity

The unit of work is **one PR-to-be = one branch = one continuous `issue-audit`
invocation.** The human types `/vergil:issue-audit <N>` once and lets it run the
full iterative back-and-forth to final approval.

| Actor | Role |
|---|---|
| USER agent | Runs a runbook that **simulates** `issue-implement` *adversarially* — it is not bound by the skill's rules and deliberately produces the flaw sequence |
| AUDIT agent | Runs `issue-audit` blind; reports one check verdict per round |
| Human | Starts both windows, observes, records verdicts |

The USER agent is a **controlled input generator**, not a creative one: it
applies the runbook's prescribed edits verbatim.

## Fixture: vanilla issue + throwaway command

A vanilla issue requests a small, real-looking feature: a throwaway CLI command
`vrg-fixture-echo` with an `--upper` flag that uppercases its argument. Chosen
to touch all six dimensions: runtime behaviour (test-adequacy), a docstring
(docstring-accuracy), a **user-facing** flag plus a CLI-reference entry
(site-docs-reflection only bites on user-facing changes), and a crisp scope
(scope-coherence). Never merged; branch and issue discarded after the run.

## The chain: single branch, one continuous audit session

The USER agent builds **one branch** as a chain of commits. Each oracle round
**fixes the prior flaw and introduces the next** (atomically — a fix that left
the delta clean would make the audit approve and end the run early), so the
cumulative delta carries **exactly one active flaw per round**. The final step
fixes the last flaw and introduces nothing — the **golden** state — earning
approval. Reaching approval is success; we never run `vrg-submit-pr`.

### Round order and per-round fixtures

Order is built around two mechanical facts (below): `pr-description-fidelity` is
keyed on the report-ready summary, so it is introduced **first**;
`commit-message-fidelity` needs a reword, so it is **last**.

| Round | Check that must fail | Flaw planted (all else correct) | Fix (+ next flaw) |
|---|---|---|---|
| 1 | pr-description-fidelity | report-ready summary overclaims — names a `--color` flag the command lacks; code otherwise golden | Revise summary to honest via `report-fixes --summary` (needs #1564) **+** commit the docstring flaw |
| 2 | docstring-accuracy | docstring says it *lowercases*; code uppercases | Correct docstring **+** add the unrelated edit |
| 3 | scope-coherence | a small, lint-clean, obviously off-topic edit to an unrelated file | Drop it **+** omit the CLI-reference entry |
| 4 | site-docs-reflection | `--upper` ships but its CLI-reference entry is missing | Add the entry **+** weaken the test |
| 5 | test-adequacy | the test covers every line (100% coverage holds) but only asserts exit 0, never that `--upper` uppercases | Restore a meaningful assertion in a commit whose **message is mislabeled** (format-valid, fidelity-wrong) |
| 6 | commit-message-fidelity | the round-5 commit's message is mislabeled (`docs(fixture): tidy wording` on a code change) | `vrg-reword <sha>` to an honest message (needs #1566) → golden → **approval** |

### Fixtures must survive `vrg-validate`

The USER agent's simulation still passes `vrg-validate` each round (a planted
flaw the validator catches never reaches the audit). The non-obvious ones:

- **Round 5 (test-adequacy):** the weak test must still hit **100% coverage** —
  it executes every line of `vrg-fixture-echo` but asserts nothing meaningful.
- **Round 6 (commit-message-fidelity):** the bad message is conventional-commit
  *format-valid* but *fidelity-wrong* (mislabeled type / vague), so a format
  lint passes and only the judgment check fails.
- **Round 3 (scope-coherence):** the unrelated edit is lint/type clean (e.g. not
  an unused import) so it survives to the audit on scope grounds alone.

## Two mechanical facts the order is built around

- **`commit-message-fidelity` cannot be fixed forward.** It scans every message
  in `base..HEAD`, so a later commit cannot erase an earlier bad message. The
  fix is to reword the offending commit — and the agent's tool surface cannot do
  that today (`vrg-git commit` denied, `vrg-commit` has no amend, interactive
  rebase unavailable). Hence prerequisite **#1566 (`vrg-reword`)**. In this test
  the bad commit is at HEAD, but #1566 is scoped to reword any branch-local
  commit, because real PRs carry bad messages mid-chain.
- **`pr-description-fidelity` is keyed on the report-ready summary.** Introducing
  its flaw means an overclaiming summary at `report-ready`; fixing it means
  *revising the summary* — which `report-fixes` cannot do today. Hence
  prerequisite **#1564**. Without it, the audit's description feedback is not
  actionable and this round cannot exist.

## Determinism

Inputs are fully prescriptive: the runbook carries the **literal** fixture
content — exact command code, docstring, coverage-complete-but-weak test,
mislabeled message, overclaiming summary, and unrelated-edit diff — authored and
ideally dry-run against the audit before a real run. Non-deterministic input
cannot yield analyzable output. Note the floor: input determinism is what we
control; the audit is an LLM, so its output retains some variance — that
variance is part of what a run reveals.

## Specificity tuning

Each flaw must fail **only** its target check. The one real coupling risk is
round 3: an unrelated edit large enough to read as a *significant undisclosed
change* could also trip `pr-description-fidelity` (omission). The edit is
therefore kept small and obviously off-topic — clearly out of scope, but not a
significant feature. The runbook fixes the exact edit.

## Execution / orchestration

1. **Setup.** A USER-identity agent creates the vanilla issue (verbatim text in
   the runbook) and a feature-branch worktree off current vergil-tooling
   `develop`. No test artifacts enter that worktree.
2. **Window A (USER):** launched with the runbook in its prompt; works the chain
   — `report-ready` with the overclaiming summary, then `report-fixes` per round.
3. **Window B (AUDIT):** `/vergil:issue-audit <N>`, bare; runs to completion.
4. The human watches each round and records the verdict log; the session ends at
   the oracle's `done: approved`.

## Verdict log (per round)

| Round | Expected check | Exactly that check failed? | Any other check false-fail? | Notes |
|---|---|---|---|---|

(A light free-text note may record any impression of cross-round influence, but
that is incidental, not the object of the test.)

## Success criteria

- Each of rounds 1–6 fails exactly its target check; no other check false-fails
  (modulo the documented round-3 tuning); every round round-trips to a clean
  re-review; the run reaches `done: approved`.
- A completed verdict log demonstrating the methodology end to end.

## Out of scope (YAGNI)

- No automated harness driving the agents — the live two-window UX is the thing
  under test.
- No actual PR: the local pre-PR phase is the unit; we stop at approval.
- No contamination measurement / control arm (see Purpose).

## Cleanup and reveal

After approval: discard the branch and worktree, close the dummy issue, and
optionally post the reveal on the issue ("this was a dual-agent audit test").

## Dependencies and sequencing

The kit cannot *run* until both prerequisites are implemented, released, and
host-installed (the agents use the installed `vrg-pr-workflow` / `vrg-*`):

1. vergil-tooling#1564 — `report-fixes` revises PR metadata.
2. vergil-tooling#1566 — `vrg-reword` rewords a branch-local commit.

Authoring the runbook (the literal fixtures) can proceed in parallel; a real run
waits on a release carrying both.
