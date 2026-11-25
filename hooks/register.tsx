// The vergil plugin's hooks module (a Claude Code mod). It labels each
// subagent's row in the agent panel with the task and issue(s) the agent was
// dispatched for, read from the Agent call's description, in place of the
// agent type (`general-purpose`). Rows whose description names no issue are
// left as Claude Code draws them.
import type { Register } from 'claude-code'

/** An issue reference: `owner/repo#N`, `repo#N` or `#N`. */
const ISSUE_REF = /(?:\b[\w.-]+\/)?(?:\b[\w.-]+)?#\d+\b/g

/** A task or batch name: `Task 15`, `Task 6b`, `Batch 6b/6c/9/10`. */
const TASK_NAME = /\b(Task|Batch)\s+(\d+[a-z]?(?:\/\d+[a-z]?)*)\b/i

/**
 * The label for an agent dispatched with `description`, or `undefined` when
 * the description names no issue. The owner is dropped from an
 * `owner/repo#N` reference to keep the row short.
 *
 * - `Implement vergil-tooling#4931 (Task 15)` → `Task 15 (vergil-tooling#4931)`
 * - `Batch 6b/6c/9/10: #4917 #4918 #4926 #4927`
 *   → `Batch 6b/6c/9/10 (#4917, #4918, #4926, #4927)`
 * - `Implement vergil-project/vergil-claude-plugin#1267`
 *   → `vergil-claude-plugin#1267`
 */
export function taskLabel(description: string): string | undefined {
  const refs: string[] = []
  for (const match of description.matchAll(ISSUE_REF)) {
    const ref = match[0].replace(/^[\w.-]+\/(?=[\w.-]+#)/, '')
    if (!refs.includes(ref)) refs.push(ref)
  }
  if (refs.length === 0) return undefined
  const [, word, name] = TASK_NAME.exec(description) ?? []
  if (word === undefined || name === undefined) return refs.join(', ')
  const kind = word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
  return `${kind} ${name} (${refs.join(', ')})`
}

/** `1h04m`, `4m12s` or `38s` for a span in milliseconds. */
export function elapsed(ms: number): string {
  const seconds = Math.max(0, Math.floor(ms / 1000))
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  if (h > 0) return `${h}h${String(m).padStart(2, '0')}m`
  if (m > 0) return `${m}m${String(s).padStart(2, '0')}s`
  return `${s}s`
}

/** The word for an agent that has finished, or `undefined` while it runs. */
function finished(taskStatus: string): string | undefined {
  switch (taskStatus) {
    case 'completed':
      return 'done'
    case 'failed':
      return 'failed'
    case 'killed':
      return 'stopped'
    default:
      return undefined
  }
}

export const register: Register = on => {
  on('ui.render', { component: 'AgentRow' }, async ($, e, next) => {
    const label = taskLabel(e.props.description)
    // A row the person's settings hide or redraw stays theirs.
    if (label === undefined || e.props.isHidden || e.props.body !== undefined) {
      return next(e)
    }

    const { Box, Text } = $.ui.resolve(e)
    const done = finished(e.props.taskStatus)
    const state = done ?? elapsed((await $.clock.now()) - e.props.startTime)
    // The latest progress summary's first line; none while it is still the
    // description, which the label already stands for.
    const summary = (e.props.label.split('\n', 1)[0] ?? '').trim()
    const activity = summary === e.props.description.trim() ? '' : summary

    return (
      <Box>
        <Text bold>{label}</Text>
        <Text dimColor>
          {' · '}
          {state}
          {activity === '' ? '' : ` · ${activity}`}
        </Text>
      </Box>
    )
  })
}
