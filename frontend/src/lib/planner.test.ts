import { beforeEach, describe, expect, it, vi } from 'vitest'
import { RouterProfile } from '@/api/dto'

// Router client simulated: every call returns a deterministic 3D geometry, a straight start, a
// detour through a midpoint 0.001 degree north (~111 m) that is 50 m higher, then the end.
// The elevation of a point on the ground is 100 + 1 m per 0.0001 degree of longitude east of 5.0.
const routeMock = vi.hoisted(() => vi.fn())
vi.mock('@/api/endpoints/router/router', () => ({ route: routeMock }))

import {
  add,
  computeRoute,
  createRoute,
  geojson,
  insert,
  remove,
  type Point,
  type Route,
  type RoutePoint,
} from './planner'

const PROFILE = RouterProfile.FASTBIKE

function groundEle(lng: number): number {
  return 100 + Math.round((lng - 5) * 10000)
}

interface RouteRequest {
  from: Point
  to: Point
  profile: RouterProfile
}

beforeEach(() => {
  routeMock.mockReset()
  routeMock.mockImplementation(async ({ from, to }: RouteRequest) => {
    const midLng = (from.lng + to.lng) / 2
    const midLat = (from.lat + to.lat) / 2 + 0.001
    return {
      route: {
        coordinates: [
          [from.lng, from.lat, groundEle(from.lng)],
          [midLng, midLat, groundEle(midLng) + 50],
          [to.lng, to.lat, groundEle(to.lng)],
        ],
      },
    }
  })
})

// ~786 m apart at latitude 45
const A: Point = { lng: 5.0, lat: 45.0 }
const B: Point = { lng: 5.01, lat: 45.0 }
const C: Point = { lng: 5.02, lat: 45.0 }
const D: Point = { lng: 5.03, lat: 45.0 }

function manualPoints(route: Route): RoutePoint[] {
  return route.points.filter((p) => p.manual)
}

function manualCoords(route: Route): number[][] {
  return manualPoints(route).map((p) => [p.lng, p.lat])
}

/** Route A -> B -> C built through add(), then the router mock is reset to count the next gesture. */
async function threePointRoute(): Promise<Route> {
  let route = computeRoute([])
  route = await add(route, A, PROFILE)
  route = await add(route, B, PROFILE)
  route = await add(route, C, PROFILE)
  routeMock.mockClear()
  return route
}

describe('computeRoute', () => {
  it('returns an empty route for no point', () => {
    const route = computeRoute([])
    expect(route.points).toEqual([])
    expect(route.dist).toBe(0)
    expect(route.ascend).toBe(0)
  })

  it('numbers the points and keeps the end points as manual', () => {
    const route = createRoute([
      [5.0, 45.0, 100],
      [5.005, 45.0005, 110],
      [5.01, 45.0, 120],
    ])
    expect(route.points.map((p) => p.idx)).toEqual([0, 1, 2])
    expect(route.points[0].manual).toBe(true)
    expect(route.points[2].manual).toBe(true)
  })

  it('drops points within 5 m of the line between their neighbours', () => {
    const route = createRoute([
      [5.0, 45.0, 100],
      [5.005, 45.0, 100],
      [5.01, 45.0, 100],
    ])
    expect(route.points).toHaveLength(2)
  })

  it('computes the distance and the positive elevation gain', () => {
    const route = createRoute([
      [5.0, 45.0, 100],
      [5.005, 45.001, 150],
      [5.01, 45.0, 120],
    ])
    expect(route.points).toHaveLength(3)
    // +50 then -30: only the climb counts
    expect(route.ascend).toBe(50)
    // two legs of ~393 m east and ~111 m north: a bit over 800 m, well under 1 km
    expect(route.dist).toBeGreaterThan(800)
    expect(route.dist).toBeLessThan(900)
  })

  it('counts a missing elevation as 0 m', () => {
    const route = createRoute([
      [5.0, 45.0],
      [5.005, 45.001, 40],
      [5.01, 45.0, 40],
    ])
    expect(route.ascend).toBe(40)
  })

  it('exposes a GeoJSON line made of lng/lat pairs without elevation', () => {
    const route = createRoute([
      [5.0, 45.0, 100],
      [5.005, 45.001, 150],
      [5.01, 45.0, 120],
    ])
    expect(geojson(route)).toEqual({
      type: 'LineString',
      coordinates: [
        [5.0, 45.0],
        [5.005, 45.001],
        [5.01, 45.0],
      ],
    })
  })
})

describe('add', () => {
  it('adds the first point without calling the router', async () => {
    const route = await add(computeRoute([]), A, PROFILE)
    expect(routeMock).not.toHaveBeenCalled()
    expect(route.points).toHaveLength(1)
    expect(route.points[0]).toMatchObject({ lng: A.lng, lat: A.lat, manual: true })
    expect(route.dist).toBe(0)
    expect(route.ascend).toBe(0)
  })

  it('passes the team slug to the router when given', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    await add(first, B, PROFILE, false, undefined, 'club')
    expect(routeMock).toHaveBeenCalledWith(
      expect.objectContaining({ teamSlug: 'club' }),
      { skipErrorToast: true },
      undefined
    )
  })

  it('adds the second point with exactly one router call carrying the profile', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    const route = await add(first, B, RouterProfile.FASTBIKE)
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(routeMock).toHaveBeenCalledWith(
      {
        from: expect.objectContaining({ lng: A.lng, lat: A.lat }),
        to: B,
        profile: RouterProfile.FASTBIKE,
      },
      { skipErrorToast: true },
      undefined
    )
    expect(manualCoords(route)).toEqual([
      [A.lng, A.lat],
      [B.lng, B.lat],
    ])
    // the detour point is kept, it is not collinear
    expect(route.points).toHaveLength(3)
    expect(route.dist).toBeGreaterThan(786)
  })

  it('calls the router once more for each further point', async () => {
    const route = await threePointRoute()
    routeMock.mockClear()
    const next = await add(route, D, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(manualPoints(next)).toHaveLength(4)
    expect(next.points[next.points.length - 1]).toMatchObject({ lng: D.lng, lat: D.lat })
  })

  it('computes the ascent from the elevation of the routed geometry', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    const route = await add(first, B, PROFILE)
    // The first control point has no elevation (counted as 0 m) while the router returns it at
    // 100 m, so that step counts as a climb too: the ascent is the sum of the positive steps.
    const climbs = route.points
      .slice(1)
      .reduce((sum, p, i) => sum + Math.max(0, (p.ele ?? 0) - (route.points[i].ele ?? 0)), 0)
    expect(route.ascend).toBe(climbs)
    expect(route.ascend).toBeGreaterThan(0)
  })

  it('snaps the previous control point to the first coordinate returned by the router', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    routeMock.mockImplementationOnce(async ({ to }: RouteRequest) => ({
      route: {
        coordinates: [
          [5.00005, 45.00005, 100],
          [to.lng, to.lat, 110],
        ],
      },
    }))
    const route = await add(first, B, PROFILE)
    expect(route.points[0]).toMatchObject({ lng: 5.00005, lat: 45.00005 })
  })

  it('does not call the router in direct mode (straight line)', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    const route = await add(first, B, PROFILE, true)
    expect(routeMock).not.toHaveBeenCalled()
    expect(route.points).toHaveLength(2)
    expect(route.points[1]).toMatchObject({ lng: B.lng, lat: B.lat, manual: true })
  })

  it('keeps the previous control point in place in direct mode', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    const route = await add(first, B, PROFILE, true)
    expect(route.points[0]).toMatchObject({ lng: A.lng, lat: A.lat })
    expect(route.dist).toBeGreaterThan(780)
  })

  it('does not call the router for a point closer than 5 m', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    // 0.00002 degree of latitude is ~2.2 m
    const route = await add(first, { lng: A.lng, lat: A.lat + 0.00002 }, PROFILE)
    expect(routeMock).not.toHaveBeenCalled()
    expect(route.points).toHaveLength(2)
  })

  it('still calls the router for a point 5 m or more away', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    // 0.0001 degree of latitude is ~11 m
    await add(first, { lng: A.lng, lat: A.lat + 0.0001 }, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(1)
  })

  it('propagates a router failure and leaves the caller to handle it', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    routeMock.mockRejectedValueOnce(new Error('boom'))
    await expect(add(first, B, PROFILE)).rejects.toThrow('boom')
  })
})

describe('insert', () => {
  it('inserts between two control points with two router calls', async () => {
    const route = await threePointRoute()
    const [pa, pb] = manualPoints(route)
    const mid: Point = { lng: 5.005, lat: 45.002 }
    const result = await insert(route, pa, mid, pb, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(2)
    expect(routeMock).toHaveBeenCalledWith(
      expect.objectContaining({ to: mid }),
      { skipErrorToast: true },
      undefined
    )
    expect(routeMock).toHaveBeenCalledWith(
      expect.objectContaining({ from: mid }),
      { skipErrorToast: true },
      undefined
    )
    expect(manualPoints(result)).toHaveLength(4)
    expect(manualCoords(result)).toContainEqual([mid.lng, mid.lat])
  })

  it('keeps the control points order', async () => {
    const route = await threePointRoute()
    const [pa, pb] = manualPoints(route)
    const mid: Point = { lng: 5.005, lat: 45.002 }
    const result = await insert(route, pa, mid, pb, PROFILE)
    expect(manualCoords(result)).toEqual([
      [A.lng, A.lat],
      [mid.lng, mid.lat],
      [B.lng, B.lat],
      [C.lng, C.lat],
    ])
  })

  it('appends after the last point with one router call (no end point)', async () => {
    const route = await threePointRoute()
    const pcPoint = manualPoints(route)[2]
    const result = await insert(route, pcPoint, D, undefined, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(manualCoords(result)[3]).toEqual([D.lng, D.lat])
  })

  it('prepends before the first point with one router call (no start point)', async () => {
    const route = await threePointRoute()
    const pa = manualPoints(route)[0]
    const before: Point = { lng: 4.99, lat: 45.0 }
    const result = await insert(route, undefined, before, pa, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(manualCoords(result)[0]).toEqual([before.lng, before.lat])
    expect(manualPoints(result)).toHaveLength(4)
  })

  it('makes no router call in direct mode', async () => {
    const route = await threePointRoute()
    const [pa, pb] = manualPoints(route)
    const mid: Point = { lng: 5.005, lat: 45.002 }
    const result = await insert(route, pa, mid, pb, PROFILE, true)
    expect(routeMock).not.toHaveBeenCalled()
    expect(manualPoints(result)).toHaveLength(4)
  })

  it('keeps the neighbours in place in direct mode', async () => {
    const route = await threePointRoute()
    const [pa, pb] = manualPoints(route)
    const mid: Point = { lng: 5.005, lat: 45.002 }
    const result = await insert(route, pa, mid, pb, PROFILE, true)
    expect(manualCoords(result)).toEqual([
      [A.lng, A.lat],
      [mid.lng, mid.lat],
      [B.lng, B.lat],
      [C.lng, C.lat],
    ])
  })

  it('skips the leg to a neighbour that is within 5 m', async () => {
    const route = await threePointRoute()
    const [pa, pb] = manualPoints(route)
    // a point ~2 m from A: the leg A -> p is skipped, the leg p -> B is not (it is ~786 m)
    await insert(route, pa, { lng: A.lng, lat: A.lat + 0.00002 }, pb, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(1)
  })

  it('snaps the inserted point to the end of the first routed leg', async () => {
    const route = await threePointRoute()
    const [pa, pb] = manualPoints(route)
    routeMock.mockImplementation(async ({ from, to }: RouteRequest) => ({
      route: {
        coordinates: [
          [from.lng, from.lat, 100],
          [to.lng + 0.00003, to.lat + 0.00003, 100],
        ],
      },
    }))
    const result = await insert(route, pa, { lng: 5.005, lat: 45.002 }, pb, PROFILE)
    const inserted = manualPoints(result)[1]
    expect(inserted.lng).toBeCloseTo(5.00503, 6)
    expect(inserted.lat).toBeCloseTo(45.00203, 6)
  })

  it('increases the distance', async () => {
    const route = await threePointRoute()
    const before = route.dist
    const [pa, pb] = manualPoints(route)
    const result = await insert(route, pa, { lng: 5.005, lat: 45.01 }, pb, PROFILE)
    expect(result.dist).toBeGreaterThan(before)
  })
})

describe('insert used as a move (drag of an interior control point)', () => {
  it('costs two router calls and keeps the number of control points', async () => {
    const route = await threePointRoute()
    const [pa, , pc] = manualPoints(route)
    const moved: Point = { lng: 5.01, lat: 45.003 }
    // The hook's updateControlPoint calls insert with the neighbours of the dragged point:
    // the old geometry between them is replaced, not the dragged point itself.
    const result = await insert(route, pa, moved, pc, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(2)
    // Not an insertion: everything between the two neighbours (here B) is replaced by the moved point
    expect(manualCoords(result)).toEqual([
      [A.lng, A.lat],
      [moved.lng, moved.lat],
      [C.lng, C.lat],
    ])
  })

  it('costs one router call for the first or last point', async () => {
    const route = await threePointRoute()
    const pb = manualPoints(route)[1]
    await insert(route, undefined, { lng: 4.995, lat: 45.0 }, pb, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(1)
  })
})

describe('remove', () => {
  it('removes an interior control point with one router call', async () => {
    const route = await threePointRoute()
    const [pa, , pc] = manualPoints(route)
    const result = await remove(route, pa, pc, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(routeMock).toHaveBeenCalledWith(
      expect.objectContaining({
        from: expect.objectContaining({ lng: A.lng }),
        to: expect.objectContaining({ lng: C.lng }),
      }),
      { skipErrorToast: true },
      undefined
    )
    expect(manualCoords(result)).toEqual([
      [A.lng, A.lat],
      [C.lng, C.lat],
    ])
  })

  it('removes the first point without calling the router', async () => {
    const route = await threePointRoute()
    const pb = manualPoints(route)[1]
    const result = await remove(route, undefined, pb, PROFILE)
    expect(routeMock).not.toHaveBeenCalled()
    expect(manualCoords(result)).toEqual([
      [B.lng, B.lat],
      [C.lng, C.lat],
    ])
  })

  it('removes the last point without calling the router', async () => {
    const route = await threePointRoute()
    const pb = manualPoints(route)[1]
    const result = await remove(route, pb, undefined, PROFILE)
    expect(routeMock).not.toHaveBeenCalled()
    expect(manualCoords(result)).toEqual([
      [A.lng, A.lat],
      [B.lng, B.lat],
    ])
  })

  it('clears the route when neither neighbour is given', async () => {
    const route = await threePointRoute()
    const result = await remove(route, undefined, undefined, PROFILE)
    expect(routeMock).not.toHaveBeenCalled()
    expect(result.points).toEqual([])
    expect(result.dist).toBe(0)
  })

  it('reconnects with a straight line in direct mode', async () => {
    const route = await threePointRoute()
    const [pa, , pc] = manualPoints(route)
    const result = await remove(route, pa, pc, PROFILE, true)
    expect(routeMock).not.toHaveBeenCalled()
    expect(result.points).toHaveLength(2)
    expect(result.dist).toBeGreaterThan(1570)
    expect(result.dist).toBeLessThan(1575)
  })

  it('reduces the distance of the route', async () => {
    const route = await threePointRoute()
    const before = route.dist
    const [pa, , pc] = manualPoints(route)
    const result = await remove(route, pa, pc, PROFILE, true)
    expect(result.dist).toBeLessThan(before)
  })
})

describe('distance and ascent of a routed line', () => {
  it('matches the sum of the legs and the positive elevation steps', async () => {
    const route = await threePointRoute()
    let dist = 0
    let up = 0
    for (let i = 1; i < route.points.length; i++) {
      const p = route.points[i - 1]
      const q = route.points[i]
      const dLat = ((q.lat - p.lat) * Math.PI) / 180
      const dLng = ((q.lng - p.lng) * Math.PI) / 180
      const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos((p.lat * Math.PI) / 180) *
          Math.cos((q.lat * Math.PI) / 180) *
          Math.sin(dLng / 2) ** 2
      dist += 2 * 6371000 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      up += Math.max(0, (q.ele ?? 0) - (p.ele ?? 0))
    }
    expect(route.dist).toBeCloseTo(dist, 6)
    expect(route.ascend).toBe(up)
    expect(route.dist).toBeGreaterThan(1572)
  })
})

describe('abandoned operations (AbortSignal)', () => {
  const aborted = () => {
    const controller = new AbortController()
    controller.abort()
    return controller.signal
  }

  it('add rejects without a router call and leaves the route untouched', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    const before = first.points.map((p) => ({ ...p }))
    await expect(add(first, B, PROFILE, false, aborted())).rejects.toThrow()
    expect(routeMock).not.toHaveBeenCalled()
    expect(first.points).toEqual(before)
  })

  it('insert and remove reject without a router call', async () => {
    const route = await threePointRoute()
    routeMock.mockClear()
    const [pa, pb, pc] = manualPoints(route)
    const before = route.points.map((p) => ({ ...p }))
    await expect(insert(route, pa, B, pc, PROFILE, false, aborted())).rejects.toThrow()
    await expect(remove(route, pa, pc, PROFILE, false, aborted())).rejects.toThrow()
    expect(pb).toBeDefined()
    expect(routeMock).not.toHaveBeenCalled()
    expect(route.points).toEqual(before)
  })

  it('a signal aborted while the router answers leaves the route intact and passes the signal on', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    const controller = new AbortController()
    routeMock.mockImplementationOnce(
      async (_body: unknown, _opts: unknown, signal: AbortSignal) => {
        controller.abort()
        signal.throwIfAborted()
      }
    )
    const lengthBefore = first.points.length
    await expect(add(first, B, PROFILE, false, controller.signal)).rejects.toThrow()
    expect(routeMock).toHaveBeenLastCalledWith(
      expect.anything(),
      { skipErrorToast: true },
      controller.signal
    )
    expect(first.points).toHaveLength(lengthBefore)
    expect(first.points[0].manual).toBe(true)
  })
})
