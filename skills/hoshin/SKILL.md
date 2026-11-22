---
name: hoshin
description: Run the fleet's 方針管理 hōshin kanri review cadence and write its public logbook, as the USER agent. Use when the human starts or ends a working day or period — `/vergil:hoshin start` ("start the day", "hoshin start", "morning review", "chōrei"), `/vergil:hoshin end` ("end of day", "hoshin end", "shūrei") or `/vergil:hoshin end <week|month|quarter|year>` ("close the week", "close the month", "wrap up the quarter"). It works out from the date and the logbook which reviews are due, closes any period left open (late, or recorded as not performed), runs the daily review and any boundary reviews with the human, files the follow-ups they decide on, and hands off one docs PR of dated logbook entries with `vrg-pr-workflow report-ready`, after a mechanical security screen and the human's approval of the full text. It skips merge review on purpose and never submits, merges or releases.
---

# Hoshin

Run the fleet's management cadence: a review at the start of each working day,
an optional one at its end, and reviews at each week, month, quarter and year
boundary, each leaving a dated entry in the public logbook at
`docs/site/docs/logbook/` in `vergil-project/docs`. The method is 方針管理
hōshin kanri, scaled down to one person working with agents; the docs site's
Management section has the background page.

- **`/vergil:hoshin start`** is the main event, run at the start of each
  working day. It closes whatever was left open, then runs the daily 朝礼
  chōrei and opens any new week, month, quarter or year.
- **`/vergil:hoshin end`** is optional and closes the day with the 終礼
  shūrei. **`end week`**, **`end month`**, **`end quarter`** and
  **`end year`** close that period now, with every smaller period still
  open beneath it (反省 hansei; the yearly `end` is the 社長診断 shachō
  shindan). A period `end` does not close is closed by the next `start`.

The rules live in the references; read each one when its step comes:

| Reference | Holds |
| --- | --- |
| [`references/calendar.md`](references/calendar.md) | the time zone, periods, boundaries, closing, gaps, windows and worked examples 1 to 6 |
| [`references/logbook.md`](references/logbook.md) | file names, the entry header and body, index lines, fixed wording, the kaizen prompt, the check format, the stopped-run choices and example 7 |
| [`references/security.md`](references/security.md) | the security rules, the pre-commit screen's patterns and its limit, examples A to D |
| `references/<level>.md` (`daily`, `weekly`, `monthly`, `quarterly`, `yearly`) | each level's `start` and `end` checklist, its data steps written as checks |

Throughout, `<docs>` is the docs repo's main clone and `<logbook>` is
`docs/site/docs/logbook/`. Each run's date and mode, `<date>` and `<mode>`,
come from the configured time zone, never the host clock.

## 1. Preflight

1. **The USER agent.**
   `[ "$(vrg-whoami --mode)" = user ] && echo ok || echo "not user"` must
   print `ok`. If not, stop: this skill runs in the user-agent session.
2. **The arguments.** Exactly one of `start`, `end`, `end week`,
   `end month`, `end quarter` or `end year`. Anything else: stop and show
   the usage line above.
3. **The docs clone, current.** Find the main clone of
   `vergil-project/docs`: a sibling of this session's repo's main clone
   (`<projects-dir>/docs`), or the path the human names. Confirm it with
   `vrg-git remote get-url origin` run inside it. If it cannot be found, ask
   the human; never guess. In `<docs>`, `vrg-git fetch origin`; it must be
   on `develop` with no local changes. If `develop` is behind
   `origin/develop`, fast-forward it (`vrg-git merge --ff-only
   origin/develop`); if it has diverged, is on another branch or is dirty,
   stop and tell the human. The run reads the logbook from this `develop`.
4. **The time zone and now.** Read `Time zone: <IANA zone>` from
   `<logbook>index.md` and compute now and the current week's Monday in that
   zone, as [calendar.md](references/calendar.md#time-zone) says. With no
   valid zone line, stop.
5. **No open logbook PR.**

   ```bash
   vrg-gh pr list --repo vergil-project/docs --state open \
     --json number,title,url --jq '.[] | select(.title | startswith("Logbook:"))'
   ```

   If one is open, stop before any review, name it (its URL and title), and
   tell the human it must merge first, or, if it is failing, be closed with
   its task and the run redone: the logbook on `develop` must be the full
   record before a run can reason about it.
6. **No stale logbook task.** List the docs repo's open tasks under the
   hoshin epic and take those titled `Logbook:`:

   ```bash
   vrg-queue hoshin --json --repo vergil-project/docs --root <projects-dir>
   ```

   Any other open task under the hoshin epic is not a candidate: name it to
   the human and leave it open. Each `Logbook:` task has no open PR (step 5 found none), so it is **stale**, a
   run that stopped or died:
   - If `vrg-git worktree list` in `<docs>` shows no worktree on its
     `feature/<N>-` branch, and `vrg-queue` gives it no `handed-off`
     disposition, close it with the fixed stale comment
     ([logbook.md](references/logbook.md#fixed-wording)) and tell the human
     you did. A local branch it left with no commit past `origin/develop`
     (`vrg-git log origin/develop..<branch>` prints nothing) is deleted with
     `vrg-git branch -D`; one with commits is left, and named to the human.
   - If a worktree is live for it, or it is `handed-off` (reported ready but
     never submitted), stop and ask the human what to do with it. Never
     close or delete it yourself.
7. **Read the logbook** as step 2 says, then refuse, writing nothing:
   - **`start`** when `<logbook>daily/<date>-start.md` already exists (the
     same mode run twice in one day);
   - **`end`** (plain or with a level) when the level it names has no open
     period, as
     [calendar.md](references/calendar.md#end-targets-the-latest-open-period)
     says, naming any smaller level still open;
   - any run whose entry to write already exists.

## 2. Read the logbook

From `<docs>` on `develop`, read:

- for each level, the front matter of its latest `start` entry, of the `end`
  entry for the same period if there is one, and of the latest entry at the
  level that has a window (for its `window_to`). File names sort by period,
  so the latest entries are the last names in the level's directory;
- `<logbook>hoshin.md`, the vital few, which every weekly review checks the
  work against;
- `<logbook>fleet.md`, the fleet's orgs, active or inactive.

A malformed header (missing key, a period that does not match the file name,
a window on a not-performed entry) is an error: stop and show it to the human.
A run never edits an entry already merged.

## 3. Decide what is due

Apply [calendar.md](references/calendar.md) to now and the logbook state:

- **On `start`:** each level's open period earlier than the current one (to
  close), each level whose current period has no `start` (to open), and each
  gap at the week level and above (to name).
- **On `end`:** the latest open period at the named level and every smaller
  level still open beneath it.

Show the human the plan in one message: what is closed, opened and named as a
gap, and each entry's file and window. For each period to close on `start`,
ask: close it now (a late `end` review) or record it as not performed, with
an optional note. At the daily level it is one prompt whose default is "not
performed": an empty answer records it so. At the week level and above,
there is no default.

## 4. Close, then open

First start the
[screen terms](references/security.md#what-the-run-records-for-the-screen);
every review that follows adds to them. Then run the reviews in this fixed
order:

1. **Closing, smallest level first** (the day into the week, the week into
   the month): each late `end` review, and each human-run `end`. A period
   recorded as not performed has no review; it gets the short entry only.
2. **On `start`, the daily 朝礼 chōrei**, so the human knows operations are
   stable before setting direction.
3. **On `start`, the boundary `start` reviews from the largest level down**
   (yearly, quarterly, monthly, weekly), since direction flows top-down and
   each level plans against the one above it.

For each review, read `references/<level>.md` and run its `start` or `end`
section. If that reference or section is missing, stop and tell the human;
never improvise a checklist. Run each check through the `vrg-*` tool its
`Tool:` field names; only a `Tool: none yet` check is gathered ad hoc, with
the `vrg-gh` / `vrg-git` queries it gives. Present the findings for the
entry's window, under the [security rules](references/security.md), and hold
the conversation the level calls for. The yearly and quarterly `start`
reviews set or refresh the vital few in `hoshin.md` by キャッチボール
catchball: the agent proposes, the human adjusts, until both accept.

Every review ends with the [kaizen prompt](references/logbook.md#the-kaizen-prompt).
Then draft its entry in the conversation (the header, the body, and for a
weekly or larger `start` any gaps), following
[logbook.md](references/logbook.md). Nothing is written to disk yet.

## 5. File follow-ups

File the follow-up work the conversation decided on, through the existing
paths, and list each in its entry:

- **A security finding:** a security record, `vrg-security-record create`
  (or the existing record `vrg-security-record list` finds). The entry cites
  its neutral issue's public ref only.
- **Other work:** `vrg-intake-create` (or `vrg-issue-create`
  where the work is already placed). Before it is filed, write its title and
  body to a scratch file outside any worktree and run the
  [screen](references/security.md#the-pre-commit-screen) over them; a hit
  stops that filing and names the match. Then show the human the full title
  and body, and file it only once they approve the text. A security record's
  neutral title and body are public too, and pass the same screen and
  approval.

Never file a follow-up without the human's decision in this run's
conversation.

## 6. Write the entries and hand off

Hand off exactly one docs PR for the run, in this order. Step 1 runs in
`<docs>`; steps 2 to 7 run inside the new worktree,
`<docs>/.worktrees/issue-<N>-logbook`:

1. **File the logbook task and its worktree.** Write the task body (the
   fixed wording: the paths the run will write) to a scratch file, then:

   ```bash
   vrg-issue-create --epic hoshin --repo vergil-project/docs \
     --title "Logbook: <date> <mode>" --body-file <file>
   vrg-git worktree add -b feature/<N>-logbook .worktrees/issue-<N>-logbook origin/develop
   ```

2. **Write the entries and index lines** in the worktree: one file per
   review drafted in step 4, closing ones and not-performed ones included,
   each level's index lines, and any `hoshin.md` change.
3. **Validate** in the worktree: `vrg-container-run -- vrg-validate`, fixing
   every failure, until green. Never suppress a gate.
4. **Screen** the final text of every file the run wrote or changed, with
   every pattern in [security.md](references/security.md#the-patterns). A
   hit stops the run and names each match (file, line, pattern).
5. **Approve.** Show the human the full final text of every entry and of
   every other changed file, and wait for their approval.
6. **Commit** in the worktree:
   `vrg-commit --type docs --scope logbook --message "Logbook: <date> <mode>"`.
7. **Report ready** with the fixed wording
   ([logbook.md](references/logbook.md#fixed-wording)):
   `vrg-pr-workflow report-ready --issue <N> --title "Logbook: <date> <mode>"
   --summary "<entries by path>" --notes "<files by path>"`. It pushes the
   branch; never push it yourself.

**Entry text changes only inside the run.** Any edit after step 5, however
small, goes back through steps 3 to 5 before the commit.

**A run that stops at step 3, 4 or 5** (a validation failure it cannot fix,
a screen hit, the human withholding approval) offers the human two choices,
as [logbook.md](references/logbook.md#a-stopped-run-edit-or-abandon) says:

- **edit** the entry text and loop back to step 3; or
- **abandon**: discard the uncommitted files (`vrg-git reset --hard` and
  `vrg-git clean -fd` in the worktree), remove the worktree
  (`vrg-git worktree remove .worktrees/issue-<N>-logbook`) and its branch
  (`vrg-git branch -D feature/<N>-logbook`) from `<docs>`, and close the task
  with the fixed abandon comment.

Preflight's stale-task rule is the backstop for a run that dies without
either.

Once `report-ready` has succeeded, or the run is abandoned, delete the run's
screen terms directory, `<docs>/build/.vergil-state/hoshin/<date>-<mode>/`.
Then tell the human: *"Ready — run `vrg-submit-pr` to open the logbook PR."*
Stop. The human submitting the PR is the review's sign-off.

## No merge review, by design

A logbook run **skips `merge-review` on purpose**. Merge review is too heavy
for a documentation-generating run, and the gates that matter, mostly keeping
security content out of public records, run inside this skill before
anything is pushed: validation, the mechanical screen and the human's
approval of the full text. The handoff notes therefore carry no merge-review
eligibility line.

- **A submitted logbook PR's task closes through the default finalize:**
  `vrg-finalize-pr`, which `vrg-submit-pr` runs by default after the merge.
- **A failing logbook PR is never fixed in place.** It is closed together
  with its task, and the run is redone through `/vergil:hoshin`. `pr-watch`
  recognises a logbook PR by its `Logbook:` title and stops. A logbook task
  is controlled by its run and is never ad-hoc work: it lives under the
  hoshin epic, which `epic-implement` and `issue-implement` refuse.

## Notes

- The skill runs as the `user` agent and never submits, merges or releases.
  It never opens the PR itself.
- Reviews report on durable state only (git and GitHub today), never on what
  an agent session is doing.
- Every path the run writes is ASCII; Japanese terms appear only in content.
- The logbook is public. [security.md](references/security.md) governs every
  public record the run creates: the entries, the follow-ups, and, through
  the fixed wording, the task, commit and handoff.
