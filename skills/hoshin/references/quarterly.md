# Hoshin: the quarterly reviews

The checklists for the quarterly level: the `start` review, which sets or
refreshes the vital few and plans the quarter's capacity, and the `end`
review, 反省 hansei, reflection on the quarter just finished. A run reads
this file in its step 4 for each quarterly review it runs. Both checklists
are thin on purpose: they are a starting point, grown by kaizen.

Run each checklist as [daily.md](daily.md#how-to-run-a-checklist) says: its
steps in order, each check through its `Tool:` field, `<from>` and `<to>`
the entry's window, every finding under the security rules, and the kaizen
prompt last. A check linked from another level's reference runs as written
there, over this entry's window.

## `start`: the quarter's direction

The quarterly `start` sets or refreshes the vital few by キャッチボール
catchball and plans the quarter's capacity.

### Checklist

1. Run [Logbook entries in a period](weekly.md#check-logbook-entries-in-a-period)
   for the previous quarter: its quarterly `end` entry (what to carry,
   change or drop) and its monthly `end` entries (their rough capacity
   figures). On the first run, there are none.
2. Recall the vital few from `hoshin.md` and, on a run that also opens the
   year, what the yearly `start` just set as the year's breakthrough
   objectives.
3. **Set or refresh the vital few by catchball:** propose three to five
   objectives, each with a line on why it matters and how progress will be
   judged, carrying, changing or dropping last quarter's as its hansei
   decided; the human adjusts, and the exchange repeats until both accept.
   The agreed text replaces the objectives in `hoshin.md`, in this run's
   PR; the entry's `## Decisions` names what changed.
4. Run [Delivery rate](monthly.md#check-delivery-rate) for the last 13
   weeks, [Queue size and age](monthly.md#check-queue-size-and-age) and
   [Open epics and their progress](weekly.md#check-open-epics-and-their-progress).
5. **Plan the quarter's capacity** with the human: from the delivery rate,
   how many tasks and epics the quarter can take; which open epics and
   planning items each objective needs; and what does not fit, to defer.
   Record the plan in `## Decisions`.
6. Ask the kaizen prompt.

## `end`: 反省 hansei

The quarterly hansei compares the quarter's objectives with what was
delivered, and decides what to carry, change or drop.

### Checklist

1. Run [Logbook entries in a period](weekly.md#check-logbook-entries-in-a-period)
   for the quarter: its quarterly `start` entry (the objectives and the
   capacity plan) and its monthly `end` entries.
2. Run [Delivered in a period](monthly.md#check-delivered-in-a-period) over
   the quarter's window, and [Delivery rate](monthly.md#check-delivery-rate)
   for the quarter's weeks.
3. Present **the quarter's objectives against what was delivered**: for
   each objective in `hoshin.md`, the epics, releases and other work that
   moved it, how far it got by the measure its line names, and the
   capacity plan against the delivery rate.
4. Decide with the human, for each objective, **carry, change or drop**,
   with the reason. Record it in `## Decisions`; the next quarterly `start`
   reads it.
5. Ask the kaizen prompt.

The quarterly reviews define no checks of their own: each data step runs a
check defined at the weekly or monthly level, over the quarter's window.
