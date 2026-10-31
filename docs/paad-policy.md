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
[deviations register](#8-deviations-register) with that reason, so it stays
visible and can be revisited.

## 1. paad version

**Decision.** paad is **unpinned** and follows the latest release.

- paad is enabled in the user-level `~/.claude/settings.json`. Agent VMs copy
  that file from the host, so the VMs get the same plugins the host has.
- The managed repo-level Claude settings template (`claude_settings.json` in
  vergil-tooling) does not enable or pin paad, and this policy does not
  change it.
- Child epic D (agentic review in `issue-implement`) adopts no `paad/config/`
  file. Any config file child epic C adds (its fallback for design review)
  names the paad version it was written for.
- For now nobody detects drift between paad releases and the workflow's
  expectations: D left drift detection out until real use shows it is needed
  (`epics/568-agentic-review-gate/spec.md` §5). The output checks in the
  [review doctrine](paad-review-doctrine.md) expect a paad version and treat
  a different one as a warning.

**Reason.** A pin would not hold where agents run: `vrg-vm update` moves every
enabled plugin to its latest version. Recording the version in any config
file is the mitigation for depending on paad's experimental config mechanism
while unpinned, and it leaves drift detectable once someone needs to detect
it.

## 2. Report files

**Decision.**

- **Design-review reports (pushback, alignment) are not written.** The
  planning issue's comments are the record of every design-review round
  (spec §3.2).
- **agentic-review output** in `issue-implement`'s gate (child epic D): paad
  writes its usual files in the task's worktree, where `paad/code-reviews/` is
  ignored like `paad/security/`. After each round the implementer moves the
  report, and paad's other output, into the task's private state directory,
  which empties the worktree's `paad/`, and posts its findings, sorted, to
  the task issue; paad's code-review backlog does not persist
  ([doctrine §3](paad-review-doctrine.md#3-mode-2-agentic-review-in-issue-implement)).
- **All other paad reports** (architecture, test-roadmap and so on) are
  committed under `paad/`, as the authors recommend.

**Reason.** The planning issue is the epic's permanent planning log, and
review history must stay out of the reviewed document so that each round's
reviewer starts with a fresh context. A report file would be a second, weaker
copy of that record. For agentic-review, the task issue is the record of each
round: ignoring `paad/code-reviews/` keeps the worktree clean for the
clean-state check and for finalize, and emptying it keeps earlier rounds out of
the next reviewer's context. Reports with no issue-based record keep the
authors' default.

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
where a child epic needs it**.

- **D adopts no config file.** The reviewer prompt alone runs agentic-review
  unattended, and the gate's output checks fail a round whose answer has a
  `Config:` line, since one means a stray `paad/config/` in the reviewed
  branch changed the review
  ([doctrine §3.4](paad-review-doctrine.md#34-output-checks)).
- **C** (iterating design review in `epic-create`) may add config files as
  its fallback, if prompting alone cannot make pushback and alignment run in
  review-only mode; that fallback is not adopted
  ([doctrine §2.10](paad-review-doctrine.md#210-fallback)). Any config file C
  adds names the paad version it was written for (section 1).

**Reason.** The config mechanism is experimental and can change in any paad
release. Adopting it only where it solves a real problem keeps that exposure
small, and the version line keeps drift detectable.

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

## 7. Other paad skills

**Decision.** The paad skills listed for child F of the epic (umbrella spec
§4.F) were evaluated one by one with the human. Each is adopted, used by hand
in a stated place in the workflow, or recorded as a deviation with its reason.

| Skill | Decision | Place in the workflow |
|---|---|---|
| `rethink` | **Adopted** | Sanity-checks any decision, the agent's or the human's. The human invokes it, and the agent may offer it at a decision point. No skill wiring for now. Unattended use waits for paad unattended mode (vergil-project/.github#698). |
| `agentic-architecture` | Interesting, used by hand | Strategic, not daily. Run by hand as part of a periodic (roughly quarterly) review, looking for changes of direction and refactoring opportunities. Results feed the planning process. |
| `fix-architecture` | Interesting, used by hand | Interactive if used at all. Its development-workflow assumptions (several fixes per session on one branch, interactive commit choices) don't match the one-issue-one-PR model, so worthwhile findings go through intake and planning instead. |
| `test-roadmap` | Interesting, used by hand | Run by hand when a repo's tests need work. If a roadmap is taken on, its phases can become an epic's tasks. |
| `agentic-owasp` | Interesting, used by hand | Run by hand in the periodic review. Every finding is security-class, so it is recorded only with `vrg-security-record`, never in public issues. |
| `agentic-dedup` | Interesting, used by hand | Run by hand in the periodic review. Results feed planning. |
| `backlog` | **Not adopted: deviation** | paad's code-review backlog is not kept (existing register row), so there is nothing for it to work on. Intake is the system of record; `intake-review` and `deferred-review` cover clean, and routing an intake item to a task covers fix. |

**Reason.** `agentic-owasp` and `agentic-dedup` are marked EXPERIMENTAL by
paad, which is a further reason to use them by hand rather than build on them.
`backlog` is marked EXPERIMENTAL too.

## 8. Deviations register

Every way our use of paad departs from the authors' recommendations, with the
reason. Add a row when a decision moves us further from paad, and remove one
when we return to paad's default.

Review history is never kept inside a spec or plan: it lives in the
planning-issue comments (spec §3.2). No row below may say otherwise.

| Deviation from paad | Reason |
|---|---|
| Mode 2 (agentic-review in `issue-implement`) caps autonomous rounds at 3, then pauses for the human | The authors say "repeat" with a human present. Unattended, an unbounded loop is unsafe. |
| paad is unpinned and follows the latest release, although C's fallback may rely on the experimental `paad/config/` (D adopts no config file) | A pin would not hold on agent VMs: `vrg-vm update` moves every enabled plugin to latest. Mitigation: any config file C adds names the version it was written for. For now nobody detects paad drift (epic 568 spec §5). |
| Design-review report files (pushback, alignment) are not written; the planning-issue comments are the record (spec §3.2) | The planning issue is the epic's permanent planning log, and review history must stay out of the reviewed document so the next round's reviewer has a fresh context. |
| pushback and alignment run review-only in a fresh subagent, and the main session presents the findings and edits the document; paad runs them interactively in the session that edits | Each round needs a context that has not seen earlier rounds (umbrella §3.1). The human still sees one finding at a time with options. |
| alignment's TDD rewrite step is skipped | `superpowers:writing-plans` writes tasks in red/green/refactor form. The reviewer reports each code task that is not as a minor finding ([doctrine §2.3](paad-review-doctrine.md#23-the-reviewer-prompt)), and it is fixed in the walk-through. |
| The reviewer's reality check does not read the history of the document under review | Commit history of earlier rounds carries the provenance that umbrella §3.1 keeps out of the reviewer's context. |
| Design-review rounds are repeated under explicit stop and continue signals, with the human deciding each round | The authors say "revise and repeat as needed" without stop rules. The experiment behind vergil-project/.github#469 showed that unruled repetition compounds complexity. |
| agentic-review writes its usual files, but `paad/code-reviews/` is ignored rather than committed; the implementer moves the report into the task's private state directory after each round and posts its findings to the task issue | The task issue is the record of each round, and a paused round keeps its material privately. Adapting to paad's defaults is more reliable than redirecting them. Emptying the directory keeps earlier rounds out of the next reviewer's context. |
| paad's code-review backlog does not persist; an out-of-scope bug goes to intake when the human rules it filed | Intake is the system of record for follow-on work (umbrella §2.4). |
| `paad:backlog` is not used | paad's code-review backlog does not persist and intake is the system of record. The queue-review skills (`intake-review`, `deferred-review`) and the task model cover its clean and fix modes. |
| The Spec Compliance intent source is a requirements file named in the prompt, not a spec-file argument | The skill's arguments take only a base and a path. Raise with the paad authors. |
| The paad usage policy lives in this one central document rather than in each repo's steering file | The authors suggest recording the policy in the steering file. A single document avoids drift between copies across the fleet. Pointing each repo's steering files at it is handed to child epic E (steering-file review). |
| `steering-audit` runs pushback findings-only: it collects and returns the findings instead of walking them one at a time, does not edit the reviewed file, and writes no report or other file | `steering-audit` walks the findings itself against the Claude config ownership model. In user scope it must write nothing at all, because the user-level files are personal and have no change control. |

The first agentic-review row above refines umbrella §3.3's "results reach the
implementer through the subagent's answer": the implementer reads paad's
report from its file in the worktree. That refinement is the human's decision,
made in the design review of epic
[vergil-project/.github#568](https://github.com/vergil-project/.github/issues/568),
to adapt to paad's defaults rather than redirect them; the task issue remains
the record of every round.

## 9. Review doctrine

The rules for running a paad review more than once on the same artifact are
in the [paad review doctrine](paad-review-doctrine.md): the common core for
every repeated review, mode 1 (human-gated design review in `epic-create`),
and mode 2 (autonomous review in `issue-implement`). The doctrine also holds
the only copy of the table that maps paad's severity scales onto one
canonical scale; other documents link to it.
