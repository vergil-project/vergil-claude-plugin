# Standard Tooling Plugin

Claude Code plugin for the vergil-tooling ecosystem. Delivers shared hooks,
skills, and agents to all managed repositories.

## Overview

This plugin is the behavioral counterpart to the
[vergil-tooling](https://github.com/vergil-project/vergil-tooling) Python
package. While vergil-tooling provides runtime CLI tools (`vrg-commit`,
`vrg-submit-pr`, etc.) via PATH, this plugin provides Claude Code configuration
that enforces workflow compliance mechanically.

## What's Included

|Component|Purpose|
|---|---|
|[Hooks](hooks/index.md)|Pre/PostToolUse/Stop workflow guardrails|
|[Skills](skills/index.md)|Shared workflow skills (commit, PR, etc.)|
|[Agents](agents/index.md)|Bootstrap subagent for session context|

## Two-Repo Model

|Repo|Delivers|Distribution|
|---|---|---|
|`vergil-tooling`|Python CLIs (`st-*`), validators|PATH|
|`vergil-claude-plugin`|Hooks, skills, agents|Claude Code plugin|

These are complementary: the plugin tells Claude how to behave; PATH makes the
tools available to run.

## Installation

### From marketplace

The plugin ships through a single channel, the floating `v2.1` rolling tag:
each release moves `v2.1` forward, and a
[rollback](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/releasing.md#rolling-back-a-release)
moves it back to an earlier release (see the
[spec](https://github.com/vergil-project/.github/blob/develop/epics/760-plugin-tag-distribution/spec.md)).
It is installed per user: add the marketplace definition and the plugin enable to your
user-level `~/.claude/settings.json`, and the enable installs the plugin. If
that file already has `extraKnownMarketplaces` or `enabledPlugins` objects,
merge these entries into them rather than adding a second copy of either key:

```json
{
  "extraKnownMarketplaces": {
    "vergil-marketplace": {
      "source": {
        "source": "github",
        "repo": "vergil-project/vergil-claude-plugin",
        "ref": "v2.1"
      }
    }
  },
  "enabledPlugins": {
    "vergil@vergil-marketplace": true
  }
}
```

**Already registered `vergil-marketplace` at another `ref`?** Editing the
`ref` is a change of source, not an update: a marketplace update alone keeps
the old registration. Follow vergil-tooling's
[Switching an existing machine](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/consuming-repo-setup.md#switching-an-existing-machine)
procedure instead.

Do not put the marketplace definition in a repo's `.claude/settings.json`. A
managed repo's file comes from the vergil-tooling template, which only enables
`vergil@vergil-marketplace`: a second `vergil-marketplace` definition there
would replace the user-level entry whole, and the nightly config audit requires
the repo file to equal the template. See vergil-tooling's
[Claude Config Ownership](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/claude-config-ownership.md)
model and
[Consuming Repo Setup](https://github.com/vergil-project/vergil-tooling/blob/develop/docs/site/docs/guides/consuming-repo-setup.md#claudesettingsjson).

### Local development

```bash
claude --plugin-dir /path/to/vergil-claude-plugin
```

## Plugin Namespace

All skills are namespaced under `vergil`:

```text
/vergil:<skill-name>
```
