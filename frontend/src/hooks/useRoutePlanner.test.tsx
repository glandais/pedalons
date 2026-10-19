import { act, renderHook, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useRoutePlanner } from './useRoutePlanner'
import { ApiClientError } from '@/lib/apiError'
import { ErrorCode } from '@/api/dto'
import { DIRECT_WARNING_METERS } from '@/lib/planner'

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

describe('useRoutePlanner deletions (B12)', () => {
  /** A router answer that bows the segment, so that it holds routed points between its ends. */
  function bowedRouter() {
    routeMock.mockImplementation(async ({ from, to }: { from: typeof A; to: typeof A }) => {
      const coordinates = [[from.lng, from.lat]]
      for (let i = 1; i < 8; i++) {
        const t = i / 8
        coordinates.push([
          from.lng + t * (to.lng - from.lng),
          from.lat + t * (to.lat - from.lat) + 0.002 * Math.sin(Math.PI * t),
        ])
      }
      coordinates.push([to.lng, to.lat])
      return { route: { coordinates } }
    })
  }

  beforeEach(() => {
    routeMock.mockReset()
    localStorage.clear()
  })

  async function drawThree() {
    bowedRouter()
    const hook = renderHook(() => useRoutePlanner())
    act(() => hook.result.current.addControlPoint(A, false))
    await waitFor(() => expect(hook.result.current.controlPoints).toHaveLength(1))
    act(() => hook.result.current.addControlPoint(B, false))
    await waitFor(() => expect(hook.result.current.controlPoints).toHaveLength(2))
    act(() => hook.result.current.addControlPoint(C, false))
    await waitFor(() => expect(hook.result.current.controlPoints).toHaveLength(3))
    routeMock.mockClear()
    return hook
  }

  /** A track loaded from a file: six well spread corners, so that its anchors show at several zooms. */
  const TRACK = [
    [5.0, 45.0, 100],
    [5.02, 45.02, 100],
    [5.04, 45.0, 100],
    [5.05, 45.003, 100],
    [5.06, 45.0, 100],
    [5.08, 45.0, 100],
  ]

  it('removes an inner point with one request from its neighbour to the next, at any zoom', async () => {
    const { result } = await drawThree()
    act(() => result.current.removeControlPoint(result.current.controlPoints[1].idx, false, 16))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))
    expect(routeMock).toHaveBeenCalledTimes(1)
    const body = routeMock.mock.calls[0][0]
    expect(body.from.lng).toBeCloseTo(A.lng, 6)
    expect(body.to.lng).toBeCloseTo(C.lng, 6)
    expect(result.current.canUndo).toBe(true)
  })

  it('cuts the start of a drawn route at the next control point, whatever the zoom', async () => {
    const { result } = await drawThree()
    const next = result.current.controlPoints[1]
    act(() => result.current.removeControlPoint(result.current.controlPoints[0].idx, false, 0))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))
    expect(routeMock).not.toHaveBeenCalled()
    expect(result.current.route.points[0].id).toBe(next.id)
  })

  it('refuses to cut the start of an import at a zoom where no anchor shows', async () => {
    const hook = renderHook(() => useRoutePlanner({ initialTrack: TRACK }))
    const before = hook.result.current.route
    act(() => hook.result.current.removeControlPoint(0, false, 9))
    await waitFor(() => expect(hook.result.current.error).toBe('planner.error.cutNeedsZoom'))
    expect(hook.result.current.canUndo).toBe(false)
    expect(hook.result.current.route).toBe(before)
    expect(routeMock).not.toHaveBeenCalled()
  })

  it('removes an anchor with one request, and undoing it costs none', async () => {
    bowedRouter()
    const hook = renderHook(() => useRoutePlanner({ initialTrack: TRACK }))
    const points = hook.result.current.route.points
    act(() => hook.result.current.removeAnchor(points[1], points[5]))
    await waitFor(() => expect(hook.result.current.canUndo).toBe(true))
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(hook.result.current.route.points.some((p) => p.id === points[3].id)).toBe(false)

    act(() => hook.result.current.undo())
    await waitFor(() => expect(hook.result.current.canUndo).toBe(false))
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(hook.result.current.route.points.some((p) => p.id === points[3].id)).toBe(true)
  })
})

describe('useRoutePlanner straight lines (B6)', () => {
  beforeEach(() => {
    routeMock.mockReset()
    localStorage.clear()
  })

  it('keeps a session-long toggle that draws without the router and is not in the history', async () => {
    const setItem = vi.spyOn(localStorage, 'setItem')
    const { result } = renderHook(() => useRoutePlanner())
    expect(result.current.directMode).toBe(false)
    act(() => result.current.setDirectMode(true))
    expect(result.current.directMode).toBe(true)

    act(() => result.current.addControlPoint(A))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(1))
    act(() => result.current.addControlPoint(B))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))
    expect(routeMock).not.toHaveBeenCalled()

    act(() => result.current.undo())
    act(() => result.current.redo())
    act(() => result.current.clearRoute())
    expect(result.current.directMode).toBe(true)
    expect(setItem.mock.calls.some(([key]) => /direct/i.test(String(key)))).toBe(false)
    setItem.mockRestore()
  })

  it('exposes straight and routed legs, and undo / redo keep them without a request', async () => {
    routeMock.mockResolvedValue({
      route: {
        coordinates: [
          [B.lng, B.lat],
          [(B.lng + C.lng) / 2, B.lat + 0.001],
          [C.lng, C.lat],
        ],
      },
    })
    const { result } = renderHook(() => useRoutePlanner())
    act(() => result.current.addControlPoint(A, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(1))
    act(() => result.current.addControlPoint(B, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))
    act(() => result.current.addControlPoint(C, false))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(3))
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(result.current.routeLegsGeoJson?.features.map((f) => f.properties.direct)).toEqual([
      true,
      false,
    ])

    act(() => result.current.undo())
    expect(result.current.route.points.at(-1)!.direct).toBe(true)
    act(() => result.current.redo())
    expect(result.current.route.points.at(-1)!.direct).toBe(false)
    expect(routeMock).toHaveBeenCalledTimes(1)
  })

  it('inherits straight legs on removal, through the hook', async () => {
    const { result } = renderHook(() => useRoutePlanner())
    for (const p of [A, B, C]) {
      act(() => result.current.addControlPoint(p, true))
      await waitFor(() => expect(result.current.route.points.length).toBeGreaterThan(0))
    }
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(3))
    act(() => result.current.removeControlPoint(1))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))
    expect(routeMock).not.toHaveBeenCalled()
  })

  it('reports a straight leg longer than the warning threshold', async () => {
    const { result } = renderHook(() => useRoutePlanner())
    act(() => result.current.addControlPoint(A, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(1))
    expect(result.current.directStats.longest).toBe(0)
    act(() => result.current.addControlPoint(B, true))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(2))
    expect(result.current.directStats.longest).toBeGreaterThan(DIRECT_WARNING_METERS)
    expect(result.current.directStats.count).toBe(1)
  })
})

describe('useRoutePlanner elevation (B1)', () => {
  beforeEach(() => {
    routeMock.mockReset()
    localStorage.clear()
  })

  it('undo and redo hand back the climb of the legs', async () => {
    routeMock.mockImplementation(async ({ from, to }: { from: typeof A; to: typeof A }) => ({
      route: {
        coordinates: [
          [from.lng, from.lat, 100],
          [to.lng, to.lat, 150],
        ],
      },
      ascend: 50,
    }))
    const { result } = renderHook(() => useRoutePlanner())
    act(() => result.current.addControlPoint(A, false))
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(1))
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(result.current.route.ascend).toBe(50))
    act(() => result.current.addControlPoint(C, false))
    await waitFor(() => expect(result.current.route.ascend).toBe(100))

    act(() => result.current.undo())
    await waitFor(() => expect(result.current.route.ascend).toBe(50))
    expect(result.current.route.points.at(-1)?.legAscend).toBe(50)

    act(() => result.current.redo())
    await waitFor(() => expect(result.current.route.ascend).toBe(100))
    expect(result.current.route.points.at(-1)?.legAscend).toBe(50)
    expect(routeMock).toHaveBeenCalledTimes(2)
  })
})

describe('useRoutePlanner move keeping the id of the point', () => {
  beforeEach(() => {
    routeMock.mockReset()
    localStorage.clear()
  })

  it('is one history entry; undo hands back the old point with no request', async () => {
    const { result } = renderHook(() => useRoutePlanner())
    for (const p of [A, B, C]) {
      act(() => result.current.addControlPoint(p, true))
      await waitFor(() => expect(result.current.controlPoints.length).toBeGreaterThan(0))
    }
    await waitFor(() => expect(result.current.controlPoints).toHaveLength(3))
    const [pa, pb, pc] = result.current.controlPoints
    const moved = { lng: B.lng, lat: B.lat + 0.01 }

    act(() => result.current.updateControlPoint(pa, moved, pc, true, pb.id))
    await waitFor(() => expect(result.current.controlPoints[1].lat).toBeCloseTo(moved.lat))
    expect(result.current.controlPoints.map((p) => p.id)).toEqual([pa.id, pb.id, pc.id])

    act(() => result.current.undo())
    expect(result.current.controlPoints[1].lat).toBeCloseTo(B.lat)
    expect(result.current.controlPoints[1].id).toBe(pb.id)
    // 3 additions, 1 move: undoing the move leaves the 3 additions to undo
    act(() => result.current.undo())
    expect(result.current.controlPoints).toHaveLength(2)
    expect(routeMock).not.toHaveBeenCalled()
  })
})

describe('useRoutePlanner router tuning (C2)', () => {
  beforeEach(() => {
    routeMock.mockReset()
    routeMock.mockResolvedValue({ route: { coordinates: [[B.lng, B.lat]] } })
    localStorage.clear()
  })

  async function drawFirstPoint(profile = 'BIKE') {
    const hook = renderHook(() => useRoutePlanner())
    act(() => hook.result.current.setRouterProfile(profile as never))
    act(() => hook.result.current.addControlPoint(A, true))
    await waitFor(() => expect(hook.result.current.controlPoints).toHaveLength(1))
    return hook
  }

  it('sends no knob until one is set', async () => {
    const { result } = await drawFirstPoint()
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(routeMock).toHaveBeenCalledTimes(1))
    const keys = Object.keys(routeMock.mock.calls[0][0])
    expect(keys).not.toContain('useHills')
    expect(keys).not.toContain('useRoads')
  })

  it('setting a knob sends no request, leaves the history alone, and applies to the next gesture', async () => {
    const { result } = await drawFirstPoint()
    const canUndo = result.current.canUndo
    act(() => result.current.setRouterTuning('useHills', 0))
    expect(routeMock).not.toHaveBeenCalled()
    expect(result.current.canUndo).toBe(canUndo)
    expect(result.current.routerTuning).toEqual({ useHills: 0 })
    act(() => result.current.addControlPoint(B, false))
    await waitFor(() => expect(routeMock).toHaveBeenCalledTimes(1))
    expect(routeMock.mock.calls[0][0]).toMatchObject({ profile: 'BIKE', useHills: 0 })
    expect(Object.keys(routeMock.mock.calls[0][0])).not.toContain('useRoads')
  })

  it('remembers the knobs per profile', async () => {
    const { result } = await drawFirstPoint()
    act(() => result.current.setRouterTuning('useHills', 0))
    act(() => result.current.setRouterProfile('GRAVEL' as never))
    expect(result.current.routerTuning).toEqual({})
    act(() => result.current.setRouterTuning('useRoads', 1))
    act(() => result.current.setRouterProfile('BIKE' as never))
    expect(result.current.routerTuning).toEqual({ useHills: 0 })
  })

  it('stores a value equal to the profile as absent', async () => {
    const { result } = await drawFirstPoint()
    act(() => result.current.setRouterTuning('useRoads', 0.75))
    expect(result.current.routerTuning).toEqual({ useRoads: 0.75 })
    act(() => result.current.setRouterTuning('useRoads', 0.25)) // BIKE's own value
    expect(result.current.routerTuning).toEqual({})
  })

  it('treats FASTBIKE use_roads 1 as the profile value', async () => {
    const { result } = await drawFirstPoint()
    act(() => result.current.setRouterProfile('FASTBIKE' as never))
    act(() => result.current.setRouterTuning('useRoads', 1))
    expect(result.current.routerTuning).toEqual({})
  })

  it('resets the current profile only', async () => {
    const { result } = await drawFirstPoint()
    act(() => result.current.setRouterTuning('useHills', 1))
    act(() => result.current.setRouterProfile('MTB' as never))
    act(() => result.current.setRouterTuning('useHills', 0))
    act(() => result.current.resetRouterTuning())
    expect(result.current.routerTuning).toEqual({})
    act(() => result.current.setRouterProfile('BIKE' as never))
    expect(result.current.routerTuning).toEqual({ useHills: 1 })
  })
})
