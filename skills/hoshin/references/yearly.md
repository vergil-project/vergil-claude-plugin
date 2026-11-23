# Hoshin: the yearly reviews

The checklists for the yearly level: the `start` review, which sets the
three-to-five-year direction and the year's breakthrough objectives, and the
`end` review, 社長診断 shachō shindan, the president's diagnosis of the year
as a whole. A run reads this file in its step 4 for each yearly review it
runs. Both checklists are thin on purpose: they are a starting point, grown
by kaizen.

Run each checklist as [daily.md](daily.md#how-to-run-a-checklist) says: its
steps in order, each check through its `Tool:` field, `<from>` and `<to>`
the entry's window, every finding under the security rules, and the kaizen
prompt last. A check linked from another level's reference runs as written
there, over this entry's window.

## `start`: the year's direction

The yearly `start` sets the three-to-five-year direction and the year's
breakthrough objectives. On a run that also opens the quarter, the
quarterly `start` that follows turns them into the vital few.

### Checklist

1. Run [Logbook entries in a period](weekly.md#check-logbook-entries-in-a-period)
   for the previous year: its yearly `end` entry (what the system should
   become) and its quarterly `end` entries. On the first run, there are
   none.
2. Run [Fleet shape](#check-fleet-shape) and
   [Open epics and their progress](weekly.md#check-open-epics-and-their-progress).
3. Agree **the three-to-five-year direction** with the human: a few
   sentences on what the fleet is for and what it should be able to do by
   then.
4. Agree **the year's breakthrough objectives**: the few changes that would
   move the fleet furthest towards that direction this year. Record the
   direction and the objectives in the entry's `## Decisions`; the
   quarterly `start` reviews set the vital few against them, by catchball.
5. Ask the kaizen prompt.

### Checks

#### Check: Fleet shape

- **Answers:** what the fleet is made of now: its orgs, active or inactive,
  and each org's repos, archived or not, and by language.
- **Sources:** the fleet roster in `fleet.md`; each fleet org's repos and
  their metadata.
- **Window:** none: the fleet as it stands now. For the yearly `end`, the
  repos created in the year, by their `createdAt`.
- **Output:** per org: its status, and the count of repos, archived and
  not, with their primary languages as counts. Repos created in the window
  by name.
- **Tool:** none yet. Today, for each fleet org:

  ```bash
  vrg-gh repo list <org> --limit 1000 \
    --json nameWithOwner,isArchived,createdAt,primaryLanguage
  ```

  Belongs to `vergil-project/.github#1316` (fleet state).

## `end`: 社長診断 shachō shindan

The shachō shindan looks at the year as a whole, against its direction:
what the system delivered, how it changed, and what it should become.

### Checklist

1. Run [Logbook entries in a period](weekly.md#check-logbook-entries-in-a-period)
   for the year: its yearly `start` entry (the direction and the
   breakthrough objectives) and its quarterly `start` and `end` entries.
2. Run [Delivered in a period](monthly.md#check-delivered-in-a-period) over
   the year's window, and [Delivery rate](monthly.md#check-delivery-rate)
   for the year's months.
3. Run [Fleet shape](#check-fleet-shape) over the year's window.
4. Present **what the system delivered**, against the year's direction and
   breakthrough objectives.
5. Present **how the system changed**: the fleet's shape, the delivery rate
   across the year, and the reviews themselves (what the kaizen notes
   changed in the skill and the tooling, and which checks gained a tool).
6. Hold the diagnosis with the human: **what the system should become**.
   Record it in `## Decisions`; the next yearly `start` reads it.
7. Ask the kaizen prompt.
