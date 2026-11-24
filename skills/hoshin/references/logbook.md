# The hoshin logbook, its PR and its checks

Where the logbook lives, how an entry is named and shaped, the fixed wording
of every other public record a run creates, the kaizen prompt, the check
format the per-level references use, and what happens to a run that stops or
a logbook PR that fails.

## Where it is

The logbook is the `docs/site/docs/logbook/` tree of `vergil-project/docs`,
published as the docs site's **Logbook** section:

```text
docs/site/docs/logbook/
  index.md     what the logbook is, the entry format, the time zone
  hoshin.md    the direction document: the vital few
  fleet.md     the fleet roster: each org, active or inactive
  daily/       index.md, and one file per daily review
  weekly/      index.md, and one file per weekly review
  monthly/     index.md, and one file per monthly review
  quarterly/   index.md, and one file per quarterly review
  yearly/      index.md, and one file per yearly review
```

`index.md` holds the line `Time zone: <IANA zone>` that every date and time
is computed in ([calendar.md](calendar.md#time-zone)). A run never edits an
entry already merged by an earlier run: a late or "not performed" close is
its own new file.

## File names

Every path is ASCII; Japanese terms appear only in content. `<mode>` is
`start` or `end`.

| Level | File name | Example |
| --- | --- | --- |
| daily | `daily/YYYY-MM-DD-<mode>.md` | `daily/2026-11-18-start.md` |
| weekly | `weekly/<Monday's YYYY-MM-DD>-<mode>.md` | `weekly/2026-11-16-end.md` |
| monthly | `monthly/YYYY-MM-<mode>.md` | `monthly/2026-11-start.md` |
| quarterly | `quarterly/YYYY-Qn-<mode>.md` | `quarterly/2026-Q4-end.md` |
| yearly | `yearly/YYYY-<mode>.md` | `yearly/2026-start.md` |

The file name's period part (before `-<mode>`) is the entry's `period`.

## The entry header

Every entry opens with YAML front matter holding exactly these keys, in this
order:

```yaml
---
level: daily            # daily | weekly | monthly | quarterly | yearly
mode: start             # start | end
period: 2026-11-18      # the file name's period part
window_from: 2026-11-17T18:42-05:00   # omitted on a not-performed entry
window_to: 2026-11-18T08:05-05:00     # omitted on a not-performed entry
ran_at: 2026-11-18T08:05-05:00
late: false
not_performed: false
---
```

`late: true` marks an `end` run late by a `start`; `not_performed: true` an
`end` recorded as not performed. Times are to the minute with their UTC
offset, in the logbook's time zone. The comments above explain the keys;
an entry carries none.

## The entry body

The body is free-form Markdown, kept loose on purpose. It opens with a level-1
heading naming the review, and holds the review's record:

```markdown
# 朝礼 chōrei: daily start 2026-11-18

## Findings

What the review's checks found in the window, under the security rules.

## Decisions

What the human and the agent decided.

## Follow-ups

Each follow-up issue filed, by its public ref.

## Kaizen

What this review should do differently.
```

A review that finds nothing still writes its entry and says so
(`Nothing ran unattended in the window.`). A weekly or larger `start` entry
names any gaps at its level ([calendar.md](calendar.md#gaps)). Every entry
obeys [security.md](security.md).

The headings use the level's term: 朝礼 chōrei (daily `start`), 終礼 shūrei
(daily `end`), 反省 hansei (the weekly, monthly and quarterly `end`), 社長診断
shachō shindan (the yearly `end`). The weekly, monthly, quarterly and yearly
`start` headings name the level and mode only.

## The not-performed entry

A review recorded as not performed is a short entry in the `end` slot: the
header with no `window_from` or `window_to`, `late: false` and
`not_performed: true`, then a heading and one line, and the human's note on
why if they gave one:

```markdown
---
level: daily
mode: end
period: 2026-11-19
ran_at: 2026-11-23T08:10-05:00
late: false
not_performed: true
---

# 終礼 shūrei: daily end 2026-11-19 (not performed)

This review was not performed.

Note: <the human's note, if any>
```

## The index lines

Each level's `index.md` lists that level's entries under its level heading,
one line per entry:

```markdown
- [<period> <mode>](<file name>)
```

An entry that ran late or was not performed adds a space and `(late)` or
`(not performed)` at the end of its line:

```markdown
- [2026-11-23 start](2026-11-23-start.md)
- [2026-11-19 end](2026-11-19-end.md) (not performed)
- [2026-11-19 start](2026-11-19-start.md)
```

Lines are newest first: ordered by period, newest period at the top, and
within one period the `end` line above the `start` line. A new line goes in
at its place, so a late `end` written today for Thursday sits just above
Thursday's `start`, not at the top. The first entry at a level replaces that
index's `No entries yet.` line. The run adds every entry's index line in the
same PR as the entry.

## Fixed wording

Every public record a run creates besides the entries themselves uses fixed
wording that carries no review content. The one exception is merge review's
records on the logbook task (its step and closing comments and any ruling
exchange), which follow merge review's own format and its rule that a
security item is named by ID or count only
([SKILL.md](../SKILL.md#merge-review)). `<date>` is the run's date and
`<mode>` its mode, `start` or `end`, so a run's records are named once
whatever levels it reviews.

- **Task title:** `Logbook: <date> <mode>`, for example
  `Logbook: 2026-11-18 start`.
- **Task body:** only the paths the run will write, one per line, then the
  line `Written by /vergil:hoshin.`:

  ```markdown
  - docs/site/docs/logbook/daily/2026-11-18-start.md
  - docs/site/docs/logbook/daily/index.md

  Written by /vergil:hoshin.
  ```

- **Worktree and branch:** `.worktrees/issue-<N>-logbook` on
  `feature/<N>-logbook`, `<N>` the task's number.
- **Commit:** `vrg-commit --type docs --scope logbook --message "Logbook:
  <date> <mode>"`, giving `docs(logbook): Logbook: <date> <mode>`.
- **Handoff:**

  ```bash
  vrg-pr-workflow report-ready --issue <N> \
    --title "Logbook: <date> <mode>" \
    --summary "Logbook entries written: <path>, <path>." \
    --notes "Merge review: done: eligible; accepted-risk 0. Files: <path>, <path>, <path>."
  ```

  The summary names the entries by path. The notes start with the merge
  review's eligibility line exactly as it gave it (or its exemption line),
  then name every file the commit changes,
  by path (the entries, the index files and any `hoshin.md`). The PR title
  starts `Logbook:`, which is how a later run's preflight recognises an
  open logbook PR.
- **Abandoned run** (closing its own task):

  ```bash
  vrg-gh issue close <N> --repo vergil-project/docs --reason "not planned" \
    --comment "Logbook run abandoned before its commit; nothing was written. The next /vergil:hoshin run works out what is still due."
  ```

- **Stale task** (closed by a later run's preflight):

  ```bash
  vrg-gh issue close <N> --repo vergil-project/docs --reason "not planned" \
    --comment "Closed as stale: this logbook run stopped before its handoff and has no open PR. The next /vergil:hoshin run works out what is still due."
  ```

## The kaizen prompt

Every review ends with the kaizen prompt, before its entry is drafted:

> What should this review do differently?

The agent asks the human, and adds its own observations: a check that missed
something, a check that was noise, a source that was slow or wrong. It also
**points out any ad hoc query it found itself repeating**, naming the query
and the check it served, since a repeated query is a candidate for a `vrg-*`
tool. The answers go in the entry's `## Kaizen` section. The monthly `end`
gathers the month's kaizen notes and turns them into plugin issues.

## The check format

Each data-gathering step in a per-level reference
(`references/<level>.md`) is a named **check**, written so it can be handed,
unchanged, to a planning issue as the brief for the tool that will mechanize
it:

```markdown
#### Check: <name>

- **Answers:** the question the check answers.
- **Sources:** the durable sources it reads (repos, issues, PRs, workflow
  runs, releases, packages).
- **Window:** the time range it reads, normally the entry's window.
- **Output:** what its result shows, and how the entry presents it under
  the security rules.
- **Tool:** the `vrg-*` tool that answers it; or `none yet`, followed by
  the `vrg-gh` / `vrg-git` queries that answer it today and the planning
  issue it belongs to (`vergil-project/.github#1316` fleet state,
  `vergil-project/.github#1140` org state, `vergil-project/.github#1317`
  history, or `new planning issue`).
```

Where `Tool:` names a tool, the agent runs that tool and never gathers the
same data ad hoc. Two rules keep the briefs and the tools in step:

- **A new `Tool: none yet` check is posted as a brief.** The plugin PR that
  adds one posts the check's brief, as merged, as a comment on the planning
  issue it names, linking the reference file at the release tag (for the
  first checklists, the epic's deployment task does this; a check naming
  `new planning issue` gets one filed, with the human's approval, first).
- **A check is switched to its tool once the tool ships.** Its `Tool:`
  field then names the tool, and the ad hoc queries are removed.

## A stopped run: edit or abandon

A run that stops after filing its task (at validation it cannot fix, at a
screen hit, or when the human withholds approval) offers the human exactly
two choices:

- **Edit:** the entry text is changed in the worktree, and the run goes back
  through validation, the screen and the approval, in that order, before any
  commit.
- **Abandon:** the run discards its uncommitted files, removes its worktree
  and branch, closes its task with the fixed abandon comment, and deletes
  its screen terms. Nothing was committed or pushed, so nothing public
  remains but the closed task.

Entry text changes only inside the run: any edit after the approval, however
small, goes back through validation, the screen and the approval before the
commit. A run that dies without either choice leaves its task open; the next
run's preflight treats it as stale.

### Example 7: a run stopped after filing its task

A `start` on 2026-11-18 has filed `vergil-project/docs#<N>`, titled
`Logbook: 2026-11-18 start`, created `.worktrees/issue-<N>-logbook`, written
`daily/2026-11-18-start.md` and its index line, and validated green. The
screen hits on one line of the entry, which carries an advisory ID.

- The run stops, names the match (the file, the line and pattern 1), and
  commits nothing.
- **The human picks edit.** The line becomes `vergil-project/<repo>: a
  security-related failure, vergil-project/.github#<N>.` The run validates again (green), screens again (clean) and
  shows the human the full text of every entry. The human approves; the run
  commits and hands off.
- **Had the human picked abandon,** the run would discard the entry, remove
  the worktree and the branch, close `vergil-project/docs#<N>` with the fixed
  abandon comment, and delete its screen terms. A later `start` the same day
  writes the day's entries afresh under a new task.

## A failing logbook PR

A submitted logbook PR whose checks fail, or that conflicts with
`develop`, is fixed by `pr-watch` like any other PR, and each fix but a
clean rebase is merge-reviewed before it is pushed, like any other fix.
A submitted logbook PR that merges closes its task through
`vrg-finalize-pr`, which `vrg-submit-pr` always runs after the merge.
