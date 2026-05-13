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

Configure in your project's `.claude/settings.json`:

```json
{
  "plugins": ["vergil-tooling"]
}
```

### Local development

```bash
claude --plugin-dir /path/to/vergil-claude-plugin
```

## Plugin Namespace

All skills are namespaced under `vergil-tooling`:

```text
/vergil-tooling:<skill-name>
```
