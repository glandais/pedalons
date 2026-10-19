// The unpaved surface of the route being drawn (WEB-100 C1a): carried by the arrival point of each
// edge, filled from the router's answer, kept through simplification, saved and restored.
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { RouterProfile, PlannerPieceMode, type UnpavedSpan } from '@/api/dto'

// Router simulated: a straight line of `STEPS` edges between the two points (every inner vertex
// is collinear, so the simplification drops them all), answering `spans` when `answer.spans` is set.
const STEPS = 10
const routeMock = vi.hoisted(() => vi.fn())
const lineElevationMock = vi.hoisted(() => vi.fn())
vi.mock('@/api/endpoints/router/router', () => ({
  route: routeMock,
  lineElevation: lineElevationMock,
}))

import {
  add,
  appendImport,
  computeRoute,
  createPoint,
  createRoute,
  edgeSurface,
  insert,
  legsGeojson,
  plannerRouteToMappable,
  remove,
  restoreSourceSpan,
  withDirectProfiles,
  routeFromSources,
  sourceOf,
  surfaceStats,
  type Point,
  type Route,
  type RouterSettings,
} from './planner'
import { restorePlannerState, serializePlannerState } from './plannerState'

const PROFILE: RouterSettings = { profile: RouterProfile.GRAVEL }

const answer = vi.hoisted(() => ({ spans: undefined as UnpavedSpan[] | undefined }))

interface Request {
  from: Point
  to: Point
}

beforeEach(() => {
  routeMock.mockReset()
  answer.spans = undefined
  routeMock.mockImplementation(async ({ from, to }: Request) => {
    const coordinates: number[][] = []
    for (let i = 0; i <= STEPS; i++) {
      const t = i / STEPS
      coordinates.push([
        from.lng + t * (to.lng - from.lng),
        from.lat + t * (to.lat - from.lat),
        100 + i,
      ])
    }
    return {
      route: { coordinates },
      ascend: STEPS,
      ...(answer.spans !== undefined && { unpaved: answer.spans }),
    }
  })
})

// ~1.5 km apart at latitude 45, on a line
const A: Point = { lng: 5.0, lat: 45.0 }
const B: Point = { lng: 5.02, lat: 45.0 }
const C: Point = { lng: 5.04, lat: 45.0 }

async function drawn(...legs: [Point, boolean?][]): Promise<Route> {
  let route = computeRoute([])
  for (const [p, direct] of legs) route = await add(route, p, PROFILE, direct ?? false)
  return route
}

const surfaces = (route: Route) =>
  route.points.slice(1).map((_, i) => edgeSurface(route.points, i + 1))

describe("the router's unpaved runs", () => {
  it('stay unknown when the router said nothing (an older backend)', async () => {
    const route = await drawn([A], [B])
    expect(route.points.every((p) => p.unpaved === undefined)).toBe(true)
    expect(surfaces(route)).toEqual(['unknown'])
  })

  it('are kept through the simplification as the share of the merged edge', async () => {
    answer.spans = [{ from: 2, to: 5 }] // 3 of 10 equal edges
    const route = await drawn([A], [B])
    // The collinear inner vertices are dropped: one edge, 30 % unpaved, still « unpaved » (errs towards over-reporting)
    expect(route.points).toHaveLength(2)
    expect(route.points[1].unpaved).toBeCloseTo(0.3, 2)
    expect(surfaces(route)).toEqual(['unpaved'])
  })

  it('make a merged edge unpaved whatever the share', async () => {
    answer.spans = [{ from: 3, to: 8 }]
    const route = await drawn([A], [B])
    expect(route.points[1].unpaved).toBeCloseTo(0.5, 2)
    expect(surfaces(route)).toEqual(['unpaved'])
    expect(surfaceStats(route).unpaved).toBeGreaterThan(0)
  })

  it('say « all paved » with an empty list', async () => {
    answer.spans = []
    const route = await drawn([A], [B])
    expect(route.points[1].unpaved).toBe(0)
    expect(surfaces(route)).toEqual(['paved'])
  })

  it('are not part of a straight line, which is off the network', async () => {
    answer.spans = [{ from: 0, to: STEPS }]
    const route = await drawn([A], [B], [C, true])
    expect(surfaces(route)).toEqual(['unpaved', 'offNetwork'])
    expect(route.points[2].unpaved).toBeUndefined()
  })

  it('give the legs of the map one feature per surface, and the profile its segments', async () => {
    answer.spans = [{ from: 0, to: STEPS }]
    let route = await drawn([A], [B])
    answer.spans = []
    route = await add(route, C, PROFILE)
    expect(legsGeojson(route).features.map((f) => f.properties)).toEqual([
      { direct: false, surface: 'unpaved' },
      { direct: false, surface: 'paved' },
    ])
    const mappable = plannerRouteToMappable(route)!
    expect(mappable.surface).toEqual(['unpaved', 'paved', 'paved'])
  })

  it('survive the removal of a point: the new leg is read again', async () => {
    answer.spans = [{ from: 0, to: STEPS }]
    const route = await drawn([A], [B], [C])
    const [start, middle, end] = route.points.filter((p) => p.manual)
    expect(middle).toBeDefined()
    answer.spans = []
    const next = await remove(route, start, end, PROFILE)
    expect(surfaces(next)).toEqual(['paved'])
  })

  it('follow an inserted point on both sides', async () => {
    answer.spans = [{ from: 0, to: STEPS }]
    const route = await drawn([A], [C])
    const [start, end] = route.points.filter((p) => p.manual)
    answer.spans = []
    const next = await insert(route, start, B, end, PROFILE)
    expect(surfaces(next)).toEqual(['paved', 'paved'])
  })

  it('never leave a stale share on the first point', async () => {
    answer.spans = [{ from: 0, to: STEPS }]
    const route = await drawn([A], [B])
    const [, end] = route.points
    const cut = await remove(route, undefined, end, PROFILE)
    expect(cut.points[0].unpaved).toBeUndefined()
  })
})

describe('a loaded track', () => {
  const coords = [
    [5.0, 45.0, 100],
    [5.001, 45.0, 101],
    [5.002, 45.0, 102],
  ]

  it('is unknown, as a file or an existing route', () => {
    // (collinear points: one edge once simplified)
    expect(surfaces(createRoute(coords))).toEqual(['unknown'])
    const imported = routeFromSources([sourceOf(coords)], 0)
    expect(surfaces(imported)).toEqual(['unknown'])
  })

  it('joins a routed leg to an import with the unpaved share of that leg', async () => {
    answer.spans = [{ from: 0, to: STEPS }]
    const route = await drawn([{ lng: 4.99, lat: 45.0 }])
    const joined = await appendImport(
      await add(route, { lng: 4.995, lat: 45.0 }, PROFILE),
      routeFromSources([sourceOf(coords)], 0),
      PROFILE,
      false
    )
    const classes = surfaces(joined)
    expect(classes).toContain('unpaved')
    expect(classes.at(-1)).toBe('unknown')
  })
})

describe('the saved state', () => {
  it('saves the runs of a routed piece and reads them back', async () => {
    answer.spans = [{ from: 0, to: STEPS }]
    let route = await drawn([A], [B])
    answer.spans = []
    route = await add(route, C, PROFILE)
    const state = serializePlannerState(route, [], RouterProfile.GRAVEL)!
    expect(state.pieces.map((p) => p.unpaved)).toEqual([[{ from: 0, to: 1 }], []])

    const restored = restorePlannerState(state).route
    expect(surfaces(restored)).toEqual(['unpaved', 'paved'])
    expect(serializePlannerState(restored, [], RouterProfile.GRAVEL)).toEqual(state)
  })

  it('leaves the surface out when the router gave none, and for a straight piece', async () => {
    const route = await drawn([A], [B], [C, true])
    const state = serializePlannerState(route, [], RouterProfile.GRAVEL)!
    expect(state.pieces.map((p) => p.mode)).toEqual([
      PlannerPieceMode.ROUTED,
      PlannerPieceMode.DIRECT,
    ])
    expect(state.pieces.every((p) => p.unpaved === undefined)).toBe(true)
    expect(surfaces(restorePlannerState(state).route)).toEqual(['unknown', 'offNetwork'])
  })

  it('saves adjacent edges as one run, ascending and apart, like the server checks', () => {
    const share = [0, 1, 1, 0, 1]
    const points = share.map((_, i) => createPoint(5 + i * 0.001, 45 + (i % 2) * 0.002))
    points.push(createPoint(5.005, 45))
    // Edge e ends at point e + 1; the last point closes the routed leg
    share.forEach((u, e) => (points[e + 1].unpaved = u))
    points[5].legAscend = 0
    const route = computeRoute(points)
    expect(route.points).toHaveLength(6)
    const state = serializePlannerState(route, [], RouterProfile.GRAVEL)!
    expect(state.pieces).toHaveLength(1)
    expect(state.pieces[0].unpaved).toEqual([
      { from: 1, to: 3 },
      { from: 4, to: 5 },
    ])
  })
})

describe('the surface through the other route operations', () => {
  it('keeps the classes when a straight edge gets its elevation profile (B1b)', async () => {
    answer.spans = [{ from: 0, to: STEPS }]
    const route = await drawn([A], [B], [C, true])
    // A real profile: the edge into C is straight, whatever the lookup answers for its key
    const withProfile = withDirectProfiles(route, (k) => ({
      key: k,
      lngLat: [
        [B.lng, B.lat],
        [C.lng, C.lat],
      ],
      ele: [100, 110],
      ascend: 10,
    }))
    expect(surfaces(withProfile)).toEqual(['unpaved', 'offNetwork'])
  })

  it('resets an edge to unknown when the file is given back between two anchors (B12)', async () => {
    const coords = Array.from({ length: 41 }, (_, i) => [5 + i * 0.001, 45 + (i % 2) * 0.0005, 100])
    const source = sourceOf(coords)
    let route = createRoute(coords)
    const [, a1, , a2] = route.points
    answer.spans = [{ from: 0, to: STEPS }]
    route = await insert(route, a1, { lng: 5.03, lat: 45.03 }, a2, PROFILE)
    expect(surfaces(route)).toContain('unpaved')
    const next = restoreSourceSpan(route, a1, a2, source)
    const a = next.points.findIndex((q) => q.id === a1.id)
    const b = next.points.findIndex((q) => q.id === a2.id)
    for (let i = a + 1; i <= b; i++) expect(edgeSurface(next.points, i)).toBe('unknown')
  })
})
