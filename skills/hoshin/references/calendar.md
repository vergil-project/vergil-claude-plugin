# The hoshin calendar

The rules a `/vergil:hoshin` run uses to work out the date, the periods, what
is due and the window each entry covers. The run applies them in its step 3
(decide what is due); nothing here is the human's job to track.

## The rules

### Time zone

Every date and time is computed in the one IANA time zone recorded in the
logbook's `index.md`, on its line `Time zone: <IANA zone>`. Never use the host
clock's zone, which may be UTC. If the line is missing or names no valid zone,
stop and tell the human; never guess one.

Get the current time and the current week's Monday in that zone with:

```bash
python3 -c 'import datetime, sys, zoneinfo
z = zoneinfo.ZoneInfo(sys.argv[1])
now = datetime.datetime.now(z)
print(now.isoformat(timespec="minutes"))
print(now.date() - datetime.timedelta(days=now.weekday()))' '<IANA zone>'
```

Every time an entry records (`window_from`, `window_to`, `ran_at`) is written
to the minute with its UTC offset at that moment, for example
`2026-11-18T08:05-05:00`. A midnight is written as `T00:00` of the day it
begins, with that day's offset.

### Days

A day with a `start` entry is a day worked. A day with no `start` entry is a
day off, and nothing about it is flagged. Days are never gaps.

### Weeks

Weeks run Monday to Sunday. A week is named by its Monday's date.

### Every period comes from the week

A week belongs to the month its Monday falls in, and so to that month's
quarter and year. The current month, quarter and year are those of the
current week's Monday, never of today's date. So:

- the current **month** is the month of the current week's Monday
  (`YYYY-MM`);
- the current **quarter** is that month's quarter (`YYYY-Qn`, months 1–3
  `Q1`, 4–6 `Q2`, 7–9 `Q3`, 10–12 `Q4`), in the Monday's year;
- the current **year** is the Monday's year.

A month therefore starts with the first Monday that falls in it and runs to
the day before the first Monday of the next month. A quarter and a year start
with the first Monday of their first month.

### The end of a period

A period ends where the next one at its level begins, at midnight (`T00:00`)
in the configured zone:

| Level | Period | Ends at |
| --- | --- | --- |
| daily | day D | 00:00 on the day after D |
| weekly | week of Monday M | 00:00 on M + 7 days |
| monthly | `YYYY-MM` | 00:00 on the first Monday of the next month |
| quarterly | `YYYY-Qn` | 00:00 on the first Monday of the next quarter's first month |
| yearly | `YYYY` | 00:00 on the first Monday of the next January |

### Boundaries

For each level, a `start` run compares the current period with the period of
that level's latest `start` entry. If they differ, the level has crossed a
boundary and the current period's `start` review is due. A level with no
entries at all is due too. The daily level crosses a boundary every day, so
every `start` writes the day's `start` entry.

### Closing an open period

At a level, an **open period** is the period of the latest `start` entry
when no `end` entry exists for it.

- **On `start`:** if a level's open period is earlier than the current
  period, the run pauses and says so, for example "Thursday 2026-11-19 was
  started but never closed". A period still in progress (the current one) is
  never offered for closing by `start`. The human chooses:
  - **close it now**: the missed `end` review runs late, and its entry
    records `late: true` and when it ran (`ran_at`); or
  - **record it as not performed**: a short entry in the `end` slot with
    `not_performed: true` and the human's optional note on why
    ([logbook.md](logbook.md#the-not-performed-entry)).

  At the daily level this is one quick prompt whose **default is "not
  performed"**, so an unclosed day costs one keystroke: Enter records it not
  performed, and only an explicit "close it" runs the late review. At the
  week level and above there is no default; the human chooses. Either entry
  goes into the same PR as the run's new `start` entries, so every `start`
  ends up with a matching `end`.
- **On `end`:** see [`end` targets the latest open period](#end-targets-the-latest-open-period).

### Gaps

At the week level and above, every period strictly between the period of the
level's latest entry and the current period has neither a `start` nor an
`end` entry. Those periods are **gaps**, and the run names them in the
current period's new `start` entry, for example
`No entries: weeks of 2026-12-07 and 2026-12-14.` A run never writes an entry
for a gap. Days are never gaps.

### Windows

Every entry that reviews something has a window, `window_from` to
`window_to`:

- **A `start` review** runs from the `window_to` of the latest entry at its
  level that has a window, to now. A skipped day widens the next window
  rather than losing time, and weekend work falls into the next weekly
  review.
- **An `end` the human runs** covers from its matching `start`'s `window_to`
  to whichever is earlier, now or the end of its period, with `late: false`.
  It never records a time in the future, so an `end` at 18:00 leaves the
  evening for the next `start`, and an `end` after midnight still stops at
  midnight.
- **An `end` run late by a `start`** covers only its own period: from its
  matching `start`'s `window_to` to the end of that period, with
  `late: true`. It never runs to now, so the overnight window is left for the
  朝礼 chōrei that follows.
- **A "not performed" entry** has no window: its header omits `window_from`
  and `window_to`. The next `start` window therefore opens where the last
  reviewed window closed, and no time goes unreviewed.

When an entry is written depends on its window only: a late `end` written on
Monday for Thursday still covers Thursday alone.

### `end` targets the latest open period

Plain `end` closes the day. `end week`, `end month`, `end quarter` or
`end year` closes that level's period now, together with every smaller level
still open beneath it, smallest first (`end month` also closes the week and
the day).

`end` always closes the **latest open period** at each level it touches (the
most recent `start` with no `end`), whatever the current date, so an `end`
run after midnight still closes the day that was worked. At each level, the
`end` covers its window as an `end` the human runs (above), with
`late: false`.

`end` refuses, writing nothing, when the level it names has no open period:
plain `end` with the latest daily `start` already closed, or `end month` with
no open month. If smaller levels are still open when the named one is not,
the refusal names them, so the human can run `end` for the right level. A
period `end` does not close is closed by the next `start`.

### The first run

On an empty logbook nothing is open, there are no gaps, and every level's
`start` review is due. The first `/vergil:hoshin start` is the bootstrap: it
runs the daily `start`, then the yearly, quarterly, monthly and weekly
`start` reviews, and sets the first `hoshin.md` by catchball. No separate
bootstrap mode exists.

A level with no earlier entry that has a window has no window end to start
from. Its first `start` window opens at the beginning of the current period
at that level (00:00 today for the daily, the current week's Monday 00:00 for
the weekly, the first Monday of the current month, quarter or year for the
larger levels) and runs to now.

## Worked examples

The zone is `America/New_York` throughout. Each example gives the run, the
logbook state it finds, and the exact files it writes, in the order it
writes them, with their windows. File names are relative to
`docs/site/docs/logbook/`.

### Example 1: the year-end week

**Run:** `start` on Thursday 2026-01-01 at 08:00 (`-05:00`).

**Logbook:** the latest entries are `daily/2025-12-31-start.md` (no `end`),
`weekly/2025-12-29-start.md`, `monthly/2025-12-start.md`,
`quarterly/2025-Q4-start.md` and `yearly/2025-start.md`. The daily `start`
for 2025-12-31 has `window_to: 2025-12-31T08:10-05:00`.

**Calendar:** the current week is the week of Monday 2025-12-29, which
belongs to December 2025, Q4 2025 and 2025. Every level above daily matches
its latest `start`, so no weekly, monthly, quarterly or yearly review is due
and nothing at those levels is open for closing. No January, Q1 or 2026
review is due until the `start` on or after Monday 2026-01-05.

**The daily prompt:** Wednesday 2025-12-31 was started but never closed; the
human takes the default, not performed.

**Files written:**

1. `daily/2025-12-31-end.md`: `not_performed: true`, no window.
2. `daily/2026-01-01-start.md`: `window_from: 2025-12-31T08:10-05:00`,
   `window_to: 2026-01-01T08:00-05:00`.

### Example 2: an `end` after midnight

**Run:** `end` at 00:30 on Friday 2026-11-20.

**Logbook:** the latest daily entry is `daily/2026-11-19-start.md`, Thursday's,
with `window_to: 2026-11-19T08:05-05:00`, and no Thursday `end`.

**Calendar:** the latest open daily period is Thursday 2026-11-19. Its end is
2026-11-20T00:00, earlier than now, so the window stops at midnight. The run
is the human's `end`, so it is not late. Friday has no `start`, so nothing is
written for Friday.

**Files written:**

1. `daily/2026-11-19-end.md`: `window_from: 2026-11-19T08:05-05:00`,
   `window_to: 2026-11-20T00:00-05:00`, `ran_at: 2026-11-20T00:30-05:00`,
   `late: false`.

### Example 3: Monday after a weekend off, Thursday left open

**Run:** `start` on Monday 2026-11-23 at 08:10.

**Logbook:** `daily/2026-11-19-start.md` (Thursday, `window_to:
2026-11-19T08:05-05:00`) with no Thursday `end`, and no entries for Friday,
Saturday or Sunday. `weekly/2026-11-16-start.md` (`window_to:
2026-11-16T08:20-05:00`) with no weekly `end`. `monthly/2026-11-start.md`,
`quarterly/2026-Q4-start.md` and `yearly/2026-start.md`, each current.

**Calendar:** the current week is the week of 2026-11-23, in November 2026,
so only the weekly level has crossed a boundary. Thursday is open and earlier
than today: the one-keystroke daily prompt. The week of 2026-11-16 is open and
earlier than the current week: the human chooses late or not performed. The
month, quarter and year are still in progress and are not offered. Friday to
Sunday are days off, never gaps, and the week of 2026-11-16 has entries, so
no gap is named.

In both outcomes below the human records the week of 2026-11-16 as not
performed, so the weekly `start` window opens at that week's `start` window
end.

**Outcome A, Thursday recorded as not performed (the default).** Files
written:

1. `daily/2026-11-19-end.md`: `not_performed: true`, no window.
2. `weekly/2026-11-16-end.md`: `not_performed: true`, no window.
3. `daily/2026-11-23-start.md`: `window_from: 2026-11-19T08:05-05:00` (the
   end of Thursday's `start` window), `window_to: 2026-11-23T08:10-05:00`.
4. `weekly/2026-11-23-start.md`: `window_from: 2026-11-16T08:20-05:00`,
   `window_to: 2026-11-23T08:10-05:00` (the time the weekly review runs).

**Outcome B, Thursday closed late.** Files written:

1. `daily/2026-11-19-end.md`: `late: true`,
   `window_from: 2026-11-19T08:05-05:00`,
   `window_to: 2026-11-20T00:00-05:00` (Thursday to midnight, never to now).
2. `weekly/2026-11-16-end.md`: `not_performed: true`, no window.
3. `daily/2026-11-23-start.md`: `window_from: 2026-11-20T00:00-05:00` (that
   midnight), `window_to: 2026-11-23T08:10-05:00`.
4. `weekly/2026-11-23-start.md`: as in outcome A.

### Example 4: an `end` on the same day

**Run:** `end` at 18:00 on Thursday 2026-11-19, then `start` at 08:00 on
Friday 2026-11-20.

**Logbook:** `daily/2026-11-19-start.md` with
`window_to: 2026-11-19T08:05-05:00`; every larger level is current.

**Calendar:** the `end` closes Thursday. Now (18:00) is earlier than the end
of the day, so the window stops at 18:00, never at midnight. On Friday,
nothing is open, and the daily `start` window opens at Thursday's `end`
window end, so the evening is reviewed.

**Files written by the `end`:**

1. `daily/2026-11-19-end.md`: `window_from: 2026-11-19T08:05-05:00`,
   `window_to: 2026-11-19T18:00-05:00`, `late: false`.

**Files written by Friday's `start`:**

1. `daily/2026-11-20-start.md`: `window_from: 2026-11-19T18:00-05:00`,
   `window_to: 2026-11-20T08:00-05:00`.

### Example 5: `end month` with the week and day open

**Run:** `end month` at 17:30 on Friday 2026-12-04.

**Logbook:** `daily/2026-12-04-start.md` (`window_to:
2026-12-04T08:00-05:00`), `weekly/2026-11-30-start.md` (`window_to:
2026-11-30T08:15-05:00`) and `monthly/2026-11-start.md` (`window_to:
2026-11-02T08:30-05:00`), none with an `end`.

**Calendar:** the week of Monday 2026-11-30 belongs to November, so the open
month is 2026-11, which ends at 00:00 on Monday 2026-12-07. Now is earlier
than the end of each open period, so every window stops at now. The run
closes smallest first.

**Files written:**

1. `daily/2026-12-04-end.md`: `window_from: 2026-12-04T08:00-05:00`,
   `window_to: 2026-12-04T17:30-05:00`, `late: false`.
2. `weekly/2026-11-30-end.md`: `window_from: 2026-11-30T08:15-05:00`,
   `window_to: 2026-12-04T17:30-05:00`, `late: false`.
3. `monthly/2026-11-end.md`: `window_from: 2026-11-02T08:30-05:00`,
   `window_to: 2026-12-04T17:30-05:00`, `late: false`.

**Then nothing is open:** once that PR has merged, a plain `end` at 18:00 the
same day finds the latest daily `start`, 2026-12-04, already closed. It
refuses, says nothing is open, and writes nothing.

### Example 6: a gap at the week level

**Run:** `start` on Monday 2026-12-21 at 08:00.

**Logbook:** the latest weekly entry is `weekly/2026-11-30-start.md`
(`window_to: 2026-11-30T08:15-05:00`), with no `end`. The latest daily entries
are `daily/2026-12-04-start.md` and `daily/2026-12-04-end.md`
(`window_to: 2026-12-04T17:30-05:00`). The latest monthly entry is
`monthly/2026-11-start.md` (`window_to: 2026-11-02T08:30-05:00`), with no
`end`. `quarterly/2026-Q4-start.md` and `yearly/2026-start.md` are current.

**Calendar:** the week of 2026-12-21 belongs to December 2026, so the weekly
and monthly levels have crossed a boundary; Q4 2026 and 2026 are still in
progress. The week of 2026-11-30 and the month 2026-11 are open and earlier
than the current ones, so the run pauses on each; the human records both as
not performed. The weeks of 2026-12-07 and 2026-12-14 have no entries at
all: they are gaps. The month level has no gap (November has entries and
December is current). The daily level has nothing open.

**Files written,** the closing ones smallest first, then the daily `start`,
then the boundary `start` reviews from the largest level down:

1. `weekly/2026-11-30-end.md`: `not_performed: true`, no window.
2. `monthly/2026-11-end.md`: `not_performed: true`, no window.
3. `daily/2026-12-21-start.md`: `window_from: 2026-12-04T17:30-05:00`,
   `window_to: 2026-12-21T08:00-05:00`.
4. `monthly/2026-12-start.md`: `window_from: 2026-11-02T08:30-05:00`,
   `window_to: 2026-12-21T08:00-05:00`.
5. `weekly/2026-12-21-start.md`: `window_from: 2026-11-30T08:15-05:00`,
   `window_to: 2026-12-21T08:00-05:00`, and in its body
   `No entries: weeks of 2026-12-07 and 2026-12-14.`

Had the human closed the week of 2026-11-30 late instead, its `end` entry
would cover `2026-11-30T08:15-05:00` to `2026-12-07T00:00-05:00` with
`late: true`, and the new weekly `start` window would open at
`2026-12-07T00:00-05:00`. The gaps are the same either way.
