# paad usage policy

How the vergil workflow uses [paad](https://github.com/Ovid/paad), and the
living register of every place where we deviate from the paad authors'
recommendations.

- **Epic:** [vergil-project/.github#500](https://github.com/vergil-project/.github/issues/500)
  (paad-first AI-assisted engineering)
- **Spec:** `epics/500-paad-first-engineering/spec.md` in
  `vergil-project/.github`. Section 6 of the spec seeded the register below;
  from now on, changes to the register are made here.

The governing principle (spec §2.1) is **paad-first**: follow paad's
recommended workflow and conventions by default, and deviate only for a stated
reason. Every deviation is recorded in the
[deviations register](#7-deviations-register) with that reason, so it stays
visible and can be revisited.

## 1. paad version

**Decision.** paad is **unpinned** and follows the latest release.

- paad is enabled in the user-level `~/.claude/settings.json`. Agent VMs copy
  that file from the host, so the VMs get the same plugins the host has.
- The managed repo-level Claude settings template (`claude_settings.json` in
  vergil-tooling) does not enable or pin paad, and this policy does not
  change it.
- Every `paad/config/` file names the paad version it was written for. Child
  epic D (agentic review in `issue-implement`) detects drift between that
  version and the installed one.

**Reason.** A pin would not hold where agents run: `vrg-vm update` moves every
enabled plugin to its latest version. Recording the version in each config
file, and detecting drift, is the mitigation for depending on paad's
experimental config mechanism while unpinned.

## 2. Report files

**Decision.**

- **Design-review reports (pushback, alignment) are not written.** The
  planning issue's comments are the record of every design-review round
  (spec §3.2).
- **agentic-review output** is routed by child epic D (spec §3.3): results
  reach the implementer through the subagent's answer and are recorded in
  task-issue comments, and no paad output is left untracked in the worktree.
- **All other paad reports** (architecture, test-roadmap and so on) are
  committed under `paad/`, as the authors recommend.

**Reason.** The planning issue is the epic's permanent planning log, and
review history must stay out of the reviewed document so that each round's
reviewer starts with a fresh context. A report file would be a second, weaker
copy of that record. For agentic-review, untracked report files break the next
round's clean-state check and leave the worktree dirty at finalize. Reports
with no issue-based record keep the authors' default.

## 3. `paad/security/`

**Decision.** Nothing under `paad/security/` is ever committed. It is ignored
twice: by the `paad/security/.gitignore` (containing `*`) that paad 2.0
creates itself, and by a `paad/security/` line in the managed `.gitignore`
block that `vrg-gitignore-sync` maintains in every repo (added by epic #500,
plan Task 1).

**Reason.** Security findings must never reach a public repository. The
managed line is defence in depth behind paad's own file. How the details are
kept once a worktree is deleted is handled by child epic A
(security-finding handling); until A lands, public records show security
findings only as counts.

## 4. `paad/config/`

**Decision.** paad's per-project config (`paad/config/`) is adopted **only
where a child epic needs it**: D for running agentic-review unattended, and C
(iterating design review in `epic-create`) as the fallback if prompting alone
cannot make pushback and alignment run in review-only mode. Every adopted file
names the paad version it was written for (section 1).

**Reason.** The config mechanism is experimental and can change in any paad
release. Adopting it only where it solves a real problem keeps that exposure
small, and the version line makes drift detectable.

## 5. `paad:handoff`

**Decision.**

- `paad:handoff` is the workflow's session-continuity skill. The vergil
  plugin's own handoff skill was removed in epic
  [vergil-project/.github#558](https://github.com/vergil-project/.github/issues/558).
- Always use the **prefixed** name (`paad:handoff`), never a bare `handoff`,
  so it is clear which skill is meant.

**Reason.** One skill per job keeps session state in one place, and paad's
skill does the job without a vergil-specific copy. The issue's comments remain
the workflow's durable recovery record; `paad:handoff` only carries session
context forward.

## 6. Existing committed reports

**Decision.** The `paad/pushback-reviews/` and `paad/alignment-reviews/` files
already committed in vergil-tooling, vergil-actions, vergil-claude-plugin and
vergil-containers stay where they are, as history. They are not moved or
deleted.

**Reason.** They are an accurate record of how earlier work was reviewed.
Section 2 governs new reports only; rewriting history gains nothing.

## 7. Deviations register

Every way our use of paad departs from the authors' recommendations, with the
reason. Add a row when a decision moves us further from paad, and remove one
when we return to paad's default.

Review history is never kept inside a spec or plan: it lives in the
planning-issue comments (spec §3.2). No row below may say otherwise.

| Deviation from paad | Reason |
|---|---|
| Mode 2 (agentic-review in `issue-implement`) caps autonomous rounds at 3, then pauses for the human | The authors say "repeat" with a human present. Unattended, an unbounded loop is unsafe. |
| paad is unpinned and follows the latest release, although D and C may rely on the experimental `paad/config/` | A pin would not hold on agent VMs: `vrg-vm update` moves every enabled plugin to latest. Mitigation: every config file names the version it was written for, and D detects drift. |
| Design-review report files (pushback, alignment) are not written; the planning-issue comments are the record (spec §3.2) | The planning issue is the epic's permanent planning log, and review history must stay out of the reviewed document so the next round's reviewer has a fresh context. |
| agentic-review results are not left as report files in the worktree; D routes them through the subagent's answer into task-issue comments (spec §3.3) | Untracked report files stop the next round's clean-state check and leave the worktree dirty at finalize. The task issue is the record of each round. |
| The paad usage policy lives in this one central document rather than in each repo's steering file | The authors suggest recording the policy in the steering file. A single document avoids drift between copies across the fleet. Pointing each repo's steering files at it is handed to child epic E (steering-file review). |
