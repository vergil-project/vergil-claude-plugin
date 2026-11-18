# Hoshin: the monthly reviews

The checklists for the monthly level: the `start` review, which sets the
month's direction, and the `end` review, 反省 hansei, reflection on the
month just finished. A run reads this file in its step 4 for each monthly
review it runs. Both checklists are thin on purpose: they are a starting
point, grown by kaizen.

Run each checklist as [daily.md](daily.md#how-to-run-a-checklist) says: its
steps in order, each check through its `Tool:` field, `<from>` and `<to>`
the entry's window, every finding under the security rules, and the kaizen
prompt last. A check linked from another level's reference runs as written
there, over this entry's window.

## `start`: the month's direction

The monthly `start` sets the month's direction against the vital few, and
looks at the size and age of the work waiting to be routed, planned or
revived.

### Checklist

1. Recall the vital few from `hoshin.md` (read in `SKILL.md` step 2) and,
   if the previous month has an `end` entry, what its hansei decided to
   carry, change or drop.
2. Run [Queue size and age](#check-queue-size-and-age) and
   [Open epics and their progress](weekly.md#check-open-epics-and-their-progress).
3. Present the findings against the vital few: which queue items or epics
   move an objective, and which queue is growing or ageing.
4. Agree **the month's direction** with the human: one to three sentences
   naming the objectives the month will move and how. Record it in the
   entry's `## Decisions` section after the line `Direction:`, which the
   month's `end` review reads. Note any queue the human wants worked down.
5. Ask the kaizen prompt.

### Checks

#### Check: Queue size and age

- **Answers:** how large and how old the intake, planning and deferred
  queues are, fleet-wide, and which items are oldest.
- **Sources:** the intake, planning and deferred queue epics in each fleet
  org's `.github`, and in each private repo that homes its own queues.
- **Window:** none: the queues as they stand now. The previous monthly
  `start` entry's figures, if any, give the change over the month.
- **Output:** per org and queue: the item count, the age of the oldest
  item and the median age, and for planning the count per size (S, M, L,
  XL, unsized). The five oldest public items by ref and title. A private
  repo's queues as counts only.
- **Tool:** `vrg-queue --json --repo <org>/.github`, for each active fleet
  org; `vrg-queue --json --repo <owner>/<private-repo>` for each private
  repo that homes its own queues, reported as counts only.

## `end`: 反省 hansei

The monthly hansei compares the month with its direction, gathers the
month's kaizen notes and turns them into plugin issues, and takes a first,
rough look at capacity.

### Checklist

1. Run [Logbook entries in a period](weekly.md#check-logbook-entries-in-a-period)
   for the month: its monthly `start` entry's `Direction:`, its weekly
   entries, and the `## Kaizen` section of every entry in the month at
   every level.
2. Run [Delivered in a period](#check-delivered-in-a-period) over the
   month's window.
3. Present **the month against its direction**: each objective the
   direction named, what moved it, and what did not happen.
4. **Gather the kaizen notes:** group the month's kaizen notes by the
   change they ask for, drop the ones already done, and with the human
   turn each change to the skill or the tooling into a plugin issue,
   filed through `SKILL.md` step 5 (screened, its text approved by the
   human, then `vrg-intake-create` in `vergil-project/vergil-claude-plugin`,
   or the repo the change belongs to). A note that asks for a `vrg-*` tool
   names the check it would mechanize.
5. Run [Delivery rate](#check-delivery-rate) for the month's weeks, and
   [Queue size and age](#check-queue-size-and-age).
6. Take **a first, rough look at capacity** with the human: how much work
   the fleet took on and finished each week, against how fast the queues
   grew. Record the rough figure in `## Decisions`; the quarterly `start`
   plans against it.
7. Ask the kaizen prompt.

### Checks

#### Check: Delivered in a period

- **Answers:** what the fleet delivered in a period: the epics closed, the
  releases cut, and the PRs merged.
- **Sources:** closed epic issues in each fleet org's `.github` and in each
  private repo that homes its own epics; the releases of every fleet repo;
  the merged PRs in every fleet org.
- **Window:** from `<from>` to `<to>`, a month, a quarter or a year.
- **Output:** for public repos, each closed epic by ref and title, the
  releases per repo by tag, and the merged PRs as a count per repo
  (human-submitted and automation-authored apart). For private repos, the
  counts of each per org.
- **Tool:** none yet. Today, for each fleet org:

  ```bash
  vrg-gh search issues --owner <org> --label epic --closed "<from>..<to>" \
    --limit 1000 --json repository,number,title,closedAt,url
  vrg-gh search prs --owner <org> --merged-at "<from>..<to>" --limit 1000 \
    --json repository,number,author,closedAt
  ```

  and, for each fleet repo, the release query of
  [Releases cut](daily.md#check-releases-cut) over the same window. A
  result of 1000 is truncated: split the range and repeat. `vrg-activity-log`
  is not used here, since its window is fixed at the last 30 days. Belongs
  to `vergil-project/.github#1317` (history).

#### Check: Delivery rate

- **Answers:** how much work the fleet finishes per week, as the first
  input to capacity: tasks closed, epics closed and PRs merged each week.
- **Sources:** closed issues and merged PRs in every fleet org.
- **Window:** the span the calling step names, cut into buckets ending at
  or before `<to>`: the month's Monday-to-Sunday weeks for the monthly
  `end`, the last 13 such weeks for the quarterly `start` and `end`, and
  the year's months for the yearly `end`.
- **Output:** a table with one row per bucket: tasks closed as completed,
  epics closed, PRs merged by the human, PRs merged by automation. Private
  repos fold into the fleet totals with no row of their own.
- **Tool:** none yet. Today, for each fleet org and each bucket, from its
  first day `<first>` to its last day `<last>`:

  ```bash
  vrg-gh search issues "reason:completed" --owner <org> \
    --closed "<first>..<last>" --limit 1000 --json repository,number,labels
  vrg-gh search prs --owner <org> --merged-at "<first>..<last>" \
    --limit 1000 --json repository,number,author
  ```

  counting issues with the `epic` label apart, and PRs whose author type is
  `Bot` as automation. Belongs to `vergil-project/.github#1317` (history).
