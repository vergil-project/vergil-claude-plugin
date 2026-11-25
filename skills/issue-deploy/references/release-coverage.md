# What a human-gated release covers

A release cut with `vrg-release` is one unit of work. It runs as a human,
and once it completes, it has done everything its stages mechanize,
including the installs its repo configures. This page is the one place
that says what that covers for each repo, and what is left over for a
deployment task. `epic-create` plans deployment tasks from it, and
`issue-deploy` runs them against it.

The facts below come from vergil-tooling's
[Releasing guide](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/releasing.md)
and
[`vrg-release` reference](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/reference/dev/release.md),
and from each repo's `[publish].install` in its `vergil.toml`. When either
changes, this page changes with it.

## A completed release is its own attestation

`vrg-release` runs its `install` stage, which runs the repo's
`[publish].install` commands, before its `release-records` stage. That
stage posts a `Released:` record, from the human's login, on every issue
the release contains. It runs only once no stage before it has failed, a
failed install included. A failed install fails the release, which
`vrg-release --resume` finishes later. No flag skips the install stage.

So a `Released:` record that `vrg-release-record check <owner>/<repo>#<N>`
passes (exit 0) shows three things: the release contains the task, the
human ran the release, and the release's installs succeeded. It is the
human's attestation of the release, posted by the release itself. A
deployment task's release precondition is this check, run on each
blocked-by development task (see
[Confirming that a blocked-by task is released](../SKILL.md#preconditions-gate--release-is-a-precondition-not-your-job)).
It needs no separate comment from the human.

A human-attested release precondition is needed only where no record
exists: the check exits 4 (`none`), because the repo does not release
with `vrg-release` (a vergil-actions tag, say) or the task was released
before the records began. There, hand the human the exact attestation
command, as
[Handing the human the attestation command](#handing-the-human-the-attestation-command)
says.

## vergil-tooling

Its `[publish].install` runs, once `promote` has moved the rolling `vX.Y`
tag to the release:

1. `vrg-tooling-install v<MINOR>` on the host that ran the release (the
   Mac). It installs the exact release the line's tag names, locked to its
   `uv.lock`, and reports it.
2. `vrg-vm update --all`. For every running VM of every configured
   identity, Lima and off-platform alike, it reinstalls vergil-tooling at
   the release the VM's pin resolves to, copies the host's `~/.claude`
   config in, and refreshes and verifies the plugins. It attempts every
   box, and a failure on any one of them fails the stage.

**Covered:** the new tooling on the Mac that ran the release and in every
running VM whose pin follows the release's line. A deployment step that
reinstalls or updates vergil-tooling there, or re-checks the installed
version, repeats the release.

**Left over** (only where the next step needs it):

- A VM that was not running when the release ran: `update --all` skips it
  and reports it, and it gets the release at its next `vrg-vm update`.
- A VM pinned to an exact `vX.Y.Z`, or to an older line after a minor or
  major release: its pin does not move. Moving it is a change to the
  identity's `vergil` version in `identities.toml` and a `vrg-vm rebuild`.
- Any host other than the one that ran the release:
  `vrg-tooling-install v<MINOR>` there.
- Dev container images: the install stage does not touch them.

## vergil-claude-plugin

Its `[publish].install` runs, once `promote` has moved the rolling `vX.Y`
tag that every consumer's marketplace follows:

1. `vrg-host plugins` on the host that ran the release. It re-adds each
   declared marketplace at its declared ref, updates every install of an
   enabled plugin, and verifies the registered repo and ref.
2. `vrg-vm update --all`, as for vergil-tooling above, which refreshes
   and verifies the plugins in every running VM.

**Covered:** the new plugin installed on the host that ran the release
and in every running VM. A deployment step that runs `vrg-host plugins` or `vrg-vm update`, or
re-checks the installed plugin, repeats the release.

**Left over:** a running Claude Code session keeps the plugin version it
loaded. Run `/reload-plugins` in each running session, or restart it,
wherever the next step runs in a session started before the release.
This is a human-run step: it is a session command, not one the agent
runs. The caveats above for a VM not running at release time, and for
any other host (which runs `vrg-host plugins` itself), apply here too.

## Any other repo

Read the repo's `[publish].install` in its `vergil.toml` at the release's
tag. What it lists is covered, as above. With none configured (the
release's `install` stage line says `none configured`), the release
installs nothing, and every install the next step needs is a deployment
step. A repo that does not release with `vrg-release` has no records and
no install stage: its release is human-attested, and its deployment steps
are whatever the plan names.

## Planning a deployment task against a release

- **Precondition:** `vrg-release-record check` exits 0 for each blocked-by
  development task, never a human-attested statement where records exist.
- **Steps:** only what is left over, from the sections above. Never a
  step that reinstalls, updates or re-verifies what the release itself
  installs.
- **Nothing left over:** keep the deployment task when a later task needs
  the release installed, not just merged. It is then the release's gate:
  its procedure is the release-record check, and its acceptance is that
  check passing, recorded with the release version.
- **Checking behavior is not deploying.** A check that a new command or
  skill behaves as intended is a validation, not a deployment step: plan
  a validation task for it if the pipeline's tests do not cover it.

## Handing the human the attestation command

Where a release precondition is human-attested, the human posts the
attestation from their own login. Never make them ask for the command:

- **In the task body:** the precondition names the comment that attests
  it, with the attestation text's shape: `Release attested: <repo>
  v<X.Y.Z> carries <the PRs or tasks the release must contain>.`
- **In the run:** when the attestation is missing, find the candidate
  release first. From the repo's main clone, fetch its tags
  (`vrg-git fetch origin --tags`) and run `vrg-git tag --contains
  <merge-sha>` for each change's merge commit. The oldest release tag
  every one of them is in is the candidate. Then give the human the
  command, filled in, with no placeholder left, as a line they run in the
  session:

  ```text
  ! vrg-gh issue comment <N> --repo <owner>/<repo> --body "Release attested: <repo> v<X.Y.Z> carries <owner>/<repo>#<PR> and <owner>/<repo>#<PR>."
  ```

  Say that it must run as the human, and that it attests a release the
  human has published. Put the same filled-in command in the `blocked`
  comment and in the run's final report, so a gate that sees only the
  report can hand it on.
