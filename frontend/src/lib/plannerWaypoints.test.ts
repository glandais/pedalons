import { describe, expect, it } from 'vitest'
import { WaypointOrigin, WaypointType, type WaypointDto } from '@/api/dto'
import { computeRoute, createPoint, cumulativeDistances, type Route } from '@/lib/planner'
import {
  locateOnRoute,
  MAX_WAYPOINTS,
  mergeImported,
  placeWaypoints,
  projectOnRoute,
  toWaypointDto,
  toWaypointRequests,
  waypointFromDto,
  waypointFromImport,
  type PlannerWaypoint,
} from './plannerWaypoints'

/** A line along the parallel 45 N, every 0.001 degree of longitude (about 79 m). */
function eastward(from: number, to: number): number[][] {
  const out: number[][] = []
  for (let lng = from; lng <= to + 1e-9; lng += 0.001) out.push([+lng.toFixed(6), 45, 100])
  return out
}

function routeOf(coords: number[][]): Route {
  // Every vertex a control point: nothing is simplified away, the tests read the line as drawn
  const route = computeRoute(
    coords.map((c) => {
      const p = createPoint(c[0], c[1], c[2])
      p.manual = true
      return p
    })
  )
  expect(route.points).toHaveLength(coords.length)
  return route
}

const straight = () => routeOf(eastward(5, 5.01))
/** Out to 5.01 and back to 5: the route passes twice by every point of the line. */
const outAndBack = () => routeOf([...eastward(5, 5.01), ...eastward(5, 5.009).reverse()])

const ON = { lng: 5.005 }
// 1 degree of latitude = 111 195 m on the sphere the server uses
const north = (metres: number) => 45 + metres / 111_194.9

function waypoint(over: Partial<PlannerWaypoint> = {}): PlannerWaypoint {
  return {
    key: 'w-x',
    origin: WaypointOrigin.AUTHOR,
    type: WaypointType.CAFE,
    name: 'Café',
    description: '',
    lng: 5.005,
    lat: 45,
    ...over,
  }
}

describe('locateOnRoute (twin of WaypointAnchoring.locate)', () => {
  it('counts a point on the route within 50 m, not beyond', () => {
    const route = straight()
    const cum = cumulativeDistances(route.points)
    const near = locateOnRoute(route, cum, { lng: ON.lng, lat: north(49) })
    const far = locateOnRoute(route, cum, { lng: ON.lng, lat: north(51) })
    expect(near).not.toBeNull()
    expect(near!).toBeCloseTo(cum[cum.length - 1] / 2, -1)
    expect(far).toBeNull()
  })

  it('has no place on a route of fewer than two points', () => {
    const route = straight()
    route.points.length = 1
    expect(locateOnRoute(route, [0], { lng: 5, lat: 45 })).toBeNull()
  })

  it('takes the first passage without a hint, and the nearest one to a hint', () => {
    const route = outAndBack()
    const cum = cumulativeDistances(route.points)
    const p = { lng: 5.005, lat: 45 }
    const first = locateOnRoute(route, cum, p)!
    const second = locateOnRoute(route, cum, p, { distance: 1500 })!
    expect(first).toBeLessThan(cum[cum.length - 1] / 2)
    expect(second).toBeGreaterThan(cum[cum.length - 1] / 2)
    expect(locateOnRoute(route, cum, p, { distance: first + 10 })).toBe(first)
  })

  it('rescales the hint onto the current length when the previous one is known', () => {
    const route = outAndBack()
    const cum = cumulativeDistances(route.points)
    const total = cum[cum.length - 1]
    const p = { lng: 5.005, lat: 45 }
    const second = locateOnRoute(route, cum, p, { distance: 1500 })!
    // 0.75 of a route that was twice shorter: 0.75 of this one, the second passage
    expect(locateOnRoute(route, cum, p, { distance: 0.75 * (total / 2), total: total / 2 })).toBe(
      second
    )
    // the same figure read on this very length points at the first passage
    expect(locateOnRoute(route, cum, p, { distance: 0.25 * total, total })).toBeLessThan(total / 2)
  })

  it('groups the two sides of a vertex into one passage', () => {
    const route = straight()
    const cum = cumulativeDistances(route.points)
    // Right on a vertex: both edges are candidates, a single passage
    const at = locateOnRoute(route, cum, { lng: 5.005, lat: 45 }, { distance: 9999 })!
    expect(at).toBeCloseTo(cum[5], 0)
  })

  it('copes with an edge of no length', () => {
    const route = routeOf([
      [5, 45, 100],
      [5, 45, 100],
      [5.002, 45, 100],
    ])
    const cum = cumulativeDistances(route.points)
    expect(locateOnRoute(route, cum, { lng: 5, lat: 45 })).toBe(0)
  })
})

describe('projectOnRoute', () => {
  it('gives the projection and the distance along the route', () => {
    const route = straight()
    const cum = cumulativeDistances(route.points)
    const at = projectOnRoute(route, cum, { lng: 5.0035, lat: north(30) })!
    expect(at.lat).toBeCloseTo(45, 6)
    expect(at.lng).toBeCloseTo(5.0035, 5)
    expect(at.distance).toBeGreaterThan(cum[3])
    expect(at.distance).toBeLessThan(cum[4])
    expect(at.distance).toBeCloseTo(cum[3] + (cum[4] - cum[3]) / 2, -1)
  })

  it('is null on a route of fewer than two points', () => {
    const route = straight()
    route.points.length = 1
    expect(projectOnRoute(route, [0], { lng: 5, lat: 45 })).toBeNull()
  })
})

describe('placeWaypoints', () => {
  it('places each point on the route, and keeps the far ones off it', () => {
    const route = straight()
    const placed = placeWaypoints(route, [
      waypoint({ key: 'a' }),
      waypoint({ key: 'b', lat: north(80) }),
    ])
    expect(placed.map((w) => w.key)).toEqual(['a', 'b'])
    expect(placed[0].distance).not.toBeNull()
    expect(placed[1].distance).toBeNull()
  })

  it('follows a route that changed: same position, new distance', () => {
    const route = straight()
    const w = waypoint()
    const before = placeWaypoints(route, [w])[0].distance!
    const longer = routeOf([[4.99, 45, 100], ...eastward(5, 5.01)])
    const after = placeWaypoints(longer, [w])[0]
    expect(after.lng).toBe(w.lng)
    expect(after.distance!).toBeGreaterThan(before)
  })
})

describe('mergeImported', () => {
  const author = waypoint({ key: 'a', name: 'Mien' })
  const imported = waypoint({ key: 'i', origin: WaypointOrigin.IMPORTED, id: '1' })
  const fresh = waypoint({ key: 'n', origin: WaypointOrigin.IMPORTED })

  it('replace drops the imported points and keeps the author’s', () => {
    const merged = mergeImported([author, imported], [fresh], 'replace')
    expect(merged.waypoints.map((w) => w.key)).toEqual(['a', 'n'])
    expect(merged.dropped).toBe(0)
  })

  it('append keeps everything', () => {
    const merged = mergeImported([author, imported], [fresh], 'append')
    expect(merged.waypoints.map((w) => w.key)).toEqual(['a', 'i', 'n'])
  })

  it('stops at the 500 a route carries and counts what is left out', () => {
    const many = Array.from({ length: MAX_WAYPOINTS - 1 }, (_, i) => waypoint({ key: `k${i}` }))
    const merged = mergeImported(
      many,
      [fresh, { ...fresh, key: 'n2' }, { ...fresh, key: 'n3' }],
      'append'
    )
    expect(merged.waypoints).toHaveLength(MAX_WAYPOINTS)
    expect(merged.dropped).toBe(2)
  })

  it('returns the same list when nothing changes, so that it is not taken for touched', () => {
    const list = [author]
    expect(mergeImported(list, [], 'replace').waypoints).toBe(list)
    expect(mergeImported(list, [], 'append').waypoints).toBe(list)
  })
})

describe('conversions', () => {
  const dto: WaypointDto = {
    id: '0abc',
    geometry: { type: 'Point', coordinates: [5.005, 45] },
    name: 'Café',
    type: WaypointType.CAFE,
    origin: WaypointOrigin.IMPORTED,
    distance: 400,
  }

  it('waypointFromDto keeps the id, the origin and the hint with the stored length', () => {
    const w = waypointFromDto(dto, 790)
    expect(w).toMatchObject({
      id: '0abc',
      origin: 'IMPORTED',
      type: 'CAFE',
      name: 'Café',
      description: '',
      lng: 5.005,
      lat: 45,
      hint: { distance: 400, total: 790 },
    })
    expect(w.key).toMatch(/^w-/)
    expect(waypointFromDto({ ...dto, distance: undefined }).hint).toBeUndefined()
    expect(waypointFromDto({ ...dto, type: 'FUTURE' as never }).type).toBe('INFO')
  })

  it('waypointFromImport has no id and no hint', () => {
    const w = waypointFromImport({ ...dto, id: undefined, origin: WaypointOrigin.AUTHOR })
    expect(w.id).toBeUndefined()
    expect(w.origin).toBe('IMPORTED')
    expect(w.hint).toBeUndefined()
  })

  it('toWaypointRequests: an existing point sends no origin, a new one its own', () => {
    const [existing, created] = toWaypointRequests([
      {
        ...waypoint({ id: '0abc', origin: WaypointOrigin.IMPORTED, name: '  Café  ' }),
        distance: 123,
      },
      { ...waypoint({ origin: WaypointOrigin.IMPORTED, description: '  ' }), distance: null },
    ])
    expect(existing).toEqual({
      id: '0abc',
      position: { lng: 5.005, lat: 45 },
      type: 'CAFE',
      name: 'Café',
      description: undefined,
      distance: 123,
      origin: undefined,
    })
    expect(created.id).toBeUndefined()
    expect(created.origin).toBe('IMPORTED')
    expect(created.distance).toBeUndefined()
  })

  it('toWaypointRequests cuts a description past the bound', () => {
    const [request] = toWaypointRequests([
      { ...waypoint({ description: 'x'.repeat(600) }), distance: 1 },
    ])
    expect(request.description).toHaveLength(500)
  })

  it('toWaypointDto is what the read-only components take', () => {
    expect(toWaypointDto({ ...waypoint({ id: '1', description: 'd' }), distance: null })).toEqual({
      geometry: { type: 'Point', coordinates: [5.005, 45] },
      name: 'Café',
      id: '1',
      type: 'CAFE',
      description: 'd',
      distance: undefined,
      origin: 'AUTHOR',
    })
  })
})
