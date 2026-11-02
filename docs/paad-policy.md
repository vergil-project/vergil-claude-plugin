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
- Neither review mode adopts a `paad/config/` file (section 4).
- The fleet runs paad from the fork's preview tree instead of the
  installed release, through a standing per-host override (section 10).
  That changes which paad a session loads, not this decision: the
  installed paad, which sessions without the override use, stays
  unpinned. It has no unattended runner, so those sessions run no review
  round (section 10).
- For now nobody detects drift between paad releases and the workflow's
  expectations: D left drift detection out until real use shows it is needed
  (`epics/568-agentic-review-gate/spec.md` §5). The output checks in the
  [review doctrine](paad-review-doctrine.md) fail a round whose delegate
  announces a version other than the validated one (section 10).

**Reason.** A pin would not hold where agents run: `vrg-vm update` moves every
enabled plugin to its latest version. Adopting no config file keeps the
workflow off paad's experimental config mechanism while unpinned.

## 2. Report files

**Decision.**

- **Design-review reports (pushback, alignment) are not written.** The
  planning issue's comments are the record of every design-review round
  (spec §3.2).
- **agentic-review output** in `issue-implement`'s gate (child epic D):
  paad writes nothing and returns its findings in its result (section 10).
  The implementer keeps the result in the task's private state directory
  and posts its findings, sorted, to the task issue; paad's code-review
  backlog does not persist
  ([doctrine §3](paad-review-doctrine.md#3-mode-2-agentic-review-in-issue-implement)).
- **All other paad reports** (architecture, test-roadmap and so on) are
  committed under `paad/`, as the authors recommend.

**Reason.** The planning issue is the epic's permanent planning log, and
review history must stay out of the reviewed document so that each round's
reviewer starts with a fresh context. A report file would be a second, weaker
copy of that record. For agentic-review, the task issue is the record of each
round, and a result that is never written to the worktree keeps earlier
rounds out of the next reviewer's context. Reports with no issue-based
record keep the authors' default.

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

**Decision.** paad's per-project config (`paad/config/`) is **not adopted**
by either review mode.

- The doctrine's output checks fail a round whose result has a `Config:`
  line, since one means a config file the caller did not name changed the
  review ([doctrine §1.9](paad-review-doctrine.md#19-the-delegate-path)).
- Under unattended mode, paad follows no config file its caller did not
  name, and reports each one it found as not followed; the workflow names
  none. A branch under review cannot change how it is reviewed.
- The earlier idea of review-only config files for mode 1 was never
  adopted; unattended mode replaced it (section 10).

**Reason.** The config mechanism is experimental and can change in any paad
release, and a config file in a reviewed branch is content the review must
not take instructions from. The review rules live in the caller's prompt
instead.

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
| paad is unpinned and follows the latest release | A pin would not hold on agent VMs: `vrg-vm update` moves every enabled plugin to latest. No `paad/config/` file is adopted (section 4). For now nobody detects paad drift (epic 568 spec §5). |
| The reviewer's reality check does not read the history of the document under review | Commit history of earlier rounds carries the provenance that umbrella §3.1 keeps out of the reviewer's context. |
| Design-review rounds are repeated under explicit stop and continue signals, with the human deciding each round | The authors say "revise and repeat as needed" without stop rules. The experiment behind vergil-project/.github#469 showed that unruled repetition compounds complexity. |
| paad's code-review backlog does not persist; an out-of-scope bug goes to intake when the human rules it filed | Intake is the system of record for follow-on work (umbrella §2.4). Under unattended mode paad neither reads nor writes it. |
| `paad:backlog` is not used | paad's code-review backlog does not persist and intake is the system of record. The queue-review skills (`intake-review`, `deferred-review`) and the task model cover its clean and fix modes. |
| The paad usage policy lives in this one central document rather than in each repo's steering file | The authors suggest recording the policy in the steering file. A single document avoids drift between copies across the fleet. Pointing each repo's steering files at it is handed to child epic E (steering-file review). |
| `steering-audit` runs pushback findings-only: it collects and returns the findings instead of walking them one at a time, does not edit the reviewed file, and writes no report or other file | `steering-audit` walks the findings itself against the Claude config ownership model. In user scope it must write nothing at all, because the user-level files are personal and have no change control. |

## 9. Review doctrine

The rules for running a paad review more than once on the same artifact are
in the [paad review doctrine](paad-review-doctrine.md): the common core for
every repeated review, mode 1 (human-gated design review in `epic-create`),
and mode 2 (autonomous review in `issue-implement`). Each round runs under
paad's unattended runner, `paad:paad-delegate`, which the session must
have loaded (section 10). The doctrine also
holds the only copy of the table that maps paad's severity scales onto one
canonical scale; other documents link to it.

## 10. paad unattended mode and the fleet checkout

**Decision.** The review doctrine's rounds (`epic-create`'s design review
and `issue-implement`'s agentic-review gate) run paad only in **unattended
mode**, except the interactive run the human may choose after a second
broken mode 1 round
([doctrine §2.4](paad-review-doctrine.md#24-output-checks-and-broken-rounds),
step 3); `steering-audit`'s own pushback run is unchanged (section 8).
vergil contributes to paad, so the fleet runs paad from the fork's tree
through a standing override, not from a paad release (epic
[vergil-project/.github#699](https://github.com/vergil-project/.github/issues/699),
spec §4.7 and §4.8, with one change the human decided since: the override
is not removed when upstream releases the change).

- **The standing arrangement.** The override and the fleet checkout below
  are permanent. The fork tracks upstream paad and stays in sync with it,
  and the fleet expects to run a patch or two ahead of it. There is no plan
  to switch the fleet to a released paad.
- **The delegate is required.** Each review round runs under
  `paad:paad-delegate`, paad's unattended runner, and only sessions that
  load the fleet checkout have it. A session without it runs no review
  round: mode 1 stops and tells the human, mode 2 pauses, and the message
  names the fix, which is to start the session with the fleet checkout
  loaded through `vrg-vm session` (the override below)
  ([doctrine §1.8](paad-review-doctrine.md#18-the-delegate-requirement)).
- **The validated version.** Review rounds rely only on a delegate
  whose announced version is the one recorded here as validated: today
  `2.0.2-preview` (the announce `v2.0.2-preview`), validated at fleet
  commit `58db477` in
  [vergil-project/.github#843](https://github.com/vergil-project/.github/issues/843),
  a reduced set of runs by the human's ruling. The version was first
  validated at fleet commit `abf879f` in
  [vergil-project/.github#733](https://github.com/vergil-project/.github/issues/733).
  A round whose delegate announces any other version fails its output
  check ([doctrine §1.9](paad-review-doctrine.md#19-the-delegate-path)).
  The human updates this line when the gate below passes on a version that
  announces differently. The check compares only the announced version: a
  later fleet commit, or an uncommitted edit in the fleet checkout, that
  announces the same version passes it. What keeps a moved commit from
  reaching reviews unvalidated is the human's process below (reviews held
  from a move until the gate passes) and the commit the human records, not
  this check. An uncommitted edit is not covered by either: it is an
  accepted risk (below).
- **The override.** The fleet loads the fork's preview tree through
  `vrg-vm session`'s `--plugin-dir` override: the host file
  `~/.config/vergil/plugin-dirs.toml` lists the fleet checkout's
  `preview/paad` (`plugin_dirs = ["/Users/pmoore/dev/projects/wphillipmoore/paad-fleet/preview/paad"]`).
  It is personal, outside every repo, and read when each session starts.
  **Turn it on** by creating the file with that entry; **turn it off** by
  deleting the file or setting `plugin_dirs = []`, and the next session
  uses the installed paad again, which has no delegate, so it runs no
  review round. The override stays on as the standing arrangement. The tool's reference is
  vergil-tooling's
  `cli-tools-overview.md`, "The `--plugin-dir` override".
- **Lima only.** The paad development environment is supported only on
  macOS with Lima VMs, which see the Mac's projects tree at the same path.
  A cloud session launches with the installed paad and says the override
  is Lima only, so it runs no review round. Cloud support is not planned.
- **The fleet checkout.** The fleet never runs the development clone
  (`/Users/pmoore/dev/projects/wphillipmoore/paad`). It runs a dedicated
  `git worktree` of it,
  `/Users/pmoore/dev/projects/wphillipmoore/paad-fleet`, on branch
  `fleet`:
  - only the human moves `fleet`, including to sync it with upstream;
    moving it is the one deliberate step that puts a paad change in front
    of the fleet;
  - move `fleet` only when no session that loads it is running a review;
  - agents never run git in the fleet worktree;
  - the human records the checkout's commit on the issue that tracks each
    move. Review rounds record nothing about it.
- **The gate.** After every move of the fleet checkout, including a sync
  with upstream, the validation sets (the seeded and plain scenario sets
  of
  [vergil-project/.github#733](https://github.com/vergil-project/.github/issues/733),
  spec §5) pass on the new commit, in newly started sessions, before
  vergil relies on it. The order is always the same: the human moves
  `fleet`, then runs the gate, and until the gate passes no session runs
  a review round that loads the fleet checkout (the human holds those
  reviews). If
  the move changes the unattended contract (the agent's name, the result's
  syntax, the status values or the input fields), the doctrine is updated
  to match before reviews resume.
- **Accepted risks.**
  - Running the development tree is a deliberate choice: whatever is in the
    fleet checkout runs in every review. That is how the change is proven
    before it goes upstream. The control is the dedicated checkout, moved
    only by the human, with reviews held until the gate passes on it.
  - The fleet checkout sits on the projects tree every Lima VM mounts
    read-write. An uncommitted edit there changes what every later session
    runs, and nothing checks for it. This is accepted; a read-only mount of
    the fleet checkout is a candidate for the next iteration.

**Reason.** Unattended mode moves the review-only rules out of vergil's
prompts and into paad's own contract, where a fresh reviewer cannot read
them as optional, and it retires the guards vergil's own prompts once
needed around paad's interactive design. vergil now develops paad changes
itself, so running the fork's tree is the normal state, not a bridge to a
release. With the fork setup permanent and validated, a fallback for
sessions without the delegate would be complexity with no supported user,
so there is none
([vergil-project/vergil-claude-plugin#879](https://github.com/vergil-project/vergil-claude-plugin/issues/879)):
a session without the override, a cloud box, or anyone using
vergil-claude-plugin with paad as released today runs no review round,
and is told how to get one. Holding reviews from each move of `fleet` until the gate passes is
what keeps a committed but unvalidated paad change out of the fleet's
reviews, and it rests on the human's process; the validated-version check
only catches a delegate that announces a version the gate has not passed.
