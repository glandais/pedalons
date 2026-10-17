import { describe, expect, it, vi, afterEach } from 'vitest'
import { renderHook } from '@testing-library/react'
import { useElevationRefetchInterval } from './useElevationRefetchInterval'

const query = (elevationState: string | undefined, queryHash = 'q1') => ({
  queryHash,
  state: { data: elevationState === undefined ? undefined : { elevationState } },
})

afterEach(() => vi.useRealTimers())

describe('useElevationRefetchInterval', () => {
  it('polls every 30 s while the HD recomputation is PENDING', () => {
    const { result } = renderHook(() => useElevationRefetchInterval())
    expect(result.current(query('PENDING'))).toBe(30_000)
  })

  it('does not poll once HD, nor when the recomputation was given up (FAST), nor without data', () => {
    const { result } = renderHook(() => useElevationRefetchInterval())
    expect(result.current(query('HD'))).toBe(false)
    expect(result.current(query('FAST'))).toBe(false)
    expect(result.current(query(undefined))).toBe(false)
  })

  it('gives up 15 minutes after the first PENDING payload, and restarts for another query', () => {
    vi.useFakeTimers()
    const { result } = renderHook(() => useElevationRefetchInterval())
    expect(result.current(query('PENDING'))).toBe(30_000)
    vi.advanceTimersByTime(16 * 60_000)
    expect(result.current(query('PENDING'))).toBe(false)
    expect(result.current(query('PENDING', 'q2'))).toBe(30_000)
  })
})
