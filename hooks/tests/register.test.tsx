// Tests for the hooks module (hooks/register.tsx): the AgentRow label.
// Run with `claude plugin test <plugin root>` on Claude Code 2.1.326 or later.
import { expect, test } from 'claude-code/testing'

import { elapsed, taskLabel } from '../register'

const START = 1_000_000

/** An AgentRow render request for one running subagent. */
function agentRow(props: Record<string, unknown>) {
  return {
    plugin: 'vergil',
    component: 'AgentRow',
    requestId: 'a1',
    props: {
      id: 'a1',
      description: 'Implement vergil-tooling#4931 (Task 15)',
      type: 'general-purpose',
      status: 'running',
      kind: 'local_agent',
      taskStatus: 'running',
      label: 'Running the test suite\nsecond line',
      startTime: START,
      cwd: '/',
      tokenCount: 0,
      tokenSamples: [],
      hasRow: true,
      rowIds: ['a1'],
      isHidden: false,
      ...props,
    },
  } as const
}

test('a task and its issue make the label', () => {
  expect(taskLabel('Implement vergil-tooling#4931 (Task 15)')).toBe(
    'Task 15 (vergil-tooling#4931)',
  )
})

test('a batch lists every issue, once each', () => {
  expect(
    taskLabel('Batch 6b/6c/9/10: #4917 #4918, #4926 and #4927 (#4917)'),
  ).toBe('Batch 6b/6c/9/10 (#4917, #4918, #4926, #4927)')
})

test('an owner is dropped and a bare issue stands alone', () => {
  expect(taskLabel('Implement vergil-project/vergil-claude-plugin#1267')).toBe(
    'vergil-claude-plugin#1267',
  )
})

test('a description with no issue gives no label', () => {
  expect(taskLabel('Explore the hook scripts')).toBeUndefined()
  expect(taskLabel('Task 15 research')).toBeUndefined()
})

test('elapsed time reads in seconds, minutes or hours', () => {
  expect(elapsed(38_400)).toBe('38s')
  expect(elapsed(252_000)).toBe('4m12s')
  expect(elapsed(3_840_000)).toBe('1h04m')
})

test('a running task row shows its label, elapsed time and activity', async ($, on) => {
  on('clock.now', () => ({ value: START + 252_000 }))

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...agentRow({}), surface })
    expect((await ui.find({ type: 'Text', text: /Task 15/ }))?.text).toBe(
      'Task 15 (vergil-tooling#4931)',
    )
    expect((await ui.find({ type: 'Text', text: /4m12s/ }))?.text).toBe(
      ' · 4m12s · Running the test suite',
    )
    expect(await ui.find({ type: 'Text', text: /general-purpose/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('a finished task row says so, and a description is not repeated', async ($, on) => {
  on('clock.now', () => ({ value: START }))

  const ui = await $.ui.mount({
    ...agentRow({
      taskStatus: 'completed',
      status: 'completed',
      label: 'Implement vergil-tooling#4931 (Task 15)',
    }),
    surface: 'terminal',
  })
  expect((await ui.find({ type: 'Text', text: /done/ }))?.text).toBe(' · done')
  await ui.unmount()
})

test('a row with no issue, a hidden row and a set body go to the engine', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  for (const props of [
    { description: 'Explore the hook scripts' },
    { isHidden: true },
    { body: 'from settings' },
  ]) {
    const ui = await $.ui.mount({ ...agentRow(props), surface: 'terminal' })
    expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe('engine')
    await ui.unmount()
  }
})
