# vergil-claude-plugin

Claude Code plugin for the vergil-tooling ecosystem. Delivers
hooks, skills, and agents that enforce the fleet workflow mechanically
in every Claude Code session.

## Table of Contents

- [What this plugin does](#what-this-plugin-does)
- [Distribution model](#distribution-model)
- [Install](#install)
- [Update](#update)
- [Component inventory](#component-inventory)
- [Plugin namespace](#plugin-namespace)
- [Related repositories](#related-repositories)
- [Development and deployment](#development-and-deployment)

## What this plugin does

This plugin is the behavioral half of a two-repo system:

| Repo | Delivers | Via |
|---|---|---|
| [`vergil-tooling`](https://github.com/vergil-project/vergil-tooling) | Python CLIs (`vrg-commit`, `vrg-submit-pr`, `vrg-container-run`, …) and Claude Code hook guard | PATH + PreToolUse hook |
| **`vergil-claude-plugin`** (this repo) | Claude Code hooks, skills, agents, commands | Claude Code plugin system |

The two are complementary: `vergil-tooling` makes the tools
available; this plugin ensures Claude Code uses them correctly —
blocking raw `git commit` in favor of `vrg-commit`, blocking raw
`gh pr create` in favor of `vrg-submit-pr`, routing per-file
validation through the dev container, and so on.

## Distribution model

The plugin ships through a **single channel**: every consumer — the host and
every agent VM — registers `vergil-marketplace@v2.1` in its user-level
settings and follows the floating `v2.1` rolling tag; each `vergil-project`
repo only enables `vergil@vergil-marketplace`. There is no per-version
pinning: the plugin is *behavioral guidance* (skills, hooks,
agents), not a versioned API that code links against, so every consumer runs
whatever release `v2.1` points at.

- **A release makes a change live.** Each plugin release moves `v2.1` forward
  to the new `v2.1.Z`, so releasing is the one act that makes a new skill or
  hook live for everyone. `main` is still the release branch, but consumers
  follow the tag, not the branch.
- **A rollback moves it back.** Rolling back is moving `v2.1` to an earlier
  `v2.1.Z` with `vrg-promote`, a human-gated release act. The procedure is
  vergil-tooling's
  [Rolling back a release](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/releasing.md#rolling-back-a-release)
  runbook. The rollback lasts until the next release moves `v2.1` forward
  again.
- **A new minor line is opt-in.** When a `2.2.0` release creates the `v2.2`
  tag, `v2.1` stops moving and the fleet stays on the last `v2.1.Z` until you
  change the `ref`; see
  [Moving to a new minor line](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/consuming-repo-setup.md#moving-to-a-new-minor-line).

To run **unreleased** (`develop`) behavior you don't need a second channel:

- **Iterating on the plugin?** Load the working tree directly with
  `claude --plugin-dir /path/to/vergil-claude-plugin` — see
  [Develop against the source tree](#develop-against-the-source-tree).
- **Need one unreleased skill ad hoc?** Tell the agent to read that file on
  `develop` and follow it — the AI-equivalent of running it by hand.

Full rationale and decision record:
[`epics/760-plugin-tag-distribution/spec.md`](https://github.com/vergil-project/.github/blob/develop/epics/760-plugin-tag-distribution/spec.md),
which supersedes the tag decision of
[`epics/45-plugin-distribution-model/spec.md`](https://github.com/vergil-project/.github/blob/develop/epics/45-plugin-distribution-model/spec.md).

## Install

**Recommended install path** for consuming repositories is the full
walkthrough documented in vergil-tooling:

- Quickstart:
  <https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/getting-started.md>
- Detailed walkthrough with rationale:
  <https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/consuming-repo-setup.md>

The short version: the plugin is installed per user, not per repo. Add
the marketplace definition and the plugin enable to your user-level
`~/.claude/settings.json`. If that file already has `extraKnownMarketplaces`
or `enabledPlugins` objects, merge these entries into them rather than
adding a second copy of either key:

```json
{
  "extraKnownMarketplaces": {
    "vergil-marketplace": {
      "source": {
        "source": "github",
        "repo": "vergil-project/vergil-claude-plugin",
        "ref": "v2.1"
      }
    }
  },
  "enabledPlugins": {
    "vergil@vergil-marketplace": true
  }
}
```

The user-level enable is what installs the plugin. The
`"ref": "v2.1"` points the marketplace at the floating `v2.1` tag, so an
[update](#update) installs the release `v2.1` points at: the latest
release, or an earlier one after a
[rollback](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/releasing.md#rolling-back-a-release),
never the `develop` bleeding edge. The plugin loads directly from that
checkout — there is no separate clone to fail. See the
[spec](https://github.com/vergil-project/.github/blob/develop/epics/760-plugin-tag-distribution/spec.md)
for the design.

Already registered `vergil-marketplace` at another `ref`, such as `main`?
Editing the `ref` is a change of source, not an update, so
`marketplace update` alone keeps the old registration. Follow
[Switching an existing machine](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/consuming-repo-setup.md#switching-an-existing-machine).

A managed repo's `.claude/settings.json` is not where this goes. It
comes from the vergil-tooling template, which only enables
`vergil@vergil-marketplace` and never defines the marketplace: a
second `vergil-marketplace` definition in the repo file would replace
your user-level entry whole. The nightly config audit requires the
repo file to equal that template. See vergil-tooling's
[Claude Config Ownership](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/claude-config-ownership.md)
model for which file owns each setting, and
[Consuming Repo Setup](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/consuming-repo-setup.md#claudesettingsjson)
for the repo file.

**Prerequisite:** this plugin's commands and skills shell out to
`vrg-commit`, `vrg-submit-pr`, `vrg-await`, and friends from
the vergil-tooling Python package. Install those on your host
PATH first — see the Getting Started guide above.

## Update

A release or a rollback moves `v2.1`; each machine picks the move up when
its plugins are next updated. On the vergil fleet, run in a human shell:

```bash
vrg-host plugins        # the host
vrg-vm update --all     # every running agent VM
```

Then restart Claude Code: a running session keeps the plugin version it
loaded. See vergil-tooling's
[Pick the move up on each machine](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/releasing.md#pick-the-move-up-on-each-machine).

To refresh a single install from inside Claude Code instead:

```text
/plugin marketplace update vergil-marketplace
/plugin update vergil@vergil-marketplace
/reload-plugins
```

What each step does:

1. **`/plugin marketplace update <marketplace>`** — refreshes the
   marketplace clone, so the release `v2.1` now points at is visible.
2. **`/plugin update <plugin>`** — installs that release into the
   local cache at `~/.claude/plugins/cache/<plugin-id>/<version>/`.
   The previous version stays on disk for 7 days as a grace window
   for concurrent sessions, then is removed automatically.
3. **`/reload-plugins`** — applies the new skills / hooks / agents
   to the **current** Claude Code session without restarting.
   Without this, the running session keeps using the old in-memory
   plugin state.

### Verify the update

```bash
claude plugin list --json
```

`vergil@vergil-marketplace` should be at the release `v2.1` points at:
normally the latest tag on
[GitHub Releases](https://github.com/vergil-project/vergil-claude-plugin/releases),
or the earlier release after a rollback. Don't judge by the newest
directory under `~/.claude/plugins/cache/vergil-marketplace/vergil/`:
after a rollback the newer, rolled-back-from version stays cached there
for up to 7 days.

### References

Sourced from the official Claude Code documentation:

- [Plugins reference — CLI commands](https://code.claude.com/docs/en/plugins-reference.md)
- [Discover plugins — Apply changes without restarting](https://code.claude.com/docs/en/discover-plugins.md)

## Component inventory

### Hooks

PreToolUse, PostToolUse, and Stop hooks that enforce guardrails
mechanically. Every hook below **except `block-heredoc`** is
gated on a managed-repo check: a repo must contain
`vergil.toml` at its root for the hook to fire. In repos
without this marker, the gated hooks
short-circuit to a no-op so the plugin doesn't interfere with
ad-hoc git work in unrelated repositories.
`block-worktree-bypass-write` has exceptions that apply
everywhere: it denies a relative target path; without `python3` it
denies every Write and Edit; and it denies a write whose path `python3`
cannot normalise. See the
[hooks reference](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/site/docs/hooks/index.md#managed-repo-gating)
for the rationale.

| Hook | Matcher | Purpose |
|---|---|---|
| `block-raw-git-commit` | PreToolUse/Bash | Redirects raw `git commit` to `vrg-commit` |
| `block-raw-gh-pr-create` | PreToolUse/Bash | Redirects raw `gh pr create` to `vrg-submit-pr` |
| `block-protected-branch-work` | PreToolUse/Bash | Blocks raw `git commit` from outside `.worktrees/*` on repos that adopt the worktree convention; otherwise blocks it on `develop`/`main`. `vrg-commit` is not matched — it checks the real branch itself |
| `block-heredoc` | PreToolUse/Bash | Blocks `<<EOF` in CLI args (use `--body-file` or `$(cat <file>)`) |
| `block-associative-arrays` | PreToolUse/Bash | Blocks bash 4+ associative arrays — host scripts must run on macOS bash 3.2 |
| `enforce-host-container-split` | PreToolUse/Bash | Denies wrapping host-only tools in `vrg-container-run`; warns on bare container-only tools |
| `block-autoclose-linkage` | PreToolUse/Bash | Blocks `--linkage Fixes/Closes/Resolves` in `vrg-submit-pr` — use `Ref` instead |
| `block-agent-merge` | PreToolUse/Bash | Unconditionally blocks `gh pr merge` / `gh pr review --approve` — merging is the human's Phase-6 action |
| `block-github-contents-api` | PreToolUse/Bash | Blocks write-method `gh api` calls to the Contents API — file changes go through the local workflow |
| `block-worktree-bypass-write` | PreToolUse/Write\|Edit | Blocks edits to the main worktree when the worktree convention is active, except ignored agent state under `build/.vergil-state/` |
| `guard-audit-writes` | PreToolUse/Write\|Edit\|NotebookEdit | AUDIT identity may write only `.vergil/audit-*` and `build/` — soft gate on the audit's read-only discipline |
| `detect-deprecation-warnings` | PostToolUse/Bash | Surfaces deprecation warnings from test output for triage |

Full reference:
<https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/site/docs/hooks/index.md>.

### Skills

Shared workflow skills, invoked as `/vergil:<name>`.

| Skill | Purpose |
|---|---|
| `epic-create` | USER agent: the run-once entry point for non-trivial work — brainstorm → spec pushback rounds → plan → plan pushback rounds → alignment rounds, create the epic and seed its bookend tasks |
| `epic-implement` | USER agent: drive an epic's tasks to their human gates, batching what needs the human |
| `epic-retrospective` | USER agent: the run-once terminal finishing gate — draft the epic's retrospective, whose docs PR closes the epic |
| `issue-implement` | USER agent: implement an issue (locally or on a cloud VM), validate to green, record the PR metadata, hand off to the human |
| `issue-deploy` | USER agent: run a `deployment` task — install/sync merged changes so they're usable, then record the outcome as a comment |
| `issue-validate` | USER agent: run a `validation` task — a live check whose acceptance is a recorded PASS/FAIL comment |
| `pr-watch` | USER agent: monitor the open PR through CI/review and reconcile feedback until it is mergeable |
| `deprecation-triage` | Triage deprecation warnings into tracking issues |
| `summarize` | Decision / operation / stream-of-consciousness summaries |
| `intake-capture` | Capture an uncurated idea/bug/to-do into the intake queue with `vrg-intake-create` |
| `intake-review` | Review the intake queue oldest first in batches of 4 and route each item with `vrg-intake-route` |
| `planning-review` | USER agent: rank the planning queue with the human and pick what to expand next with `epic-create` |
| `deferred-review` | Review the deferred queue in batches of 4 — re-check each item's revival conditions and recommend keep, refresh, revive, or drop |
| `migrate-repo` | Migrate a repo's existing open-issue backlog into the epic/task framework |
| `steering-audit` | Review the steering and settings files against the Claude config ownership model, one finding at a time; `steering-audit user` reviews the user-level files read-only |

Full reference:
<https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/site/docs/skills/index.md>.

### Agents

| Agent | Purpose |
|---|---|
| `bootstrap` | Session-start preflight: repository profile, branch state, standards reference, hook guard availability |

## Plugin namespace

All skills are namespaced under `vergil` (the plugin's `name`):

```text
/vergil:<skill-name>
```

Example: `/vergil:issue-implement`.

## Related repositories

- [`vergil-tooling`](https://github.com/vergil-project/vergil-tooling)
  — Python CLIs, bash validators, git hooks (consumed via PATH).
- [`vergil-containers`](https://github.com/vergil-project/vergil-containers)
  — Dev container images (`ghcr.io/vergil-project/dev-python`, `dev-go`,
  etc.) that `vrg-container-run` dispatches into.
- [`vergil-actions`](https://github.com/vergil-project/vergil-actions)
  — Shared GitHub Actions composite actions consumed by CI.

## Development and deployment

This section covers contributing to the plugin itself — how to set
up a working environment and ship a change. Distinct from the
[Install](#install) and [Update](#update) sections, which cover
how a *consumer* of the plugin uses it.

### Set up a worktree

Sessions on this repo always start at the project root
(`~/dev/github/vergil-claude-plugin/`), never inside a
worktree. Each in-flight issue gets its own worktree under
`.worktrees/issue-<N>-<slug>/` on a `feature/<N>-<slug>` branch.
The full procedure (issue resolution, sub-issue creation,
worktree+branch creation, agent prompt template) lives at
[`docs/development/starting-work-on-an-issue.md`](docs/development/starting-work-on-an-issue.md).

The worktree convention is enforced by the
`block-protected-branch-work` hook (raw `git commit` originating
from outside `.worktrees/*/` is denied) and by `vrg-commit`'s own
run-time protected-branch check.

### Ship a change

Under the Vergil 2.1 workflow, the agent prepares the change and
the **human** opens the PR:

1. The USER agent runs `/vergil:issue-implement <issue>` — implement,
   validate to green, then record the PR metadata via
   `vrg-pr-workflow report-ready`, which also pushes the branch.
2. **You** run `vrg-submit-pr` to open the PR (agents cannot).
3. Run the emitted `/vergil:pr-watch <PR_URL>` in the USER agent
   session to monitor the PR through CI and review and reconcile
   feedback until it is mergeable.

Auto-merge is disabled fleet-wide; you review and merge
feature/bugfix PRs manually.

### Cut a release

Releases are cut via `vrg-release`, a standalone CLI in
vergil-tooling. See the
[vergil-tooling documentation](https://github.com/vergil-project/vergil-tooling)
for usage.

### Develop against the source tree

When iterating on hooks or skills before release, load the plugin
directly from the source tree to avoid the marketplace
round-trip:

```bash
claude --plugin-dir /path/to/vergil-claude-plugin
```

This bypasses `~/.claude/plugins/cache/` and mounts the working
tree as the plugin source.

### Reporting issues

Open an issue at
<https://github.com/vergil-project/vergil-claude-plugin/issues>.
