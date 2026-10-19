import { beforeEach, describe, expect, it, vi } from 'vitest'
import { RouterProfile, PlannerJunctionKind, PlannerPieceMode } from '@/api/dto'

// Router simulated: a bowed line of 8 intervals between the two points, 100 m of ground.
const routeMock = vi.hoisted(() => vi.fn())
const lineElevationMock = vi.hoisted(() => vi.fn())
vi.mock('@/api/endpoints/router/router', () => ({
  route: routeMock,
  lineElevation: lineElevationMock,
}))

import {
  add,
  computeRoute,
  createPoint,
  createRoute,
  edgeMode,
  insert,
  remove,
  sourceOf,
  type Point,
  type Route,
  type RouterSettings,
  type RoutePoint,
} from './planner'
import {
  MAX_PLANNER_PIECES,
  PlannerStateFormatError,
  restorePlannerState,
  serializePlannerState,
} from './plannerState'
import { decode1, decode2 } from './polyline'

const PROFILE: RouterSettings = { profile: RouterProfile.GRAVEL }

interface Request {
  from: Point
  to: Point
}

beforeEach(() => {
  routeMock.mockReset()
  routeMock.mockImplementation(async ({ from, to }: Request) => {
    const coordinates: number[][] = []
    for (let i = 0; i <= 8; i++) {
      const t = i / 8
      coordinates.push([
        i === 0 ? from.lng : i === 8 ? to.lng : from.lng + t * (to.lng - from.lng),
        i === 0
          ? from.lat
          : i === 8
            ? to.lat
            : from.lat + t * (to.lat - from.lat) + 0.002 * Math.sin(Math.PI * t),
        120 + i,
      ])
    }
    return { route: { coordinates }, ascend: 8 }
  })
})

const A: Point = { lng: 5.0, lat: 45.0 }
const B: Point = { lng: 5.02, lat: 45.0 }
const C: Point = { lng: 5.04, lat: 45.01 }
const D: Point = { lng: 5.06, lat: 45.0 }

const VERTICES: number[][] = [
  [5.0, 45.0],
  [5.02, 45.02],
  [5.04, 45.0],
  [5.05, 45.003],
  [5.06, 45.0],
  [5.08, 45.0],
]

/** A loaded track: straight legs between the corners, 10 intervals each, integer elevations. */
function track(): number[][] {
  const out: number[][] = []
  let i = 0
  for (let k = 0; k < VERTICES.length - 1; k++) {
    for (let j = 0; j < 10; j++, i++) {
      const t = j / 10
      out.push([
        VERTICES[k][0] + t * (VERTICES[k + 1][0] - VERTICES[k][0]),
        VERTICES[k][1] + t * (VERTICES[k + 1][1] - VERTICES[k][1]),
        100 + (i % 7) * 2,
      ])
    }
  }
  out.push([...VERTICES[VERTICES.length - 1], 100 + (i % 7) * 2])
  return out
}
const TRACK = track() // 51 points; the corners are at 0, 10, 20, 30, 40, 50

async function drawn(...legs: [Point, boolean?][]): Promise<Route> {
  let route = computeRoute([])
  for (const [p, direct] of legs) route = await add(route, p, PROFILE, direct ?? false)
  routeMock.mockClear()
  return route
}

/** The plan's example: an import, then a point P dragged out between two of its anchors. */
async function importWithDetour() {
  const source = sourceOf(TRACK, 80)
  let route = createRoute(TRACK, 80)
  const [, , a1, , a2] = route.points
  expect([a1.sourceIdx, a2.sourceIdx]).toEqual([20, 40])
  route = await insert(route, a1, { lng: 5.045, lat: 45.015 }, a2, PROFILE)
  routeMock.mockClear()
  return { route, source }
}

const controlCoords = (route: Route) =>
  route.points.filter((p) => p.manual).map((p) => [p.lng, p.lat])

describe('edgeMode', () => {
  const imported = () => createRoute(TRACK).points

  it('reads a straight edge from the arrival point', () => {
    const pts = imported().map((p) => ({ ...p }))
    pts[2].direct = true
    expect(edgeMode(pts, 2)).toBe('DIRECT')
  })

  it('takes a routed leg ending between two imported points for routed, even without interior', () => {
    const pts = imported().map((p) => ({ ...p }))
    pts[2].legAscend = 0
    expect(edgeMode(pts, 2)).toBe('ROUTED')
  })

  it('takes contiguous imported points of one import for the file', () => {
    const pts = imported().map((p) => ({ ...p }))
    expect(edgeMode(pts, 1)).toBe('IMPORTED')
  })

  it('does not take a decreasing index or another import for the file', () => {
    const pts = imported().map((p) => ({ ...p }))
    pts[2].sourceIdx = 5
    expect(edgeMode(pts, 2)).toBe('ROUTED')
    const other = imported().map((p) => ({ ...p }))
    other[3].sourceId = 1
    expect(edgeMode(other, 3)).toBe('ROUTED')
    const noIndex = imported().map((p) => ({ ...p }))
    delete noIndex[3].sourceIdx
    expect(edgeMode(noIndex, 3)).toBe('ROUTED')
  })
})

describe('serializePlannerState', () => {
  it('saves a drawn track as routed pieces and a straight one, all junctions being control points', async () => {
    const route = await drawn([A], [B], [C], [D, true])
    const state = serializePlannerState(route, [], RouterProfile.GRAVEL)!
    expect(state.version).toBe(1)
    expect(state.profile).toBe(RouterProfile.GRAVEL)
    expect(state.sources).toEqual([])
    expect(state.pieces.map((p) => p.mode)).toEqual([
      PlannerPieceMode.ROUTED,
      PlannerPieceMode.ROUTED,
      PlannerPieceMode.DIRECT,
    ])
    expect(state.junctions).toHaveLength(4)
    expect(state.junctions.every((j) => j.kind === PlannerJunctionKind.CONTROL)).toBe(true)
    expect(state.junctions.every((j) => j.source === undefined)).toBe(true)
    // The routed piece carries the climb of its leg and its interior elevations
    expect(state.pieces[0].ascend).toBe(8)
    expect(state.pieces[0].ele).toBeDefined()
    expect(decode2(state.pieces[0].line!).length).toBe(decode1(state.pieces[0].ele!).length)
    // A straight piece has no interior and no climb of its own
    expect(state.pieces[2].line).toBe('')
    expect(state.pieces[2].ascend).toBeUndefined()
  })

  it('saves a reopened track, untouched, as one imported piece', () => {
    const route = createRoute(TRACK, 80)
    const state = serializePlannerState(route, [sourceOf(TRACK, 80)], RouterProfile.FASTBIKE)!
    expect(state.pieces).toEqual([
      { mode: PlannerPieceMode.IMPORTED, source: 0, from: 0, to: TRACK.length - 1 },
    ])
    expect(state.junctions).toHaveLength(2)
    expect(state.junctions.map((j) => [j.source, j.idx])).toEqual([
      [0, 0],
      [0, TRACK.length - 1],
    ])
    expect(state.sources).toHaveLength(1)
    expect(decode2(state.sources[0].line)).toHaveLength(TRACK.length)
    expect(state.sources[0].ascendScale).toBeCloseTo(80 / sourceOf(TRACK).cumul.at(-1)!, 9)
  })

  it('saves the example of the plan: import, a detour between two anchors', async () => {
    const { route, source } = await importWithDetour()
    const state = serializePlannerState(route, [source], RouterProfile.GRAVEL)!
    expect(state.junctions.map((j) => j.kind)).toEqual([
      'CONTROL',
      'JOIN',
      'CONTROL',
      'JOIN',
      'CONTROL',
    ])
    expect(state.pieces.map((p) => p.mode)).toEqual(['IMPORTED', 'ROUTED', 'ROUTED', 'IMPORTED'])
    expect(state.pieces[0]).toMatchObject({ source: 0, from: 0, to: 20 })
    expect(state.pieces[3]).toMatchObject({ source: 0, from: 40, to: 50 })
    expect(state.junctions[1]).toMatchObject({ source: 0, idx: 20 })
    expect(state.junctions[3]).toMatchObject({ source: 0, idx: 40 })
  })

  it('keeps an imported point between two routed legs as a join with its provenance', async () => {
    let route = createRoute(TRACK)
    const [, v1, v2, v3] = route.points
    route = await insert(route, v1, { lng: 5.03, lat: 45.015 }, v2, PROFILE)
    route = await insert(route, v2, { lng: 5.045, lat: 45.012 }, v3, PROFILE)
    const state = serializePlannerState(route, [sourceOf(TRACK)], RouterProfile.GRAVEL)!
    const joins = state.junctions.filter((j) => j.kind === 'JOIN')
    expect(joins.map((j) => j.idx)).toEqual([10, 20, 30])
    expect(state.pieces.map((p) => p.mode)).toEqual([
      'IMPORTED',
      'ROUTED',
      'ROUTED',
      'ROUTED',
      'ROUTED',
      'IMPORTED',
    ])
  })

  it('trims the source to the range that is referenced, keeping the scale', async () => {
    const source = sourceOf(TRACK, 80)
    let route = createRoute(TRACK, 80)
    // Cut the start at the anchor of index 20: the file before it is not kept
    route = await remove(route, undefined, route.points[2], PROFILE)
    const state = serializePlannerState(route, [source], RouterProfile.GRAVEL)!
    expect(decode2(state.sources[0].line)).toHaveLength(TRACK.length - 20)
    expect(state.sources[0].ascendScale).toBe(source.ascendScale)
    expect(state.pieces).toEqual([{ mode: 'IMPORTED', source: 0, from: 0, to: TRACK.length - 21 }])
    expect(state.junctions[0]).toMatchObject({ source: 0, idx: 0 })
  })

  it('keeps the elevations of a source that has a gap, the climb of the file survives', () => {
    const gappy = TRACK.map((c) => [...c])
    gappy[7] = [gappy[7][0], gappy[7][1]]
    gappy[0] = [gappy[0][0], gappy[0][1]]
    const route = createRoute(TRACK, 80)
    const state = serializePlannerState(route, [sourceOf(gappy, 80)], RouterProfile.FASTBIKE)!
    const ele = decode1(state.sources[0].ele!)
    expect(ele).toHaveLength(TRACK.length)
    expect(ele[7]).toBe(gappy[6][2]) // carried from the previous point
    expect(ele[0]).toBe(gappy[1][2]) // the first ones take the next known
  })

  it('saves an imported-looking edge of an unknown file as a line, not as no state', () => {
    const route = createRoute(TRACK, 80)
    const state = serializePlannerState(route, [], RouterProfile.FASTBIKE)
    expect(state).not.toBeNull()
    expect(state!.sources).toHaveLength(0)
    expect(state!.pieces.every((piece) => piece.mode !== PlannerPieceMode.IMPORTED)).toBe(true)
  })

  it('returns null under two points and past the bounds', () => {
    expect(serializePlannerState(computeRoute([]), [], RouterProfile.GRAVEL)).toBeNull()
    const points: RoutePoint[] = []
    for (let i = 0; i <= MAX_PLANNER_PIECES + 1; i++) {
      const p = createPoint(5 + i * 0.0001, 45)
      p.manual = true
      p.direct = i > 0
      points.push(p)
    }
    const route = computeRoute(points)
    expect(serializePlannerState(route, [], RouterProfile.GRAVEL)).toBeNull()
    // One piece fewer is within the bounds
    const fewer = computeRoute(points.slice(0, MAX_PLANNER_PIECES + 1))
    expect(serializePlannerState(fewer, [], RouterProfile.GRAVEL)).not.toBeNull()
  })
})

describe('restorePlannerState', () => {
  it('reads a state back without any request: same control points, straight legs, length and climb', async () => {
    const { route, source } = await importWithDetour()
    const state = serializePlannerState(route, [source], RouterProfile.GRAVEL)!
    routeMock.mockClear()

    const restored = restorePlannerState(state)
    expect(routeMock).not.toHaveBeenCalled()
    expect(restored.sources).toHaveLength(1)

    const before = controlCoords(route)
    const after = controlCoords(restored.route)
    expect(after).toHaveLength(before.length)
    after.forEach((c, i) => {
      expect(c[0]).toBeCloseTo(before[i][0], 6)
      expect(c[1]).toBeCloseTo(before[i][1], 6)
    })
    expect(Math.abs(restored.route.dist - route.dist)).toBeLessThan(1)
    expect(Math.abs(restored.route.ascend - route.ascend)).toBeLessThan(0.5)
  })

  it('keeps straight legs straight, and the joins visible and imported', async () => {
    const route = await drawn([A], [B], [C, true], [D])
    const state = serializePlannerState(route, [], RouterProfile.GRAVEL)!
    const restored = restorePlannerState(state).route
    expect(restored.points.filter((p) => p.direct).length).toBe(
      route.points.filter((p) => p.direct).length
    )
    expect(Math.abs(restored.ascend - route.ascend)).toBeLessThan(0.5)

    const plan = await importWithDetour()
    const again = restorePlannerState(
      serializePlannerState(plan.route, [plan.source], RouterProfile.GRAVEL)!
    ).route
    const joins = again.points.filter((p) => p.imported && !p.manual && p.zoom === 0)
    expect(joins.map((p) => p.sourceIdx)).toEqual([20, 40])
  })

  it('gives back what it was given: serialize(restore(s)) equals s', async () => {
    const { route, source } = await importWithDetour()
    const state = serializePlannerState(route, [source], RouterProfile.GRAVEL)!
    const restored = restorePlannerState(state)
    expect(serializePlannerState(restored.route, restored.sources, RouterProfile.GRAVEL)).toEqual(
      state
    )

    // A cut start, whose source was trimmed
    const full = createRoute(TRACK, 80)
    const cut = await remove(full, undefined, full.points[2], PROFILE)
    const cutState = serializePlannerState(cut, [sourceOf(TRACK, 80)], RouterProfile.GRAVEL)!
    const reopened = restorePlannerState(cutState)
    expect(serializePlannerState(reopened.route, reopened.sources, RouterProfile.GRAVEL)).toEqual(
      cutState
    )
  })

  it('refuses an unknown version', async () => {
    const route = await drawn([A], [B])
    const state = serializePlannerState(route, [], RouterProfile.GRAVEL)!
    expect(() => restorePlannerState({ ...state, version: 2 })).toThrow(PlannerStateFormatError)
  })

  it('refuses an inconsistent state', async () => {
    const route = await drawn([A], [B])
    const state = serializePlannerState(route, [], RouterProfile.GRAVEL)!
    expect(() => restorePlannerState({ ...state, junctions: state.junctions.slice(1) })).toThrow(
      PlannerStateFormatError
    )
    expect(() =>
      restorePlannerState({
        ...state,
        pieces: [{ mode: PlannerPieceMode.ROUTED, line: 'not a polyline \u0001' }],
      })
    ).toThrow(PlannerStateFormatError)
  })
})
