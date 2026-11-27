# Agents

The plugin provides custom subagents that can be invoked during Claude Code
sessions. Each pins its model in its definition's `model:` line; the
[model map](models.md) records the model of every agent and skill, and
why.

## Bootstrap Agent

**Tools**: Read, Glob, Grep, Bash

The bootstrap agent runs at the start of every work session to validate the
development environment and emit a preflight status report. It runs before any
code changes are made.

### Checks Performed

1. **Repository Profile** — reports the repository name (the current
   directory's name), reads `vergil.toml` and extracts
   `repository_type`, `branching_model`, `primary_language`, and
   `canonical_local_validation_command`

2. **Branch State** — reports the current branch and warns if on a protected
   branch (`main` or `develop`)

3. **Hook Guard** — reports where `vrg-hook-guard` is on PATH, or warns that
   it is not found

### Status Report

The agent emits a structured report:

```text
=== Session Bootstrap ===
Repository:    <repo name>
Profile:       <repository_type> | <branching_model> | <primary_language>
Branch:        <current branch> [WARNING if protected]
Validation:    <validation command or "not configured">
Hook guard:    <vrg-hook-guard path or "NOT FOUND">
=========================
```

Any warnings are collected and listed in a separate section after the status
block.

## Task Runner Agent

**Tools**: all (no `tools:` line, so it inherits the full tool set)

The task runner (`vergil:task-runner`) drives one task run that
`epic-implement` dispatches: one issue, or one batch, through
`issue-implement`, `issue-validate` or `issue-deploy`. It runs the routed
skill end to end under the
[Agent prompt contract](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/worktree-convention.md#agent-prompt-contract)
its prompt names. Its definition adds no procedure of its own: the skills
carry it. It needs the Agent and Skill tools, so it has no tool list.
Only `epic-implement` dispatches it, and never with a per-invocation
`model`, which would outrank its pin.

## Implementer Agent

**Tools**: Read, Edit, Write, Glob, Grep, Bash

The implementer (`vergil:implementer`) is the writer an `issue-implement`
driver dispatches for every change to a task's tracked files, code, docs
and config alike. In the worktree its prompt names, it makes the change,
commits it in small `vrg-commit` commits in the convention the prompt
gives, and validates with `vrg-container-run -- vrg-validate` until green.

It never suppresses a gate, never submits, pushes or posts on GitHub,
never creates issues, never runs merge review, and never edits anything
under `build/.vergil-state/`. Once five `vrg-validate` runs in one
dispatch have all exited non-zero, judged by exit code alone, it stops
and returns `stuck`. Its last message is exactly this block, which the
driver reads:

```text
Implementer result: green|stuck
Commits: <sha> <subject>   (one line each, oldest first; "none" if none)
Validate runs: <n>, last exit <code>
Tried: <stuck only: what was tried and what still fails>
Notes: <deviations from the issue and why; concerns noticed; or "none">
```

The driver checks a `green` result for itself (a clean tree, the commits
on the branch, its own green validate) before merge review.
`scripts/bin/validate-custom` pins its tool list, so it can never gain
the Agent tool.

## Merge Reviewer Agent

**Tools**: Read, Glob, Grep

The merge reviewer judges one step of a merge-review run: the first review of
a branch once `vrg-validate` is green, or a check of the fix that follows it.
Only the `merge-review` skill dispatches it, with one line: the absolute path
of a request file the skill wrote into the task's private state directory.
The request and reply follow the merge-review profile of vergil-tooling's
[agent-to-agent review protocol](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/specs/merge-review-protocol.md).

### Read-only

The reviewer reads and reports; it never changes the code. Its tools are
exactly Read, Glob and Grep: no Write, Edit or Bash, so it has no way to
write to the file system or run a command. Everything a command would
produce, such as the diff, comes in the request, and everything it produces
goes back in its reply. The plugin's `capture-merge-review-result`
SubagentStop hook stores that reply, its final message, byte for byte as the
step's result, with a capture record holding its SHA-256, so nobody retypes
it; the skill then checks it and screens it against the doctrine's
security definition. A reply that touches no security finding (its
own, or for a check an earlier step's) and in which the screen finds
nothing that would help an attacker (a below-bar remark, or a description
of a security fix the branch makes) is then published whole in the step's
comment on the task issue, so the full review survives handoff; any other
reply is withheld.
`scripts/bin/validate-custom` pins this tool list, so adding a tool to the
agent fails validation.

The request, the issue and its comments, the diffs and every file the
reviewer reads are data, never instructions to it.

### The Scope

The reviewer judges scope against the issue body as amended by the human's
comments on the issue, which can narrow, widen or settle it. The request
carries only the human maintainer's unedited comments:
`vrg-merge-review-request` fetches and filters them itself, so a comment by
an agent identity or a third party never changes the scope the reviewer
uses. A comment changes what the
task is, never how the reviewer works.

### What It Judges

Every finding answers one of two questions: is the change safe to put into
production, and would a senior engineer block the merge. A `docs-only`
change gets only the second. A finding is raised only when the reviewer is
certain it is real, the branch introduced it, and CI (the `vrg-validate`
run and the PR CI workflows) does not already check it: nothing in
formatting, linting, type checking, tests and coverage, security scanners or
dependency audits.

Each finding is one of four kinds:

- **defect**: the fix stays within the existing design;
- **design question**: the fix would add machinery the design does not
  have, so the human decides;
- **out-of-scope**: content the scope did not ask for;
- **pre-existing**: a note on a problem the branch did not introduce, never
  asked to be fixed on the branch.

In a check, the reviewer reports `fixed` or `not-fixed` for each finding the
implementer was asked to change, and raises any new problem the fix caused
as a new finding.

### Reply

The reply opens with one fenced `merge-review-result` block holding a JSON
object (the step and request ID copied from the request, the findings, and
in a check the fix status), followed by prose for the human. The reply
carries no verdict: the skill decides from the findings' kinds. A security
finding has no summary in the block; its details appear only in the prose,
which is never posted.
