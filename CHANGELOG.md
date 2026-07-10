# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.1.33] - 2026-07-10

### Documentation

- reverse oversight doctrine — encourage sub-agents, trust and escalate (#632)
- reverse oversight doctrine — encourage sub-agents, trust and escalate (#633)
- reverse oversight doctrine in issue-validate/issue-deploy; keep never-fabricate (#634)
- state Front-Loaded Judgment, Trusted Execution as canonical invariant (#635)

### Features

- add epic-implement driver skill (#631)

## [2.1.32] - 2026-07-09

### Documentation

- teach epic-create/migrate-repo the resolved epic home (#621)

## [2.1.31] - 2026-07-09

### Features

- add skill to reconstruct a remote branch's submit-ready state locally (#617)

## [2.1.30] - 2026-07-09

### Documentation

- state same-repo placement law; file doc-review bookend in member repo (#613)

## [2.1.29] - 2026-07-09

### Documentation

- extract shared operational lifecycle; record SUCCESS (#602)
- generalize doctrine to operational tasks (+ deployment) (#604)
- redirect deployment issues to issue-deploy; discover deploy needs (#607)

### Features

- add the issue-deploy skill (#603)

## [2.1.28] - 2026-07-08

### Documentation

- add post-merge validation doctrine (#592)
- discover/create validation follow-ons + redirect (#593)

### Features

- add issue-validate skill (#594)

## [2.1.27] - 2026-07-05

### Features

- align migrate-repo to the ad-hoc model in .github (#576) (#585)

## [2.1.26] - 2026-07-04

### Features

- route intake to .github with --kind (triage-capture, memory-audit) (#575) (#581)

## [2.1.25] - 2026-07-04

### CI

- add on: issues.closed caller for event-driven epic rollup (#571)

### Chores

- relicense to MIT (#573)

### Features

- make epic-create the orchestrating outer workflow (#574) (#577)

## [2.1.24] - 2026-07-01

### Bug fixes

- update issue-create references to the new vrg-* creation commands (#567)

### Documentation

- document the single released-channel distribution model (#45) (#563)
- fix stale install config + namespace; single-channel model (#45) (#564)

## [2.1.23] - 2026-06-30

### Documentation

- capture the plan-evolution-addendum convention (#40) (#557)

## [2.1.22] - 2026-06-30

### Chores

- point plugin marketplace at main (single released channel, #45) (#552)

## [2.1.21] - 2026-06-30

### Features

- epic-create — promote a brainstormed spec into a finite epic (#547)

## [2.1.20] - 2026-06-29

### Features

- migrate-repo — enrich retro-epics from existing specs (current-work, reference-only) (#542)

## [2.1.19] - 2026-06-29

### Features

- migrate-repo — guided backlog migration into the epic/task framework (#535)

## [2.1.18] - 2026-06-29

### Features

- triage intake — capture + review skills (#530)

## [2.1.17] - 2026-06-29

### Documentation

- epic/task convention on-ramp + linkage/namespace fixes (#525)

## [2.1.15] - 2026-06-25

### Refactoring

- simplify pr-watch to USER-only (#517)

## [2.1.14] - 2026-06-25

### Refactoring

- collapse issue-implement to run-and-done; remove issue-audit (#512)

## [2.1.13] - 2026-06-25

### Documentation

- update live references to vergil-containers (#506) (#507)

## [2.1.12] - 2026-06-18

### Chores

- pin own marketplace ref to develop for release compliance (#501) (#502)

### Documentation

- state that vrg-pr-workflow / vrg-pr-await are blocking request-reply calls (#499) (#500)

## [2.1.11] - 2026-06-12

### Chores

- convert consumer-refresh from slash commands to CLI (#495)

## [2.1.10] - 2026-06-12

### Documentation

- rewrite skill descriptions to lead with invocation triggers (#489) (#490)

## [2.1.9] - 2026-06-11

### Documentation

- document base-branch conflict resolution in issue-implement (#481) (#485)

## [2.1.8] - 2026-06-11

### Chores

- re-trigger CI to pick up PR body issue linkage
- remove legacy implement/audit skills; keep only the issue-* pair (#479) (#480)

## [2.1.7] - 2026-06-10

### Documentation

- default issue-implement to no-audit; make audit opt-in (#474) (#475)

### Release

- 2.1.7 (#477)

## [2.1.6] - 2026-06-09

### Documentation

- add dual-agent audit test kit design (vergil-tooling#1563) (#468)
- add dual-agent audit test runbook (vergil-tooling#1563) (#470)

### Features

- sequential handshake: issue-audit takes a worktree path; transparent loops (vergil-tooling#1572) (#469)

## [2.1.5] - 2026-06-08

### Features

- add issue-implement and issue-audit oracle-loop skills (#464)

## [2.1.4] - 2026-06-08

### Bug fixes

- grant actions: read to the security job (#457)

### Documentation

- clarify pr-template fields and supported YAML (#459)

## [2.1.3] - 2026-06-05

### Bug fixes

- match raw-git-commit fallback against quote-stripped text
- match pr-create tool-name predicates against stripped text
- match agent-merge tool-name predicates against stripped text
- match host-container-split loops against stripped text
- match deprecation test-command predicate against stripped text
- match protected-branch gating predicate against stripped text
- anchor autoclose-linkage tool predicate on stripped text
- match contents-api invocation detection against stripped text
- match associative-array predicate against stripped text

### Build

- wire hook test suites into vrg-validate via validate-custom

### Documentation

- add command-matcher quoting design (#450)
- fold pushback resolutions into command-matcher quoting design
- verify canonical vectors empirically; correct table verdicts
- add #450 matcher-quoting implementation plan
- document quote-stripped command matching
- link the filed vergil-tooling sub-issue in the matcher spec

### Features

- add shared quote-stripping helper for command matchers

### Testing

- add failing stripper tests for command matchers
- add failing matcher tests encoding the canonical case table

## [2.1.2] - 2026-06-05

### Bug fixes

- restore host-container guard after vrg-container-run rename
- simplify block-agent-merge to unconditional deny
- reword autoclose-linkage rationale for the 2.1 workflow
- contents-api deny message: template handoff, human submits
- host tool list: drop vrg-finalize-repo, add 2.1 tools

### Chores

- migrate vergil pin and workflow refs to v2.1
- gitignore agent workspace, build output, local settings

### Documentation

- fix stale tool names and missing chore branch type
- add hooks/2.1 workflow reconciliation design
- fold pushback resolutions into hooks/2.1 reconciliation design
- record filed companion issue numbers in appendix A
- add #441 drift-repair implementation plan
- repoint teardown to vrg-finalize-pr; document live hooks; mark lifecycles superseded
- add #442 audit write-guard implementation plan
- document guard-audit-writes
- repository-standards: issues close via human finalization

### Features

- add AUDIT identity write-guard
- register guard-audit-writes for Write/Edit/NotebookEdit

### Refactoring

- retire remind-finalize hook

### Testing

- add failing table-driven tests for the audit write-guard

## [2.1.1] - 2026-06-04

### Bug fixes

- track latest main release via relative-path plugin source

## [2.1.0] - 2026-06-04

### Bug fixes

- fix MD012 in site skills catalog after dependency-update removal

### Documentation

- add 2.1 workflow and skill rationalization design
- fold pushback resolutions into 2.1 design
- add #427 plugin skill rationalization implementation plan
- define .vergil/audit-feedback.yml channel format
- reconcile deprecation-triage and handoff with the 2.1 model

### Features

- add implement skill (USER local loop)
- add audit skill (AUDIT local loop)
- add pr-watch skill (post-PR loop)

### Refactoring

- retire pr-workflow skill; repoint active refs to the 2.1 model
- retire dependency-update skill (mechanized in vergil-tooling)

## [2.0.16] - 2026-05-28

### Chores

- revert container-prefix dev workaround

## [2.0.13] - 2026-05-28

### Chores

- bump to 2.0.12, skip failed 2.0.11
- switch CI/CD container prefix from prod to dev
- force CI re-resolution after v2.0 tag rollback
- bump to 2.0.13

## [2.0.11] - 2026-05-27

### Bug fixes

- replace /dev/stdin with cat in block-heredoc hook
- replace vestigial post-merge config with hardcoded cd.yml monitoring
- align template section with vrg-container-run rename

### Chores

- bump version to 2.0.11
- remove legacy .githooks and invalid primary-language
- replace .githooks with Claude Code hook guard
- add missing container parameters and fix stale standards doc

## [2.0.10] - 2026-05-21

### Bug fixes

- correct marketplace name to vergil-marketplace throughout

### Chores

- bump version to 2.0.10

## [2.0.9] - 2026-05-21

### Chores

- bump version to 2.0.9
- add consumer-refresh config to vergil.toml

## [2.0.8] - 2026-05-21

### Bug fixes

- align CLAUDE.md with consumer template for repo-config audit compliance
- replace stale pre-commit hook (ST_COMMIT_CONTEXT → VRG_COMMIT_CONTEXT)
- sync VERSION file with plugin.json (2.0.0 → 2.0.7)

### Chores

- bump version to 2.0.7
- remove publish skill — workflow moved to vrg-publish CLI
- add label to version selector in site header
- bump version to 2.0.8

## [2.0.6] - 2026-05-18

### Bug fixes

- replace stale gh auth token preflight with vrg-gh credential model

### Chores

- bump version to 2.0.6
- remove co-authors section, normalize vergil dep to v2.0

## [2.0.5] - 2026-05-18

### Chores

- bump version to 2.0.5
- add GPL-3 LICENSE file
- remove per-repo templates in favor of org defaults
- add integration test marker for #340
- rename vrg-github-config to vrg-github-repo-config

### Features

- deploy permission model and update hook messages
- deploy deny rules to project-level settings

## [2.0.4] - 2026-05-14

### Bug fixes

- use release/ branch prefix for bump PR polling

### Chores

- bump version to 2.0.4

## [2.0.3] - 2026-05-14

### Chores

- bump version to 2.0.3
- remove redundant vergil-tooling key from vergil.toml
- pin vergil to minor version and drop redundant vergil-tooling key

### Reverts

- restore vergil-tooling key pending vergil-tooling#755

## [2.0.2] - 2026-05-13

### Bug fixes

- correct marketplace name in consumer-refresh sequence

### Chores

- bump version to 2.0.2

## [2.0.1] - 2026-05-13

### Bug fixes

- add vergil-tooling key to vergil.toml dependencies (#308)

### CI

- update vergil-actions refs from v1.5 to v2.0

### Chores

- bump version to 1.4.26
- update plugin identity to vergil-marketplace

### Features

- rename to vergil-claude-plugin under vergil-project org (#305)

## [1.4.24] - 2026-05-11

### Chores

- bump version to 1.4.24

### Refactoring

- align skill with template redesign
- align PR and issue templates with standard-tooling

## [1.4.23] - 2026-05-09

### Bug fixes

- pass boolean to ci-security reusable workflow inputs

### Chores

- prepare release 1.4.22
- bump version to 1.4.23
- fleet-wide config and workflow cleanup
- shorten issue template header comments to fit yamllint line-length
- migrate to reusable publish/docs workflows
- trigger CI re-run

### Features

- block Write/Edit to main worktree and GitHub Contents API writes
- adopt CI/CD workflow convention (#383)

## [1.4.22] - 2026-05-08

### Bug fixes

- remove unnecessary uv run prefix from st-docker-run invocations
- correct enforcement attribution for auto-close keyword ban

### Chores

- prepare release 1.4.21
- bump version to 1.4.22
- decommission st-validate-local remnants
- remove deprecated project-issue skill references
- adopt chore(release) convention and document required --scope

### Features

- require full triage of all st-finalize-repo errors and warnings

## [1.4.21] - 2026-05-07

### Chores

- prepare release 1.4.20
- bump version to 1.4.21

### Features

- add GitHub config compliance check to PR and publish workflow preflight

## [1.4.20] - 2026-05-06

### Bug fixes

- set primary-language to claude-plugin and use reusable ci-release workflow
- use claude-plugin as language consistently across all workflow calls

### Chores

- prepare release 1.4.19
- bump version to 1.4.20

## [1.4.19] - 2026-05-06

### Bug fixes

- add container-suffix to ci-quality workflow call

### Chores

- prepare release 1.4.18
- bump version to 1.4.19

## [1.4.18] - 2026-05-05

### Chores

- prepare release 1.4.17
- bump version to 1.4.18
- remove project-issue skill
- upgrade to standard-actions v1.5 and add ci config for enforcement

### Documentation

- add fleet rollout design spec and implementation plan

### Features

- add operational summary section to pr-workflow and publish skills

## [1.4.17] - 2026-05-01

### Bug fixes

- fix markdown lint error in hooks index
- update managed-repo detection to use standard-tooling.toml
- update error messages to reference standard-tooling.toml
- update skill and agent instructions to read standard-tooling.toml
- remove st-validate-local from HOST_TOOLS

### Chores

- prepare release 1.4.16
- bump version to 1.4.17
- remove phantom block-memory-writes hook references
- update gating comments to reference standard-tooling.toml

### Documentation

- add design spec for human-routed memory writes
- apply pushback review resolutions to design spec
- add implementation plan for human-routed memory writes
- replace memory ban with managed-memory policy
- add memory policy exemption note
- update documentation to reference standard-tooling.toml

### Features

- add memory-init skill
- add memory-audit skill

## [1.4.16] - 2026-05-01

### Bug fixes

- remove 'Locating standard-tooling host commands' section — just run commands from PATH

### Chores

- prepare release 1.4.15
- bump version to 1.4.16
- remove command -v st-docker-run tool-presence guard

## [1.4.15] - 2026-05-01

### Bug fixes

- block gh api equivalents of blocked gh subcommands (pr create, pr merge, pr review) (#217)
- change 'stop and fix' to 'stop and report' in failure handling (#222)

### Chores

- prepare release 1.4.14
- bump version to 1.4.15
- remove legacy st-config.toml (#215)

## [1.4.14] - 2026-04-30

### Chores

- prepare release 1.4.13
- bump version to 1.4.14

### Features

- add handoff skill for session-to-session continuity

## [1.4.13] - 2026-04-30

### Bug fixes

- tighten Phase 3 bump-PR polling to ban ad-hoc shell scripts
- read consumer-refresh sequence from standard-tooling.toml instead of hardcoding
- update consumer-refresh to note reload-plugins bug and require session restart

### Chores

- prepare release 1.4.12
- bump version to 1.4.13
- remove stale cross-repo docker rebuild verification from publish skill

## [1.4.12] - 2026-04-30

### Bug fixes

- remove uv from HOST_TOOLS to unblock st-docker-run -- uv run

### Chores

- prepare release 1.4.11
- bump version to 1.4.12
- seed standard-tooling.toml
- strip config sections from repository-standards.md

### Documentation

- add v2.0 skill rearchitecture spec and pushback review
- add TDD testing harness design spec for skill testing
- revise TDD harness spec with pushback resolutions
- add TDD testing harness pilot implementation plan
- align spec and plan with alignment review resolutions

### Features

- use st-wait-until-green in pr-workflow, add to host tools

## [1.4.11] - 2026-04-29

### Bug fixes

- make Phase 7 hand-off display-only, fix stale three-step reference
- fix line-length violations in block-agent-merge plan

### Chores

- prepare release 1.4.10
- bump version to 1.4.11

## [1.4.10] - 2026-04-29

### Bug fixes

- redirect container-tool warning to st-validate-local abstraction layer

### Chores

- prepare release 1.4.9
- bump version to 1.4.10
- bootstrap st-config.toml for cache-first docker workflow
- remove duplicate ci: markdownlint job

### Documentation

- add spec for blocking agent merge of non-release PRs
- update block-agent-merge spec with pushback resolutions
- add implementation plan and alignment review for block-agent-merge
- add Phase 5 dep-update PR to agent-merge policy

### Features

- add block-agent-merge PreToolUse hook
- add st-docker-cache and st-config.toml support to workflows

## [1.4.9] - 2026-04-28

### Bug fixes

- strengthen issue-closure step in pr-workflow so agents stop skipping it

### Chores

- prepare release 1.4.8
- bump version to 1.4.9

## [1.4.8] - 2026-04-28

### Bug fixes

- remove non-existent /plugin update command from consumer-refresh sequence
- require explicit version extraction from publish.yml in preflight

### Chores

- prepare release 1.4.7
- bump version to 1.4.8

## [1.4.7] - 2026-04-28

### Chores

- prepare release 1.4.6
- bump version to 1.4.7

### Documentation

- remove include directives and downgrade standards-and-conventions refs

### Features

- publish: verify bump PR issue linkage before merge
- forbid auto-close linkage, require Ref and explicit issue closure

## [1.4.6] - 2026-04-28

### Bug fixes

- shorten mkdocs.yml site_description and drop stale commands reference

### Chores

- prepare release 1.4.5
- bump version to 1.4.6
- bump CI action pins for next cycle
- upgrade standard-actions from @v1.3 to @v1.4

### Documentation

- align docs tree with post-audit codebase state

## [1.4.5] - 2026-04-28

### Chores

- prepare release 1.4.4
- bump version to 1.4.5
- migrate standard-actions refs from @develop to @v1.3
- remove st-list-project-repos and st-set-project-field from host tools list

### Documentation

- audit: rationalize skill catalog as a coherent dev+deploy toolkit
- publish + pr-workflow: docs.yml verification, Phase 6 closure, Phase 7 hand-off
- summarize: keep three-mode unified skill; SOC mode is canonical for the fleet
- complete audit steps 6-7, align host/container routing (#96)

### Features

- pr-workflow: verify post-merge async workflows from repository profile
- enforce host-vs-container tool routing per #96
- publish: verify cross-repo image rebuild for standard-tooling releases

### Refactoring

- eliminate branch-workflow skill; extract substance to starting-work-on-an-issue.md
- rewrite pr-workflow for worktree convention + humans-review posture
- project-issue: strip GitHub Projects integration, remove add-to-project workflow

## [1.4.4] - 2026-04-27

### Chores

- prepare release 1.4.3
- bump version to 1.4.4
- delete ci-push.yml (Tier 2 redundant with validate-local)

### Documentation

- document plugin update sequence in README and CLAUDE.md

### Features

- gate enforcement hooks on managed-repo detection

## [1.4.3] - 2026-04-27

### Bug fixes

- resolve session cwd and main repo root for worktree commits

### Chores

- prepare release 1.4.2
- bump version to 1.4.3
- vendor .githooks gate + .yamllint (#89)

### Documentation

- split tool routing: release/git tools on host, validators in container

### Features

- remove per-edit validate-* hooks; rely on st-validate-local at PR time

## [1.4.2] - 2026-04-24

### Chores

- prepare release 1.4.1

## [1.4.1] - 2026-04-24

### Bug fixes

- pass version-replacement to version-bump-pr composite; bump 1.4.1

### Chores

- merge main into release/1.4.0
- prepare release 1.4.0

### Documentation

- reorder publish skill phases so bump PR merge runs in parallel with slow publish

### Release

- 1.3.0 (#62)
- 1.3.1 (#67)

## [1.4.0] - 2026-04-24

### Features

- rewrite publish skill for poll-and-merge; bump composite pins to v1.2; plugin 1.4.0 (#70)

## [1.3.1] - 2026-04-23

### Bug fixes

- pin consumers to main ref in marketplace.json (#65)

## [1.3.0] - 2026-04-23

### Bug fixes

- use markdown-standards in validate-markdown.sh for CI parity (#14)
- fix markdownlint and structural check failures (#16)
- skip Cargo.toml and Cargo.lock in generic TOML validation (#18)
- add PreToolUse hook to block bash associative arrays (#29)
- fix marketplace.json source schema and resolve markdownlint errors (#31)
- update skills, hooks, and bootstrap for container-first execution via st-docker-run (#37)

### CI

- use dev-docs container for docs CI (#27)

### Chores

- bootstrap repository scaffold
- add .markdownlintignore for auto-generated files (#190) (#9)
- install standard-tooling-plugin in its own repo (#22)
- ban MEMORY.md usage in CLAUDE.md (#23)
- use st-markdown-standards instead of legacy bare wrapper (#25)
- remove taplo TOML validation from hooks (#34)
- rename dev-docs container reference to dev-base (#39)
- remove block-memory-writes.sh (anachronism from polyglot era) (#44)
- plugin cleanup and docs refresh for v1.3.0 release prep (#60)

### Documentation

- cross-ref git-workflow guide and refresh hook entries (block-memory-writes removed, block-protected-branch-work now worktree-aware) (#48)

### Features

- add 5 core PreToolUse guardrail hooks (#1)
- add bootstrap session-start agent (#2)
- migrate 8 skills from standards-and-conventions (#3)
- add 3 post-action hooks for finalization, deprecation, and stop guard (#4)
- add self-hosted marketplace for plugin distribution (#5)
- add MkDocs site scaffold, changelog infrastructure, and CI workflows (#7)
- add PostToolUse file validation on Write|Edit (#12)
- add CI workflows and rulesets (#19)
- adopt git worktree convention for parallel AI agent development (#43)
- make block-protected-branch-work.sh worktree-aware (opt-in via .gitignore signal) (#45)
