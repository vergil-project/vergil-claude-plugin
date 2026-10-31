# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

<!-- vergil:template:claude-md:begin -->
## Memory

Never write, edit or delete memory files without explicit human approval.
Propose the entry and where it belongs first, then wait for the decision.

## Worktrees

- Sessions always start at the project root, never inside `.worktrees/`.
- One worktree per issue: `.worktrees/issue-<N>-<slug>/` on branch
  `feature/<N>-<slug>`. Remove it once its branch lands.
- The main worktree is read-only, bar ignored `build/` scratch; every edit goes through a worktree.
- Read, Edit and Write use the worktree's absolute path. Bash commands `cd`
  into the worktree first or use absolute paths.
- The full convention: <https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/worktree-convention.md>.
- Brief each parallel sub-agent with its [Agent prompt contract](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/worktree-convention.md#agent-prompt-contract).

## Git and GitHub

Use `vrg-git` and `vrg-gh` only; the hook guard blocks raw `git` and `gh`. If a
command is not available through the wrappers, explain why and ask the human to
run it with `! <command>` in the prompt.

## Validation

`vrg-container-run -- vrg-validate` is the only validation command. Don't run
linters, formatters or tests outside it; a tool it doesn't invoke is not part
of the pipeline.

## PR handoff

- Agents never run `vrg-submit-pr`. Submitting, merging and finalizing a PR are
  human actions.
- Hand off with `vrg-pr-workflow report-ready --issue <N> --title --summary
  --notes`. It pushes the branch itself. Leave `--linkage` at its default (`Ref`).
- A delta touching `.github/workflows/**` makes GitHub refuse the agent push.
  That is expected: report-ready records the state anyway and the human's
  `vrg-submit-pr` pushes the branch.
- After report-ready the branch is frozen: no new commits and no push that
  advances it; more work is a new follow-up issue. Re-running report-ready to
  fix the prose is allowed. `vrg-pr-workflow unfreeze` is the only way to lift it.
- The report-ready title, summary and notes are public (the relay ref is
  world-readable): never put secrets in them.

## Local settings

`.claude/settings.local.json` must stay absent or exactly `{}`; the agent tools
refuse otherwise. See the [ownership model](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/claude-config-ownership.md).

## Engineering principles

- Correctness over cost over speed. Never ship known-broken code with a
  follow-up fix; if something is wrong, fix it now.
- No silent failures: no swallowed exceptions, no `except: return ""`, no
  fallbacks that hide errors. A failure hidden in code becomes a hallucination
  at the AI layer.

## paad

paad usage policy and deviations:
<https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/paad-policy.md>.
<!-- vergil:template:claude-md:end -->

## Validation in this repo

The repo's custom validator, `scripts/bin/validate-custom` (which runs
the hook test suites under `hooks/tests/`), is part of the `vrg-validate`
pipeline locally and also runs in PR CI as the `quality / custom` job (from
vergil-actions v2.1.58). Its log is kept as `quality-custom.log` in the
`quality / evidence` artifact.

## Project overview

This is a Claude Code plugin that delivers shared hooks, skills, agents, and
commands to all managed repositories in the vergil-tooling ecosystem. It is
the behavioral counterpart to the `vergil-tooling` Python package (which
delivers runtime CLI tools via PATH). The plugin namespace is `vergil`
(skills are invoked as `/vergil:<skill-name>`). Install, update and component
details are in [`README.md`](README.md).

## Working on this repo

- Start work on an issue with `/vergil:issue-implement`.
- The ship-a-change flow and worktree setup are in
  [`README.md` → Development and deployment](README.md#development-and-deployment).
  Releases are cut with `vrg-release` (vergil-tooling).
- To refresh a local install after a release, follow the README's
  [Update section](README.md#update) exactly; don't improvise the sequence.
- Agents follow the
  [execution doctrine](docs/site/docs/skills/index.md#execution-doctrine--front-loaded-judgment-trusted-execution)
  (Front-Loaded Judgment, Trusted Execution).

## Architecture

- `.claude-plugin/plugin.json` — plugin identity and version; its `name`
  (`vergil`) sets the skill namespace. `marketplace.json` publishes it.
- `hooks/hooks.json` — PreToolUse and PostToolUse hooks that enforce
  guardrails mechanically; scripts in `hooks/scripts/`, tests in
  `hooks/tests/`.
- `skills/` — one directory per workflow skill, each with a `SKILL.md`.
- `agents/` — custom subagents (the session `bootstrap` agent).
- `commands/` — user-invokable slash commands (Markdown files); none ship
  today.

## Two-Repo Model

| Repo | Delivers | Via |
| --- | --- | --- |
| `vergil-tooling` | Python CLIs, bash, hooks | PATH |
| `vergil-claude-plugin` | Hooks, skills, agents, commands | Plugin |

These are complementary: the plugin tells Claude how to behave; PATH makes the
tools available to run.

## Plugin distribution model

The plugin ships through a **single channel**: every consumer (the
`vergil-project` repos, the host and every agent VM) registers
`vergil-marketplace@v2.1`, the floating `v2.1` rolling tag. No per-version
pinning, no dev marketplace. A release makes a skill/hook live for everyone by
moving `v2.1` forward to the new `v2.1.Z`; a rollback (`vrg-promote`, a human
act) moves it back to an earlier one. `main` stays the release branch, but
consumers follow the tag. To run unreleased `develop` behavior, load the source
tree with `claude --plugin-dir` or tell the agent to read the file directly.
Rationale: `vergil-project/.github`
[epic #760's spec](https://github.com/vergil-project/.github/blob/develop/epics/760-plugin-tag-distribution/spec.md),
which supersedes epic #45's tag decision.
