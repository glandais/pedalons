import { renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { useKeyboardPointMove } from './useKeyboardPointMove'

function key(
  k: string,
  mods: Partial<{ shiftKey: boolean; ctrlKey: boolean; altKey: boolean; metaKey: boolean }> = {}
) {
  return {
    key: k,
    shiftKey: false,
    ctrlKey: false,
    altKey: false,
    metaKey: false,
    ...mods,
    preventDefault: vi.fn(),
    stopPropagation: vi.fn(),
  }
}

function setup() {
  const onStep = vi.fn()
  const onCommit = vi.fn()
  const onCancel = vi.fn()
  const hook = renderHook(() => useKeyboardPointMove({ onStep, onCommit, onCancel }))
  return { onStep, onCommit, onCancel, api: () => hook.result.current, hook }
}

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())

describe('useKeyboardPointMove', () => {
  it('steps by 10 px, 50 px with Shift, in screen axes, and keeps the arrow from the map', () => {
    const { onStep, api } = setup()
    const right = key('ArrowRight')
    api().onKeyDown(right)
    api().onKeyDown(key('ArrowUp'))
    api().onKeyDown(key('ArrowDown', { shiftKey: true }))
    api().onKeyDown(key('ArrowLeft'))
    expect(onStep.mock.calls).toEqual([
      [10, 0],
      [0, -10],
      [0, 50],
      [-10, 0],
    ])
    expect(right.preventDefault).toHaveBeenCalled()
    expect(right.stopPropagation).toHaveBeenCalled()
  })

  it('does not commit while an arrow is held, repeats included', () => {
    const { onStep, onCommit, api } = setup()
    api().onKeyDown(key('ArrowLeft'))
    api().onKeyDown(key('ArrowLeft'))
    api().onKeyDown(key('ArrowLeft'))
    vi.advanceTimersByTime(5000)
    expect(onStep).toHaveBeenCalledTimes(3)
    expect(onCommit).not.toHaveBeenCalled()
  })

  it('commits once, 500 ms after the last release', () => {
    const { onCommit, api } = setup()
    api().onKeyDown(key('ArrowLeft'))
    api().onKeyUp({ key: 'ArrowLeft' })
    vi.advanceTimersByTime(499)
    expect(onCommit).not.toHaveBeenCalled()
    vi.advanceTimersByTime(1)
    expect(onCommit).toHaveBeenCalledTimes(1)
    vi.advanceTimersByTime(5000)
    expect(onCommit).toHaveBeenCalledTimes(1)
    expect(api().pending()).toBe(false)
  })

  it('waits for the last of two held arrows', () => {
    const { onCommit, api } = setup()
    api().onKeyDown(key('ArrowLeft'))
    api().onKeyDown(key('ArrowUp'))
    api().onKeyUp({ key: 'ArrowLeft' })
    vi.advanceTimersByTime(2000)
    expect(onCommit).not.toHaveBeenCalled()
    api().onKeyUp({ key: 'ArrowUp' })
    vi.advanceTimersByTime(500)
    expect(onCommit).toHaveBeenCalledTimes(1)
  })

  it('restarts the wait on a key pressed within it', () => {
    const { onCommit, api } = setup()
    api().onKeyDown(key('ArrowLeft'))
    api().onKeyUp({ key: 'ArrowLeft' })
    vi.advanceTimersByTime(400)
    api().onKeyDown(key('ArrowLeft'))
    api().onKeyUp({ key: 'ArrowLeft' })
    vi.advanceTimersByTime(400)
    expect(onCommit).not.toHaveBeenCalled()
    vi.advanceTimersByTime(100)
    expect(onCommit).toHaveBeenCalledTimes(1)
  })

  it('commits at once on Enter and on blur, only during a burst', () => {
    const { onCommit, api } = setup()
    api().onBlur()
    api().onKeyDown(key('Enter'))
    expect(onCommit).not.toHaveBeenCalled()

    api().onKeyDown(key('ArrowLeft'))
    const enter = key('Enter')
    api().onKeyDown(enter)
    expect(onCommit).toHaveBeenCalledTimes(1)
    expect(enter.stopPropagation).toHaveBeenCalled()

    api().onKeyDown(key('ArrowLeft'))
    api().onBlur()
    expect(onCommit).toHaveBeenCalledTimes(2)
    vi.advanceTimersByTime(5000)
    expect(onCommit).toHaveBeenCalledTimes(2)
  })

  it('abandons on Escape, and the timer fires nothing', () => {
    const { onCommit, onCancel, api } = setup()
    api().onKeyDown(key('ArrowLeft'))
    api().onKeyUp({ key: 'ArrowLeft' })
    const esc = key('Escape')
    api().onKeyDown(esc)
    expect(onCancel).toHaveBeenCalledTimes(1)
    expect(esc.preventDefault).toHaveBeenCalled()
    expect(esc.stopPropagation).toHaveBeenCalled()
    vi.advanceTimersByTime(5000)
    expect(onCommit).not.toHaveBeenCalled()
  })

  it('leaves Escape alone outside a burst', () => {
    const { onCancel, api } = setup()
    const esc = key('Escape')
    api().onKeyDown(esc)
    expect(onCancel).not.toHaveBeenCalled()
    expect(esc.preventDefault).not.toHaveBeenCalled()
    expect(esc.stopPropagation).not.toHaveBeenCalled()
  })

  it.each(['ctrlKey', 'altKey', 'metaKey'] as const)('does not handle an arrow with %s', (mod) => {
    const { onStep, api } = setup()
    const e = key('ArrowLeft', { [mod]: true })
    api().onKeyDown(e)
    expect(onStep).not.toHaveBeenCalled()
    expect(e.preventDefault).not.toHaveBeenCalled()
    expect(e.stopPropagation).not.toHaveBeenCalled()
    expect(api().pending()).toBe(false)
  })

  it('cancel() empties the state without calling back', () => {
    const { onCommit, onCancel, api } = setup()
    api().onKeyDown(key('ArrowLeft'))
    api().onKeyUp({ key: 'ArrowLeft' })
    api().cancel()
    expect(api().pending()).toBe(false)
    vi.advanceTimersByTime(5000)
    expect(onCommit).not.toHaveBeenCalled()
    expect(onCancel).not.toHaveBeenCalled()
  })
})
