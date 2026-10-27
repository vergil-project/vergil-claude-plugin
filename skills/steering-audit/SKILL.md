---
name: steering-audit
description: Review the Claude Code steering and settings files against the Claude config ownership model, one finding at a time with the human. Use when the human asks to "audit steering files", "review CLAUDE.md", "review Claude settings", "steering audit", or wants the periodic (at least quarterly) steering review, or after a Claude Code release that changes settings or instruction-file behavior. Repo scope (the default) reviews the repo's CLAUDE.md, .claude/rules/, .claude/settings.json, any AGENTS.md and the local-settings copies, and applies edits through the normal worktree and PR flow. `steering-audit user` reviews ~/.claude/CLAUDE.md and ~/.claude/settings.json read-only — it writes no file and records nothing publicly. Re-verifies the model's platform facts, runs mechanical checks, runs a findings-only /paad:pushback on each steering file, then walks the findings one at a time.
---

# Steering audit

## Overview

The **ownership model** says which file owns each Claude Code setting and
instruction in a Vergil-managed repo:
<https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/claude-config-ownership.md>.
Read it at the start of every run. It is the rule set this skill checks
against: the placement rule, the ownership table, the platform facts, the
local-settings rule and the recurring-review section.

The nightly config audit (`vrg-github-repo-config audit`) covers what a machine
can check. This skill is the **judgment** layer: it re-verifies the model's
platform facts, runs its own mechanical checks, has `/paad:pushback` review
each steering file, then walks every finding with the human, one at a time.
The human decides every disposition.

**When to run it:** at least quarterly, and whenever a Claude Code release
changes settings or instruction-file behavior.

## Scopes

| Invocation | Scope | Files |
| --- | --- | --- |
| `/vergil:steering-audit` (or `repo`) | **repo** (default) | the current repo's `CLAUDE.md`, `.claude/rules/`, `.claude/settings.json`, any `AGENTS.md`, and every `.claude/settings.local.json` copy Claude Code may load |
| `/vergil:steering-audit user` | **user** | `~/.claude/CLAUDE.md` and `~/.claude/settings.json` |

Any other argument: stop and ask which scope was meant.

### User scope is read-only and interactive only

The user files have no change control, so in user scope:

- **The skill writes no file of any kind**: no edits, no drafts, no reports, no
  notes, no temp files, in any directory. All feedback stays in the session.
- **The human decides every change and makes it on the host.** The agent may
  show proposed wording in the conversation; it never applies it.
- **Findings never go to GitHub or intake** — no issue, comment, PR body,
  report-ready note or commit carries the files' content or any finding. The
  only public record is the date and counts (step 6). The names of sections
  that stay are never recorded; only the names of sections that move to a
  public home may be.
- It runs **once per cycle**, not once per repo.
- On an agent VM, `~/.claude/` is a copy of the host's files. Tell the human
  which machine was read; changes are still made on the host.

### No memory access

This skill does not read, write or depend on memory files.

## Preflight

1. **Repo scope:** confirm you are the **USER** agent (`vrg-whoami --mode` is
   `user`) — repo-scope dispositions file intake items and open a worktree.
   Run from the project root of a repo with a `vergil.toml`. Note whether it is
   in the managed fleet (pins `vergil = "v2.1"` and its
   `.github/workflows/ops.yml` calls `ops-github-config`); the template and
   audit rules apply in full only there.
2. **User scope:** no identity requirement. Confirm the human is present: this
   scope is interactive only.
3. Fetch and read the ownership model page (link above). If it cannot be read,
   stop and say so; do not audit from memory.

## Workflow

### 1. Inventory

Report what exists before judging anything.

**Repo scope:**

- `CLAUDE.md` and its line count, counted as `len(text.splitlines())`:
  `awk 'END { print NR }' CLAUDE.md` (counts a final line without a newline;
  a trailing newline adds nothing). Note where the managed template region
  starts and ends.
- `.claude/rules/*.md`, each with its `paths:` scope.
- `.claude/settings.json`.
- Any `AGENTS.md`, anywhere in the tree (`vrg-git ls-files '*AGENTS.md'`).
- Every `.claude/settings.local.json` copy Claude Code may load: the **main
  checkout's root** (the parent of `vrg-git rev-parse --path-format=absolute
  --git-common-dir`), the current worktree's root, and the invoking directory
  and its ancestors up to the worktree root. For each: absent, exactly `{}`,
  or non-empty. Do not quote a non-empty copy's content into any public
  record.

**User scope:** `~/.claude/CLAUDE.md` (with its line count and section list)
and `~/.claude/settings.json` (its top-level keys).

### 2. Re-verify the platform facts

The model page lists its verification date, the docs pages it cites, and the
latest `CHANGELOG.md` entry at verification. For each numbered platform fact:

- Fetch the cited page and check the fact still holds as written.
- Read the Claude Code `CHANGELOG.md` entries newer than the one the page
  names, for any change to settings, precedence, permissions, hooks, plugin
  loading, marketplaces, attribution or instruction files (`CLAUDE.md`,
  `.claude/rules/`, `AGENTS.md`).

**Report any drift first**, before every other finding: the fact, what the
page now says, and the URL. A page that cannot be fetched is reported as
**unverified**, never as "no drift". Drift means the model page needs updating
in vergil-tooling: in repo scope it is a finding like any other; in user scope
tell the human and leave the filing to them (step 5).

### 3. Mechanical checks

**Repo scope only:** run `vrg-github-repo-config audit` from the repo root and
report every failure and warning it prints. (It audits the repo as published on
GitHub, so local unpushed changes are not reflected.) A non-zero exit that is
not an audit failure is a tool failure: report it, do not skip it.

**Both scopes**, on each steering file:

- **Paths exist.** Every file or directory path the file names exists —
  repo-relative paths from the repo root, `~/` paths in the home directory.
  URLs are not paths and are skipped. A path with a placeholder (`<N>`,
  `<slug>`) or a glob passes when something matches its shape.
- **Commands resolve.** Every command the file tells an agent to run resolves:
  the executable is on `PATH` (`command -v <cmd>`), and a named subcommand or
  flag appears in its `--help`. A named skill or slash command
  (`/vergil:<name>`, `paad:<name>`) exists in the loaded plugins.
- **Line count.** A repo `CLAUDE.md` over 200 lines is a finding. The user
  `CLAUDE.md` has no fixed budget but is held to "minimal".
- **Ownership rules** from the model's ownership table, for example:
  - repo `.claude/settings.json`: equals the managed template after JSON
    parsing; no `extraKnownMarketplaces`; no repo-specific key;
  - every loadable `.claude/settings.local.json`: absent or exactly `{}`;
  - no `AGENTS.md`;
  - repo `CLAUDE.md`: no restated fleet policy outside the template region;
    catalogues and architecture detail belong in site docs (linked); an
    instruction that matters for only part of the repo belongs in a
    path-scoped `.claude/rules/` file;
  - user `CLAUDE.md`: only preferences that are genuinely personal and have
    no change-controlled home — engineering or workflow policy is a finding;
  - user `settings.json`: plugin enablement and marketplaces for all plugins,
    the agent-VM permission mode, personal model and UI settings; nothing that
    works on only one OS (the same file runs on the macOS host and Linux VMs).
    The `bypassPermissions` mode there is the model's accepted exception —
    do not flag it.

### 4. Review each steering file with `/paad:pushback`

Steering files are the Markdown instruction files: `CLAUDE.md` and each
`.claude/rules/*.md` (repo scope), or `~/.claude/CLAUDE.md` (user scope).
Settings files are JSON and are covered by step 3, not pushback. An
`AGENTS.md` is not reviewed: the model removes it, so it is already a
finding.

Run pushback once per steering file, with the path and these directives
appended to its arguments **exactly as written**:

```text
<path> — collect the findings and return them; do not present them one at a time; do not edit the reviewed file; write no report and no other file.
```

Pushback treats the steering file as the document under review. Its findings
come back to this skill; they are not walked inside pushback.

After each run, confirm nothing was written: in repo scope `vrg-git status
--porcelain` shows no new or changed file; in both scopes no `paad/` report or
`paad/security/` file appeared in the working directory. If anything was
written, stop, tell the human exactly what and where, and ask before removing
it — never remove it silently. In user scope this is a breach of the
no-file rule and must be reported as such.

### 5. Walk the findings one at a time

Collect everything: drift (step 2) first, then mechanical (step 3), then
pushback (step 4). Merge duplicates. **Verify each finding** against the file
before presenting it; drop any that does not hold, and tell the human how many
were dropped and why.

Present **one finding at a time**: the file and location, the evidence, the
rule from the ownership model it touches, and one **suggested** disposition with
the reason. Then **wait for the human's decision** before the next one.

| Disposition | Meaning |
| --- | --- |
| **keep** | No change; the human gives the reason. |
| **edit** | Change the text in place. |
| **move** | Move it to a named managed home: the `CLAUDE.md` template region (vergil-tooling `data/claude_md_consumer.md`), the plugin (a skill or hook in vergil-claude-plugin), repo docs, or a `.claude/rules/` file. Name the home. |
| **delete** | Remove it. |
| **file to intake** | *Repo scope only.* Capture it with `/vergil:intake-capture` for later work. |

In repo scope, a finding that would help an attacker never goes to the public
intake queue: record it with `vrg-security-record` instead. In user scope
nothing is filed anywhere, drift included — the human may capture a
non-personal item (such as platform drift) themselves.

The human can stop at any point; unwalked findings are simply not applied.

### 6. Apply and record

**Repo scope:** edits go through the normal flow — one task issue, a worktree
on its feature branch, `vrg-container-run -- vrg-validate` green, and
`vrg-pr-workflow report-ready` (see `issue-implement`). If the run is already
part of a task (such as a steering sweep), use that task; otherwise ask the
human which issue the edits belong to. A **move** whose destination is another
repo (the template, the plugin) is two changes: remove it here, and capture
the addition there to intake — never edit another repo from this worktree.
Finish with a summary: the counts per disposition, the intake and PR links.

**User scope:** apply nothing. Give the human the list of agreed changes in
the session, to make on the host. The public record, if the human wants one,
is only the date and counts — for example
`steering-audit user: reviewed on <date>; <n> findings: <k> keep, <e> edit, <m> move, <d> delete` —
plus the names of any sections that move to a public home. The skill posts it
nowhere.

## Not part of this skill

`/doctor prompt-audit` (the bundled instruction-file audit) is an optional
check the human can run by hand; this skill does not call it (whether it
should: vergil-project/.github#604).
