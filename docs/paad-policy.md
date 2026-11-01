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
- The fleet may run unreleased paad work from the fork's preview tree
  instead of the installed release, through a per-host override
  (section 10). That changes which paad a session loads, not this
  decision: the installed paad stays unpinned.
- For now nobody detects drift between paad releases and the workflow's
  expectations: D left drift detection out until real use shows it is needed
  (`epics/568-agentic-review-gate/spec.md` §5). The output checks in the
  [review doctrine](paad-review-doctrine.md) expect a paad version and treat
  a different one as a warning.

**Reason.** A pin would not hold where agents run: `vrg-vm update` moves every
enabled plugin to its latest version. Adopting no config file keeps the
workflow off paad's experimental config mechanism while unpinned.

## 2. Report files

**Decision.**

- **Design-review reports (pushback, alignment) are not written.** The
  planning issue's comments are the record of every design-review round
  (spec §3.2).
- **agentic-review output** in `issue-implement`'s gate (child epic D): on
  the delegate path paad writes nothing and returns its findings in its
  result (section 10). On the fallback path paad writes its usual files in the task's worktree, where `paad/code-reviews/` is
  ignored like `paad/security/`. After each round the implementer moves the
  report, and paad's other output, into the task's private state directory,
  which empties the worktree's `paad/code-reviews/` and `paad/security/`
  (but its `.gitignore`), and posts its findings, sorted, to
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

**Decision.** paad's per-project config (`paad/config/`) is **not adopted**
by either review mode.

- On both of the doctrine's paths, the output checks fail a round whose
  result has a `Config:` line, since one means a `paad/config/` file in the
  reviewed tree changed the review
  ([doctrine §1.9](paad-review-doctrine.md#19-the-delegate-path),
  [§2.4](paad-review-doctrine.md#24-output-checks-and-broken-rounds),
  [§3.4](paad-review-doctrine.md#34-output-checks)).
- Under unattended mode, paad follows no config file its caller did not
  name, and reports each one it found as not followed; the workflow names
  none. A branch under review cannot change how it is reviewed.
- The earlier idea of review-only config files as mode 1's fallback was
  never adopted, and unattended mode replaces it: mode 1's fallback is now
  the doctrine's fallback path (section 10).

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

Rows marked **(fallback path)** describe how the doctrine's fallback path
works around paad's interactive design. Unattended mode does each of these
things itself, as paad's own behaviour, so the delegate path retires them;
they stay for the fallback path until a released paad carries the mode
(section 10).

| Deviation from paad | Reason |
|---|---|
| Mode 2 (agentic-review in `issue-implement`) caps autonomous rounds at 3, then pauses for the human | The authors say "repeat" with a human present. Unattended, an unbounded loop is unsafe. |
| paad is unpinned and follows the latest release | A pin would not hold on agent VMs: `vrg-vm update` moves every enabled plugin to latest. No `paad/config/` file is adopted (section 4). For now nobody detects paad drift (epic 568 spec §5). |
| **(fallback path)** Design-review report files (pushback, alignment) are not written; the planning-issue comments are the record (spec §3.2) | The planning issue is the epic's permanent planning log, and review history must stay out of the reviewed document so the next round's reviewer has a fresh context. |
| **(fallback path)** pushback and alignment run review-only in a fresh subagent, and the main session presents the findings and edits the document; paad runs them interactively in the session that edits | Each round needs a context that has not seen earlier rounds (umbrella §3.1). The human still sees one finding at a time with options. |
| **(fallback path)** alignment's TDD rewrite step is skipped | `superpowers:writing-plans` writes tasks in red/green/refactor form. The reviewer reports each code task that is not as a minor finding ([doctrine §2.3](paad-review-doctrine.md#23-the-reviewer-prompt)), and it is fixed in the walk-through. |
| The reviewer's reality check does not read the history of the document under review | Commit history of earlier rounds carries the provenance that umbrella §3.1 keeps out of the reviewer's context. |
| Design-review rounds are repeated under explicit stop and continue signals, with the human deciding each round | The authors say "revise and repeat as needed" without stop rules. The experiment behind vergil-project/.github#469 showed that unruled repetition compounds complexity. |
| **(fallback path)** agentic-review writes its usual files, but `paad/code-reviews/` is ignored rather than committed; the implementer moves the report into the task's private state directory after each round and posts its findings to the task issue | The task issue is the record of each round, and a paused round keeps its material privately. Adapting to paad's defaults is more reliable than redirecting them. Emptying the directory keeps earlier rounds out of the next reviewer's context. |
| **(fallback path)** paad's code-review backlog does not persist; an out-of-scope bug goes to intake when the human rules it filed | Intake is the system of record for follow-on work (umbrella §2.4). |
| `paad:backlog` is not used | paad's code-review backlog does not persist and intake is the system of record. The queue-review skills (`intake-review`, `deferred-review`) and the task model cover its clean and fix modes. |
| **(fallback path)** The Spec Compliance intent source is a requirements file named in the prompt, not a spec-file argument | The skill's arguments take only a base and a path. Unattended mode's `Intent:` input carries it on the delegate path. |
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
and mode 2 (autonomous review in `issue-implement`). Each round runs under
paad's unattended runner, `paad:paad-delegate`, when the session has it
loaded, and on the fallback path otherwise (section 10). The doctrine also
holds the only copy of the table that maps paad's severity scales onto one
canonical scale; other documents link to it.

## 10. paad unattended mode and the fleet checkout

**Decision.** The review skills run paad in **unattended mode** wherever it
is available, and the fleet may run it from unreleased work on the paad
fork before any paad release carries it (epic
[vergil-project/.github#699](https://github.com/vergil-project/.github/issues/699),
spec §4.7 and §4.8).

- **The two paths.** Each review round runs under `paad:paad-delegate`,
  paad's unattended runner, when the session has it loaded, and on the
  **fallback path** otherwise: the `general-purpose` reviewer with today's
  prompts and checks. A round on the fallback path records the deviation
  ([doctrine §1.8](paad-review-doctrine.md#18-the-two-paths)).
- **The fallback stays until a released paad carries the mode.** The
  author may take the change in a different shape, later, or not at all.
  Once a release carries it, and the gate below has passed against that
  release, the doctrine retires the text it marks *Fallback path only*, and
  the register rows marked **(fallback path)** (section 8) go with it.
- **The override.** The fleet loads the fork's preview tree through
  `vrg-vm session`'s `--plugin-dir` override: the host file
  `~/.config/vergil/plugin-dirs.toml` lists the fleet checkout's
  `preview/paad` (`plugin_dirs = ["/Users/pmoore/dev/projects/wphillipmoore/paad-fleet/preview/paad"]`).
  It is personal, outside every repo, and read when each session starts.
  **Turn it on** by creating the file with that entry; **turn it off** by
  deleting the file or setting `plugin_dirs = []`, and the next session
  uses the installed paad again. After a released paad carries the mode,
  the override is removed. The tool's reference is vergil-tooling's
  `cli-tools-overview.md`, "The `--plugin-dir` override".
- **Lima only.** The paad development environment is supported only on
  macOS with Lima VMs, which see the Mac's projects tree at the same path.
  A cloud session launches with the installed paad, says the override is
  Lima only, and its rounds take the fallback path. Cloud support is not
  planned.
- **The fleet checkout.** The fleet never runs the development clone
  (`/Users/pmoore/dev/projects/wphillipmoore/paad`). It runs a dedicated
  `git worktree` of it,
  `/Users/pmoore/dev/projects/wphillipmoore/paad-fleet`, on branch
  `fleet`:
  - only the human moves `fleet`; moving it is the one deliberate step that
    puts a paad change in front of the fleet;
  - agents never run git in the fleet worktree;
  - the human records the checkout's commit on the issue that tracks each
    move. Review rounds record nothing about it.
- **The gate.** After every move of the fleet checkout, the validation sets
  (the seeded and plain scenario sets of
  [vergil-project/.github#733](https://github.com/vergil-project/.github/issues/733),
  spec §5) pass on the new commit, in newly started sessions, before
  vergil relies on it. The same gate applies to switching vergil to a
  released paad: the validation sets pass against that release first, and
  if its unattended contract changed (the agent's name, the result's
  syntax, the status values or the input fields), the doctrine is updated
  to match before the switch.
- **Accepted risks.**
  - Running the development tree is a deliberate choice: whatever is in the
    fleet checkout runs in every review. That is how the change is proven
    before it goes upstream, and the dedicated checkout, moved only by the
    human after the gate, is the control.
  - The fleet checkout sits on the projects tree every Lima VM mounts
    read-write. An uncommitted edit there changes what every later session
    runs, and nothing checks for it. This is accepted; a read-only mount of
    the fleet checkout is a candidate for the next iteration.
  - paad is unpinned (section 1), so a paad release that ships the
    delegate reaches the fleet on the next `vrg-vm update`, and the
    selection rule would take it before the gate has run against it. A
    result that does not match the doctrine's format fails its round, but a
    contract change that still parses would not; the human runs the gate
    when such a release appears.

**Reason.** Unattended mode moves the review-only rules out of vergil's
prompts and into paad's own contract, where a fresh reviewer cannot read
them as optional, and it retires most of the fallback path's guards
(section 8). Keeping the fallback means a session without the override, a
cloud box, or anyone using vergil-claude-plugin with a released paad still
runs a checked review. The gate keeps an unvalidated paad change from
reaching the fleet's reviews by accident.
