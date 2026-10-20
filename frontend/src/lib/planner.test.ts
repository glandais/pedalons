import { beforeEach, describe, expect, it, vi } from 'vitest'
import { RouterProfile } from '@/api/dto'

// Router client simulated: every call returns a deterministic 3D geometry, a straight start, a
// detour through a midpoint 0.001 degree north (~111 m) that is 50 m higher, then the end.
// The elevation of a point on the ground is 100 + 1 m per 0.0001 degree of longitude east of 5.0.
const routeMock = vi.hoisted(() => vi.fn())
const lineElevationMock = vi.hoisted(() => vi.fn())
vi.mock('@/api/endpoints/router/router', () => ({
  route: routeMock,
  lineElevation: lineElevationMock,
}))

import {
  add,
  computeRoute,
  createRoute,
  directStats,
  edgeKey,
  fillElevations,
  geojson,
  insert,
  isStraightSpan,
  legBounds,
  legsGeojson,
  nearestSegment,
  plannerRouteToMappable,
  PlannerRefusedError,
  remove,
  restoreSourceSpan,
  routeAscend,
  sourceOf,
  spanBounds,
  straightEdgesMissingProfile,
  withDirectProfiles,
  type DirectProfile,
  type Point,
  type Route,
  type RouterSettings,
  type RoutePoint,
} from './planner'

const PROFILE: RouterSettings = { profile: RouterProfile.FASTBIKE }

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
      ascend: 50,
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

  it('skips a missing elevation instead of inventing a climb from 0 m', () => {
    const route = createRoute([
      [5.0, 45.0],
      [5.005, 45.001, 40],
      [5.01, 45.0, 40],
    ])
    expect(route.ascend).toBe(0)
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

  it('sends the tuning knobs that are set, and only those', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    await add(first, B, { profile: RouterProfile.BIKE, useHills: 0 })
    const body = routeMock.mock.calls[0][0]
    expect(body).toMatchObject({ profile: RouterProfile.BIKE, useHills: 0 })
    expect(Object.keys(body)).not.toContain('useRoads')
  })

  it('sends neither knob when the settings carry none', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    await add(first, B, { profile: RouterProfile.BIKE, useHills: undefined, useRoads: undefined })
    const keys = Object.keys(routeMock.mock.calls[0][0])
    expect(keys).not.toContain('useHills')
    expect(keys).not.toContain('useRoads')
  })

  it('adds the second point with exactly one router call carrying the profile', async () => {
    const first = await add(computeRoute([]), A, PROFILE)
    const route = await add(first, B, PROFILE)
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
    // The router's own figure for the leg, not the elevation steps of its geometry, and the first
    // control point takes the road's elevation instead of counting from 0 m.
    expect(route.ascend).toBe(50)
    expect(route.points[0].ele).toBe(100)
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
    const [pa, pb, pc] = manualPoints(route)
    const moved: Point = { lng: 5.01, lat: 45.003 }
    // The planner moves a point with the leg bounds of the dragged point: the old geometry
    // between them is replaced, not the dragged point itself.
    const { start, end } = legBounds(
      route,
      route.points.indexOf(pb) - 1,
      route.points.indexOf(pb) + 1
    )
    expect(start!.id).toBe(pa.id)
    expect(end!.id).toBe(pc.id)
    const result = await insert(route, start, moved, end, PROFILE)
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

  it('gives the moved point a new id, unless keepId says otherwise', async () => {
    const route = await threePointRoute()
    const [pa, pb, pc] = manualPoints(route)
    const { start, end } = legBounds(
      route,
      route.points.indexOf(pb) - 1,
      route.points.indexOf(pb) + 1
    )
    const plain = await insert(route, start, { lng: 5.01, lat: 45.003 }, end, PROFILE)
    expect(manualPoints(plain).map((p) => p.id)).not.toContain(pb.id)

    routeMock.mockClear()
    const kept = await insert(
      route,
      start,
      { lng: 5.01, lat: 45.003 },
      end,
      PROFILE,
      false,
      undefined,
      undefined,
      pb.id
    )
    expect(routeMock).toHaveBeenCalledTimes(2)
    expect(manualPoints(kept).map((p) => p.id)).toEqual([pa.id, pb.id, pc.id])
    // No two points share an id
    expect(new Set(kept.points.map((p) => p.id)).size).toBe(kept.points.length)
  })

  it('keeps the id of the first and of the last point moved, with one router call', async () => {
    const route = await threePointRoute()
    const [pa, pb, pc] = manualPoints(route)
    routeMock.mockClear()
    const first = await insert(
      route,
      undefined,
      { lng: 4.995, lat: 45 },
      pb,
      PROFILE,
      false,
      undefined,
      undefined,
      pa.id
    )
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(first.points[0].id).toBe(pa.id)
    routeMock.mockClear()
    const last = await insert(
      route,
      pb,
      { lng: 5.03, lat: 45 },
      undefined,
      PROFILE,
      false,
      undefined,
      undefined,
      pc.id
    )
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(last.points.at(-1)!.id).toBe(pc.id)
    expect(new Set(last.points.map((p) => p.id)).size).toBe(last.points.length)
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
        from: expect.objectContaining({ lng: A.lng, lat: A.lat }),
        to: expect.objectContaining({ lng: C.lng, lat: C.lat }),
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
    expect(result.points[0].id).toBe(pb.id)
    expect(result.points[0].manual).toBe(true)
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
    expect(result.points.at(-1)!.id).toBe(pb.id)
    expect(result.points.at(-1)!.manual).toBe(true)
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
    expect(result.points[1].direct).toBe(true)
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
  it('matches the sum of the legs and the climb the router measured for each', async () => {
    const route = await threePointRoute()
    let dist = 0
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
    }
    expect(route.dist).toBeCloseTo(dist, 6)
    expect(route.ascend).toBe(100)
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

// ---------------------------------------------------------------------------------------------
// B12: gesture bounds independent of the zoom, local simplification, anchor removal

interface Leg {
  from: Point
  to: Point
}

/** Router answer along an arc: n + 1 points, exactly `from` first and `to` last, bulging to the left. */
function arcAnswer({ from, to }: Leg, n = 8, bulge = 0.1) {
  const dLng = to.lng - from.lng
  const dLat = to.lat - from.lat
  const chord = Math.hypot(dLng, dLat)
  const coordinates: number[][] = []
  for (let i = 0; i <= n; i++) {
    const t = i / n
    let lng = to.lng
    let lat = to.lat
    if (i === 0) {
      lng = from.lng
      lat = from.lat
    } else if (i < n) {
      const off = bulge * chord * 4 * t * (1 - t)
      lng = from.lng + t * dLng + (-dLat / chord) * off
      lat = from.lat + t * dLat + (dLng / chord) * off
    }
    coordinates.push([lng, lat, groundEle(lng)])
  }
  return { route: { coordinates } }
}

const VERTICES: number[][] = [
  [5.0, 45.0],
  [5.02, 45.02],
  [5.04, 45.0],
  [5.05, 45.003],
  [5.06, 45.0],
  [5.08, 45.0],
]

/** Straight legs between the corners, `perLeg` intervals each (so perLeg * legs + 1 points). */
function densify(corners: number[][], perLeg: number): number[][] {
  const out: number[][] = []
  for (let i = 0; i < corners.length - 1; i++) {
    for (let k = 0; k < perLeg; k++) {
      const t = k / perLeg
      out.push([
        corners[i][0] + t * (corners[i + 1][0] - corners[i][0]),
        corners[i][1] + t * (corners[i + 1][1] - corners[i][1]),
        100,
      ])
    }
  }
  out.push([...corners[corners.length - 1], 100])
  return out
}

const IMPORT = densify(VERTICES, 10)

function importedRoute(): Route {
  return createRoute(IMPORT)
}

const snapshot = (route: Route) => route.points.map((p) => ({ ...p }))
const near = (a: Point, b: Point) => {
  expect(a.lng).toBeCloseTo(b.lng, 6)
  expect(a.lat).toBeCloseTo(b.lat, 6)
}

describe('B12 gesture bounds', () => {
  let legs: Leg[]

  beforeEach(() => {
    legs = []
    routeMock.mockReset()
    routeMock.mockImplementation(async ({ from, to }: RouteRequest) => {
      // Copies: the planner moves the points the request was built from
      legs.push({ from: { lng: from.lng, lat: from.lat }, to: { lng: to.lng, lat: to.lat } })
      return arcAnswer({ from, to })
    })
  })

  async function drawn(...points: Point[]): Promise<Route> {
    let route = computeRoute([])
    for (const p of points) route = await add(route, p, PROFILE)
    legs.length = 0
    routeMock.mockClear()
    return route
  }

  const levels = (route: Route) => route.points.map((p) => ({ id: p.id, zoom: p.zoom }))

  it('1. tracks where the imported points come from', async () => {
    const imported = importedRoute()
    expect(imported.points.every((p) => p.imported)).toBe(true)
    // known levels of the zigzag
    expect(imported.points).toHaveLength(6)
    imported.points.forEach((p, i) => {
      expect(p.lng).toBeCloseTo(VERTICES[i][0], 9)
      expect(p.lat).toBeCloseTo(VERTICES[i][1], 9)
    })
    expect(imported.points.map((p) => p.zoom)).toEqual([0, 11, 12, 14, 14, 0])
    expect(imported.points.map((p) => p.manual)).toEqual([true, false, false, false, false, true])

    const first = await add(computeRoute([]), A, PROFILE)
    expect(first.points[0].imported).toBe(false)

    let route = await drawn(A, B, C)
    const [pa, , pc] = manualPoints(route)
    route = await insert(route, pa, { lng: 5.005, lat: 45.002 }, pc, PROFILE)
    const m = route.points.find((p) => p.manual && p.lng === 5.005)
    expect(m).toBeDefined()
    const { start, end } = legBounds(
      route,
      route.points.indexOf(m!) - 1,
      route.points.indexOf(m!) + 1
    )
    route = await remove(route, start, end, PROFILE)
    expect(route.points.some((p) => p.imported)).toBe(false)

    const extended = await add(imported, { lng: 5.1, lat: 45.01 }, PROFILE)
    const oldEnd = extended.points.find((p) => p.lng === 5.08 && p.lat === 45.0)!
    expect(oldEnd.imported).toBe(true)
    expect(oldEnd.manual).toBe(true)
    expect(extended.points.slice(6).every((p) => !p.imported)).toBe(true)
    expect(extended.points.at(-1)!.imported).toBe(false)

    // what the router adds on an import is not imported: insert...
    const base = importedRoute()
    const [, , , v3, v4] = base.points
    const ins = await insert(base, v3, { lng: 5.055, lat: 45.05 }, v4, PROFILE)
    const i3 = ins.points.findIndex((p) => p.id === v3.id)
    const i4 = ins.points.findIndex((p) => p.id === v4.id)
    expect(i4 - i3).toBeGreaterThan(1)
    expect(ins.points.slice(i3 + 1, i4).every((p) => !p.imported)).toBe(true)
    expect(ins.points.slice(0, i3 + 1).every((p) => p.imported)).toBe(true)
    expect(ins.points.slice(i4).every((p) => p.imported)).toBe(true)

    // ... and remove
    const base2 = importedRoute()
    const [, w1, , , , w5] = base2.points
    const rem = await remove(base2, w1, w5, PROFILE)
    const j1 = rem.points.findIndex((p) => p.id === w1.id)
    const j5 = rem.points.findIndex((p) => p.id === w5.id)
    expect(j5 - j1).toBeGreaterThan(1)
    expect(rem.points.slice(j1 + 1, j5).every((p) => !p.imported)).toBe(true)
    expect(rem.points.slice(0, j1 + 1).every((p) => p.imported)).toBe(true)
    expect(rem.points.slice(j5).every((p) => p.imported)).toBe(true)

    // the copy the hook keeps for undo/redo keeps the field
    expect(snapshot(ins).map((p) => p.imported)).toEqual(ins.points.map((p) => p.imported))
  })

  it('2. legBounds ignores the zoom, spanBounds ignores routed points', async () => {
    const route = await drawn(A, B, C)
    const [pa, pb, pc] = manualPoints(route)
    const iB = route.points.indexOf(pb)
    const leg = legBounds(route, iB - 1, iB + 1)
    expect(leg.start!.id).toBe(pa.id)
    expect(leg.end!.id).toBe(pc.id)
    for (const z of [0, 12, 22]) {
      const span = spanBounds(route, iB - 1, iB + 1, z)
      expect(span.start!.id).toBe(pa.id)
      expect(span.end!.id).toBe(pc.id)
    }
    const j = 1
    expect(route.points[j].manual).toBe(false)
    const around = legBounds(route, j, j)
    expect(around.start!.id).toBe(pa.id)
    expect(around.end!.id).toBe(pb.id)
    // nothing on one side
    expect(legBounds(route, -1, 1).start).toBeUndefined()
    expect(legBounds(route, 1, route.points.length).end).toBeUndefined()
  })

  it('3. removing an inner point reroutes once between its neighbours', async () => {
    const M = { lng: 5.01, lat: 45.03 }
    const route = await drawn(A, M, C)
    const iM = route.points.findIndex((p) => p.lat === M.lat)
    const { start, end } = legBounds(route, iM - 1, iM + 1)
    const result = await remove(route, start, end, PROFILE)
    expect(legs).toHaveLength(1)
    near(legs[0].from, A)
    near(legs[0].to, C)
    expect(Math.max(...result.points.map((p) => p.lat))).toBeLessThan(45.005)
    expect(manualPoints(result)).toHaveLength(2)

    // a router refusal leaves the route as it was
    const again = await drawn(A, M, C)
    const before = snapshot(again)
    routeMock.mockRejectedValueOnce(new Error('ROUTING_SEGMENT_TOO_LONG'))
    const iM2 = again.points.findIndex((p) => p.lat === M.lat)
    const b = legBounds(again, iM2 - 1, iM2 + 1)
    await expect(remove(again, b.start, b.end, PROFILE)).rejects.toThrow()
    expect(again.points).toEqual(before)
  })

  it('4. removing an inserted point on an import keeps the track around it', async () => {
    const r = importedRoute()
    const [v0, v1, v2, v3, v4, v5] = r.points
    const outside = [v0, v3, v4, v5].map((p) => ({ id: p.id, lng: p.lng, lat: p.lat }))
    const M = { lng: 5.03, lat: 45.012 }
    const { start: s0, end: e0 } = spanBounds(r, 1, 2, 16)
    expect([s0!.id, e0!.id]).toEqual([v1.id, v2.id])
    const inserted = await insert(r, s0, M, e0, PROFILE, false)
    legs.length = 0
    const iM = inserted.points.findIndex((p) => p.manual && !p.imported)
    const { start, end } = legBounds(inserted, iM - 1, iM + 1)
    expect([start!.id, end!.id]).toEqual([v1.id, v2.id])
    const result = await remove(inserted, start, end, PROFILE)
    expect(legs).toHaveLength(1)
    near(legs[0].from, { lng: 5.02, lat: 45.02 })
    near(legs[0].to, { lng: 5.04, lat: 45.0 })
    for (const o of outside) {
      const p = result.points.find((q) => q.id === o.id)!
      expect(p).toBeDefined()
      expect([p.lng, p.lat]).toEqual([o.lng, o.lat])
    }
  })

  it('4. a loop keeps its length when an inserted point is removed', async () => {
    const dLat = 2000 / 111320
    const dLng = 2000 / (111320 * Math.cos((45 * Math.PI) / 180))
    const square = [
      [5, 45],
      [5 + dLng, 45],
      [5 + dLng, 45 + dLat],
      [5, 45 + dLat],
      [5, 45.00002],
    ]
    const loop = createRoute(densify(square, 20))
    const initial = loop.dist
    const M = { lng: 5 + dLng / 2, lat: 45.0005 }
    const iSeg = nearestSegment(loop, M)!.index
    const { start: s0, end: e0 } = spanBounds(loop, iSeg, iSeg + 1, 16)
    const inserted = await insert(loop, s0, M, e0, PROFILE)
    legs.length = 0
    const iM = inserted.points.findIndex((p) => p.manual && !p.imported)
    const { start, end } = legBounds(inserted, iM - 1, iM + 1)
    const result = await remove(inserted, start, end, PROFILE)
    const last = legs.at(-1)!
    const dStart = Math.hypot(last.from.lng - 5, last.from.lat - 45)
    const dEnd = Math.hypot(last.to.lng - 5, last.to.lat - 45.00002)
    expect(dStart < 1e-4 && dEnd < 1e-4).toBe(false)
    expect(result.dist).toBeGreaterThan(0.8 * initial)
  })

  it('5. cutting an end of a drawn route does not depend on the zoom', async () => {
    for (const z of [0, 22]) {
      const route = await drawn(A, B, C)
      const [, pb] = manualPoints(route)
      const { start, end } = spanBounds(route, -1, 1, z)
      expect(start).toBeUndefined()
      const result = await remove(route, start, end, PROFILE)
      expect(routeMock).not.toHaveBeenCalled()
      expect(result.points[0].id).toBe(pb.id)
      expect(result.points[0].manual).toBe(true)
    }
  })

  it('5. cutting an import: refused when no anchor shows, else cut at the first one', async () => {
    const r = importedRoute()
    const before = snapshot(r)
    const low = spanBounds(r, -1, 1, 10)
    await expect(remove(r, low.start, low.end, PROFILE)).rejects.toBeInstanceOf(PlannerRefusedError)
    expect(r.points).toEqual(before)
    expect(routeMock).not.toHaveBeenCalled()

    const at11 = spanBounds(r, -1, 1, 11)
    const cut = await remove(r, at11.start, at11.end, PROFILE)
    expect(routeMock).not.toHaveBeenCalled()
    expect(cut.points[0].id).toBe(before[1].id)
    expect(cut.points[0].manual).toBe(true)

    const r2 = importedRoute()
    const last = r2.points.length - 1
    const at12 = spanBounds(r2, last - 1, last + 1, 12)
    expect(at12.start!.id).toBe(r2.points[2].id)
    const cutEnd = await remove(r2, at12.start, at12.end, PROFILE)
    expect(cutEnd.points.at(-1)!.id).toBe(r2.points[2].id)
    expect(cutEnd.points.at(-1)!.manual).toBe(true)
  })

  it('6. removing an anchor reroutes once between the visible anchors', async () => {
    const r = importedRoute()
    const [, v1, v2, v3, v4, v5] = r.points
    const bounds = spanBounds(r, 1, 3, 12)
    expect([bounds.start!.id, bounds.end!.id]).toEqual([v1.id, v5.id])
    const result = await remove(r, bounds.start, bounds.end, PROFILE)
    expect(legs).toHaveLength(1)
    near(legs[0].from, { lng: 5.02, lat: 45.02 })
    near(legs[0].to, { lng: 5.08, lat: 45.0 })
    const ids = result.points.map((p) => p.id)
    for (const gone of [v2, v3, v4]) expect(ids).not.toContain(gone.id)

    const direct = importedRoute()
    legs.length = 0
    const b2 = spanBounds(direct, 1, 3, 12)
    await remove(direct, b2.start, b2.end, PROFILE, true)
    expect(legs).toHaveLength(0)
  })

  it('6. an abandoned signal rejects, even in a straight line', async () => {
    const controller = new AbortController()
    controller.abort()
    for (const direct of [false, true]) {
      const r = importedRoute()
      const before = snapshot(r)
      const b = spanBounds(r, 1, 3, 12)
      await expect(remove(r, b.start, b.end, PROFILE, direct, controller.signal)).rejects.toThrow()
      expect(legs).toHaveLength(0)
      expect(r.points).toEqual(before)
    }
  })

  it('7. inserting on a routed leg always routes between the manual points', async () => {
    for (const z of [0, 12, 22]) {
      const route = await drawn(A, B, C)
      const seg = nearestSegment(route, { lng: 5.005, lat: 45.0 })!
      const { start, end } = spanBounds(route, seg.index, seg.index + 1, z)
      await insert(route, start, seg.point, end, PROFILE)
      expect(legs).toHaveLength(2)
      near(legs[0].from, A)
      near(legs[1].to, B)
      legs.length = 0
    }
  })

  it('7. inserting on an import is bounded by the anchors visible at the zoom', async () => {
    const target = { lng: 5.055, lat: 45.0015 }
    const expected: Array<[number, Point, Point]> = [
      [12, { lng: 5.04, lat: 45.0 }, { lng: 5.08, lat: 45.0 }],
      [14, { lng: 5.05, lat: 45.003 }, { lng: 5.06, lat: 45.0 }],
    ]
    for (const [z, from, to] of expected) {
      legs.length = 0
      const r = importedRoute()
      const seg = nearestSegment(r, target)!
      expect(seg.index).toBe(3)
      const { start, end } = spanBounds(r, seg.index, seg.index + 1, z)
      await insert(r, start, seg.point, end, PROFILE)
      expect(legs).toHaveLength(2)
      near(legs[0].from, from)
      near(legs[1].to, to)
    }
  })

  it('8. moving a point re-routes between its neighbours', async () => {
    const route = await drawn(A, B, C)
    const [pa, pb, pc] = manualPoints(route)
    const iB = route.points.indexOf(pb)
    const { start, end } = legBounds(route, iB - 1, iB + 1)
    expect([start!.id, end!.id]).toEqual([pa.id, pc.id])
    const result = await insert(route, start, { lng: 5.01, lat: 45.003 }, end, PROFILE)
    expect(legs).toHaveLength(2)
    expect(manualPoints(result)).toHaveLength(3)
  })

  it('9. a point set next to a control point does not replace it', async () => {
    const route = await drawn(A, B, C)
    const pb = manualPoints(route)[1]
    const keep = { id: pb.id, lng: pb.lng, lat: pb.lat }
    const p = { lng: B.lng + 0.01 * (C.lng - B.lng), lat: B.lat }
    const seg = nearestSegment(route, p)!
    const { start, end } = spanBounds(route, seg.index, seg.index + 1, 22)
    expect([start!.id, end!.id]).toContain(pb.id)
    const result = await insert(route, start, p, end, PROFILE)
    const b = result.points.find((q) => q.id === keep.id)!
    expect([b.lng, b.lat]).toEqual([keep.lng, keep.lat])
    expect(manualPoints(result)).toHaveLength(4)
  })

  it('10. the simplification stays local to the bounds', async () => {
    const r = importedRoute()
    const [, , , v3, v4] = r.points
    const before = levels(r)
    const { start, end } = spanBounds(r, 3, 4, 14)
    expect([start!.id, end!.id]).toEqual([v3.id, v4.id])
    const result = await insert(r, start, { lng: 5.055, lat: 45.05 }, end, PROFILE)
    const after = levels(result)
    const i3 = after.findIndex((p) => p.id === v3.id)
    const i4 = after.findIndex((p) => p.id === v4.id)
    expect(after.slice(0, i3 + 1)).toEqual(before.slice(0, 4))
    expect(after.slice(i4)).toEqual(before.slice(4))
    // a bound that is not manual stays unmarked
    expect(result.points[i3].manual).toBe(false)
    // the span between the bounds is simplified again and holds the new manual point
    const middle = result.points.slice(i3 + 1, i4)
    expect(middle.length).toBeGreaterThan(0)
    expect(middle.some((p) => p.manual)).toBe(true)
  })

  it('11. the nearest segment is not always next to the nearest vertex', () => {
    // A long straight leg, then a detour that comes back near its middle
    const route = createRoute([
      [5.0, 45.0, 0],
      [5.1, 45.0, 0],
      [5.1, 45.0005, 0],
      [5.05, 45.0006, 0],
      [5.0, 45.0005, 0],
    ])
    const seg = nearestSegment(route, { lng: 5.05, lat: 45.0001 })!
    expect(seg.index).toBe(0)
    expect(seg.point.lat).toBeCloseTo(45.0, 9)
  })

  it('10. remove and add leave the levels outside their bounds alone', async () => {
    // remove between two anchors
    const r = importedRoute()
    const [, v1, , , , v5] = r.points
    const before = levels(r)
    const removed = await remove(r, v1, v5, PROFILE)
    const after = levels(removed)
    const i1 = after.findIndex((p) => p.id === v1.id)
    const i5 = after.findIndex((p) => p.id === v5.id)
    expect(after.slice(0, i1 + 1)).toEqual(before.slice(0, 2))
    expect(after.slice(i5)).toEqual(before.slice(5))

    // a cut keeps the levels of what stays
    const c = importedRoute()
    const cutBefore = levels(c)
    const cut = await remove(c, undefined, c.points[2], PROFILE)
    expect(levels(cut).slice(1)).toEqual(cutBefore.slice(3))

    // add extends the route: the points before the old end keep their level
    const a = importedRoute()
    const addBefore = levels(a)
    const added = await add(a, { lng: 5.1, lat: 45.01 }, PROFILE)
    expect(levels(added).slice(0, addBefore.length - 1)).toEqual(addBefore.slice(0, -1))
  })
})

describe('B6 straight lines', () => {
  const P: Point = { lng: 5.005, lat: 45.0005 }

  /** A, then B and C each drawn in the given mode. */
  async function drawn(...modes: boolean[]): Promise<Route> {
    let route = await add(computeRoute([]), A, PROFILE)
    const targets = [B, C, D]
    for (const [i, direct] of modes.entries()) {
      route = await add(route, targets[i], PROFILE, direct)
    }
    routeMock.mockClear()
    return route
  }

  it('1. add flags the arrival point of a straight leg only', async () => {
    const straight = await drawn(true)
    expect(routeMock).not.toHaveBeenCalled()
    expect(straight.points.map((p) => p.direct)).toEqual([false, true])

    const routed = await drawn(false)
    expect(routed.points.every((p) => !p.direct)).toBe(true)

    // A hop under 5 m skips the router without being a requested straight line
    const hop = await add(await drawn(), { lng: 5.00001, lat: 45.0 }, PROFILE)
    expect(routeMock).not.toHaveBeenCalled()
    expect(hop.points.every((p) => !p.direct)).toBe(true)
  })

  it('2. a straight insert needs no request and leaves no duplicate', async () => {
    const route = await threePointRoute()
    const [pa, pb] = manualPoints(route)
    const result = await insert(route, pa, P, pb, PROFILE, true)
    expect(routeMock).not.toHaveBeenCalled()
    const inserted = result.points.find((p) => p.lng === P.lng && p.lat === P.lat)!
    expect(inserted.direct).toBe(true)
    expect(result.points.find((p) => p.id === pb.id)!.direct).toBe(true)
    expect(result.points.filter((p) => p.lng === P.lng && p.lat === P.lat)).toHaveLength(1)
    expect(result.points.filter((p) => p.lng === B.lng && p.lat === B.lat)).toHaveLength(1)
    // the leg after B stays routed
    expect(result.points.at(-1)!.direct).toBe(false)
  })

  it('3. the mode of the gesture wins: a routed insert in a straight leg is routed', async () => {
    const route = await drawn(true)
    const [pa, pb] = route.points
    const result = await insert(route, pa, P, pb, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(2)
    expect(result.points.some((p) => p.direct)).toBe(false)
  })

  it('4. adding at the end or at the head keeps the first point not direct', async () => {
    const end = await add(await drawn(true), C, PROFILE, true)
    expect(end.points.map((p) => p.direct)).toEqual([false, true, true])

    const route = await drawn(true)
    const head = await insert(route, undefined, P, route.points[0], PROFILE, true)
    expect(routeMock).not.toHaveBeenCalled()
    expect(head.points.map((p) => p.direct)).toEqual([false, true, true])
  })

  it('5. remove inherits straight legs, never loses a routed one', async () => {
    const straight = await drawn(true, true)
    const [pa, , pc] = manualPoints(straight)
    const merged = await remove(straight, pa, pc, PROFILE)
    expect(routeMock).not.toHaveBeenCalled()
    expect(merged.points.map((p) => p.direct)).toEqual([false, true])

    const mixed = await drawn(false, true)
    const [ma, , mc] = manualPoints(mixed)
    const rerouted = await remove(mixed, ma, mc, PROFILE)
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(rerouted.points.at(-1)!.direct).toBe(false)

    routeMock.mockClear()
    const routed = await drawn(false, false)
    const [ra, , rc] = manualPoints(routed)
    const forced = await remove(routed, ra, rc, PROFILE, true)
    expect(routeMock).not.toHaveBeenCalled()
    expect(forced.points.at(-1)!.direct).toBe(true)
  })

  it('6. cutting the start of a straight route resets the first point', async () => {
    const route = await drawn(true, true)
    const result = await remove(route, undefined, route.points[1], PROFILE)
    expect(result.points.map((p) => p.direct)).toEqual([false, true])
  })

  it('7. removing an imported anchor in straight mode leaves imported / straight / imported', async () => {
    const base = importedRoute()
    const [, w1, , , w4] = base.points
    const result = await remove(base, w1, w4, PROFILE, true)
    expect(routeMock).not.toHaveBeenCalled()
    expect(result.points.find((p) => p.id === w4.id)!.direct).toBe(true)
    const legs = legsGeojson(result)
    expect(legs.features.map((f) => f.properties.direct)).toEqual([false, true, false])
  })

  it('8. a loaded track is entirely not direct', () => {
    expect(importedRoute().points.every((p) => !p.direct)).toBe(true)
  })

  it('9. a local insertion leaves the points outside its bounds untouched', async () => {
    // A straight leg exists outside the bounds, so `direct` is not trivially false everywhere
    const loaded = importedRoute()
    const [, w1, , , w4] = loaded.points
    const base = await remove(loaded, w1, w4, PROFILE, true)
    expect(base.points.find((p) => p.id === w4.id)!.direct).toBe(true)
    const before = snapshot(base)
    const [v0, v1] = base.points
    const mid = { lng: (v0.lng + v1.lng) / 2 + 0.0005, lat: (v0.lat + v1.lat) / 2 + 0.0005 }
    const result = await insert(base, v0, mid, v1, PROFILE, true)
    const i3 = result.points.findIndex((p) => p.id === v0.id)
    const i4 = result.points.findIndex((p) => p.id === v1.id)
    expect(result.points.find((p) => p.id === w4.id)!.direct).toBe(true)
    for (let k = 0; k <= i3; k++) {
      expect(result.points[k].id).toBe(before[k].id)
      expect(result.points[k].direct).toBe(before[k].direct)
    }
    for (let k = i4 + 1; k < result.points.length; k++) {
      const old = before[before.length - (result.points.length - k)]
      expect(result.points[k].id).toBe(old.id)
      expect(result.points[k].direct).toBe(old.direct)
    }
  })

  it('10. legsGeojson groups consecutive edges of the same kind', async () => {
    const route = await drawn(false, true, false)
    const { features } = legsGeojson(route)
    expect(features.map((f) => f.properties.direct)).toEqual([false, true, false])
    expect(features[0].geometry.coordinates.at(-1)).toEqual(features[1].geometry.coordinates[0])
    expect(features[1].geometry.coordinates.at(-1)).toEqual(features[2].geometry.coordinates[0])
    expect(features[1].geometry.coordinates).toHaveLength(2)

    const allRouted = await drawn(false, false)
    const single = legsGeojson(allRouted)
    expect(single.features).toHaveLength(1)
    expect(single.features[0].geometry.coordinates).toEqual(geojson(allRouted).coordinates)

    expect(legsGeojson(computeRoute([])).features).toEqual([])
    expect(legsGeojson(await add(computeRoute([]), A, PROFILE)).features).toEqual([])
  })

  it('11. directStats sums the straight legs', async () => {
    expect(directStats(await drawn(false))).toEqual({ total: 0, longest: 0, count: 0 })
    const stats = directStats(await drawn(true, true))
    expect(stats.count).toBe(2)
    expect(stats.longest).toBeGreaterThan(785)
    expect(stats.longest).toBeLessThan(787)
    expect(stats.total).toBeGreaterThan(1570)
    expect(stats.total).toBeLessThan(1574)
  })

  it('12. isStraightSpan is false for an empty or inverted range', async () => {
    const route = await drawn(true, true)
    expect(isStraightSpan(route, 0, 2)).toBe(true)
    expect(isStraightSpan(route, 1, 1)).toBe(false)
    expect(isStraightSpan(route, 2, 1)).toBe(false)
    const mixed = await drawn(false, true)
    expect(isStraightSpan(mixed, 0, mixed.points.length - 1)).toBe(false)
  })
})

describe('B1 elevation', () => {
  /** One router answer: a flat two-point geometry carrying the climb the router measured. */
  const answer =
    (ascend: number | undefined) =>
    async ({ from, to }: RouteRequest) => ({
      route: {
        coordinates: [
          [from.lng, from.lat, groundEle(from.lng)],
          [to.lng, to.lat, groundEle(to.lng)],
        ],
      },
      ascend,
    })

  it('adds the climb of each routed leg once, and gives the first point an elevation', async () => {
    const route = await threePointRoute()
    expect(route.ascend).toBe(100)
    expect(route.points[0].ele).toBeDefined()
    const [, pb, pc] = manualPoints(route)
    expect(pb.legAscend).toBe(50)
    expect(pc.legAscend).toBe(50)
  })

  it('falls back on the positive steps of the geometry when the router gives no climb', async () => {
    routeMock.mockImplementation(answer(undefined))
    let route = await add(computeRoute([]), A, PROFILE)
    route = await add(route, B, PROFILE)
    // 100 m -> 200 m
    expect(route.ascend).toBe(100)
  })

  it('insert takes the climb of both new legs, and the inserted point adds no elevation of its own', async () => {
    const route = await threePointRoute()
    const [pa, pb, pc] = manualPoints(route)
    routeMock.mockReset()
    routeMock.mockImplementationOnce(answer(30)).mockImplementationOnce(answer(70))
    const next = await insert(route, pa, { lng: 5.005, lat: 45.0 }, pb, PROFILE)
    const inserted = next.points.find((p) => p.lng === 5.005 && p.manual)!
    expect(inserted.legAscend).toBe(30)
    // The inserted point takes the snapped router elevation
    expect(inserted.ele).toBe(groundEle(5.005))
    expect(next.points.find((p) => p.id === pb.id)!.legAscend).toBe(70)
    expect(next.points.find((p) => p.id === pc.id)!.legAscend).toBe(50)
    expect(next.ascend).toBe(150)
  })

  it('remove reconnects with the climb of the new leg', async () => {
    const route = await threePointRoute()
    const [pa, , pc] = manualPoints(route)
    routeMock.mockReset()
    routeMock.mockImplementation(answer(80))
    const next = await remove(route, pa, pc, PROFILE)
    expect(next.ascend).toBe(80)
  })

  it('removing the start does not count the leg that was cut', async () => {
    const route = await threePointRoute()
    const [, pb] = manualPoints(route)
    const next = await remove(route, undefined, pb, PROFILE)
    expect(next.ascend).toBe(50)
  })

  it('counts the net climb of a straight line after a routed leg, and 0 for a final one', async () => {
    const route = await threePointRoute()
    const [pa, pb] = manualPoints(route)
    routeMock.mockClear()
    // A straight point between A (100 m) and B (200 m): +100 m net, then B->C is still 50
    const inserted = await insert(route, pa, { lng: 5.005, lat: 45.0 }, pb, PROFILE, true)
    expect(inserted.ascend).toBeCloseTo(150, 6)
    expect(routeMock).not.toHaveBeenCalled()
    // A straight line at the end has no elevation to reach: nothing climbed
    const ended = await add(await threePointRoute(), D, PROFILE, true)
    expect(ended.ascend).toBe(100)
    expect(routeMock).not.toHaveBeenCalled()
  })

  it('a route of straight lines only has 0 m and no profile', async () => {
    let route = await add(computeRoute([]), A, PROFILE)
    route = await add(route, B, PROFILE, true)
    route = await add(route, C, PROFILE, true)
    expect(route.ascend).toBe(0)
    expect(plannerRouteToMappable(route)).toBeNull()
  })

  describe('relief of straight edges (B1b)', () => {
    /** A -> B straight, then B -> C straight: no elevation anywhere. */
    async function straightRoute(): Promise<Route> {
      let route = await add(computeRoute([]), A, PROFILE)
      route = await add(route, B, PROFILE, true)
      return add(route, C, PROFILE, true)
    }

    /** The profile of the edge `from -> to`: 3 samples, 100 m, 130 m, 110 m, climbing 30 m. */
    function profileOf(from: Point, to: Point, ascend = 30): DirectProfile {
      return {
        key: edgeKey(from, to),
        lngLat: [
          [from.lng, from.lat],
          [(from.lng + to.lng) / 2, (from.lat + to.lat) / 2],
          [to.lng, to.lat],
        ],
        ele: [100, 130, 110],
        ascend,
      }
    }

    const lookupOf = (profiles: DirectProfile[]) => (key: string) =>
      profiles.find((p) => p.key === key)

    it('takes the climb of a straight edge from its profile when the key matches', async () => {
      const route = await straightRoute()
      const enriched = withDirectProfiles(route, lookupOf([profileOf(A, B)]))
      // A -> B measured (30); B -> C has no profile: net climb between its filled elevations (110 -> 110)
      expect(enriched.ascend).toBeCloseTo(30, 6)
      expect(route.ascend).toBe(0)
    })

    it('ignores a stale profile (a point moved) and falls back on the net climb', async () => {
      const route = await straightRoute()
      const enriched = withDirectProfiles(route, lookupOf([profileOf(A, B)]))
      const moved = enriched.points.map((p) => ({ ...p }))
      moved[1].lng += 0.001
      // net climb between the filled ends (100 m -> 110 m), not the 30 m of the profile
      expect(routeAscend(moved)).toBeCloseTo(10, 6)
    })

    it('is idempotent and changes neither the points, nor their ids and indices', async () => {
      const route = await straightRoute()
      const lookup = lookupOf([profileOf(A, B), profileOf(B, C, 5)])
      const once = withDirectProfiles(route, lookup)
      expect(once).not.toBe(route)
      expect(once.points.map((p) => [p.id, p.idx, p.lng, p.lat])).toEqual(
        route.points.map((p) => [p.id, p.idx, p.lng, p.lat])
      )
      expect(withDirectProfiles(once, lookup)).toBe(once)
      expect(withDirectProfiles(route, () => undefined)).toBe(route)
      expect(once.ascend).toBeCloseTo(35, 6)
    })

    it('copies the points it changes: the history copies and the old route stay intact', async () => {
      const route = await straightRoute()
      const history = route.points.map((p) => ({ ...p }))
      const enriched = withDirectProfiles(route, lookupOf([profileOf(A, B)]))
      expect(route.points.every((p) => p.directProfile === undefined && p.ele === undefined)).toBe(
        true
      )
      expect(history.every((p) => p.directProfile === undefined)).toBe(true)
      expect(enriched.points[1].directProfile).toBeDefined()
      expect(enriched.points[0].ele).toBe(100)
      expect(enriched.points[1].ele).toBe(110)
    })

    it('lists the straight edges of 10 m to 100 km without a valid profile', async () => {
      const route = await straightRoute()
      const missing = straightEdgesMissingProfile(route)
      expect(missing.map((e) => e.key)).toEqual([edgeKey(A, B), edgeKey(B, C)])
      expect(missing[0].meters).toBeGreaterThan(700)
      const enriched = withDirectProfiles(route, lookupOf([profileOf(A, B)]))
      expect(straightEdgesMissingProfile(enriched).map((e) => e.key)).toEqual([edgeKey(B, C)])
      // under 10 m and over 100 km: nothing to read
      const hop = await add(route, { lng: C.lng + 0.00005, lat: C.lat }, PROFILE, true)
      expect(straightEdgesMissingProfile(hop)).toHaveLength(2)
      const far = await add(route, { lng: 7, lat: 45 }, PROFILE, true)
      expect(straightEdgesMissingProfile(far)).toHaveLength(2)
    })

    it('carries the route points it is given, none by default (C3e)', async () => {
      const route = withDirectProfiles(await straightRoute(), lookupOf([profileOf(A, B)]))
      expect(plannerRouteToMappable(route)!.waypoints).toEqual([])
      const waypoints = [
        {
          geometry: { type: 'Point', coordinates: [5.005, 45] },
          name: 'Café',
          type: 'CAFE',
          origin: 'AUTHOR',
          distance: 400,
        },
      ] as never
      expect(plannerRouteToMappable(route, waypoints)!.waypoints).toBe(waypoints)
    })

    it('unfolds the samples in the profile, with their positions, route indices and dashes', async () => {
      const route = withDirectProfiles(await straightRoute(), lookupOf([profileOf(A, B)]))
      const mappable = plannerRouteToMappable(route)!
      const coords = mappable.tracks[0].line.coordinates
      // A, the sample, B, C
      expect(coords).toHaveLength(4)
      expect(coords.map((c) => c[2])).toEqual([100, 130, 110, 110])
      expect(mappable.positions[1]).toEqual({ lng: 5.005, lat: 45 })
      expect(mappable.routeIndex).toEqual([0, 1, 1, 2])
      expect(mappable.profileIndexOfRoute).toEqual([0, 2, 3])
      expect(mappable.dashed).toEqual([true, true, true, false])
      for (let i = 1; i < coords.length; i++) expect(coords[i][3]).toBeGreaterThan(coords[i - 1][3])
      expect(coords[2][3]).toBeCloseTo(mappable.distance - (coords[3][3] - coords[2][3]), 6)
    })

    it('a route of straight lines only has a profile once one was read', async () => {
      const route = await straightRoute()
      expect(plannerRouteToMappable(route)).toBeNull()
      expect(
        plannerRouteToMappable(withDirectProfiles(route, lookupOf([profileOf(A, B)])))
      ).not.toBeNull()
    })
  })

  it('scales the climb of a loaded track to the reference D+, whatever the simplification drops', () => {
    // Collinear: Douglas-Peucker keeps the two ends, the peak in the middle is dropped
    const coords = [
      [5.0, 45.0, 100],
      [5.005, 45.0, 150],
      [5.01, 45.0, 100],
      [5.015, 45.0, 100],
    ]
    const scaled = createRoute(coords, 1234)
    expect(scaled.points).toHaveLength(2)
    expect(scaled.ascend).toBeCloseTo(1234, 6)
    // No reference: the raw cumulative climb of the whole input, not of the kept points
    expect(createRoute(coords).ascend).toBeCloseTo(50, 6)
  })

  it('removing an angle of a loaded track keeps the portions around it and adds the new leg', async () => {
    const route = createRoute([
      [5.0, 45.0, 100],
      [5.01, 45.0, 150],
      [5.01, 45.01, 200],
      [5.02, 45.01, 230],
      [5.02, 45.02, 260],
    ])
    expect(route.points).toHaveLength(5)
    expect(route.ascend).toBeCloseTo(160, 6)
    routeMock.mockReset()
    routeMock.mockImplementation(answer(20))
    const next = await remove(route, route.points[1], route.points[3], PROFILE)
    // 100 -> 150 kept, the new leg, then 230 -> 260 kept
    expect(next.ascend).toBeCloseTo(50 + 20 + 30, 6)
  })

  it('a computation replayed on the same points keeps the ascent', async () => {
    const route = await threePointRoute()
    expect(computeRoute(route.points.map((p) => ({ ...p }))).ascend).toBe(route.ascend)
    expect(routeAscend(route.points)).toBe(route.ascend)
  })

  it('exposes the profile with one entry per point, increasing distances and filled elevations', async () => {
    const route = await threePointRoute()
    const mappable = plannerRouteToMappable(route)!
    const coords = mappable.tracks[0].line.coordinates
    expect(coords).toHaveLength(route.points.length)
    expect(mappable.distance).toBe(route.dist)
    for (let i = 1; i < coords.length; i++) expect(coords[i][3]).toBeGreaterThan(coords[i - 1][3])
    expect(coords.at(-1)![3]).toBeCloseTo(route.dist, 6)
  })

  it('fills a missing elevation linearly along the distance, the nearest known at the ends', () => {
    const at = (lng: number, ele?: number) =>
      ({
        id: `x${lng}`,
        idx: 0,
        lng,
        lat: 45,
        ele,
        manual: false,
        imported: false,
        direct: false,
        zoom: 0,
      }) satisfies RoutePoint
    const filled = fillElevations([at(5.0), at(5.01, 100), at(5.02), at(5.03, 200), at(5.04)])
    expect(filled[0]).toBe(100)
    expect(filled[1]).toBe(100)
    expect(filled[2]).toBeCloseTo(150, 3)
    expect(filled[3]).toBe(200)
    expect(filled[4]).toBe(200)
    expect(fillElevations([at(5.0), at(5.01)])).toEqual([undefined, undefined])
  })
})

describe('C4a source span', () => {
  beforeEach(() => {
    routeMock.mockReset()
    routeMock.mockImplementation(async (leg: RouteRequest) => arcAnswer(leg))
  })

  /** An import with a P dragged out between its anchors 1 and 3, and the bounds of P's leg. */
  async function detour(coords: number[][] = IMPORT) {
    const source = sourceOf(coords)
    let route = createRoute(coords)
    const [, a1, , a2] = route.points
    route = await insert(route, a1, { lng: 5.03, lat: 45.03 }, a2, PROFILE)
    const p = route.points.find((q) => q.manual && q.lng === 5.03)!
    const at = route.points.indexOf(p)
    const { start, end } = legBounds(route, at - 1, at + 1)
    routeMock.mockClear()
    return { source, route, p, start: start!, end: end! }
  }

  it('gives the file back between two anchors of the same import, without any request', async () => {
    const { source, route, start, end } = await detour()
    expect([start.sourceIdx, end.sourceIdx]).toEqual([10, 30])
    const outside = route.points.filter((q) => q.idx <= start.idx || q.idx >= end.idx)
    const ids = outside.map((q) => [q.id, q.lng, q.lat])

    const next = restoreSourceSpan(route, start, end, source)
    expect(routeMock).not.toHaveBeenCalled()
    const a = next.points.findIndex((q) => q.id === start.id)
    const b = next.points.findIndex((q) => q.id === end.id)
    const between = next.points.slice(a + 1, b)
    expect(between.length).toBeGreaterThan(0)
    for (const q of between) {
      expect(q.imported).toBe(true)
      expect(q.manual).toBe(false)
      expect(q.sourceIdx).toBeGreaterThan(10)
      expect(q.sourceIdx).toBeLessThan(30)
      near(q, { lng: IMPORT[q.sourceIdx!][0], lat: IMPORT[q.sourceIdx!][1] })
    }
    expect(next.points.some((q) => q.manual && q.lng === 5.03)).toBe(false)
    // The rest of the route is the same points
    expect(
      next.points.filter((q) => q.idx <= a || q.idx >= b).map((q) => [q.id, q.lng, q.lat])
    ).toEqual(ids)
    // The edge into the end is the file's again
    expect(end.direct).toBe(false)
    expect(end.legAscend).toBeUndefined()
  })

  it('credits the climb of the file that was given back', async () => {
    const climbing = IMPORT.map((c, i) => [c[0], c[1], 100 + (i % 5) * 3])
    const { source, route, start, end } = await detour(climbing)
    const next = restoreSourceSpan(route, start, end, source)
    expect(next.ascend).toBeCloseTo(createRoute(climbing).ascend, 6)
    expect(next.ascend).toBeGreaterThan(0)
  })
})
