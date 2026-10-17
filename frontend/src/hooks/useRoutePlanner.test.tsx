import { act, renderHook, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useRoutePlanner } from './useRoutePlanner'
import { ApiClientError } from '@/lib/apiError'
import { ErrorCode } from '@/api/dto'

const routeMock = vi.hoisted(() => vi.fn())
vi.mock('@/api/endpoints/router/router', () => ({ route: routeMock }))
vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))

function apiError(code: ErrorCode, status: number) {
  return new ApiClientError(status, { code })
}

const A = { lng: 5, lat: 45 }
const B = { lng: 5.01, lat: 45 }
const C = { lng: 5.02, lat: 45 }

/** A router answer that stays pending until released, and rejects when its signal aborts. */
function pendingRouter() {
  routeMock.mockImplementation(
    (_body: unknown, _opts: unknown, signal?: AbortSignal) =>
      new Promise((_resolve, reject) => {
        signal?.addEventListener('abort', () => reject(new Error('aborted')))
      })
  )
}

describe('useRoutePlanner undo while a calculation runs', () => {
  beforeEach(() => {
    routeMock.mockReset()
    localStorage.clear()
  })

  it('only abandons the calculation and keeps the history', async () => {
    const { result } = renderHook(() => useRoutePlanner())
    act(() => result.current.addControlPoint(A, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(1))
    act(() => result.current.addControlPoint(B, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))

    pendingRouter()
    act(() => result.current.addControlPoint(C, false))
    await waitFor(() => expect(result.current.isLoading).toBe(true))
    // a gesture arriving meanwhile is dropped (lock)
    act(() => result.current.addControlPoint(A, false))
    expect(routeMock).toHaveBeenCalledTimes(1)

    act(() => result.current.undo())
    await waitFor(() => expect(result.current.isLoading).toBe(false))
    expect(result.current.controlPoints).toHaveLength(2)
    expect(result.current.error).toBeNull()
  })
})

describe('useRoutePlanner router errors and team', () => {
  beforeEach(() => {
    routeMock.mockReset()
    localStorage.clear()
  })

  async function drawTwoPoints(teamSlug?: string) {
    const hook = renderHook(() => useRoutePlanner({ teamSlug }))
    act(() => hook.result.current.addControlPoint(A, true))
    await waitFor(() => expect(hook.result.current.controlPoints).toHaveLength(1))
    return hook
  }

  it('sends the team slug with the routed call', async () => {
    routeMock.mockResolvedValue({ route: { coordinates: [[B.lng, B.lat]] } })
    const { result } = await drawTwoPoints('club')
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(routeMock).toHaveBeenCalledTimes(1))
    expect(routeMock.mock.calls[0][0]).toMatchObject({ teamSlug: 'club' })
  })

  it('sends no team slug from the GPX tools', async () => {
    routeMock.mockResolvedValue({ route: { coordinates: [[B.lng, B.lat]] } })
    const { result } = await drawTwoPoints()
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(routeMock).toHaveBeenCalledTimes(1))
    expect(routeMock.mock.calls[0][0].teamSlug).toBeUndefined()
  })

  it.each([
    [ErrorCode.ROUTING_QUOTA_EXCEEDED, 503, 'planner.error.quota'],
    [ErrorCode.ROUTING_SEGMENT_TOO_LONG, 400, 'planner.error.segmentTooLong'],
    [ErrorCode.ROUTING_UNAVAILABLE, 503, 'planner.error.unavailable'],
    [ErrorCode.ROUTE_PLANNER_DISABLED, 400, 'planner.error.disabledSite'],
    [ErrorCode.FORBIDDEN, 403, 'planner.error.forbidden'],
    [ErrorCode.UNKNOWN, 500, 'planner.error.routing'],
  ])('maps %s to its own message and adds no point', async (code, status, key) => {
    routeMock.mockRejectedValue(apiError(code, status))
    const { result } = await drawTwoPoints()
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(result.current.error).toBe(key))
    expect(result.current.controlPoints).toHaveLength(1)
  })

  it('blames the team, not the site, when a team was named', async () => {
    routeMock.mockRejectedValue(apiError(ErrorCode.ROUTE_PLANNER_DISABLED, 400))
    const { result } = await drawTwoPoints('club')
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(result.current.error).toBe('planner.error.disabled'))
  })

  it('explains a missing route with the straight-line shortcut', async () => {
    routeMock.mockRejectedValue(apiError(ErrorCode.ROUTING_NO_ROUTE, 400))
    const { result } = await drawTwoPoints()
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(result.current.error).toBe('planner.error.noRoute'))
  })

  it('falls back on the generic message for a non API error', async () => {
    routeMock.mockRejectedValue(new Error('boom'))
    const { result } = await drawTwoPoints()
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(result.current.error).toBe('planner.error.routing'))
  })
})
