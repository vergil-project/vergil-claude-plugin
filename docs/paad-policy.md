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

**Decision.** The fleet installs paad from the vergil fork,
`wphillipmoore/paad`, at ref `develop`, through the marketplace, on every
box (section 10). paad is **unpinned**: each box installs the latest commit
pushed to `develop` on its next plugin refresh.

- paad is enabled in the user-level `~/.claude/settings.json`, whose
  `extraKnownMarketplaces.paad` entry names the fork. Agent VMs copy that
  file from the host, so the VMs get the same plugins, from the same
  marketplace source, as the host.
- The managed repo-level Claude settings template (`claude_settings.json` in
  vergil-tooling) does not enable or pin paad, and this policy does not
  change it.
- Neither review mode adopts a `paad/config/` file (section 4).
- For now nobody detects drift between upstream paad releases and the
  workflow's expectations: D left drift detection out until real use shows
  it is needed (`epics/568-agentic-review-gate/spec.md` §5). vergil depends
  on no specific paad version, and the
  [review doctrine](paad-review-doctrine.md) checks none: what keeps a
  change to the fork's `develop` honest is the validation gate that runs
  before every push (section 10).

**Reason.** vergil develops paad changes itself, so the fleet runs the fork,
not an upstream release (section 10). A pin would not hold where agents run:
`vrg-vm update` moves every enabled plugin to the latest its marketplace
serves, and the fork's `develop` carries no plugin version, so boxes track
commits (section 10). Adopting no config file keeps the workflow off paad's
experimental config mechanism while unpinned.

## 2. Report files

**Decision.**

- **Design-review reports (pushback, alignment) are not written.** The
  planning issue's comments are the record of every design-review round
  (spec §3.2).
- **All other paad reports** (architecture, test-roadmap and so on) are
  committed under `paad/`, as the authors recommend.

**Reason.** The planning issue is the epic's permanent planning log, and
review history must stay out of the reviewed document so that each round's
reviewer starts with a fresh context. A report file would be a second, weaker
copy of that record. Reports with no issue-based
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
§4.F), and the four more that paad 2.0.2 ships (`agentic-a11y`, `vibe`,
`makefile` and `paad-help`, decided in
vergil-project/vergil-claude-plugin#844), were evaluated one by one with the
human. Each is adopted, used by hand in a stated place in the workflow,
recorded as a deviation with its reason, or considered and not integrated.
A skill that is considered, not integrated, is not part of the workflow and
is not a deviation, so it has no register row; if it is ever used, it is
revisited on its own at that time. `agentic-review`, which the fleet used
and then dropped, is listed here too.

| Skill | Decision | Place in the workflow |
|---|---|---|
| `rethink` | **Adopted** | Sanity-checks any decision, the agent's or the human's. The human invokes it, and the agent may offer it at a decision point. No skill wiring for now. Unattended use waits for paad unattended mode (vergil-project/.github#698). |
| `agentic-architecture` | Interesting, used by hand | Strategic, not daily. Run by hand as part of a periodic (roughly quarterly) review, looking for changes of direction and refactoring opportunities. Results feed the planning process. |
| `fix-architecture` | **Considered, not integrated** | Revisit on its own if it is ever used. Its development-workflow assumptions (several fixes per session on one branch, interactive commit choices) don't match the one-issue-one-PR model. |
| `test-roadmap` | **Considered, not integrated** | Revisit on its own if it is ever used. It commits onto the current branch as it goes, the roadmap in build mode and one phase per run in execute mode, which the one-issue-one-PR model has no settled place for yet. |
| `agentic-owasp` | Interesting, used by hand | Run by hand in the periodic review. Every finding is security-class, so it is recorded only with `vrg-security-record`, never in public issues. |
| `agentic-dedup` | Interesting, used by hand | Run by hand in the periodic review. Results feed planning. |
| `backlog` | **Not adopted: deviation** | paad's code-review backlog is not kept (existing register row), so there is nothing for it to work on. Intake is the system of record; `intake-review` and `deferred-review` cover clean, and routing an intake item to a task covers fix. |
| `agentic-a11y` | Interesting, used by hand | Run by hand in the periodic review of repos with a user-facing surface: the docs sites and the `vrg-*` CLIs. It is a strategic audit like its siblings and has no unattended mode, so it needs no skill wiring. The review doctrine's §1.3 severity table already maps its scale. |
| `vibe` | **Considered, not integrated** | Revisit on its own if it is ever used. It assumes no issue, worktree or one-PR flow, runs tests directly instead of through `vrg-validate`, leaves its edits uncommitted, and points at `agentic-review`, which the fleet has dropped. |
| `makefile` | **Considered, not integrated** | Revisit on its own if it is ever used. No fleet repo has a Makefile, and `vrg-validate` is the single validation entry point. |
| `agentic-review` | **Not adopted: deviation** | Dropped by epic vergil-project/.github#885, which removed it from `issue-implement`; no skill calls it. A task branch is reviewed before handoff by vergil's own `merge-review` (epic vergil-project/.github#881) instead (register row). |
| `paad-help` | **Adopted** | Answers which paad skills exist, what one does and how to invoke it. Used on request; no skill wiring. |

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
| paad is unpinned: every box installs the latest commit pushed to the fork's `develop` | A pin would not hold on agent VMs: `vrg-vm update` moves every enabled plugin to the latest its marketplace serves. The fork's `develop` carries no plugin version, so each pushed commit installs on the next refresh with nothing bumped (section 10). No `paad/config/` file is adopted (section 4). For now nobody detects paad drift (epic 568 spec §5). |
| The fleet installs paad from a fork, upstream's latest release plus the fleet's patches, not from an upstream release | vergil develops paad changes itself (unattended mode first) and proves them in the fleet before offering them upstream. The fork's `develop` is rebased onto each upstream release; only the human changes the fork, and only after the validation gate passes on the candidate (section 10). |
| The reviewer's reality check does not read the history of the document under review | Commit history of earlier rounds carries the provenance that umbrella §3.1 keeps out of the reviewer's context. |
| Design-review rounds are repeated under explicit stop and continue signals, with the human deciding each round | The authors say "revise and repeat as needed" without stop rules. The experiment behind vergil-project/.github#469 showed that unruled repetition compounds complexity. |
| paad's code-review backlog does not persist; an out-of-scope bug goes to intake when the human rules it filed | Intake is the system of record for follow-on work (umbrella §2.4). Under unattended mode paad neither reads nor writes it. |
| `paad:backlog` is not used | paad's code-review backlog does not persist and intake is the system of record. The queue-review skills (`intake-review`, `deferred-review`) and the task model cover its clean and fix modes. |
| `paad:agentic-review` is not used | Its review rounds did not converge on the fleet's small PRs, so epic vergil-project/.github#885 removed it from `issue-implement`. vergil's own `merge-review` reviews a task branch before handoff (section 7). |
| The paad usage policy lives in this one central document rather than in each repo's steering file | The authors suggest recording the policy in the steering file. A single document avoids drift between copies across the fleet. Pointing each repo's steering files at it is handed to child epic E (steering-file review). |
| `steering-audit` runs pushback findings-only: it collects and returns the findings instead of walking them one at a time, does not edit the reviewed file, and writes no report or other file | `steering-audit` walks the findings itself against the Claude config ownership model. In user scope it must write nothing at all, because the user-level files are personal and have no change control. |

## 9. Review doctrine

The rules for running a paad review more than once on the same artifact are
in the [paad review doctrine](paad-review-doctrine.md): the common core and
mode 1 (human-gated design review in `epic-create`). Each round runs under
paad's unattended runner, `paad:paad-delegate`, which every box gets with
paad installed from the fork (section 10). The doctrine also
holds the only copy of the table that maps paad's severity scales onto one
canonical scale; other documents link to it.

## 10. paad from the fork

**Decision.** The review doctrine's rounds (`epic-create`'s design review)
run paad only in **unattended mode**, except the interactive run the human may choose after a second
broken mode 1 round
([doctrine §2.4](paad-review-doctrine.md#24-output-checks-and-broken-rounds),
step 3); `steering-audit`'s own pushback run is unchanged (section 8).
vergil contributes to paad, so the fleet installs paad from the vergil fork,
not from an upstream release (unattended mode: epic
[vergil-project/.github#699](https://github.com/vergil-project/.github/issues/699),
spec §4.7 and §4.8; the install from the fork: epic
[vergil-project/.github#885](https://github.com/vergil-project/.github/issues/885),
spec §5).

- **The install source.** Every box, the host, Lima VMs and cloud VMs
  alike, installs paad from `wphillipmoore/paad` at ref `develop`, through
  the marketplace. The `paad` entry in the host's `~/.claude/settings.json`
  `extraKnownMarketplaces` is:

  ```json
  "paad": {
    "source": { "source": "github", "repo": "wphillipmoore/paad", "ref": "develop" }
  }
  ```

  `vrg-vm` copies the file into each VM and registers the marketplace from
  it; the host picks it up through `vrg-host plugins`. The plugin id stays
  `paad@paad`, so no skill or agent name differs from upstream's. Nothing
  overrides the installed paad when a session starts.
- **The standing arrangement.** The fork is permanent. It tracks upstream
  paad and runs a patch or two ahead of it. There is no plan to switch the
  fleet to a released paad.
- **The `develop` branch.** `develop` is upstream's latest release tag
  (`paad--v<X.Y.Z>`) plus the fleet's patches, pushed to GitHub. It never
  carries upstream's unreleased work: the fleet takes in upstream's preview
  changes only when upstream releases them. Its catalog entry for `paad`
  has `"source": "./preview/paad"`: the fork's unattended-mode work, the
  delegate included, lives only in `preview/paad`, and `plugins/paad` is
  upstream's released tree. Contributions upstream go as PRs from topic
  branches in the fork, never from `develop`; once upstream merges one, the
  next rebase drops the fleet's copy.
- **The version scheme: boxes track commits.** Claude Code takes an
  installed plugin's version from its manifest's `version`, then from its
  catalog entry's, and only when neither is set from the source's commit
  SHA; it replaces a cached copy only when that version changes
  ([plugin loading reference, "Versions and updates"](https://code.claude.com/docs/en/plugins/loading.md#versions-and-updates)).
  So on `develop`, `preview/paad/.claude-plugin/plugin.json` and the
  catalog entry for `paad` carry **no `version` field**, and each box picks
  up every pushed commit on its next refresh. Nothing is bumped on a push.
  - `package.json` and `plugins/paad` keep upstream's base version, and
    every `SKILL.md` in `preview/paad` announces `<base>-preview` (for
    example `v2.1.0-preview`), so a transcript still names the tree that
    ran.
  - The fork's `make check-versions` and `check-skill-versions` are
    patched to require the two fields' absence and to check the announce
    lines against `<base>-preview`, with `<base>` read from
    `plugins/paad`. This Makefile patch and the two removed fields are the
    fleet's only version delta. A rebase onto a new upstream release takes
    upstream's new base version and re-applies that delta.
  - The fork never releases. With no `version` in `preview/paad`'s
    manifest, upstream's release machinery (`make bump-version`,
    `make bump-tree`, `scripts/promote.py`) no longer runs on the fork,
    and is not meant to: the fork rebases onto upstream's release tags
    instead.
- **How a box picks up a change.** Both were found on a cloud VM in
  [vergil-project/.github#894](https://github.com/vergil-project/.github/issues/894):
  - **Switching the marketplace source.** After the host's
    `extraKnownMarketplaces.paad` entry was changed to the fork, the
    host's `vrg-vm update --all` switched the box's `paad` marketplace to
    the fork. No manual `claude plugin marketplace remove paad` was
    needed.
  - **A pushed commit installs with nothing bumped.** A commit pushed to
    `develop` installed on the next `vrg-vm update --all`, keyed by its
    commit SHA (the version `claude plugin list --json` shows is the short
    SHA), with no version changed anywhere.

  `vrg-vm` is a host-only tool for the human: it refuses to run inside a
  VM, so refreshing a box means running `vrg-vm update --all` on the host.
  The host refreshes itself with `vrg-host plugins`.
- **The rebase process.** Run by the human on each upstream release:
  1. Fetch upstream (`Ovid/paad`) with its tags.
  2. Rebase `develop` onto upstream's release tag (`paad--v<X.Y.Z>`),
     never onto `upstream/main`. Drop any fleet patch the release already
     contains.
  3. Check that the tag carries no unreleased upstream work: at the tag,
     `preview/paad` and `plugins/paad` differ only by upstream's preview
     markers (the announce suffix, the `internal` flag and the
     `plugin.json` version). Any other difference stops the rebase for the
     human to look at.
  4. Check the version delta: no `version` in `preview/paad`'s manifest or
     in its catalog entry, and the announce lines on the new base.
  5. Run the fork's own checks (`make test`).
  6. Run the validation gate (below) on the result.
  7. Force-push `develop` (`--force-with-lease`), under the push rule
     below.
- **The validation gate.** Before any change reaches `develop`, including
  a rebase, the validation scenario sets (the seeded and plain sets of
  [vergil-project/.github#733](https://github.com/vergil-project/.github/issues/733),
  spec §5) pass against the candidate tree, in newly started sessions. The
  candidate is loaded with Claude Code's own
  `claude --plugin-dir <candidate>/preview/paad` flag, as a **manual test**
  following `issue-validate`'s conventions, not as fleet plumbing: nothing
  in vergil configures or reads it. The run may be its own validation task
  or a step of the deployment task that pushes the result. If the change
  alters the unattended contract (the agent's name, the result's syntax,
  the status values or the input fields), the doctrine is updated to match
  before reviews rely on it.
  - **The push rule.** The commit pushed is the commit validated: just
    before the push, the fork's working tree is clean and `develop`'s HEAD
    is the commit the gate ran on.
  - **The exemption.** A push that touches nothing under `preview/paad/`
    (for example the root `README.md`, `CHANGELOG.md` or `docs/`, or an
    empty commit) is exempt from the scenario sets.

  Pushing `develop` is the one deliberate step that puts a paad change in
  front of the fleet: the next refresh on each box installs it. The human
  records the pushed commit on the issue that tracks each push. Review
  rounds record nothing about it.
- **Only the human changes the fork.** Every push, rebase and branch move
  in `wphillipmoore/paad` is run by the human. Agents never run git
  commands that change the fork (`vrg-git` does not stop them); they run
  read-only commands there and give the human the commands to run.
- **The delegate is required.** Each review round runs under
  `paad:paad-delegate`, paad's unattended runner, which the fork's paad
  provides on every box. A session without it runs no review round: it is
  a misconfigured box. The session stops and tells the human, and the
  message names the fix: the host settings entry above
  (`extraKnownMarketplaces.paad` → `wphillipmoore/paad` at `develop`),
  then `vrg-host plugins` for the host or `vrg-vm update --all` for the
  VMs, and a new session
  ([doctrine §1.8](paad-review-doctrine.md#18-the-delegate-requirement)).
- **No version check.** vergil depends on no specific paad version, and
  boxes track commits, not versions. The delegate's announce line is
  checked for the skill's name only
  ([doctrine §1.9](paad-review-doctrine.md#19-the-delegate-path)); the
  version it announces is compared with nothing. Whether the fleet ever
  returns to a released paad, and whether versions are checked then, is
  the human's decision.
- **Accepted risks.**
  - Every push to `develop` reaches every box: a mistaken push runs in
    every session's paad on its next refresh. The control is the
    validation gate before each push and the push rule, and it rests on
    the human's process.
  - The fork's development clone
    (`/Users/pmoore/dev/projects/wphillipmoore/paad`) sits on the projects
    tree every Lima VM mounts read-write. A change made to it from a VM is
    caught only by the push rule: the human pushes only a clean tree whose
    HEAD is the commit the gate ran on.
  - Only the human pushes to the fork, and nothing technical enforces it:
    `vrg-git` allows `push`. The rule rests on agents following this
    policy.

**Reason.** Unattended mode moves the review-only rules out of vergil's
prompts and into paad's own contract, where a fresh reviewer cannot read
them as optional, and it retires the guards vergil's own prompts once
needed around paad's interactive design. vergil now develops paad changes
itself, so running the fork is the normal state, not a bridge to a
release. Installing it through the marketplace gives every box, cloud VMs
included, the same paad with the delegate, through the refresh `vrg-vm`
and `vrg-host` already run. A fallback for sessions without the delegate
would be complexity with no supported user, so there is none
([vergil-project/vergil-claude-plugin#879](https://github.com/vergil-project/vergil-claude-plugin/issues/879)):
a misconfigured box, or anyone using vergil-claude-plugin with paad as
upstream releases it today, runs no review round and is told how to get
one. Gating every push to `develop` on the validation gate is what keeps
an unvalidated paad change off every box, and it rests on the human's
process.
