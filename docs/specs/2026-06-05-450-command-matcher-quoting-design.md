# Command-Matcher Quoting — Design

**Status:** Design (approved in brainstorm 2026-06-05) ·
**Date:** 2026-06-05 ·
**Issues:** [#450](https://github.com/vergil-project/vergil-claude-plugin/issues/450)
(this repo) · vergil-tooling sub-issue to be filed for the
`vrg-hook-guard` half (linked here once created)

PreToolUse hook matchers scan the raw Bash command text for tool
names. Two implementations exist — bash regexes in this repo's
`hooks/scripts/` and Python in vergil-tooling's `vrg-hook-guard` —
and each has the half of the correct matcher the other is missing:

| Implementation | Quote-aware? | Command-position anchored? | Resulting false positive |
| --- | --- | --- | --- |
| Plugin scripts | no | yes — `(^\|[;&\|]\s*)` | tool name at line start inside a quoted multi-line `--body`/`--message` argument (#450) |
| `vrg-hook-guard` | yes (naive) | no — lookbehind `(?<![a-zA-Z0-9_-])` | `./.git`, `/usr/lib/git`, any `.`/`/`-prefixed hit (observed live: `find … -path ./.git` denied) |

Both defects are the same class: the matcher cannot tell command
position from argument content. This spec defines one canonical
matcher rule and applies it to both implementations.

## 1. Decisions confirmed in brainstorm (2026-06-05)

1. **Scope: both repos, one design.** The shared matcher strategy is
   specified once here; implementation lands as two PRs (one per
   repo).
2. **Crude quote-stripping is the end state.** These hooks guard
   against agent slip-ups, not adversarial evasion. The
   `vrg-git`/`vrg-gh` wrappers (subcommand allowlists, credential
   selection) remain the real enforcement layer. No follow-up path to
   shell tokenization.
3. **Spec lives in this repo; vergil-tooling gets a sub-issue.**
   Issue #450 is filed here and 9 of the 10 affected matchers are
   here. The sub-issue links back to #450 and this spec.

## 2. The canonical matcher rule

> A tool-name predicate matches only when the tool name appears in
> command position in the quote-stripped command text.

### 2.1 Quote stripping

A single left-to-right pass replaces quoted spans with the
placeholder `""`:

```text
"(\\.|[^"\\])*"   double-quoted span, honoring backslash escapes
'[^']*'           single-quoted span, no escapes (shell semantics)
```

Combined as **one alternation** so leftmost-match-wins mirrors how
the shell itself scans the command. This handles nesting
(`"don't"`, `'say "hi"'`) without special cases.

- The placeholder `""` (rather than deletion) preserves token
  boundaries.
- Unbalanced quotes leave the remainder unstripped. That input is a
  shell syntax error anyway, and the failure direction is a false
  positive (over-blocking) — never a weakened guard. Accepted.

### 2.2 Command-position anchoring

```text
(^|[;&|(]\s*)<tool>(\s|$)
```

Applied per line (grep's natural behavior in bash; `re.MULTILINE`
in Python). Line starts are real command positions *after*
stripping, because multi-line quoted arguments are gone.

One deliberate hardening over the current plugin anchor: `(` joins
the separator class so subshells — `(git …)` and `$(git …)` — are
caught.

### 2.3 Predicate classification

Not every predicate moves to stripped text:

- **Tool-name predicates** (is `git commit` / `gh pr create` /
  `vrg-submit-pr` being *invoked*?) → match against **stripped**
  text with the canonical anchor.
- **Argument-content predicates** (contents-API URLs, HTTP-method
  flags, `--linkage` values) → keep matching **raw** text. Their
  targets legitimately live inside quotes; stripping would create
  false negatives.

### 2.4 Accepted gaps (out of scope)

Documented so nobody re-litigates them later:

- Escaped quotes outside any quote context (`\"git commit\"` at top
  level).
- `eval` indirection.
- Command substitution nested inside double quotes.
- The plugin scripts have no `bash -c` recheck (and never did);
  only `vrg-hook-guard` carries one (§4.3).

All are agent-evasion shapes, not slip-up shapes (decision 2).

## 3. Plugin-repo changes

### 3.1 New shared helper

`hooks/scripts/lib/command-match.sh` — sourceable, following the
`managed-repo-check.sh` convention. Provides:

```bash
strip_quoted_segments <command-text>   # → stripped text on stdout
```

Implementation note: `sed`/`grep` are line-oriented and cannot span
the multi-line quoted strings that cause #450. The stripper is
jq-based — jq is already a hard dependency of every hook script,
and its `gsub` (Oniguruma) operates on the whole string:

```bash
jq -Rsr 'gsub("\"(\\\\.|[^\"\\\\])*\"|'\''[^'\'']*'\''"; "\"\"")'
```

(Exact escaping to be settled in implementation; the regex is the
§2.1 alternation.)

### 3.2 Per-script changes

Pattern everywhere: compute `stripped=$(strip_quoted_segments
"$command")` once; point tool-name predicates at `$stripped`; leave
argument-content predicates on `$command`.

| Script | Change |
| --- | --- |
| `block-raw-git-commit.sh` | fallback `git commit` regex → stripped |
| `block-raw-gh-pr-create.sh` | both predicates → stripped |
| `block-agent-merge.sh` | all three predicates → stripped |
| `enforce-host-container-split.sh` | both loop matchers → stripped |
| `detect-deprecation-warnings.sh` | command matcher → stripped (the *output* scan for deprecation warnings is untouched) |
| `block-protected-branch-work.sh` | inverted matcher → stripped — fixes the guard-*weakening* direction noted in #450 |
| `block-autoclose-linkage.sh` | loose `vrg-submit-pr\b` → canonical anchor on stripped; `--linkage (Fixes\|Closes\|Resolves)` value check stays raw |
| `block-github-contents-api.sh` | `gh api` tool-name check → stripped; contents-URL and HTTP-method checks stay raw |
| `block-associative-arrays.sh` | `declare -A` matcher → stripped |
| `block-heredoc.sh` | **unchanged** — its regex must see the quoted delimiter in `<<'EOF'`; stripping would break real heredoc detection. FP on prose mentioning heredocs remains, accepted |

The last two table rows (`block-github-contents-api.sh`,
`block-associative-arrays.sh`) go beyond #450's listed scripts;
they are the identical one-line fix and were approved in brainstorm
to avoid leaving known instances of the defect class behind.

All anchored regexes also pick up the `(` separator from §2.2.

## 4. vergil-tooling changes (`vrg_hook_guard.py`)

### 4.1 Stripper upgrade

`_QUOTED_STR_RE` becomes the §2.1 alternation (adds `\"` escape
handling inside double quotes).

### 4.2 Anchor replacement

`_RAW_GIT_RE` / `_RAW_GH_RE` lookbehind `(?<![a-zA-Z0-9_-])` is
replaced with the canonical anchor `(^|[;&|(]\s*)git(\s|$)` (resp.
`gh`) compiled with `re.MULTILINE`. This fixes the `./.git` and
path-prefix false positives.

### 4.3 `bash -c` recheck preserved — with an extended anchor

Today, when the stripped text contains `bash -c`, the guard
rechecks the *raw* text because the quoted argument of `bash -c`
*is* command text. The canonical anchor would break that recheck
(in `bash -c "git commit"`, `git` is preceded by `"`). The recheck
path therefore uses an extended separator class that includes quote
characters:

```text
(^|[;&|("']\s*)<tool>(\s|$)
```

Slightly looser, but applied only to commands containing
`bash -c`; the over-blocking surface is tiny and the alternative is
an evasion regression.

## 5. Error handling

The stripper has no silent-failure path. If jq unexpectedly errors,
`set -euo pipefail` aborts the hook script non-zero and Claude Code
surfaces a visible non-blocking error — the same behavior as
today's jq input parsing. No fallback-to-raw-text, no swallowed
errors: a broken stripper fails loudly rather than quietly
reverting to the buggy matching.

## 6. Testing

### 6.1 Plugin — `hooks/tests/command-match.test.sh`

Table-driven (bash-3.2 parallel arrays, per the
`guard-audit-writes.test.sh` convention), exercising
`strip_quoted_segments` directly:

- the #450 repro — multi-line `--body` with `git commit` at line
  start → stripped text contains no `git commit`
- escaped quotes inside double-quoted spans
- nesting: `"don't"`, `'say "hi"'`
- unbalanced quote → remainder unstripped (documented FP direction)
- empty command

### 6.2 Plugin — `hooks/tests/command-matchers.test.sh`

Per-script allow/deny table feeding hook JSON to each of the nine
changed scripts. Representative cases:

- #450 repro payload → allow
- plain `git commit -m x` → deny
- `cd foo && git commit` → deny
- `$(git commit)` → deny (new `(` separator)
- inverted-guard case for `block-protected-branch-work.sh`: a
  quoted-body `git commit` mention on a protected branch no longer
  *skips* the guard

`block-raw-git-commit.sh` is tested with `vrg-hook-guard` masked
from `PATH` so the fallback regex path is what runs.

### 6.3 vergil-tooling — `tests/vergil_tooling/test_vrg_hook_guard.py`

Extend the existing pytest module:

- `find … -path ./.git` → allow (the live regression)
- multi-line quoted body with `git commit` at line start → allow
- `bash -c "git commit"` → still deny (recheck path)
- plain `git commit` / `gh pr create` → still deny

### 6.4 Validation

`vrg-container-run -- vrg-validate` in each repo. If the hook test
scripts are not yet wired into `vrg-validate`, wiring them in is
part of the implementation plan, not this spec.

## 7. Rollout

1. **This repo:** PR from `bugfix/450-matcher-quoted-args` →
   `develop`, resolving #450. Ref-only linkage per policy — the
   issue is closed manually by the human after finalization, never
   by auto-close keywords.
2. **vergil-tooling:** sub-issue filed (links #450 + this spec),
   own branch/PR cycle.
3. After the plugin PR merges to `develop`, consumers refresh:
   `/plugin marketplace update vergil-marketplace` →
   `/reload-plugins`.
