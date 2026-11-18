# Hoshin security rules and the pre-commit screen

The logbook is published on the public docs site. Nothing a security record
keeps private may appear in it, or in any other public record a run creates.
This file holds the rules, the mechanical screen that enforces them before
anything is committed, and the worked examples.

Every example here uses placeholder names: `<org>`, `<private-repo>`,
`<public-repo>`, `<alert-number>`, `<advisory-id>`, `<N>`. Never write a real
private repo name, alert number or advisory ID into this skill or into an
example.

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
   review creates one first. The cause stays in the review conversation and
   the private record.

   > `vergil-project/<public-repo>`: a security-related failure,
   > `vergil-project/.github#<N>`.

4. **No raw security-tool output.** The run never pastes raw output from a
   security tool (a scanner, an audit, a secret or workflow checker) into an
   entry, summarised or not.

   > The dependency audit failed in one public repo: a security-related
   > failure, `vergil-project/.github#<N>`.

5. **Private repositories appear only as counts per org.** Before writing,
   the run checks each repo's visibility. A public repo is reported in
   detail. A private repo appears only as counts per org: no name, no PR or
   issue titles or numbers, no failure details. Its follow-up work is filed
   in the private repo itself, and the entry gives only the count of such
   follow-ups.

   > `<org>`: 1 failed run in a private repo; 1 follow-up filed there.

6. **The rules cover every public record a run creates.** Follow-up issues
   in public repos pass the same screen as the entries, and the human
   approves their text, before they are filed. The task, commit and handoff
   use the fixed wording in [logbook.md](logbook.md#fixed-wording), which
   carries no review content.

   > A public follow-up titled "Retry the docs refresh on a transient
   > fetch failure", screened and approved, then filed.

### Checking visibility

Read the fleet's orgs from `logbook/fleet.md`, and each org's repos and their
visibility with:

```bash
vrg-gh repo list <org> --limit 1000 --json nameWithOwner,visibility
```

Do this before any review gathers data, so every repo is known to be public or
private before anything about it is written down. A repo whose visibility the
run cannot read is treated as private, and the run says so.

## Example A: a failed run in a private repo

The 朝礼 chōrei finds that a scheduled `ops.yml` run failed overnight in a
private repo of `<org>`, and the review decides to file a follow-up.

- **The review conversation** (private, never written to the logbook) names
  `<private-repo>`, the workflow, the failing step and its cause, and the
  follow-up is filed in `<private-repo>` itself.
- **The entry says only:**

  > `<org>`: 1 failed run in a private repo; 1 follow-up filed there.

  No repo name, no workflow name, no cause, no issue ref.

## Example B: a failed security job in a public repo

The chōrei finds a failed dependency-audit job in
`vergil-project/<public-repo>`, caused by a newly published advisory.

- **The review conversation** names the advisory, the package and the
  versions. The run creates a security record for it with
  `vrg-security-record create` (or finds the existing one with
  `vrg-security-record list`), whose neutral issue is
  `vergil-project/.github#<N>`.
- **The entry says only:**

  > `vergil-project/<public-repo>`: a security-related failure,
  > `vergil-project/.github#<N>`.

  No advisory ID, no package, no severity, no tool output, never the cause.

## The pre-commit screen

The screen runs over the final text of every file the run wrote or changed
(its entries, index lines and any `hoshin.md` change), once
`vrg-container-run -- vrg-validate` is green and before the human's approval
and the commit. It runs again, the same way, over the title and body of every
follow-up issue to be filed in a public repo, before it is filed. Any hit
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
  screen-names.txt      one per line, matched as a whole name
  screen-numbers.txt    one per line, matched as a reference or alert number
```

- `screen-literals.txt`: every alert URL the review read; every
  `<org>/<repo>` of a private repo from the visibility check; every title
  of a private repo's PR or issue the review read.
- `screen-names.txt`: the bare `<repo>` name of every private repo from the
  visibility check.
- `screen-numbers.txt`: every alert number the review read; every number of
  a private repo's PR or issue the review read.

Names and numbers are matched only in the forms that can name the thing,
never as any substring, so the dates and times every header and index line
carries (`2026-11-18T08:05-05:00`), the allowed per-org counts (`1 failed
run in a private repo`) and a public repo whose name merely contains a
private one never hit:

- **a bare name** only as a whole name: not inside a longer name, so a
  letter, digit, `_`, `-` or `.` on its left, or a letter, digit, `_` or
  `-` on its right, rules a match out;
- **a number** only as a reference or an alert number: as a bare `#<n>`
  (with no repo name before the `#`), or straight after an alert or
  reference word (`alert`, `advisory`, `issue`, `PR`, `pull request`,
  `number`, `no.`, with only spaces, `#` or `:` between); and never as part
  of a longer number. A full reference or URL to a private repo
  (`<org>/<private-repo>#<n>`, `.../<private-repo>/issues/<n>`) already
  hits on the repo's name and on pattern 6, so a public reference such as
  `vergil-project/vergil-tooling#<n>` never hits merely because a private
  issue shares its number.

Build their pattern files from the terms, beside them, before the first
screen:

```bash
awk '{ gsub(/\./, "\\."); print "(^|[^A-Za-z0-9_.-])" $0 "([^A-Za-z0-9_-]|$)" }' \
  screen-names.txt > screen-names.re
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

2. **Each alert number and alert URL the review read in this run**, matched
   literally (the URLs in `screen-literals.txt`, the numbers through
   `screen-numbers.re`, below).
3. **Each private repo name** from the visibility check, matched literally
   (`<org>/<repo>` in `screen-literals.txt`, the bare name through
   `screen-names.re`):

   ```bash
   grep -nHiF -f screen-literals.txt <files>
   grep -nHiE -f screen-names.re <files>
   grep -nHiE -f screen-numbers.re <files>
   ```

   These three commands also cover patterns 2 and 5. Skip a command whose
   terms file is empty, since an empty pattern file matches nothing.
4. **A line pairing a repo name with "alert", "advisory" or a severity word
   next to a number.** A line is a hit when it holds a repo name (any
   `<owner>/<repo>` token, or the bare name of any repo the visibility check
   listed) and an alert word or severity word directly next to a number:

   ```bash
   grep -nHiE '[0-9]+[[:space:]]*(alerts?|advisor(y|ies)|critical|high|medium|moderate|low)([^[:alpha:]]|$)|(^|[^[:alpha:]])(alerts?|advisor(y|ies)|critical|high|medium|moderate|low)[[:space:]]*[:=(]?[[:space:]]*[0-9]+' <files>
   ```

   then, of the lines it prints, every one that also holds a repo name.
5. **Each private repo PR or issue title and number read in this run**,
   matched literally (in the terms files, above).
6. **Any `#N` that does not resolve to a public repo.** List every reference:

   ```bash
   grep -nHoE '([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+|github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(issues|pull)/[0-9]+' <files>
   ```

   A bare `#N` names no repo, so it never resolves: write every reference as
   `<owner>/<repo>#<N>`. A full reference resolves only when the repo is
   public and the issue or PR exists:

   ```bash
   vrg-gh repo view <owner>/<repo> --json visibility --jq .visibility   # PUBLIC
   vrg-gh api repos/<owner>/<repo>/issues/<N> --jq .number              # exists
   ```

   Any reference that fails either check, or that the run cannot check, is a
   hit. A `#N` that resolves to a public repo never matches.
7. **Markers of pasted security-tool output.**

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

## Example C: an entry that breaks a security rule

A draft daily `start` entry holds these lines (each placeholder stands for
the real value the review read):

```markdown
- Dependabot raised <advisory-id> against vergil-project/<public-repo>.
- See <alert-url> for the details.
- <private-repo>: the nightly CD build failed.
- vergil-project/<public-repo>: 3 high alerts open.
- The fix for "<private-issue-title>" is waiting on review.
- Follow-up filed as #<N>.
- Total: 2 (HIGH: 1, CRITICAL: 1)
- Filed vergil-project/vergil-tooling#<N> for the flaky retry.
```

Here `<advisory-id>` is a real `GHSA-` ID, `<alert-url>` an alert URL the
review read, `<private-repo>` a repo the visibility check found private, and
`<private-issue-title>` the title of an issue the review read in it.

The screen stops the run before any commit and names each match:

| Line | Pattern hit |
| --- | --- |
| 1 | 1, a `GHSA-` ID |
| 2 | 2, an alert URL the review read |
| 3 | 3, a private repo name |
| 4 | 4, a repo name with a severity word next to a number |
| 5 | 5, a private repo's issue title the review read |
| 6 | 6, a bare `#N`, which does not resolve to a public repo |
| 7 | 7, pasted security-tool output |

Line 8 passes: `vergil-project/vergil-tooling` is public and the issue
exists, so its `#N` resolves. Nothing is committed or pushed. The human picks
**edit**, the lines are rewritten under the rules above (line 1 becomes a
security-record ref, line 3 a per-org count, line 7 is dropped), and the run
goes back through validation, the screen and the approval
([logbook.md](logbook.md#example-7-a-run-stopped-after-filing-its-task)).

## Example D: a follow-up that breaks a security rule

The weekly `start` decides on two follow-ups in public repos. Before filing
either, the run writes each one's title and body to a scratch file and runs
the screen over it.

- **"Bump the vulnerable package in `<public-repo>` to fix
  `<advisory-id>`"** hits pattern 1. The filing stops, and the run names the
  match. The finding goes into a security record instead
  (`vrg-security-record create`, with a neutral title such as "Dependency
  update needed in `<public-repo>`" that itself passes the screen), and the
  entry cites the record's neutral issue ref.
- **"Add a retry to the docs refresh fetch step"** passes. The run shows the
  human its full title and body; once the human approves the text, it is
  filed (`vrg-intake-create` or `vrg-issue-create`), and the entry lists its
  ref.

No public follow-up is filed without both the clean screen and the human's
approval of its text.
