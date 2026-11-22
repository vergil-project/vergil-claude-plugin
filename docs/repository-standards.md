# Standard Tooling Plugin Repository Standards

## Table of Contents

- [Post-merge async workflows](#post-merge-async-workflows)
- [External tooling dependencies](#external-tooling-dependencies)
- [CI gates](#ci-gates)
- [Commit and PR scripts](#commit-and-pr-scripts)
- [Local deviations](#local-deviations)

## Post-merge async workflows

Workflows triggered by a merge to `develop` that must be verified
as part of PR finalization. A PR is not "done" until every listed
workflow has reached `conclusion: success` for the merge commit.

| Workflow    | Trigger          | What it does                          |
| ----------- | ---------------- | ------------------------------------- |
| `docs.yml`  | push to `develop`| Rebuild MkDocs site, deploy dev alias |

Repos with additional async post-merge workflows (e.g.,
`docker-publish.yml` in `vergil-tooling`) add them to this
table. The `pr-watch` skill (post-PR loop) reads this section to
determine which post-merge workflows to verify.

## External tooling dependencies

- markdownlint (markdownlint-cli)

## CI gates

Hard gates (required status checks on `develop`):

- Standards compliance:
  - Repository profile validation (`repo-profile`)
  - Markdownlint (`markdown-standards`)
  - Commit message lint (CI validator)
  - Issue linkage validation (`pr-issue-linkage`)

Local hard gates (pre-commit hooks):

- Branch naming enforcement: branching-model-aware prefix validation.
- Commit message lint: Conventional Commits required.

## Commit and PR scripts

AI agents **must** use the wrapper scripts for commits and PR submission.
Do not construct commit messages or PR bodies manually.

### Committing

```bash
vrg-commit \
  --type TYPE --scope SCOPE --message MESSAGE \
  [--body BODY]
```

- `--type` (required): `feat|fix|docs|style|refactor|test|chore|ci|build|revert`
- `--scope` (required): conventional commit scope
- `--message` (required): commit description
- `--body` (optional): detailed commit body

The git hooks validate the result. Commits carry no AI co-author
trailer; Claude Code attribution is turned off in
`.claude/settings.json` (vergil-project/vergil-tooling#3200).

### Submitting PRs

```bash
vrg-submit-pr \
  --issue NUMBER --title TEXT --summary TEXT \
  [--linkage KEYWORD] [--notes TEXT] [--dry-run] \
  [--release]
```

PR submission is a human action: an agent hands off with
`vrg-pr-workflow report-ready`, and the human runs `vrg-submit-pr`,
which reads the recorded state. The flags above are its direct
(emergency) CLI mode.

- `--issue` (required): GitHub issue number (just the number)
- `--title` (required): PR title
- `--summary` (required): one-line PR summary
- `--linkage` (optional, default: `Ref`): `Ref` or `Closes`; `Fixes`
  and `Resolves` are forbidden. The linked issue must be a **task, not
  an epic** (`vrg-submit-pr` rejects epic links). For a task under an
  epic, `vrg-submit-pr` selects `Closes` itself, so the PR closes the
  task on merge; a legacy issue (no epic parent) keeps the requested
  keyword, and a `Ref` link leaves it open for manual close. See the
  epic/task convention in `CLAUDE.md`.
- `--notes` (optional): additional notes
- `--dry-run` (optional): print generated PR without executing
- `--release` (optional): after a fully successful finalize, cut a
  release with `vrg-release`, whose install is part of every release

`vrg-submit-pr` opens PRs against `develop` only (releases go through
`vrg-release`) and turns auto-merge on itself, pinned to the pushed
head: squash for a single-issue PR, rebase for a batch PR. GitHub then
merges the PR once its required checks pass. By default it then runs
`vrg-finalize-pr`, which waits for the PR to merge and never merges it
itself. Once a PR has merged, finalize's settle phase first closes any
issue the PR closes that GitHub left open (only GitHub's closing
references, so a `Ref` link is never touched), then syncs, cleans up,
provisions and validates `develop` under the checkout lock, and reports
its CD run. Epic rollup is event-driven (`vrg-epic-rollup`), not part
of finalize.

## Local deviations

- No primary language — this repo contains only Markdown, JSON, and shell
  scripts for Claude Code plugin configuration.
- No language-specific CI (no ruff, mypy, pytest, etc.).
