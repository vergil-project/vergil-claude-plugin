# Hoshin: the weekly reviews

The checklists for the weekly level: the `start` review, which sets the
week's direction, and the `end` review, 反省 hansei, reflection on the week
just finished. A run reads this file in its step 4 for each weekly review it
runs. Both checklists are thin on purpose: they are a starting point, grown
by kaizen.

Run each checklist as [daily.md](daily.md#how-to-run-a-checklist) says: its
steps in order, each check through its `Tool:` field, `<from>` and `<to>`
the entry's window, every finding under the security rules, and the kaizen
prompt last. A check linked from another level's reference runs as written
there, over this entry's window.

## `start`: the week's direction

The weekly `start` checks the work against the vital few in `hoshin.md` and
chooses the week's focus.

### Checklist

1. Recall the vital few from `hoshin.md` (read in `SKILL.md` step 2) and,
   if the previous week has an `end` entry, what its hansei decided to
   carry into this week.
2. Run [Open epics and their progress](#check-open-epics-and-their-progress)
   and [Epic drift](#check-epic-drift).
3. Present the findings against the vital few: which objectives the open
   epics serve, which objective has no epic moving it, and which epic
   serves none.
4. Choose **the week's focus** with the human: a short list, three items
   at most, each tied to one of the vital few by name. Record it in the
   entry's `## Decisions` section as a list under the line `Focus:`, which
   the week's `end` review reads.
5. Ask the kaizen prompt.

### Checks

#### Check: Open epics and their progress

- **Answers:** which epics are open in the fleet, how far each has got
  (tasks done of tasks in all), and how old each is.
- **Sources:** the open epics in each fleet org's `.github`, and in each
  private repo that homes its own epics, with their native sub-issues.
- **Window:** none: the epics open now.
- **Output:** for public epics, one line per epic: ref, title, tasks done
  of total, age. For epics homed in a private repo, the count of open epics
  per org, and the total tasks done of total, with no titles.
- **Tool:** `vrg-roadmap --org <org>`, for each active fleet org; for each
  private repo the visibility check listed, `vrg-roadmap --repo
  <owner>/<private-repo>`, reported as counts only.

#### Check: Epic drift

- **Answers:** whether the epic and task bookkeeping has drifted: merged
  PRs whose task is still open, open epics whose tasks are all closed, and
  issues in the wrong place.
- **Sources:** each fleet org's epics, tasks and merged PRs.
- **Window:** the tool's own, the last 30 days of merged PRs.
- **Output:** the count of drift items per org, and for a public repo each
  item by ref. Drift is reported only; the run never closes it (the tool's
  `--close` is a human action).
- **Tool:** `vrg-epic-audit`, read-only (never `--close`), run from inside
  a clone of a repo in each active fleet org (it finds the org from that
  clone's `origin`). An exit of 1 marks a partial report, which the entry
  says.

## `end`: 反省 hansei

The weekly hansei compares the week's focus with what happened, judges how
stable the week was from its daily entries, and asks what to improve.

### Checklist

1. Run [Logbook entries in a period](#check-logbook-entries-in-a-period)
   for the week: its weekly `start` entry's `Focus:` list, and its daily
   entries.
2. Run [Merged PRs](daily.md#check-merged-prs) and
   [Closed issues and epics](daily.md#check-closed-issues-and-epics) over
   the week's window.
3. Run [Open epics and their progress](#check-open-epics-and-their-progress).
4. Present **the week's focus against what happened**: each focus item met,
   moved or untouched, with the PRs, issues and epics behind it, and the
   work done outside the focus.
5. Present **how stable the week was**, from the daily entries: the days
   worked, the days whose chōrei found failed runs or stuck automation, the
   shūrei left not performed, and any failure that recurred across days.
6. Hold the hansei with the human: what went well, what did not, and what
   to carry into next week. Record what to carry in `## Decisions`.
7. Ask the kaizen prompt, for the system as well as for this review: what
   should the fleet's work, not only this review, do differently next week?

### Checks

#### Check: Logbook entries in a period

- **Answers:** what the logbook recorded in a period: which entries exist
  at which levels, which ran late or were not performed, and what each
  entry's findings, decisions and kaizen sections say. Every review above
  the daily level reads the record below it through this check.
- **Sources:** the logbook on `develop` in the docs main clone
  (`docs/site/docs/logbook/`), and the entries this run has drafted but not
  yet committed.
- **Window:** the period under review: the week, month, quarter or year
  whose entries are read, named by the levels and periods the calling step
  gives.
- **Output:** for each level read, the entries in the period by file name,
  with `late` and `not_performed` from their headers, then what the calling
  step asks for (a `Focus:` list, the stability signals, the kaizen notes).
  The entries are public already; the output still follows the security
  rules.
- **Tool:** none yet. Today, in the docs main clone:

  ```bash
  vrg-git ls-tree --name-only origin/develop docs/site/docs/logbook/<level>/
  vrg-git show origin/develop:docs/site/docs/logbook/<level>/<file>
  ```

  keeping the files whose name's period part falls in the period
  ([logbook.md](logbook.md#file-names)). Belongs to a `new planning issue`
  (a logbook reader), one issue for this check and every level that links
  to it.
