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

The script resolves the correct `Co-Authored-By` identity from
`vergil.toml` and the git hooks validate the result.

### Submitting PRs

```bash
vrg-submit-pr \
  --issue NUMBER --title TEXT --summary TEXT \
  [--linkage KEYWORD] [--notes TEXT] [--dry-run]
```

- `--issue` (required): GitHub issue number (just the number)
- `--title` (required): PR title
- `--summary` (required): one-line PR summary
- `--linkage` (optional, default: `Ref`): **always use `Ref`**.
  `Fixes`, `Closes`, and `Resolves` are forbidden — they auto-close
  the issue at merge time, bypassing finalization. Issues are closed
  explicitly after `vrg-finalize-repo` succeeds.
- `--notes` (optional): additional notes
- `--dry-run` (optional): print generated PR without executing

The script detects the target branch and merge strategy automatically.

## Local deviations

- No primary language — this repo contains only Markdown, JSON, and shell
  scripts for Claude Code plugin configuration.
- No language-specific CI (no ruff, mypy, pytest, etc.).
