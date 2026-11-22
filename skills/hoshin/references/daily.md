# Hoshin: the daily reviews

The checklists for the daily level, 日常管理 nichijō kanri: the `start`
review, 朝礼 chōrei, and the `end` review, 終礼 shūrei. A run reads this file
in its step 4 for each daily review it runs. Both checklists are thin on
purpose: they are a starting point, grown by kaizen.

## How to run a checklist

- Run the checklist's steps in order. A data step names a check; run the
  check as its `Tool:` field says
  ([logbook.md](logbook.md#the-check-format)): through the named `vrg-*`
  tool, or, for `Tool: none yet`, through the queries it gives.
- `<from>` and `<to>` are the entry's `window_from` and `window_to`
  ([calendar.md](calendar.md#windows)), written in queries as ISO 8601 times
  with seconds and offset (`2026-11-17T18:42:00-05:00`). The GitHub search
  and run filters take them as a range, `"<from>..<to>"`.
- **The fleet** is every org in `fleet.md`, inactive ones included, since
  anything that ran there is a finding. **The fleet's repos** are each fleet
  org's repos, archived ones excluded:
  `vrg-gh repo list <org> --limit 1000 --no-archived --json nameWithOwner`.
- `<projects-dir>` is the directory holding the human's main clones, as
  `SKILL.md` preflight finds it; each org's clones sit under it.
- Every finding is presented under the
  [security rules](security.md#the-rules): a security-related failure only
  as one, with its security record's neutral ref; no alert or advisory IDs
  and no raw security-tool output in the entry. The review conversation may
  name what the entry may not.
- Record in the screen terms
  ([security.md](security.md#what-the-run-records-for-the-screen)) every
  alert number or URL a check reads.
- Every review ends with the
  [kaizen prompt](logbook.md#the-kaizen-prompt).

## `start`: 朝礼 chōrei

The chōrei reviews the unattended work since the last entry, across the
fleet, so the human knows operations are stable before setting direction,
and settles what needs action today.

### Checklist

1. Run [Failed and cancelled runs](#check-failed-and-cancelled-runs).
2. Run [Automation PRs](#check-automation-prs).
3. Run [Releases cut](#check-releases-cut).
4. Run [Security and audit signals](#check-security-and-audit-signals) and
   [Open security records](#check-open-security-records).
5. Present the findings, then agree with the human **what needs action
   today**: each failure to fix, PR to unstick or record to work, and who
   or what takes it. File the follow-ups decided on through `SKILL.md`
   step 5.
6. Ask the kaizen prompt.

### Checks

#### Check: Failed and cancelled runs

- **Answers:** which workflow runs in the fleet failed or were cancelled in
  the window, and why each failed.
- **Sources:** the GitHub Actions runs of every fleet repo: CD builds, the
  `ops.yml` audit, the epic rollup and sweep, and every other scheduled or
  event-driven workflow.
- **Window:** runs created from `<from>` to `<to>`.
- **Output:** one line per failed or cancelled run: repo, workflow, event,
  conclusion, and the failed job with a one-line cause (a rerun that later
  passed says so). A run whose cause is a security finding (a security scan,
  a dependency audit, the GitHub-config audit) is only "a security-related
  failure" with its security record's neutral ref, creating the record first
  if it has none ([security.md](security.md#example-a-a-failed-security-job)).
  With none, the entry says `No failed or cancelled runs in the window.`
- **Tool:** none yet. Today, for each fleet repo:

  ```bash
  vrg-gh run list --repo <owner>/<repo> --created "<from>..<to>" --limit 200 \
    --json databaseId,workflowName,event,conclusion,headBranch,createdAt,url \
    --jq '.[] | select(.conclusion == "failure" or .conclusion == "cancelled"
      or .conclusion == "startup_failure" or .conclusion == "timed_out")'
  vrg-gh run view <databaseId> --repo <owner>/<repo> --json jobs \
    --jq '.jobs[] | select(.conclusion == "failure") | {name, steps: [.steps[] | select(.conclusion == "failure") | .name]}'
  vrg-gh run view <databaseId> --repo <owner>/<repo> --log-failed
  ```

  A list that returns 200 runs is truncated: narrow the range and repeat.
  The failed log is read in the review conversation only, never quoted into
  the entry. Belongs to `vergil-project/.github#1317` (history).

#### Check: Automation PRs

- **Answers:** which automation-authored PRs (dependency updates, upstream
  refreshes, version adds and drops, release back-merges) merged in the
  window, which are still open, and which of those are stuck.
- **Sources:** pull requests in every fleet org authored by a GitHub App
  (author type `Bot`: the org's automation App and Dependabot), with their
  checks.
- **Window:** merged from `<from>` to `<to>`; open PRs as they stand now.
  An open PR is **stuck** when its checks are failing, it has merge
  conflicts, or it has had no update for more than a day.
- **Output:** the count merged per repo, and one line per open PR: repo,
  number, title, age, and for a stuck one why.
- **Tool:** none yet. Today, for each fleet org:

  ```bash
  vrg-gh search prs --owner <org> --merged-at "<from>..<to>" --limit 1000 \
    --json repository,number,title,author,closedAt,url \
    --jq '.[] | select(.author.type == "Bot")'
  vrg-gh search prs --owner <org> --state open --limit 1000 \
    --json repository,number,title,author,createdAt,updatedAt,url \
    --jq '.[] | select(.author.type == "Bot")'
  vrg-gh pr view <number> --repo <owner>/<repo> \
    --json mergeable,mergeStateStatus,statusCheckRollup,autoMergeRequest
  ```

  Belongs to `vergil-project/.github#1317` (history) for the merged PRs and
  `vergil-project/.github#1140` (org state) for the open and stuck ones.

#### Check: Releases cut

- **Answers:** which releases were published in the fleet in the window.
- **Sources:** the GitHub releases of every fleet repo.
- **Window:** published from `<from>` to `<to>`.
- **Output:** one line per release: repo and tag. With none,
  `No releases in the window.`
- **Tool:** none yet. Today, for each fleet repo:

  ```bash
  vrg-gh release list --repo <owner>/<repo> --limit 1000 \
    --json tagName,name,publishedAt,isDraft,isPrerelease \
    --jq '.[] | select(.isDraft | not)'
  ```

  keeping each release whose `publishedAt` falls in the window. A result of
  1000 is truncated, and the review says so. Belongs to
  `vergil-project/.github#1317` (history).

#### Check: Security and audit signals

- **Answers:** whether the nightly GitHub-config audit or the Dependabot
  alert audit raised anything new in the window, in which repos.
- **Sources:** the `ops.yml` runs of every fleet repo, whose reusable
  `ops-github-config.yml` workflow runs `vrg-github-repo-config update` and
  `vrg-dependabot-audit`; a red step in either is the signal. The user
  agent's token cannot read alerts directly, so the run's conclusion is the
  source.
- **Window:** `ops.yml` runs created from `<from>` to `<to>`; a repo whose
  latest run in the window failed where its previous run passed is new.
- **Output:** a single fleet-wide count of repos with an audit or alert
  signal, and each one as "a security-related failure" with the neutral ref
  of its security record, which the review finds with
  `vrg-security-record list` or creates with `vrg-security-record create`.
  Never an alert count, a severity, an
  alert number or the audit's output.
- **Tool:** none yet. Today, for each fleet repo:

  ```bash
  vrg-gh run list --repo <owner>/<repo> --workflow ops.yml \
    --created "<from>..<to>" --limit 20 \
    --json databaseId,conclusion,createdAt,url
  vrg-gh run list --repo <owner>/<repo> --workflow ops.yml --limit 2 \
    --json databaseId,conclusion,createdAt
  vrg-gh run view <databaseId> --repo <owner>/<repo> --json jobs \
    --jq '.jobs[] | {name, conclusion, steps: [.steps[] | select(.conclusion == "failure") | .name]}'
  ```

  Belongs to `vergil-project/.github#1316` (fleet state).

#### Check: Open security records

- **Answers:** which security records are open, so every signal above is
  matched to its record and none is reported without one.
- **Sources:** the draft security advisories in each fleet org's `.github`
  and their neutral issues.
- **Window:** none: the records open now.
- **Output:** the count of open records across the fleet, and the neutral
  issue ref of each one this review's findings touch. Never an advisory ID
  or its text.
- **Tool:** `vrg-security-record list --state draft`, run from inside a
  clone of a repo in each fleet org (it finds the org from that clone's
  `origin`). It prints advisory IDs: they stay in the review conversation
  and go into the screen terms.

## `end`: 終礼 shūrei

The shūrei closes the day: what the durable record shows changed, what is
waiting on the human, what failed, and a note for tomorrow's chōrei.

### Checklist

1. Run [Merged PRs](#check-merged-prs), [Closed issues and
   epics](#check-closed-issues-and-epics) and
   [Releases cut](#check-releases-cut).
2. Run [Handed-off work](#check-handed-off-work) and
   [Rulings awaiting the human](#check-rulings-awaiting-the-human).
3. Run [Failed and cancelled runs](#check-failed-and-cancelled-runs) and
   [Security and audit signals](#check-security-and-audit-signals) over
   the day's window.
4. Present the findings, then agree with the human **a note for tomorrow's
   chōrei**: what to look at first, and anything left half-done.
5. Ask the kaizen prompt.

### Checks

#### Check: Merged PRs

- **Answers:** which PRs merged in the fleet in the window, by whom
  (human-submitted or automation-authored).
- **Sources:** pull requests in every fleet org.
- **Window:** merged from `<from>` to `<to>`.
- **Output:** the count per repo and one line per human-submitted PR (repo,
  number, title), with automation PRs as a count per repo.
- **Tool:** none yet. Today, for each fleet org:

  ```bash
  vrg-gh search prs --owner <org> --merged-at "<from>..<to>" --limit 1000 \
    --json repository,number,title,author,closedAt,url
  ```

  A result of 1000 is truncated: split the range and repeat. Belongs to
  `vergil-project/.github#1317` (history).

#### Check: Closed issues and epics

- **Answers:** which issues and epics closed in the fleet in the window.
- **Sources:** closed issues in every fleet org.
- **Window:** the days the window touches, from `<from>`'s day to `<to>`'s
  day; the tool groups by day.
- **Output:** each closed epic by ref and title, and the count of other
  issues closed per repo.
- **Tool:** `vrg-activity-log --org <org>`, for each active fleet org,
  reading only the days in the window. Its window is the last 30 days; a
  warning that it hit its result cap marks the oldest days incomplete, which
  a daily window never reaches.

#### Check: Handed-off work

- **Answers:** what work is waiting on the human to submit or merge:
  reported-ready branches not yet submitted, and submitted PRs not yet
  merged.
- **Sources:** each main clone's worktrees and their workflow state, the
  relay refs (`refs/vergil/pr-workflow/<branch>`) that `report-ready`
  pushes to each repo's origin, and the open PRs on each origin.
- **Window:** none: the state now.
- **Output:** one line per item: repo, branch or PR, its issue, and how
  long it has waited.
- **Tool:** `vrg-repo-status`, run in each main clone under
  `<projects-dir>`: its Development table shows each worktree's PR and
  workflow state, and its open-PR table the PRs no local worktree backs.
  It reads local clones only: a branch reported ready from a VM shows only
  in the relay refs, so also run, in each main clone,
  `vrg-git ls-remote origin 'refs/vergil/pr-workflow/*'`.

#### Check: Rulings awaiting the human

- **Answers:** which issues in the fleet hold a ruling request, or items
  listed under `Awaiting a ruling`, that the human has not yet answered.
- **Sources:** comments on open issues in every fleet org: a ruling
  request ends with the marker `<!-- vrg-ruling kind=request -->`, and its
  response with `<!-- vrg-ruling kind=response request=<id> reply=<id> -->`;
  a non-review item is a list under `Awaiting a ruling` with no later
  `Human ruling:` line from a trusted author.
- **Window:** none: the requests open now.
- **Output:** one line per issue: ref, title and what kind of ruling it
  waits for.
- **Tool:** none yet. Today, for each fleet org:

  ```bash
  vrg-gh search issues "\"Awaiting a ruling\"" --owner <org> --state open \
    --limit 200 --json repository,number,title,url
  vrg-gh issue view <number> --repo <owner>/<repo> \
    --json comments --jq '.comments[] | {author: .author.login, createdAt, body}'
  ```

  and, for merge-review requests, each main clone's
  `build/.vergil-state/issue-implement/<N>/merge-review/open-request.json`.
  A request counts as waiting when no response marker names its ID.
  Belongs to `vergil-project/.github#1316` (fleet state).
