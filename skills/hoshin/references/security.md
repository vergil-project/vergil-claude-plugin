# Hoshin security rules and the pre-commit screen

The logbook is published on the public docs site. Nothing a security record
keeps private may appear in it, or in any other public record a run creates.
This file holds the rules, the mechanical screen that enforces them before
anything is committed, and the worked examples.

Every example here uses placeholder names: `<org>`, `<repo>`,
`<alert-number>`, `<advisory-id>`, `<N>`, `<date>`. Never write a real alert number or
advisory ID into this skill or into an example.

## The rules

Each rule is followed by one example of the allowed wording.

1. **A security finding goes into a security record.** A security finding
   raised in a review is recorded with `vrg-security-record create`, details
   in the private advisory and a neutral title and body on its issue. The
   entry refers to it only by the issue's public ref, in abstract terms.

   > Recorded a security finding: `vergil-project/.github#<N>`.

2. **Alerts and advisories appear only as security-record refs.** Security
   alerts and advisories a review reads appear in an entry only as the public
   refs of their security records' neutral issues. An entry carries no alert
   or advisory IDs and no per-repo alert counts or severities; at most a
   single fleet-wide count. Their details stay in the review conversation.

   > 3 open security alerts across the fleet, tracked in
   > `vergil-project/.github#<N>` and `vergil-project/.github#<N>`.

3. **A security-related failure is named only as one.** A failed run whose
   cause is a security finding (a security scan, a dependency audit, the
   GitHub-config audit) is reported only as "a security-related failure",
   with the neutral ref of its security record. If it has no record yet, the
   review creates one first. Nothing else about it appears in a public
   record: no cause, effect, impact, affected artefact or start date. Those
   stay in the review conversation and the private record.

   > `vergil-project/<repo>`: a security-related failure,
   > `vergil-project/.github#<N>`.

4. **No raw security-tool output.** The run never pastes raw output from a
   security tool (a scanner, an audit, a secret or workflow checker) into an
   entry, summarised or not.

   > `vergil-project/<repo>`: a security-related failure,
   > `vergil-project/.github#<N>`.

5. **The rules cover every public record a run creates.** Follow-up issues
   pass the same screen as the entries, and the human approves their text,
   before they are filed. The task, commit and handoff
   use the fixed wording in [logbook.md](logbook.md#fixed-wording), which
   carries no review content.

   > A public follow-up titled "Retry the docs refresh on a transient
   > fetch failure", screened and approved, then filed.

6. **Kaizen notes keep the kind of finding private.** A kaizen note about
   security tooling or security records says nothing about the kind of
   finding any record holds (dependency, code, secret or configuration),
   nor which tool found it.

   > Kaizen: a security record, `vergil-project/.github#<N>`, waited a week
   > for triage.

## Example A: a failed security job

The 朝礼 chōrei finds a failed dependency-audit job in
`vergil-project/<repo>`, caused by a newly published advisory.

- **The review conversation** names the advisory, the package and the
  versions. The run creates a security record for it with
  `vrg-security-record create` (or finds the existing one with
  `vrg-security-record list`), whose neutral issue is
  `vergil-project/.github#<N>`.
- **The entry says only:**

  > `vergil-project/<repo>`: a security-related failure,
  > `vergil-project/.github#<N>`.

  No advisory ID, no package, no severity, no tool output, never the cause.

## The pre-commit screen

The screen runs over the final text of every file the run wrote or changed
(its entries, index lines and any `hoshin.md` change), once
`vrg-container-run -- vrg-validate` is green and before the human's approval
and the commit. It runs again, the same way, over the title and body of every
follow-up issue to be filed, before it is filed. Any hit
stops: the run names each match (file, line and the pattern it hit), commits
nothing, pushes nothing and files nothing. A hit is never waived; it is fixed
by rewording the text and going back through validation, the screen and the
approval.

### What the run records for the screen

While it reviews, the run keeps the **screen terms**: what it read in this
run that may never appear in public. They are written to a private state
directory in the docs main clone, which `build/` keeps out of git, never to
the worktree:

```text
<docs main clone>/build/.vergil-state/hoshin/<date>-<mode>/
  screen-literals.txt   one per line, matched literally, case-insensitive
  screen-numbers.txt    one per line, matched as an alert number
```

- `screen-literals.txt`: every alert URL the review read.
- `screen-numbers.txt`: every alert number the review read.

Numbers are matched only in the forms that can name an alert, never as any
substring, so the dates and times every header and index line carries
(`2026-11-18T08:05-05:00`) never hit: as a bare `#<n>` (with no repo name
before the `#`), or straight after an alert or reference word (`alert`,
`advisory`, `issue`, `PR`, `pull request`, `number`, `no.`, with only
spaces, `#` or `:` between); and never as part of a longer number. A full
reference such as `vergil-project/vergil-tooling#<n>` never hits merely
because an alert shares its number.

Build the numbers' pattern file from its terms, beside them, before the
first screen:

```bash
awk '{ print "(^|[^A-Za-z0-9_.-])#" $0 "([^0-9]|$)"
       print "(^|[^A-Za-z])(alerts?|advisor(y|ies)|issues?|prs?|pull requests?|numbers?|no\\.)[[:space:]#:]*" $0 "([^0-9]|$)" }' \
  screen-numbers.txt > screen-numbers.re
```

The run deletes the directory once the run ends: after `report-ready`, or on
abandon.

### The patterns

These are the screen's patterns, exactly. `<files>` is every file the run
wrote or changed in the worktree; for a follow-up, its title and body written
to a scratch file outside the worktree.

1. **`GHSA-` and `CVE-` IDs.**

   ```bash
   grep -nHiE 'GHSA-|CVE-[0-9]' <files>
   ```

2. **Each alert number and alert URL the review read in this run** (the
   URLs in `screen-literals.txt`, matched literally, and the numbers through
   `screen-numbers.re`):

   ```bash
   grep -nHiF -f screen-literals.txt <files>
   grep -nHiE -f screen-numbers.re <files>
   ```

   Skip a command whose terms file is empty, since an empty pattern file
   matches nothing.
3. **A line pairing a repo name with "alert", "advisory" or a severity word
   next to a number.** A line is a hit when it holds a repo name (any
   `<owner>/<repo>` token, or the bare name of any of
   [the fleet's repos](daily.md#how-to-run-a-checklist)) and an alert word
   or severity word directly next to a number:

   ```bash
   grep -nHiE '[0-9]+[[:space:]]*(alerts?|advisor(y|ies)|critical|high|medium|moderate|low)([^[:alpha:]]|$)|(^|[^[:alpha:]])(alerts?|advisor(y|ies)|critical|high|medium|moderate|low)[[:space:]]*[:=(]?[[:space:]]*[0-9]+' <files>
   ```

   then, of the lines it prints, every one that also holds a repo name.
4. **Any `#N` that does not resolve.** List every reference:

   ```bash
   grep -nHoE '([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+|github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(issues|pull)/[0-9]+' <files>
   ```

   A bare `#N` names no repo, so it never resolves: write every reference as
   `<owner>/<repo>#<N>`. A full reference resolves only when the issue or PR
   exists:

   ```bash
   vrg-gh issue view <N> --repo <owner>/<repo> --json number --jq .number   # exists
   ```

   Any reference that fails the check, or that the run cannot check, is a
   hit. A `#N` that resolves never matches.
5. **Markers of pasted security-tool output.**

   ```bash
   grep -nHE '│|┌|┐|└|┘|├|┤|┬|┴|┼|Total: [0-9]+ \(|(UNKNOWN|LOW|MEDIUM|HIGH|CRITICAL): [0-9]+|[0-9]+ vulnerabilit(y|ies)|RUSTSEC-[0-9]|PYSEC-[0-9]|Vulnerability ID|Installed Version|Fixed Version|RuleID:|Secret:' <files>
   ```

### What the screen does not catch

Alert counts or severities split across lines (a repo name on one line, "3
high" on the next; a table whose header holds the word and whose cells hold
the numbers) are not reliably caught by a pattern. They are left to the
human's approval of the final text, which is why the run shows the human the
full text of every entry before the commit. The screen narrows what reaches
the human; it does not replace their reading.

Rules 3 and 6 are not patterns either. The run checks them itself when it
reviews the full text, before showing it to the human:

- **Rule 3.** A draft line
  "`vergil-project/<repo>`: a security-related failure since `<date>`; its
  releases are blocked, `vergil-project/.github#<N>`" gives the failure's
  start date and effect. The run cuts it to
  "`vergil-project/<repo>`: a security-related failure,
  `vergil-project/.github#<N>`".
- **Rule 6.** A draft kaizen note "The dependency finding in
  `vergil-project/.github#<N>` waited a week for triage" names the kind of
  finding. The run rewrites it as "A security record,
  `vergil-project/.github#<N>`, waited a week for triage".

## Example B: an entry that breaks a security rule

A draft daily `start` entry holds these lines (each placeholder stands for
the real value the review read):

```markdown
- Dependabot raised <advisory-id> against vergil-project/<repo>.
- See <alert-url> for the details.
- vergil-project/<repo>: 3 high alerts open.
- Follow-up filed as #<N>.
- Total: 2 (HIGH: 1, CRITICAL: 1)
- Filed vergil-project/vergil-tooling#<N> for the flaky retry.
```

Here `<advisory-id>` is a real `GHSA-` ID and `<alert-url>` an alert URL the
review read.

The screen stops the run before any commit and names each match:

| Line | Pattern hit |
| --- | --- |
| 1 | 1, a `GHSA-` ID |
| 2 | 2, an alert URL the review read |
| 3 | 3, a repo name with a severity word next to a number |
| 4 | 4, a bare `#N`, which does not resolve |
| 5 | 5, pasted security-tool output |

Line 6 passes: the issue exists, so its `#N` resolves. Nothing is committed
or pushed. The human picks **edit**, the lines are rewritten under the rules
above (line 1 becomes a security-record ref, line 5 is dropped), and the run
goes back through validation, the screen and the approval
([logbook.md](logbook.md#example-7-a-run-stopped-after-filing-its-task)).

## Example C: a follow-up that breaks a security rule

The weekly `start` decides on two follow-ups. Before filing
either, the run writes each one's title and body to a scratch file and runs
the screen over it.

- **"Bump the vulnerable package in `<repo>` to fix
  `<advisory-id>`"** hits pattern 1. The filing stops, and the run names the
  match. The finding goes into a security record instead
  (`vrg-security-record create`, with a neutral title such as "Dependency
  update needed in `<repo>`" that itself passes the screen), and the
  entry cites the record's neutral issue ref.
- **"Add a retry to the docs refresh fetch step"** passes. The run shows the
  human its full title and body; once the human approves the text, it is
  filed (`vrg-intake-create` or `vrg-issue-create`), and the entry lists its
  ref.

No follow-up is filed without both the clean screen and the human's
approval of its text.
