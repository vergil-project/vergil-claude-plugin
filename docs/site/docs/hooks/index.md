# Hooks

The plugin provides PreToolUse and PostToolUse hooks that enforce
workflow guardrails mechanically. These replace duplicated documentation
rules across all consuming repos — rules that humans and agents
alike routinely drift from when enforcement is prose-only.

> **Looking for the overall workflow?** See
> [`vergil-tooling` → Git Workflow](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/git-workflow.md)
> for the big-picture guide covering branching, commit/PR/finalize
> cycle, worktrees, and how these plugin hooks compose with the
> pre-commit git hook. This page is the reference for the plugin's
> hooks specifically; the pre-commit git hook is documented in
> [`vergil-tooling` → Git Hooks and Validation](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/git-hooks-and-validation.md).

Each entry below covers what the hook catches, why it exists, and how
to achieve the intent correctly when the hook blocks you.

## Managed-repo gating

Every hook below **except `block-heredoc`** is gated on a
managed-repo check. A repo is "managed" when `vergil.toml`
exists at the repo root.

When the marker is not present, the gated hooks short-circuit to a
no-op so the plugin doesn't interfere with ad-hoc git work in
unrelated repositories. Detection is a pure-shell walk up from the
bash session's CWD looking for the marker, terminating at a
`.git` boundary or the filesystem root. No `git` subprocess; the
gate's overhead is a handful of `stat()` calls.

`block-heredoc` is intentionally **not** gated — heredoc syntax in
CLI invocations breaks unpredictably regardless of which repo
you're in, so the rule is universal.

See [issue #87](https://github.com/vergil-project/vergil-claude-plugin/issues/87)
for the rationale.

## Command matching: quote-stripping

Every Bash-command matcher below (except `block-heredoc`) tests
tool names against a **quote-stripped** copy of the command string:
single- and double-quoted spans are replaced with `""` first, then
the tool name must appear in command position
(`(^|[;&|({]\s*)<tool>(\s|$)`, applied per line).

This is why a commit body or issue body that *mentions* a blocked
command — even at the start of a line inside a multi-line `--body`
argument — does not trigger a false deny, while the same text in
command position still does.

`block-heredoc` matches raw text: its regex must see the quoted
delimiter in `<<'EOF'`, which stripping would remove.

Canonical rule, accepted gaps, and the shared test vectors:
[`docs/specs/2026-06-05-450-command-matcher-quoting-design.md`](https://github.com/vergil-project/vergil-claude-plugin/blob/develop/docs/specs/2026-06-05-450-command-matcher-quoting-design.md).
See [issue #450](https://github.com/vergil-project/vergil-claude-plugin/issues/450).

## PreToolUse Hooks — Bash

### block-raw-git-commit

**What.** Denies Bash tool invocations that call `git commit` (or
pipe-chained equivalents).

**Why.** `vrg-commit` constructs standards-compliant conventional
commit messages with the co-author trailer resolved from
`vergil.toml`. Hand-written `git commit -m`
invocations drift from the commit-message standard over time; raw
commits also bypass the co-author resolution entirely.

**Alternative.** Use
[`vrg-commit`](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/reference/dev/commit.md)
with the appropriate `--type`, `--scope`, `--message`, `--body`, and
`--agent` flags.

### block-raw-gh-pr-create

**What.** Denies Bash tool invocations that call `gh pr create`.

**Why.** `vrg-submit-pr` builds standards-compliant PR bodies with
proper issue linkage keywords (`Fixes`, `Closes`, `Resolves`, `Ref`)
that the `pr-issue-linkage` CI validator requires. Manual `gh pr
create` commands routinely ship without linkage and fail CI on the
first try.

**Alternative.** Use
[`vrg-submit-pr`](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/reference/dev/submit-pr.md)
with `--issue`, `--summary`, `--linkage`, and `--notes` flags.

### block-protected-branch-work

**What.** Denies Bash tool invocations that run `git commit` or
`vrg-commit` when the effective working directory falls outside the
worktree convention's allowed locations.

**Why.** Behavior depends on whether the target repo has adopted the
[worktree convention](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/worktree-convention.md).
The hook detects adoption by looking for a `.worktrees/` line in the
repo's `.gitignore`. On adopted repos, commits must originate from
inside `.worktrees/<name>/`; the main tree is read-only. On
non-adopted repos, the hook falls back to the legacy behavior of
blocking commits on `main` or `develop` regardless of directory.

**Alternative.** On adopted repos: create a worktree with
`git worktree add .worktrees/issue-N-<slug> -b feature/N-<slug>
origin/develop` and run all edits + commits from inside that
directory. On non-adopted repos: create and check out a feature
branch with a name matching the repo's `branching_model` prefixes.

This hook complements the pre-commit git hook's
[protected-branch check](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/git-hooks-and-validation.md#pre-commit)
— this one catches the agent-tool invocation early; the pre-commit
hook catches every `git commit` regardless of how it was invoked.

### block-heredoc

**What.** Denies Bash tool invocations that contain heredoc syntax
(`<<EOF`, `<<'EOF'`, etc.) in CLI arguments.

**Why.** Heredocs routinely produce incorrect escaping when passed
through multiple shell layers (agent → Bash tool → subprocess →
CLI). Several CLIs (`gh`, `git commit`, `curl`) silently succeed
with malformed content, producing invalid commit messages, broken
PR bodies, or corrupt JSON bodies. Writing to a file and passing it
via `--body-file` / `--file` / `$(cat <path>)` avoids the entire
class of bug.

**Alternative.** Write the multi-line content to a temp file and
reference it: `--body-file /tmp/body.txt` or
`--body "$(cat /tmp/body.txt)"`.

### block-associative-arrays

**What.** Denies Bash tool invocations that use bash 4+ associative
arrays (`declare -A`, `typeset -A`).

**Why.** The hook scripts and `vrg-container-run` dispatcher themselves
run on the host shell, which on macOS is bash 3.2 (Apple has not
shipped a newer bash since the GPL license change). Associative
arrays silently fail on macOS bash 3.2, producing hard-to-debug
behavior. Inside the dev container bash is modern, but the scripts
that *launch* the container cannot assume that environment.

**Alternative.** Use parallel indexed arrays, or switch to awk/jq
for key-value lookups. If you genuinely need associative arrays,
the code belongs inside the container, not in host scripts.

### enforce-host-container-split

**What.** Checks the routing of every `st-*`, `gh`, `git`, and
language-toolchain command against the canonical host-vs-container
split from
[#96](https://github.com/vergil-project/vergil-claude-plugin/issues/96).

- **Denies** wrapping a host-only tool in `vrg-container-run --`
  (e.g., `vrg-container-run -- gh issue list`). The host tool needs
  SSH-agent, host git config, or host `gh` auth — the container
  can't satisfy those.
- **Warns** (via `additionalContext`, not deny) when a
  container-only tool is invoked directly — whether bare
  (e.g., `ruff check .`) or wrapped in `vrg-container-run --`.
  Both bypass the canonical validation entry point. The correct
  command is `vrg-container-run -- vrg-validate`, which handles
  all tool routing internally.

The canonical tool lists live in
`hooks/scripts/lib/host-container-tools.sh` so the same source of
truth powers both the hook and any future docs/lint.

**Why.** The drift that produced #96 — 47 days of agents silently
wrapping host tools in the container — was caused by documentation
being the only enforcement mechanism. Issue
[#168](https://github.com/vergil-project/vergil-claude-plugin/issues/168)
extended this to also catch agents bypassing the canonical
validation entry point by calling linters directly (even correctly
wrapped in `vrg-container-run`). The agent should never invoke
individual linters — `vrg-validate` handles tool routing internally.

**Alternative.** For denied commands: invoke the host tool
directly (drop the `vrg-container-run --` prefix). For warned
commands: use `vrg-container-run -- vrg-validate` instead of invoking
individual linters.

### block-autoclose-linkage

**What.** Denies `vrg-submit-pr` invocations that pass `--linkage
Fixes`, `--linkage Closes`, or `--linkage Resolves`.

**Why.** These keywords auto-close the linked issue when the PR
merges. Under the 2.1 workflow issues are closed **explicitly by
the human after PR finalization** (`vrg-finalize-pr`) — an issue
closed automatically at merge time signals "done" before the human
has confirmed the work cycle is complete. Closing is deliberately
manual today; agents have closed issues incorrectly, so no
automation owns it (a future close-analysis agent may).

**Alternative.** Use `--linkage Ref`. Issue closing is the human's
post-finalization action — not the agent's.

### block-agent-merge

**What.** Denies Bash tool invocations that call `gh pr merge`,
`gh pr review --approve`, or the equivalent `gh api` calls —
unconditionally.

**Why.** Under the 2.1 workflow agents have no merge path at all:
the per-VM GitHub App credentials cannot merge, and merging is the
human's Phase-6 action (`vrg-finalize-pr`). Skill prose saying "do
not merge" is advisory; agents rationalize past it. This hook makes
the rule mechanical — an ergonomic fast-fail on top of the hard
credential gate. The deny applies to **all identities** and all
branches, release PRs included; the pre-2.1 release-branch
allow-list (delegated to a `vrg-check-pr-merge` tool that was never
shipped) was removed in [#441](https://github.com/vergil-project/vergil-claude-plugin/issues/441).
See [#162](https://github.com/vergil-project/vergil-claude-plugin/issues/162)
for the original motivating incident.

**Alternative.** Hand the PR URL to the human, who merges and
finalizes via `vrg-finalize-pr`.

### block-github-contents-api

**What.** Denies `gh api` calls that write (PUT/POST/DELETE) to the
GitHub Contents API. Reads (GET) are allowed.

**Why.** Writing files via the API bypasses the local workflow
entirely — no validation, no commit standards, no PR template. File
changes go through the worktree: edit, `vrg-commit`, write
`.vergil/pr-template.yml`; the human submits with `vrg-submit-pr`.
(`vrg-gh` denies `gh api` outright; this hook catches raw `gh`.)

**Alternative.** Make the change in your worktree and follow the
local workflow.

## PreToolUse Hooks — Write|Edit

### block-worktree-bypass-write

**What.** Blocks Write/Edit file modifications targeting the main
worktree when the parallel-AI-agent worktree convention is active.

**Why.** The main worktree is read-only by convention — all edits
flow through a `.worktrees/<name>/` worktree on a feature branch.
Symlinks into the main worktree are resolved best-effort and caught.
Design: `docs/specs/2026-05-09-worktree-write-guard-design.md`.

**Alternative.** Write to your assigned worktree's absolute path.

### guard-audit-writes

**What.** When `VRG_IDENTITY_MODE=audit`, denies Write/Edit/
NotebookEdit calls targeting anything other than `.vergil/audit-*`
(the audit's own artifacts) or `build/` (scratch space) inside the
worktree. Other identities are never constrained by this hook.

**Why.** The 2.1 workflow spec makes the AUDIT identity "read-only
by discipline, not by sandbox" — this hook turns the discipline into
a mechanical gate per the no-honor-system principle. The allowlist
deliberately excludes `.vergil/pr-template.yml`: that file is the
USER agent's artifact and the human's `vrg-submit-pr` input.

**Soft gate, by design.** Identity comes from an environment
variable a misbehaving agent can unset; every in-VM guard is soft.
It steers a correctly behaving agent — hard enforcement lives at
the per-identity GitHub App credentials, the pinned
`vergil-audit/approved` required check, and the VM sandbox. Keeping
the guard simple is the accepted trade-off. Bash-command writes
(`>`, `tee`, `sed -i` …) are a documented gap for the same reason.

**Failure mode.** Fail-closed inside the audit identity (no path,
unresolvable path, or path escaping the worktree → deny);
fail-open outside it.

**Alternative.** Write audit findings to
`.vergil/audit-feedback.yml`; use `build/` for scratch. Tests:
`hooks/tests/guard-audit-writes.test.sh`.

## PostToolUse Hooks — Bash

### detect-deprecation-warnings

**What.** Scans test output and command output for deprecation
warnings; surfaces them to the agent for triage.

**Why.** Deprecation warnings get silently tolerated for months
until the deprecated feature is removed. Surfacing them at the
moment they first appear makes them trackable via the
[deprecation-triage skill](../skills/index.md#deprecation-triage)
while the context is fresh.

**Alternative.** Triage the warning via the `deprecation-triage`
skill — either fix it now or capture it in a tracking issue with
clear resolution criteria.

## Hooks deliberately not provided

### Per-edit linting / validation

The plugin does **not** ship a `PostToolUse` Write|Edit hook that
runs ruff / mypy / yamllint / markdownlint / shellcheck on each
edited file. An earlier version did (`validate-on-edit.sh` plus
per-language `validate-*.sh` scripts); it was removed in
[#91](https://github.com/vergil-project/vergil-claude-plugin/issues/91).

**Why removed.** Each per-edit invocation paid the dev-container
startup cost (1–3 s on typical hardware) for one file's worth of
work — five container starts for a single Python edit (`ruff check
--fix`, `ruff format`, `ruff check`, `mypy`, `ty check`). Across a
session with dozens of edits, that's minutes of wall-clock overhead
per session, every session. The same checks already run in two
cheaper places: `vrg-validate` covers them in a single
container start before PR submission, and CI re-runs them on every
PR. The per-edit layer was the third copy with the worst
cost-per-value ratio.

**What replaces it.** Nothing per-edit. Validation runs at PR time
via [`vrg-validate`](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/reference/dev/validate.md),
which is the documented "only validation command" per every
consuming repo's CLAUDE.md. The
[`block-raw-git-commit`](#block-raw-git-commit) PreToolUse hook
already enforces commits going through `vrg-commit`, and `vrg-commit`
runs the pre-commit git hook — so there's a hard gate between
"edits land" and "edits ship."

**Don't re-add this.** A future contributor noticing the absence
should resist the impulse to re-add per-edit validation as a
"missing feature." The cost-per-value math doesn't work; the gap
is intentional.

### Stop hook for finalization

The plugin no longer ships a Stop hook that blocks session exit
on "PR submitted but `vrg-finalize-repo` not run." That hook
(`stop-guard-finalization.sh`) was removed in
[#56](https://github.com/vergil-project/vergil-claude-plugin/issues/56).

**Why removed.** Under the 2.1 workflow the agent's work cycle ends
at the PR template: it writes `.vergil/pr-template.yml` and stops —
the **human** runs `vrg-submit-pr`, merges, and finalizes
(`vrg-finalize-pr`). A session-end gate keyed to agent-side
finalization has no correct trigger left.

**What replaces it.** Nothing needs to: submission, merge, and
finalization are all human actions now. The retired
`remind-finalize` PostToolUse hook (removed in #441) is gone for
the same reason — its trigger, `vrg-submit-pr` in an agent
session, no longer occurs.

**Don't re-add this.** Re-adding a session-end finalize gate
would block the standard PR submission workflow and force agents
into broken cleanup behavior just to satisfy the hook.

## How hooks work — technical

Hooks are defined in `hooks/hooks.json` and implemented as shell
scripts in `hooks/scripts/`. Each hook receives the tool input as
JSON on stdin and returns a JSON response indicating whether to
allow, deny, or annotate the action.

### PreToolUse response

A PreToolUse hook can deny an action by writing JSON to stdout and
exiting 0:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Reason the action is being denied."
  }
}
```

Exit 0 with no JSON = allow. Exit 2 = hook errored; Claude Code
surfaces the error to the user.

### PostToolUse response

A PostToolUse hook can inject context by writing JSON and exiting 0:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Message surfaced to the agent."
  }
}
```

PostToolUse hooks cannot un-do the tool action; they can only add
context the agent sees in its next turn. Exit 2 is a fatal hook
error — useful when validation cannot run and the absence of
validation should be visible.

### Stop response

A Stop hook can block session exit by returning:

```json
{
  "decision": "block",
  "reason": "Reason the session cannot exit."
}
```
