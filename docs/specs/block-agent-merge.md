# Spec: Hard gate to prevent agent from merging non-release PRs

**Issue:** [#162](https://github.com/vergil-project/vergil-claude-plugin/issues/162)

## Problem

An agent merged a feature PR directly via `gh pr merge`, bypassing
human review. The pr-workflow skill says "do not merge the PR" but
skill prose is advisory — the agent rationalized past it. There is
no mechanical enforcement preventing `gh pr merge` on any PR.

## Design

A PreToolUse hook that intercepts Bash tool calls containing
`gh pr merge` or `gh pr review --approve` and denies them unless
the target is a release-workflow PR. The hook delegates PR
resolution and branch-name verification to a new `st-*` host
command, keeping all mechanical parsing out of shell.

### What to block

| Command pattern | Reason |
|---|---|
| `gh pr merge` | Direct merge of any PR |
| `gh pr review --approve` | Self-approval (could satisfy a required-reviews gate) |

### What to allow

Release-workflow PRs that the agent is expected to merge via
`vrg-merge-when-green` from the publish skill. These are identified
by branch name:

- `release/*` — the release PR to main
- `chore/bump-version-*` — the post-publish version bump PR to develop

**Important:** `vrg-merge-when-green` does NOT need a hook exemption.
It calls `gh pr merge` internally via Python's subprocess module,
not through Claude Code's Bash tool. The hook only intercepts
commands that pass through the Bash tool boundary. This means:

- `vrg-merge-when-green <url>` — **not intercepted** (the `gh pr
  merge` happens inside the Python process, never visible to the
  hook)
- `gh pr merge <url>` typed directly — **intercepted and checked**

The allow-list for direct `gh pr merge` exists as a safety net
for cases where an agent calls `gh pr merge` directly on a
release PR instead of using `vrg-merge-when-green`. This should
not happen in normal operation but the hook should not create a
false-positive block if it does.

### Architecture: delegate parsing to `vrg-check-pr-merge`

The hook script does NOT parse PR references or query GitHub
itself. Instead, it detects `gh pr merge` or `gh pr review
--approve` in the command string and delegates to a new
`vrg-check-pr-merge` host command in vergil-tooling.

This follows the foundational architectural decision: mechanical
tasks belong in Python scripts (`st-*`), not in shell hooks where
agents or contributors might get creative with parsing. The less
we leave to ad-hoc shell logic, the fewer failure scenarios we
create.

**`vrg-check-pr-merge`** (new command in vergil-tooling):

- Takes the raw Bash command string as input
- Extracts the PR reference (number or URL), handling all flag
  ordering variations, `--repo` arguments, pipelines, etc.
- Resolves the branch name via the GitHub API
- Checks the branch against the allow-list (`release/*`,
  `chore/bump-version-*`)
- Exit codes follow the three-state convention
  ([vergil-tooling#373](https://github.com/vergil-project/vergil-tooling/issues/373)):
  - **Exit 0** — allowed (release-workflow branch)
  - **Exit 1** — denied (tool ran, branch does not match
    allow-list; deny message on stderr)
  - **Exit 2** — unknown (tool could not determine the answer —
    GitHub API failure, parse failure, etc.; error details on
    stderr)
- On any failure to determine the answer, exit 2 and surface the
  full error message (not hide it) so the user can diagnose

### Hook behavior

1. Read stdin (JSON with `tool_input.command` and `cwd`).
2. Check managed-repo gate (`is_managed_repo`). Exit 0 if not
   managed.
3. Check if the command contains `gh pr merge` or
   `gh pr review --approve`. Exit 0 if neither.
4. Pass the command string to `vrg-check-pr-merge`.
5. If `vrg-check-pr-merge` exits 0, exit 0 (allow).
6. If `vrg-check-pr-merge` exits 1, emit a deny decision using
   the stderr from `vrg-check-pr-merge` as the reason (definitive
   denial).
7. If `vrg-check-pr-merge` exits 2 or any other non-zero code,
   emit a deny decision with a message indicating the tool could
   not determine whether the merge is allowed, including the
   stderr output for diagnosis. The merge is still blocked — a
   merge the tool cannot verify is not safe to allow — but the
   reason distinguishes "policy denied" from "tool failure."

### Deny message

```text
Blocked: agents may not merge non-release PRs. The pr-workflow
policy requires human review and merge for feature/bugfix PRs.
Hand off the PR URL to the user and stop the work cycle.

Only release-workflow PRs (release/* and chore/bump-version-*)
may be agent-merged, and only via vrg-merge-when-green from the
publish skill. See issue #162.
```

### Defense in depth: `vrg-merge-when-green` branch check

`vrg-merge-when-green` itself should also verify the target branch
name before merging. This is a separate change in vergil-tooling
that adds a sanity check: if the branch does not match `release/*`
or `chore/bump-version-*`, the script refuses to merge and exits
non-zero. This closes the bypass where an agent calls
`vrg-merge-when-green` on a feature PR — the Python subprocess
path that the hook cannot intercept.

## Implementation: two-repo split

### vergil-tooling (cross-repo)

1. **New command: `vrg-check-pr-merge`** — Python script that
   takes a raw Bash command string, extracts the PR ref, resolves
   the branch name via GitHub API, and checks against the
   allow-list. Exits 0 (allowed) or non-zero (denied, with
   error message on stderr).

2. **Modified: `vrg-merge-when-green`** — Add branch-name
   verification before merging. Refuse to merge if the branch
   does not match `release/*` or `chore/bump-version-*`.

### vergil-claude-plugin (this repo)

1. **New file: `hooks/scripts/block-agent-merge.sh`** —
   PreToolUse hook script following the same structure as
   `block-autoclose-linkage.sh`:

   - Shebang, `set -euo pipefail`
   - Source `lib/managed-repo-check.sh`
   - Read stdin, extract cwd, gate on `is_managed_repo`
   - Match `gh pr merge` or `gh pr review --approve`
   - Delegate to `vrg-check-pr-merge` with the command string
   - Emit deny decision with stderr from `vrg-check-pr-merge`
     if it exits non-zero

2. **Modified: `hooks/hooks.json`** — Add the new hook to the
   `PreToolUse` > `Bash` array:

   ```json
   {
     "type": "command",
     "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/block-agent-merge.sh",
     "statusMessage": "Checking for unauthorized PR merge..."
   }
   ```

3. **Modified: `docs/site/docs/hooks/index.md`** — Add a section
   documenting the new hook with the standard What / Why /
   Alternative format:

   - **What:** Blocks `gh pr merge` and `gh pr review --approve`
     for non-release PRs.
   - **Why:** Agents must not merge feature/bugfix PRs. Human
     review is required. Skill prose alone is not reliable — see
     incident in #162.
   - **Alternative:** Hand off the PR URL to the user. For release
     PRs, use `vrg-merge-when-green` from the publish skill.

## Edge cases

### Agent passes PR number vs URL

`vrg-check-pr-merge` handles both `gh pr merge 364` and
`gh pr merge https://github.com/owner/repo/pull/364`. The GitHub
API accepts either form.

### Agent pipes or chains commands

The hook regex matches `gh pr merge` anywhere in a pipeline or
command chain (`;`, `&&`, `||`). The existing hooks use patterns
like `(^|[;&|]\s*)gh\s+pr\s+merge` for this.

### gh pr merge with flags before the PR ref

The agent might write `gh pr merge --squash 364` or
`gh pr merge --merge --delete-branch <url>`. `vrg-check-pr-merge`
handles all flag ordering variations in Python, not shell.

### GitHub API failure

If the GitHub API call fails (bad PR ref, network error, auth
issue), `vrg-check-pr-merge` exits 2 (unknown) and surfaces the
full error message on stderr. The hook still blocks the merge — a
merge the tool cannot verify is not safe to allow — but the deny
message distinguishes "tool failure" from "policy denied."

### Cross-repo PRs

The agent might merge a PR in a different repo:
`gh pr merge --repo owner/other-repo 42`. `vrg-check-pr-merge`
extracts and forwards the `--repo` argument to the API call.

## Testing

### `vrg-check-pr-merge` (unit tests in vergil-tooling)

1. **Allowed branch:** PR on `release/1.4.9` — exits 0.
2. **Allowed branch:** PR on `chore/bump-version-1.4.10` — exits 0.
3. **Blocked branch:** PR on `feature/42-foo` — exits 1.
4. **Flags before ref:** `--squash 364` — extracts 364 correctly.
5. **URL format:** full GitHub URL — resolves correctly.
6. **`--repo` flag:** extracts repo and passes to API.
7. **API failure:** exits 2 with error message on stderr.

### `block-agent-merge.sh` (manual hook testing)

1. **Denied (exit 1):** Input containing `gh pr merge 42` where
   `vrg-check-pr-merge` exits 1. Expect deny with policy message.
2. **Unknown (exit 2):** Input containing `gh pr merge 42` where
   `vrg-check-pr-merge` exits 2. Expect deny with tool-failure
   message (distinct from policy denial).
3. **Allow case:** Input containing `gh pr merge <url>` where
   `vrg-check-pr-merge` returns 0. Expect allow (exit 0).
4. **Non-managed repo:** Input with a cwd that has no
   `vergil.toml`. Expect allow (exit 0).
5. **No match:** Input containing `gh issue list`. Expect allow
   (exit 0).
6. **gh pr review --approve block:** Input containing
   `gh pr review --approve 42` where `vrg-check-pr-merge` exits 1.
   Expect deny.

### `vrg-merge-when-green` (updated tests in vergil-tooling)

1. **Release branch:** `release/1.4.9` — proceeds to merge.
2. **Bump branch:** `chore/bump-version-1.4.10` — proceeds.
3. **Feature branch:** `feature/42-foo` — refuses, exits non-zero.

## Not in scope

- **GitHub branch protection rules** (required reviewers, etc.)
  are defense-in-depth and should be configured separately. This
  spec covers only the agent-side gate.
- **Blocking `gh pr close`** on non-release PRs. Closing a PR
  doesn't merge code and agents legitimately close PRs during
  finalization.
- **Blocking soft-approval patterns** (`gh pr review --comment`
  with LGTM-like text). Only `--approve` has mechanical effect
  on branch protection gates.
