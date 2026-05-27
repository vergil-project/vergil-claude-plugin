# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Memory management

Memory is allowed with human approval. The authoritative policy is in
the user's global `~/.claude/CLAUDE.md` — agents must propose memory
writes and suggest a destination (repo memory, global CLAUDE.md, or
plugin/skill issue) before writing. See that file for the full
workflow.

Available skills:
- `/vergil:memory-init` — set up or update the policy header
  in a project's `MEMORY.md`.
- `/vergil:memory-audit` — structured collaborative review
  of memory files.

## Parallel AI agent development

This repository supports running multiple Claude Code agents in parallel via
git worktrees. The convention keeps parallel agents' working trees isolated
while preserving shared project memory (which Claude Code derives from the
session's starting CWD).

**Canonical spec:**
[`vergil-tooling/docs/specs/worktree-convention.md`](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/worktree-convention.md)
— full rationale, trust model, failure modes, and memory-path implications.
The canonical text lives in `vergil-tooling`; this section is the local
on-ramp.

### Structure

```text
<project-root>/                              ← sessions ALWAYS start here
  .git/
  CLAUDE.md, …                               ← main worktree (usually `develop`)
  .worktrees/                                ← container for parallel worktrees
    issue-<N>-<short-slug>/                  ← worktree on feature/<N>-<short-slug>
    …
```

### Rules

1. **Sessions always start at the project root.**
   Never start Claude from inside `.worktrees/<name>/`. This keeps the
   memory-path slug stable and shared.
2. **Each parallel agent is assigned exactly one worktree.** The session
   prompt names the worktree (see Agent prompt contract below).
   - For Read / Edit / Write tools: use the worktree's absolute path.
   - For Bash commands that touch files: `cd` into the worktree first,
     or use absolute paths.
3. **The main worktree is read-only.** All edits flow through a worktree
   on a feature branch — the logical endpoint of the standing
   "no direct commits to develop" policy.
4. **One worktree per issue.** Don't stack in-flight issues. When a
   branch lands, remove the worktree before starting the next.
5. **Naming: `issue-<N>-<short-slug>`.** `<N>` is the GitHub issue
   number; `<short-slug>` is 2–4 kebab-case tokens.

### Agent prompt contract

When launching a parallel-agent session, use this template (fill in the
placeholders):

```text
You are working on issue #<N>: <issue title>.

Your worktree is: <project-root>/.worktrees/issue-<N>-<slug>/
Your branch is:   feature/<N>-<slug>

Rules for this session:
- Do all git operations from inside your worktree:
    cd <absolute-worktree-path> && vrg-git <command>
- For Read / Edit / Write tools, use the absolute worktree path.
- For Bash commands that touch files, cd into the worktree first
  or use absolute paths.
- Do not edit files at the project root. The main worktree is
  read-only — all changes flow through your worktree on your
  feature branch.
- When you need to run validation, run it from inside your worktree
  (vrg-container-run mounts the current directory).
```

All fields are required.

## Shell command policy

Use `vrg-git` instead of `git` for all git operations. Use `vrg-gh`
instead of `gh` for all GitHub CLI operations. These wrappers enforce
subcommand allowlists, flag deny lists, and credential selection.

Raw `git` and `gh` are denied by the permission model. If a command
is not available through the wrappers, explain the situation to the
human who can run it directly via `! <command>` in the prompt.

## Validation

```bash
vrg-container-run -- vrg-validate
```

This is the **only** validation command. Do not run individual linters,
formatters, or other tools outside of `vrg-validate`. If a tool is not
invoked by `vrg-validate`, it is not part of the validation pipeline.

## Starting work on an issue

When the user references a GitHub issue and wants work to begin on
it, follow the procedure in
[`docs/development/starting-work-on-an-issue.md`](docs/development/starting-work-on-an-issue.md).
It covers: resolving project / cross-repo / repo-local issue
inputs to a repo-local issue number, sub-issue creation when work
spans repos, existing-worktree and existing-remote-branch
detection, and the canonical `git worktree add` invocation that
honors the worktree convention.

This replaces the former `branch-workflow` skill. The substance is
the same; the format is now agent-instruction documentation rather
than a slash-command, since the procedure was rarely invoked
cold and is most useful as a reference at the moment work begins.

## Shell command policy — additional rules

**Do NOT use heredocs** (`<<EOF` / `<<'EOF'`) for multi-line arguments to CLI
tools such as `gh`, `git commit`, or `curl`. Always write multi-line content
to a temporary file and pass it via `--body-file` or `--file` instead.

## Project Overview

This is a Claude Code plugin that delivers shared hooks, skills, agents, and
commands to all managed repositories in the vergil-tooling ecosystem. It is
the behavioral counterpart to the `vergil-tooling` Python package (which
delivers runtime CLI tools via PATH).

**Project name**: vergil-claude-plugin

**Plugin namespace**: `vergil-tooling` (skills invoked as
`/vergil-tooling:<skill-name>`)

**Status**: Pre-release (0.x)

## Architecture

### Plugin Manifest (`.claude-plugin/plugin.json`)

Defines the plugin identity, version, and metadata. The `name` field
(`vergil-tooling`) determines the skill namespace prefix.

### Hooks (`hooks/hooks.json`)

PreToolUse and PostToolUse hooks that enforce guardrails mechanically rather
than relying on CLAUDE.md prose. These replace duplicated documentation rules
across all consuming repos.

### Skills (`skills/`)

Shared workflow skills migrated from `standards-and-conventions`. Each skill
is a directory containing a `SKILL.md` file with frontmatter and instructions.

### Agents (`agents/`)

Custom subagents including the bootstrap agent for session-start context
loading, PATH discovery, and preflight validation.

### Commands (`commands/`)

User-invokable slash commands (Markdown files).

## Two-Repo Model

| Repo                       | Delivers                  | Via    |
| -------------------------- | ------------------------- | ------ |
| `vergil-tooling`         | Python CLIs, bash, hooks  | PATH   |
| `vergil-claude-plugin`  | Skills, agents, commands  | Plugin |

These are complementary: the plugin tells Claude how to behave; PATH makes the
tools available to run.

## Branching and PR Workflow

- **Protected branches**: `main`, `develop` — no direct commits
- **Branch naming**: `feature/*`, `bugfix/*`, `hotfix/*`, `chore/*`, or
  `release/*` only
- **Feature/bugfix PRs** target `develop` with squash merge
- **Release PRs** target `main` with regular merge

## Commit and PR Scripts

**NEVER use raw `git commit`** — always use `vrg-commit`.
**NEVER use raw `gh pr create`** — always use `vrg-submit-pr`.

## Refreshing the plugin locally

When the user asks how to refresh / update / reinstall this plugin
after a new release, the canonical sequence is in the README's
[Update section](README.md#update). Do **not** guess or improvise —
the sequence is two steps (`marketplace update` → `reload-plugins`)
and both are required.

## Development and deployment of this repo

Working on the plugin itself (vs. consuming it) has its own
canonical procedure. See
[`README.md` → Development and deployment](README.md#development-and-deployment)
for: worktree setup and the `pr-workflow` skill for shipping a
change. Releases are cut via `vrg-publish` (a standalone CLI in
vergil-tooling).
