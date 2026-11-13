---
name: fixture-run
description: File a fixture run — the change, release and validation trio that drives one language fixture repo through Vergil's full cycle (change → PR → merge → release → validate) against a released Vergil change. Use when an epic's plan seeds a fixture run ("file the fixture runs", "run fixture-run for python-lib", "seed the Rust fixture runs"), invoked as `fixture-run <epic-ref> <fixture>[,<fixture>…] --validates <what> --after <owner/repo#N> [--after …]`. It files tasks only, one trio per fixture, and prints their refs; it never runs them. Refuses a run without `--after`. Run as the vergil-user agent.
---

# Fixture run

A **fixture run** is one pass through Vergil's full development cycle on one
**fixture repo**: a small, real, managed repo whose only job is to be driven
through that cycle after a major change, so a language's support is proven
end to end (epic
[vergil-project/.github#1091](https://github.com/vergil-project/.github/issues/1091),
spec §6.3).

This skill is the **recipe**. It files a run's three tasks, a **trio**, with
the bodies below and the `Blocked-by:` links between them, all linked under
the epic that needs the run. Each task is then run by the skill already built
for its kind:

| Task | Kind | Run with | Blocked by | Closes when |
|---|---|---|---|---|
| (a) change | ordinary task | `issue-implement` | every `--after` ref | its PR is finalized |
| (r) release | `deployment` | `issue-deploy` | (a) | the release exists and contains (a)'s merge |
| (b) validation | `validation` | `issue-validate` | (r) | `Outcome: SUCCESS` is recorded |

**The recipe files tasks only.** It never implements, releases or validates
anything, and it never runs one of the trio's skills.

## The fixtures

The one list of fixtures. A new language gets fixtures by adding its
`vergil-fixture-<lang>-lib` and `vergil-fixture-<lang>-app` rows here, with no
other change to this skill (spec §6.6).

| Fixture | Repo | Language | Shape (`repository-type`) |
|---|---|---|---|
| `python-lib` | `vergil-project/vergil-fixture-python-lib` | python | `library` |
| `python-app` | `vergil-project/vergil-fixture-python-app` | python | `application` |
| `rust-lib` | `vergil-project/vergil-fixture-rust-lib` | rust | `library` |
| `rust-app` | `vergil-project/vergil-fixture-rust-app` | rust | `application` |

## Known gaps

A check that fails because of a gap already recorded on
[vergil-project/.github#410](https://github.com/vergil-project/.github/issues/410)
is a **known gap**: the validation task records it, with its evidence, as a
comment on #410, and it does not count against the run. Today's known gaps,
both on the Rust fixtures:

| Language | Check | Gap |
|---|---|---|
| rust | Dependency update | `vrg-update-deps` has no Cargo updater, so the release's dependency update cannot restore a rolled-back crate. The Rust change task also skips the rollback. |
| rust | Evidence bundle | The CI evidence bundles name only Python's tools and reports. |

When #410 closes a gap, its row is removed here (a change to this skill), the
same check becomes its proof, and a failure of it is an ordinary failure
again. Removing the dependency-update row also turns the rollback on for that
language.

## Learned ready-to-start conditions

"Ready to start" (the change task's first step) has one defined rule: runs on
one fixture are serialized. Every other condition is learned from the runs
and recorded here, one bullet each, with the run that found it:

- None yet.

A run that finds a new condition lists it under `Awaiting a ruling` on its
change task
([doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues));
once the human approves, it is added here through an ordinary task in
vergil-claude-plugin. The recipe copies this list into every change task it
files.

## Arguments

```text
fixture-run <epic-ref> <fixture>[,<fixture>…] --validates <what> --after <owner/repo#N> [--after …]
```

- **`<epic-ref>`** — the epic that needs the run, as `owner/repo#N` (for
  example `vergil-project/.github#1091`). Every task of every trio is linked
  under it.
- **`<fixture>`** — one or more fixtures from [the list](#the-fixtures), by
  short name (`rust-lib`) or repo name (`vergil-fixture-rust-lib`),
  comma-separated; `all` means all of them. One trio is filed per fixture.
- **`--validates <what>`** — the released change under validation, naming
  what ships it and its version or digest, for example
  `vergil-tooling v2.1.309`, `vergil-actions v2.1.58` or a container image and
  digest. It drives the validation task's deployed-version probe.
- **`--after <owner/repo#N>`** — **required**, repeatable. Each ref is the
  release or deployment task that ships the change to the fixtures, and is
  stamped as the change task's `--blocked-by`. A fixture consumes only
  released Vergil, so a run blocked only by the code task that merges the
  change would test the previous release.

## Preflight

1. Confirm you are the **USER** agent:
   `[ "$(vrg-whoami --mode)" = user ] && echo ok || echo "not user"` must
   print `ok`.
2. **Parse the arguments.** Stop with the reason, filing nothing, if:
   - no `--after` is given: `fixture-run: refusing to file a run without
     --after (the release or deployment task that ships the change)`;
   - `--validates` is missing or empty;
   - a fixture is not in [the list](#the-fixtures), or one is named twice.
3. **The epic.** `vrg-gh issue view <N> --repo <owner>/<repo> --json
   labels,state` must show an open issue labelled `epic`. If it carries
   `intake`, `planning` or `deferred` (a queue epic) or `archive`, stop: a
   run belongs to an epic doing the work.
4. **Each `--after` ref** must exist and carry the `deployment` label
   (`vrg-gh issue view <N> --repo <owner>/<repo> --json labels,state`). A ref
   without it is a code task or something else: stop and say which, since
   the run must wait for the release or deployment that ships the change. It
   may be open or closed.
5. **Approval to file.** Creating issues needs the human's approval
   ([doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues)).
   For a fixture run it comes from the epic plan that seeded the run
   (`epic-create`'s fixture-run rule). Read the epic's plan (its
   `plan.md` in the epic's `epics/<N>-<slug>/` directory of the org
   `.github`) and confirm it calls for a fixture run on each named fixture.
   If it does not, stop and ask the human: file only on their approval in
   this session.
6. **Each fixture repo** exists and is readable:
   `vrg-gh repo view vergil-project/<repo> --json name`. If one is not, stop
   before filing anything.
7. **Not already filed.** For each fixture, search its open issues for a
   trio of this run:
   `vrg-gh issue list --repo vergil-project/<repo> --state open --search
   "Fixture run in:title" --json number,title,labels`. A task titled for the
   same `<what>` means the run was filed already: stop and show it rather
   than file a duplicate. An open trio for another run does **not** stop the
   filing: serialization is the change task's "Ready to start" check, not
   the recipe's.

## Filing

For each fixture, in the order given, file (a), then (r), then (b), each
with `vrg-issue-create` and a body file. Write the body files to a fresh
scratch directory (`mktemp -d`), one per task, filled from the
[templates](#templates). A `## ` line in an operational body file starts a
section, so a template uses `###` or bold text inside a section, never `##`.

```bash
# (a) change: an ordinary task; Blocked-by every --after ref.
vrg-issue-create --epic <epic-ref> --repo vergil-project/<repo> \
  --title "Fixture run: change — <what>" --body-file <dir>/change.md \
  --blocked-by <after-1> [--blocked-by <after-2> …]

# (r) release: blocked by (a).
vrg-issue-create --epic <epic-ref> --repo vergil-project/<repo> --kind deployment \
  --title "Fixture run: release — <what>" --body-file <dir>/release.md \
  --blocked-by vergil-project/<repo>#<a>

# (b) validation: blocked by (r).
vrg-issue-create --epic <epic-ref> --repo vergil-project/<repo> --kind validation \
  --title "Fixture run: validate — <what>" --body-file <dir>/validate.md \
  --blocked-by vergil-project/<repo>#<r>
```

Each successful call prints `Created <url>, linked under epic <slug>.`; take
the issue number from that URL. (r)'s body names (a), and (b)'s names (a) and
(r), so each is written once the refs it names are known.

Then post one comment on each of the three tasks naming the whole trio, so
every task can find the others:

```bash
vrg-gh issue comment <N> --repo vergil-project/<repo> --body "Fixture run (filed by fixture-run): change vergil-project/<repo>#<a>, release vergil-project/<repo>#<r>, validation vergil-project/<repo>#<b>. Validates: <what>."
```

**On any failure, stop.** If a `vrg-issue-create` call exits non-zero, file
nothing more and do not retry it blindly: a call that reports `created <url>
but failed to link it` has created the issue, and its message gives the
`vrg-epic-move` command that links it. Report every task filed so far, and
the failure, so the human can finish or close a partial trio. Never leave a
partial trio unreported.

**Report** each fixture's trio as three refs, with the skill that runs each:

```text
vergil-fixture-rust-lib: change #<a> (issue-implement) → release #<r> (issue-deploy) → validation #<b> (issue-validate)
```

## Templates

Fill every recipe field before filing: `<repo>`, `<language>` and `<shape>`
from [the list](#the-fixtures), `<what>`, `<epic-ref>`, and the trio refs
`<a>` and `<r>`. Copy the
[learned conditions](#learned-ready-to-start-conditions) and, for the
fixture's language, the [known gaps](#known-gaps) as they stand when the
run is filed. The other fields (`vX.Y.Z`, `<package>`, `<older>`, `<range>`,
`<a's merge commit>`) are filled by the agent that runs the task, from what
it finds.

### (a) Change task

Keep only the rollback paragraph for the fixture's language and drop its
`<Python:>` or `<Rust:>` marker: **Python** rolls a dependency back; **Rust**
skips the rollback while its dependency-update known gap stands.

````markdown
A fixture run on `vergil-project/<repo>` (<language> <shape>), validating
**<what>**. Filed by the `fixture-run` recipe for
<epic-ref>; it is the change task of a trio, followed by a release task and a
validation task (see the comment below for their refs). Implement it with
`issue-implement`, exactly like a task on any real repo.

## Ready to start

Before implementing anything, confirm the fixture is in a state from which
the full cycle can begin.

- **Runs on one fixture are serialized.** Start only when no other fixture
  run's release or validation task on this repo is open:
  `vrg-gh issue list --repo vergil-project/<repo> --state open --search "Fixture run in:title"`
  must show no `deployment` or `validation` task other than this run's own
  (named in the trio comment below).
- Learned conditions (from the `fixture-run` skill):
  <the learned conditions, one bullet each, or "none yet">

If the fixture is not ready (something left open or red from earlier), stop
and work with the human to get it there. Anything broken outside the fixture
is filed, with the human's approval, in the repo that owns it, never fixed
by weakening the fixture. A new condition you had to learn goes under
`Awaiting a ruling` as a proposed addition to the `fixture-run` skill's
learned conditions.

## Change

One small, real change through the normal worktree flow: a new function
(library) or subcommand (application) with its tests, added without
restructuring the program, and keeping coverage at 100%. Validate with
`vrg-container-run -- vrg-validate`, run merge review, and hand off with
`vrg-pr-workflow report-ready`. No gate is lowered or suppressed.

<Python:>
**Dependency rollback.** In the same change, move one third-party runtime
dependency back to an earlier version **in `uv.lock` only** (for example
`uv lock --upgrade-package '<package>==<older>'`). Leave its declared range
in `pyproject.toml` open, so the release's dependency update has a
guaranteed upgrade to make. The earlier version must pass the vulnerability
audit, so the PR never goes red for the wrong reason. Record it on this
issue and in the report-ready notes as one line:
`Rolled back: <package> <locked version> -> <older> (declared <range>)`.

<Rust:>
**Dependency rollback: skipped.** `vrg-update-deps` has no Cargo updater (a
known gap recorded on vergil-project/.github#410), so nothing would restore
a rolled-back crate. Leave `Cargo.lock` alone.

## Submit and merge

The human runs `vrg-submit-pr`, then `vrg-finalize-pr` once CI is green,
which closes this task.
````

### (r) Release task

````markdown
## Intro

The release task of a fixture run on `vergil-project/<repo>`, validating
**<what>**, filed by the `fixture-run` recipe for <epic-ref>. The human
releases the fixture with `vrg-release`; the agent never cuts a release. Run
it with `issue-deploy`. It closes once the release exists and contains the
change task vergil-project/<repo>#<a>'s merge.

## Preconditions

- The change task vergil-project/<repo>#<a> is closed and its PR is merged to
  `develop`.
- `develop`'s CI is green at that merge, so the release starts clean.
- No other release of the fixture is in flight: no open release tracking
  issue or release PR on the repo.

## Procedure

1. Hand the human the human-run step below and wait for them to report it.
2. Find the new release: `vrg-gh release list --repo vergil-project/<repo> --limit 3`
   names `vX.Y.Z`, and `vrg-gh release view vX.Y.Z --repo vergil-project/<repo>`
   shows it published.
3. Confirm the release workflow runs the tag started have **finished**
   (`vrg-gh run list --repo vergil-project/<repo> --limit 10`). A tag that
   exists while its release workflow is queued or still running means
   **blocked, not FAILURE**: comment `blocked: preconditions not met —
   release vX.Y.Z still running` and stop; re-run once it has finished.
4. Confirm the release contains (a)'s merge: in a clone of the fixture,
   `vrg-git fetch origin --tags` then
   `vrg-git merge-base --is-ancestor <a's merge commit> vX.Y.Z` exits 0.

## Human-run steps

- From a clone of `vergil-project/<repo>` on an up-to-date `develop`, run
  the release, with no flags (the dependency update it runs is part of what
  the validation checks):

  ```bash
  vrg-release
  ```

  Check: `vrg-release` exits 0.

## Acceptance

- The GitHub Release `vX.Y.Z` is published and its release workflow has
  finished.
- `vX.Y.Z` contains vergil-project/<repo>#<a>'s merge commit.
- The result records the version as `Released: vX.Y.Z`, with the release
  URL; the validation task reads it.
````

### (b) Validation task

The known-gaps line is the fixture language's rows of [Known gaps](#known-gaps),
or `none` for a language with no row.

````markdown
## Intro

The validation task of a fixture run on `vergil-project/<repo>`
(<language> <shape>), validating **<what>**, filed by the `fixture-run`
recipe for <epic-ref>. Change task vergil-project/<repo>#<a>, release task
vergil-project/<repo>#<r>. Run it with `issue-validate`: it only checks and
records, with no worktree, no commits and no PR.

## Preconditions

A machine probe; check each before anything else, with evidence.

- The fixture repo exists and this session can clone it.
- `develop` and `main` exist.
- `vergil.toml` has `repository-type = "<shape>"` and `primary-language = "<language>"`.
- The release task vergil-project/<repo>#<r> is closed with
  `Outcome: SUCCESS`, and the release it recorded (`Released: vX.Y.Z`)
  contains the change task vergil-project/<repo>#<a>'s merge.
- The release's workflow runs have **finished**. A `vX.Y.Z` tag that exists
  while its release workflow is queued or still running is blocked, not
  FAILURE.
- **Deployed-version probe.** <what> is what the fixture actually consumed
  in the runs this task judges (the change PR's CI and `main`'s CI for the
  release). The fixtures consume only released Vergil: their workflows call
  vergil-actions at the rolling series tag, `setup/vergil` installs the
  vergil-tooling version the `[dependencies].vergil` pin in `vergil.toml`
  resolves to, and CI runs on the `prod-*` images. Show, from those runs'
  logs, that the vergil-tooling version the "Install vergil-tooling" step
  installed, the vergil-actions tag the workflows resolved, or the image
  digest the jobs pulled is <what> or a later release that contains it. A
  probe that cannot show it is blocked: never validate against the previous
  release.

## Procedure

Check each, in order, and record the evidence for each (links, run IDs, tag
names, versions):

1. **CI gates.** Every required CI gate passed on the change PR and on
   `main` at the release. For a library, the CI matrix ran every version in
   the language's window (the versions `setup/vergil`'s resolver step logged).
2. **Ops and config sync.** The fixture's latest scheduled `ops.yml` run is
   green, and every automated config-sync PR opened since the previous
   fixture run's validation on this repo (or, for the first run, since the
   repo was created) merged on its own.
3. **Release.** The release produced the `vX.Y.Z` tag, the GitHub Release
   with its CI evidence bundle attached, the back-merge to `develop` with its
   version bump, and the moved `vX.Y` tag (it resolves to `vX.Y.Z`'s commit).
4. **Evidence bundle.** The bundle's contents match the fixture's language:
   the tools it names and the reports it holds come from <language>'s
   `vrg-validate` gates (the ones the fixture's CI ran), not merely a bundle
   that exists.
5. **Dependency update.** The release's dependency-update stage brought the
   dependency the change task rolled back (its `Rolled back:` line) up to the
   newest version its declared range allows, through its usual PR. Record
   the versions before and after, and the PR.
6. **Docs.** The fixture's docs site was published for the release
   (its Pages deployment run succeeded and the site serves it).
7. **Nothing published to a package registry.** No crates.io, PyPI, apt/dnf
   index or container-registry upload: the release workflow ran no registry
   upload, `vergil.toml` has no `[package]` table, and no registry holds the
   fixture's package. The release's provenance attestation and the
   fixture's own Pages site are not artifacts in this sense.

**Known gaps** for <language>: <the language's known-gap rows, or "none">.
A check that fails only because of a known gap recorded on
vergil-project/.github#410 is reported as a known gap: post its evidence as
a comment on #410 and list it in the result. It does not count as a failure.

## Acceptance

- `Outcome: SUCCESS` only if every precondition passed and every check
  passed or is a known gap, each known gap listed in the result as
  `Known gap: <check> — <link to its #410 comment>`.
- Otherwise `Outcome: FAILURE`. File each failure in the repo that owns the
  broken behaviour (for example vergil-tooling or vergil-containers), never
  in the fixture, as `issue-validate`'s failure fix tasks. If the right fix
  is in the fixture itself (for example, a dependency the fixture uses was
  withdrawn), it is a separate, ordinary task in the fixture's ad-hoc epic
  (`vrg-issue-create --epic adhoc --repo vergil-project/<repo>`). A run never
  weakens the fixture to make itself pass.
````

## Boundaries

- **Files tasks only.** The recipe never runs a task of the trio, never
  opens a PR, and never releases. The human submits and finalizes the change
  task's PR and runs `vrg-release`.
- **The approval is the plan's.** The recipe files what the epic's plan
  seeded; anything else it would file needs the human's approval first
  ([doctrine §1.7](../../docs/paad-review-doctrine.md#17-creating-issues)).
- **Nothing reaches a package registry.** No step of a run publishes the
  fixture anywhere but its own GitHub Release and Pages site.
- **No gate is lowered.** A fixture is never weakened to make a run pass
  (spec §4).
