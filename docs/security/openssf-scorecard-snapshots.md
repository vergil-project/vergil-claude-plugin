# OpenSSF Scorecard snapshots

Point-in-time [OpenSSF Scorecard](https://github.com/ossf/scorecard) captures for
this repository. A Scorecard result is a report of security posture at one
commit, not an open work item — so we capture it here as dated snapshots and
re-run it on a cadence, rather than accreting findings in the issue tracker.

**Remediation is tracked separately.** This document is the *record*, not the
work. The actual OpenSSF hardening work lives in epic
[vergil-project/.github#54](https://github.com/vergil-project/.github/issues/54),
tracking issue
[vergil-project/vergil-tooling#828](https://github.com/vergil-project/vergil-tooling/issues/828).

## How to add a snapshot

Re-run the Scorecard from a checkout of this repo and append a new dated section
at the top of [Snapshots](#snapshots) (newest first), then add a row to the
[trend table](#trend):

```bash
vrg-scorecard --repo=github.com/vergil-project/vergil-claude-plugin --show-details
```

Record, for each snapshot: the aggregate score, the evaluated commit SHA, the
Scorecard version, the per-check table, and the detailed findings. Cadence:
roughly quarterly, or after any deliberate hardening change worth measuring.

## Trend

| Date | Aggregate | Commit | Scorecard |
|------|-----------|--------|-----------|
| 2026-08-12 | 5.0 / 10 | `f304ca9d3627` | v5.5.0 |
| 2026-05-19 | 4.6 / 10 | `a8c25cc6a81c` | v5.5.0 |

Score legend: 🟢 10/10 · 🔴 0–9/10 (needs work) · ⚪ -1/10 (not applicable /
not detected).

## Snapshots

### 2026-08-12

**Aggregate score:** 5.0 / 10
**Commit:** `f304ca9d3627ec7ac09f2f6b617f778028255015`
**Scorecard version:** v5.5.0
**Tracking issue:**
[vergil-project/vergil-tooling#828](https://github.com/vergil-project/vergil-tooling/issues/828)

#### Changes since the 2026-05-19 baseline

The aggregate rose 4.6 → 5.0. Movement by check:

- **Maintained** 0 → 10 — the repo is no longer "created within the last 90
  days"; 30 commits and 7 issue activity in the trailing 90 days now score it.
- **Signed-Releases** -1 → 0 — releases now exist (v2.1.34–v2.1.38), so the
  check applies; none are signed or carry provenance, hence 0.
- **CI-Tests** 20/20 (was 15/15) and **Code-Review** 0/20 (was 0/12) — same
  scores, larger merged-PR sample.

All other checks are unchanged from the baseline.

#### Scores by check

| Score | Check | Reason |
|-------|-------|--------|
| ⚪ -1/10 | Packaging | packaging workflow not detected |
| 🔴 0/10 | Signed-Releases | releases exist but none are signed or carry provenance |
| 🔴 0/10 | CII-Best-Practices | no effort to earn an OpenSSF best practices badge detected |
| 🔴 0/10 | Code-Review | Found 0/20 approved changesets |
| 🔴 0/10 | Contributors | project has 0 contributing companies or organizations |
| 🔴 0/10 | Dependency-Update-Tool | no update tool detected |
| 🔴 0/10 | Fuzzing | project is not fuzzed |
| 🔴 0/10 | Pinned-Dependencies | dependency not pinned by hash detected |
| 🔴 0/10 | Token-Permissions | detected GitHub workflow tokens with excessive permissions |
| 🔴 4/10 | Branch-Protection | branch protection is not maximal on development and all release branches |
| 🟢 10/10 | Binary-Artifacts | no binaries found in the repo |
| 🟢 10/10 | CI-Tests | 20 out of 20 merged PRs checked by a CI test |
| 🟢 10/10 | Dangerous-Workflow | no dangerous workflow patterns detected |
| 🟢 10/10 | License | license file detected (MIT) |
| 🟢 10/10 | Maintained | 30 commits and 7 issue activity in the last 90 days |
| 🟢 10/10 | SAST | SAST tool is run on all commits |
| 🟢 10/10 | Security-Policy | security policy file detected |
| 🟢 10/10 | Vulnerabilities | 0 existing vulnerabilities detected |

#### Detailed findings

##### Packaging (-1/10)

**Reason:** packaging workflow not detected

**Warnings:**
- `no GitHub/GitLab publishing workflow detected.`

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#packaging

##### Signed-Releases (0/10)

**Reason:** Project has not signed or included provenance with any releases.

**Warnings:**
- `release artifacts v2.1.34–v2.1.38 not signed`
- `release artifacts v2.1.34–v2.1.38 do not have provenance`

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#signed-releases

##### CII-Best-Practices (0/10)

**Reason:** no effort to earn an OpenSSF best practices badge detected

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#cii-best-practices

##### Code-Review (0/10)

**Reason:** Found 0/20 approved changesets -- score normalized to 0

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#code-review

##### Contributors (0/10)

**Reason:** project has 0 contributing companies or organizations -- score normalized to 0

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#contributors

##### Dependency-Update-Tool (0/10)

**Reason:** no update tool detected

**Warnings:**
- `no dependency update tool configurations found`

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#dependency-update-tool

##### Fuzzing (0/10)

**Reason:** project is not fuzzed

**Warnings:**
- `no fuzzer integrations found`

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#fuzzing

##### Pinned-Dependencies (0/10)

**Reason:** dependency not pinned by hash detected -- score normalized to 0

**Warnings:**
- `third-party GitHubAction not pinned by hash: .github/workflows/cd.yml:21`
- `third-party GitHubAction not pinned by hash: .github/workflows/cd.yml:27`
- `third-party GitHubAction not pinned by hash: .github/workflows/ci.yml:24`
- `third-party GitHubAction not pinned by hash: .github/workflows/ci.yml:27`
- `third-party GitHubAction not pinned by hash: .github/workflows/ci.yml:35`
- `third-party GitHubAction not pinned by hash: .github/workflows/ci.yml:51`
- `third-party GitHubAction not pinned by hash: .github/workflows/epic-rollup.yml:20`

<details><summary>Info details</summary>

- `0 out of 7 third-party GitHubAction dependencies pinned`

Remediation helper (pin by hash): https://app.stepsecurity.io/securerepo

</details>

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#pinned-dependencies

##### Token-Permissions (0/10)

**Reason:** detected GitHub workflow tokens with excessive permissions

**Warnings:**
- `topLevel 'contents' permission set to 'write': .github/workflows/cd.yml:15`
- `jobLevel 'contents' permission set to 'write': .github/workflows/cd.yml:23`
- `jobLevel 'security-events' permission set to 'write': .github/workflows/ci.yml:45`

<details><summary>Info details</summary>

- `ci.yml and epic-rollup.yml top-level tokens are scoped to 'contents: read'`
- `ci.yml grants 'actions: read' and 'security-events: write' only at the job that needs them`

</details>

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#token-permissions

##### Branch-Protection (4/10)

**Reason:** branch protection is not maximal on development and all release branches

**Warnings:**
- `branch 'develop' does not require approvers`
- `codeowners review is not required on branch 'develop'`
- `'last push approval' is disabled on branch 'develop'`

<details><summary>Info details</summary>

- `'allow deletion' disabled on branch 'develop'`
- `'force pushes' disabled on branch 'develop'`
- `'branch protection settings apply to administrators' is required to merge on branch 'develop'`
- `'stale review dismissal' is required to merge on branch 'develop'`
- `'up-to-date branches' is required to merge on branch 'develop'`
- `status check found to merge onto on branch 'develop'`
- `PRs are required in order to make changes on branch 'develop'`

</details>

**Documentation:** https://github.com/ossf/scorecard/blob/main/docs/checks.md#branch-protection

---

### 2026-05-19 (baseline)

**Aggregate score:** 4.6 / 10
**Commit:** `a8c25cc6a81c`
**Scorecard version:** v5.5.0
**Tracking issue:**
[vergil-project/vergil-tooling#828](https://github.com/vergil-project/vergil-tooling/issues/828)

> First captured snapshot, preserved from the tracking issue
> ([#351](https://github.com/vergil-project/vergil-claude-plugin/issues/351)).

#### Scores by check

| Score | Check | Reason |
|-------|-------|--------|
| ⚪ -1/10 | Packaging | packaging workflow not detected |
| ⚪ -1/10 | Signed-Releases | no releases found |
| 🔴 0/10 | CII-Best-Practices | no effort to earn an OpenSSF best practices badge detected |
| 🔴 0/10 | Code-Review | Found 0/12 approved changesets |
| 🔴 0/10 | Contributors | project has 0 contributing companies or organizations |
| 🔴 0/10 | Dependency-Update-Tool | no update tool detected |
| 🔴 0/10 | Fuzzing | project is not fuzzed |
| 🔴 0/10 | Maintained | project was created within the last 90 days. Please review its contents carefully |
| 🔴 0/10 | Pinned-Dependencies | dependency not pinned by hash detected |
| 🔴 0/10 | Token-Permissions | detected GitHub workflow tokens with excessive permissions |
| 🔴 4/10 | Branch-Protection | branch protection is not maximal on development and all release branches |
| 🟢 10/10 | Binary-Artifacts | no binaries found in the repo |
| 🟢 10/10 | CI-Tests | 15 out of 15 merged PRs checked by a CI test |
| 🟢 10/10 | Dangerous-Workflow | no dangerous workflow patterns detected |
| 🟢 10/10 | License | license file detected |
| 🟢 10/10 | SAST | SAST tool is run on all commits |
| 🟢 10/10 | Security-Policy | security policy file detected |
| 🟢 10/10 | Vulnerabilities | 0 existing vulnerabilities detected |

#### Detailed findings

##### Packaging (-1/10)

**Reason:** packaging workflow not detected

**Warnings:**
- `no GitHub/GitLab publishing workflow detected.`

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#packaging

##### Signed-Releases (-1/10)

**Reason:** no releases found

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#signed-releases

##### CII-Best-Practices (0/10)

**Reason:** no effort to earn an OpenSSF best practices badge detected

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#cii-best-practices

##### Code-Review (0/10)

**Reason:** Found 0/12 approved changesets -- score normalized to 0

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#code-review

##### Contributors (0/10)

**Reason:** project has 0 contributing companies or organizations -- score normalized to 0

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#contributors

##### Dependency-Update-Tool (0/10)

**Reason:** no update tool detected

**Warnings:**
- `no dependency update tool configurations found`

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#dependency-update-tool

##### Fuzzing (0/10)

**Reason:** project is not fuzzed

**Warnings:**
- `no fuzzer integrations found`

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#fuzzing

##### Maintained (0/10)

**Reason:** project was created within the last 90 days. Please review its contents carefully

**Warnings:**
- `Repository was created within the last 90 days.`

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#maintained

##### Pinned-Dependencies (0/10)

**Reason:** dependency not pinned by hash detected -- score normalized to 0

**Warnings:**
- `third-party GitHubAction not pinned by hash: .github/workflows/cd.yml:17`
- `third-party GitHubAction not pinned by hash: .github/workflows/cd.yml:23`
- `GitHub-owned GitHubAction not pinned by hash: .github/workflows/ci.yml:28`
- `GitHub-owned GitHubAction not pinned by hash: .github/workflows/ci.yml:31`
- `third-party GitHubAction not pinned by hash: .github/workflows/ci.yml:43`
- `third-party GitHubAction not pinned by hash: .github/workflows/ci.yml:50`
- `third-party GitHubAction not pinned by hash: .github/workflows/ci.yml:61`
- `pipCommand not pinned by hash: .github/workflows/ci.yml:37`

<details><summary>Info details (3 items)</summary>

- `0 out of 2 GitHub-owned GitHubAction dependencies pinned`
- `0 out of 5 third-party GitHubAction dependencies pinned`
- `0 out of 1 pipCommand dependencies pinned`

</details>

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#pinned-dependencies

##### Token-Permissions (0/10)

**Reason:** detected GitHub workflow tokens with excessive permissions

**Warnings:**
- `jobLevel 'contents' permission set to 'write': .github/workflows/cd.yml:19`
- `jobLevel 'security-events' permission set to 'write': .github/workflows/ci.yml:58`
- `topLevel 'contents' permission set to 'write': .github/workflows/cd.yml:11`

<details><summary>Info details (2 items)</summary>

- `jobLevel 'contents' permission set to 'read': .github/workflows/ci.yml:57`
- `topLevel 'contents' permission set to 'read': .github/workflows/ci.yml:16`

</details>

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#token-permissions

##### Branch-Protection (4/10)

**Reason:** branch protection is not maximal on development and all release branches

**Warnings:**
- `branch 'develop' does not require approvers`
- `codeowners review is not required on branch 'develop'`
- `'last push approval' is disabled on branch 'develop'`

<details><summary>Info details (7 items)</summary>

- `'allow deletion' disabled on branch 'develop'`
- `'force pushes' disabled on branch 'develop'`
- `'branch protection settings apply to administrators' is required to merge on branch 'develop'`
- `'stale review dismissal' is required to merge on branch 'develop'`
- `'up-to-date branches' is required to merge on branch 'develop'`
- `status check found to merge onto on branch 'develop'`
- `PRs are required in order to make changes on branch 'develop'`

</details>

**Documentation:** https://github.com/ossf/scorecard/blob/c395761df6afe1a69e476bc60a013a94bcbc153f/docs/checks.md#branch-protection
