# vergil-claude-plugin

Claude Code plugin for the vergil-tooling ecosystem. Delivers
hooks, skills, and agents that enforce the fleet workflow mechanically
in every Claude Code session.

## Table of Contents

- [What this plugin does](#what-this-plugin-does)
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

## Install

**Recommended install path** for consuming repositories is the full
walkthrough documented in vergil-tooling:

- Quickstart:
  <https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/getting-started.md>
- Detailed walkthrough with rationale:
  <https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/consuming-repo-setup.md>

The short version: add this to your repo's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "vergil-marketplace": {
      "source": {
        "source": "github",
        "repo": "vergil-project/vergil-claude-plugin",
        "ref": "main"
      }
    }
  },
  "enabledPlugins": {
    "vergil@vergil-marketplace": true
  }
}
```

Commit that file. Claude Code discovers and enables the plugin on
session start. The `"ref": "main"` pins the marketplace to the
**release** branch, so `marketplace update` tracks the latest
released version (not the `develop` bleeding edge). The plugin loads
directly from that checkout — there is no separate clone to fail.

**Prerequisite:** this plugin's commands and skills shell out to
`vrg-commit`, `vrg-submit-pr`, `vrg-await`, and friends from
the vergil-tooling Python package. Install those on your host
PATH first — see the Getting Started guide above.

## Update

After a new release ships, refresh the local install with this
two-step sequence:

```text
/plugin marketplace update vergil-marketplace
/reload-plugins
```

What each step does:

1. **`/plugin marketplace update <marketplace>`** — refreshes the
   marketplace index and downloads the new plugin version into the
   local cache at `~/.claude/plugins/cache/<plugin-id>/<version>/`.
   The previous version stays on disk for 7 days as a grace window
   for concurrent sessions, then is removed automatically.
2. **`/reload-plugins`** — applies the new skills / hooks / agents
   to the **current** Claude Code session without restarting.
   Without this, the running session keeps using the old in-memory
   plugin state.

### Verify the update

```bash
ls -1 ~/.claude/plugins/cache/vergil-marketplace/vergil/
```

You should see one directory per cached version. The newest
version should match the latest tag on
[GitHub Releases](https://github.com/vergil-project/vergil-claude-plugin/releases).

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
ad-hoc git work in unrelated repositories. See the
[hooks reference](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/site/docs/hooks/index.md#managed-repo-gating)
for the rationale.

| Hook | Matcher | Purpose |
|---|---|---|
| `block-raw-git-commit` | PreToolUse/Bash | Redirects raw `git commit` to `vrg-commit` |
| `block-raw-gh-pr-create` | PreToolUse/Bash | Redirects raw `gh pr create` to `vrg-submit-pr` |
| `block-protected-branch-work` | PreToolUse/Bash | Blocks commits from outside `.worktrees/*` on repos that adopt the worktree convention; otherwise blocks commits on `develop`/`main` |
| `block-heredoc` | PreToolUse/Bash | Blocks `<<EOF` in CLI args (use `--body-file` or `$(cat <file>)`) |
| `block-associative-arrays` | PreToolUse/Bash | Blocks bash 4+ associative arrays — host scripts must run on macOS bash 3.2 |
| `enforce-host-container-split` | PreToolUse/Bash | Denies wrapping host-only tools in `vrg-container-run`; warns on bare container-only tools |
| `block-autoclose-linkage` | PreToolUse/Bash | Blocks `--linkage Fixes/Closes/Resolves` in `vrg-submit-pr` — use `Ref` instead |
| `block-agent-merge` | PreToolUse/Bash | Unconditionally blocks `gh pr merge` / `gh pr review --approve` — merging is the human's Phase-6 action |
| `block-github-contents-api` | PreToolUse/Bash | Blocks write-method `gh api` calls to the Contents API — file changes go through the local workflow |
| `block-worktree-bypass-write` | PreToolUse/Write\|Edit | Blocks edits to the main worktree when the worktree convention is active |
| `guard-audit-writes` | PreToolUse/Write\|Edit\|NotebookEdit | AUDIT identity may write only `.vergil/audit-*` and `build/` — soft gate on the audit's read-only discipline |
| `detect-deprecation-warnings` | PostToolUse/Bash | Surfaces deprecation warnings from test output for triage |

Full reference:
<https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/site/docs/hooks/index.md>.

### Skills

Shared workflow skills, invoked as `/vergil:<name>`.

| Skill | Purpose |
|---|---|
| `issue-implement` | USER agent: implement an issue, validate to green, drive the PR-workflow oracle, hand off to the human (local audit pair opt-in) |
| `issue-audit` | AUDIT agent: review the change delta read-only via the oracle loop and report verdicts (opt-in; experimental) |
| `pr-watch` | Post-PR loop — monitor/reconcile (USER) or re-review and gate (AUDIT) |
| `deprecation-triage` | Triage deprecation warnings into tracking issues |
| `summarize` | Decision / operation / stream-of-consciousness summaries |
| `handoff` | Session-to-session continuity (capture/resume) |
| `memory-audit` | Collaborative review of memory files |
| `memory-init` | Initialize the memory directory with the policy header |

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
`block-protected-branch-work` hook: commits originating from
outside `.worktrees/*/` are denied.

### Ship a change

Under the Vergil 2.1 workflow, the agent prepares the change and
the **human** opens the PR:

1. The USER agent runs `/vergil:issue-implement <issue>` — implement,
   validate to green, then drive the `vrg-pr-workflow` oracle to
   record the PR metadata.
2. **You** run `vrg-submit-pr` to open the PR (agents cannot).
3. Paste the emitted `/vergil:pr-watch <PR_URL>` into both the USER
   and AUDIT agent sessions for the post-PR loop; the AUDIT identity
   gates merge via the `vergil-audit/approved` check.

Auto-merge is disabled fleet-wide; you review and merge
feature/bugfix PRs manually.

> **Transition note.** This flow requires `vergil-tooling` 2.1
> installed site-wide. Until then, submit changes manually the 2.0
> way; the 2.1 skills are authored but not yet wired into daily dev.

### Cut a release

Releases are cut via `vrg-publish`, a standalone CLI in
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
