import { beforeEach, describe, expect, it, vi } from 'vitest'
import { PlannerPieceMode, RouterProfile, type GpxImportTrack, type PlannerState } from '@/api/dto'

// The raw shapes of the planner state (docs/LEDGER_*.md API-147, phase C): carried opaquely from
// the router and the import to the saved state, dropped by any gesture that changes a leg without
// the router.

// Router simulated: a bowed line of 8 intervals between the two points, and its raw shape, 32
// intervals, each answer's shape told apart by its call number (a millionth of a degree).
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
  createRoute,
  insert,
  LEG_SHAPE_TOLERANCE_M,
  pieceShape,
  remove,
  restoreSourceSpan,
  routeFromSources,
  sourceFromImport,
  sourceOf,
  type Point,
  type Route,
  type RouterSettings,
} from './planner'
import { MAX_PLANNER_STATE_CHARS, restorePlannerState, serializePlannerState } from './plannerState'
import { encode1, encode2 } from './polyline'

const PROFILE: RouterSettings = { profile: RouterProfile.GRAVEL }

interface Request {
  from: Point
  to: Point
}

function bowed(from: Point, to: Point, intervals: number, tag = 0): number[][] {
  const out: number[][] = []
  for (let i = 0; i <= intervals; i++) {
    const t = i / intervals
    const inner = i > 0 && i < intervals
    out.push([
      from.lng + t * (to.lng - from.lng),
      from.lat + t * (to.lat - from.lat) + (inner ? 0.002 * Math.sin(Math.PI * t) + tag * 1e-6 : 0),
      120 + i,
    ])
  }
  return out
}

/** The shape the router answered on its `call`-th request (1-based). */
const shapes: string[] = []

beforeEach(() => {
  shapes.length = 0
  routeMock.mockReset()
  routeMock.mockImplementation(async ({ from, to }: Request) => {
    const shape = encode2(bowed(from, to, 32, shapes.length + 1))
    shapes.push(shape)
    return { route: { coordinates: bowed(from, to, 8) }, ascend: 8, shape }
  })
})

const A: Point = { lng: 5.0, lat: 45.0 }
const B: Point = { lng: 5.02, lat: 45.0 }
const C: Point = { lng: 5.04, lat: 45.01 }
const D: Point = { lng: 5.06, lat: 45.0 }

async function drawn(...legs: [Point, boolean?][]): Promise<Route> {
  let route = computeRoute([])
  for (const [p, direct] of legs) route = await add(route, p, PROFILE, direct ?? false)
  return route
}

function serialize(route: Route, sources = sourcesOf()): PlannerState {
  const state = serializePlannerState(route, sources, RouterProfile.GRAVEL)
  expect(state).not.toBeNull()
  return state!
}

const sourcesOf = () => [] as ReturnType<typeof sourceOf>[]

const pieceShapes = (state: PlannerState) => state.pieces.map((p) => p.shape)

/** Every string of the state, as the server counts them against MAX_PLANNER_STATE_CHARS. */
function stateChars(state: PlannerState): number {
  const len = (s?: string) => s?.length ?? 0
  return (
    state.sources.reduce((n, s) => n + len(s.line) + len(s.ele) + len(s.climb) + len(s.shape), 0) +
    state.pieces.reduce((n, p) => n + len(p.line) + len(p.ele) + len(p.shape), 0)
  )
}

describe('routed legs carry the router shape', () => {
  it('saves each leg with the shape the router answered for it, a straight one with none', async () => {
    const route = await drawn([A], [B], [C, true], [D])
    const state = serialize(route)
    expect(state.pieces.map((p) => p.mode)).toEqual([
      PlannerPieceMode.ROUTED,
      PlannerPieceMode.DIRECT,
      PlannerPieceMode.ROUTED,
    ])
    expect(pieceShapes(state)).toEqual([shapes[0], undefined, shapes[1]])
  })

  it('a backend that sends no shape leaves the pieces without one', async () => {
    routeMock.mockImplementation(async ({ from, to }: Request) => ({
      route: { coordinates: bowed(from, to, 8) },
      ascend: 8,
    }))
    const state = serialize(await drawn([A], [B], [C]))
    expect(pieceShapes(state)).toEqual([undefined, undefined])
  })

  it('round-trips through a saved state, and a history copy of the route', async () => {
    const route = await drawn([A], [B], [C, true], [D])
    const first = serialize(route)
    const { route: restored, sources } = restorePlannerState(first)
    expect(serialize(restored, sources)).toEqual(first)
    // What the history keeps (useRoutePlanner's copyRoute): the points copied, the shapes shared
    const copy = { ...route, points: route.points.map((p) => ({ ...p })) }
    expect(pieceShapes(serialize(copy))).toEqual(pieceShapes(first))
  })
})

describe('gestures that call the router replace the shape', () => {
  it('moving a point re-routes both of its legs', async () => {
    const route = await drawn([A], [B], [C])
    const [a, b, c] = route.points.filter((p) => p.manual)
    const moved = await insert(
      route,
      a,
      { lng: 5.021, lat: 45.004 },
      c,
      PROFILE,
      false,
      undefined,
      undefined,
      b.id
    )
    expect(pieceShapes(serialize(moved))).toEqual([shapes[2], shapes[3]])
  })

  it('inserting a point inside a leg splits it into two new routed legs', async () => {
    const route = await drawn([A], [B])
    const [a, b] = route.points.filter((p) => p.manual)
    const split = await insert(route, a, { lng: 5.01, lat: 45.002 }, b, PROFILE)
    expect(pieceShapes(serialize(split))).toEqual([shapes[1], shapes[2]])
  })

  it('removing a point re-routes its neighbours with the new answer', async () => {
    const route = await drawn([A], [B], [C])
    const [a, , c] = route.points.filter((p) => p.manual)
    const merged = await remove(route, a, c, PROFILE)
    expect(pieceShapes(serialize(merged))).toEqual([shapes[2]])
  })

  it('removing the first or the last point keeps the shapes of the legs left', async () => {
    const route = await drawn([A], [B], [C])
    const b = route.points.filter((p) => p.manual)[1]
    expect(pieceShapes(serialize(await remove(route, undefined, b, PROFILE)))).toEqual([shapes[1]])
    const again = await drawn([A], [B], [C])
    const b2 = again.points.filter((p) => p.manual)[1]
    expect(pieceShapes(serialize(await remove(again, b2, undefined, PROFILE)))).toEqual([shapes[2]])
  })
})

describe('gestures without the router drop the shape', () => {
  it('a point removed as a straight line leaves a straight piece', async () => {
    const route = await drawn([A], [B], [C])
    const [a, , c] = route.points.filter((p) => p.manual)
    const merged = await remove(route, a, c, PROFILE, true)
    const state = serialize(merged)
    expect(state.pieces.map((p) => p.mode)).toEqual([PlannerPieceMode.DIRECT])
    expect(pieceShapes(state)).toEqual([undefined])
    expect(merged.points.at(-1)!.legShape).toBeUndefined()
  })

  it('a junction moved without re-routing its leg drops that leg only', async () => {
    const route = await drawn([A], [B], [C])
    const b = route.points.find((p) => p.manual && p.lng === B.lng)!
    // A few metres (the router snapping the shared end of the next leg): kept
    b.lat += 2e-5
    expect(pieceShapes(serialize(route))).toEqual([shapes[0], shapes[1]])
    // Further than the tolerance (13 m): both legs that meet there drop it
    b.lat += 1e-4
    expect(LEG_SHAPE_TOLERANCE_M).toBeLessThan(13)
    expect(pieceShapes(serialize(route))).toEqual([undefined, undefined])
  })

  it('a piece that is not exactly one leg takes no shape', async () => {
    const route = await drawn([A], [B], [C])
    const last = route.points.length - 1
    // From the first point to the last: two legs
    expect(pieceShape(route.points, 0, last)).toBeUndefined()
  })
})

/**
 * A track as the import endpoint answers it: going east in a zigzag (~45 m each way, so that the
 * simplification keeps anchors inside it), with its raw track twice as dense along the same line.
 */
function importTrack(lng: number, lat: number, n: number): GpxImportTrack {
  const at = (x: number) => {
    const phase = x % 8
    return [lng + x * 0.0005, lat + 0.0001 * (phase < 4 ? phase : 8 - phase)]
  }
  const coords = Array.from({ length: n }, (_, i) => at(i))
  const raw = Array.from({ length: 2 * n - 1 }, (_, i) => at(i / 2))
  return {
    line: encode2(coords),
    ele: encode1(coords.map((_, i) => 100 + 2 * i)),
    dist: (n - 1) * 39,
    ascend: 2 * (n - 1),
    shape: encode2(raw),
  }
}

describe('imported sources carry the file shape', () => {
  it('keeps the raw track of the file and sends the source whole with it', () => {
    const track = importTrack(5, 45, 40)
    const source = sourceFromImport(track)
    expect(source.shape).toBe(track.shape)
    const route = routeFromSources([source], 0)
    const state = serialize(route, [source])
    expect(state.sources).toHaveLength(1)
    expect(state.sources[0].shape).toBe(track.shape)
    expect(state.sources[0].line).toBe(track.line)
    // Round trip: the source comes back with it
    const restored = restorePlannerState(state)
    expect(restored.sources[0].shape).toBe(track.shape)
    expect(serialize(restored.route, restored.sources)).toEqual(state)
  })

  it('a cut source is still sent whole with its shape, and trimmed without one', async () => {
    const track = importTrack(5, 45, 40)
    const source = sourceFromImport(track)
    let route = routeFromSources([source], 0)
    // The import's tail removed: the route ends on an anchor inside the file
    const anchor = route.points.find(
      (p) => p.sourceIdx !== undefined && p.sourceIdx > 10 && p.sourceIdx < 30
    )!
    route = await remove(route, anchor, undefined, PROFILE)
    const state = serialize(route, [source])
    expect(state.sources[0].shape).toBe(track.shape)
    expect(state.sources[0].line).toBe(track.line)
    const bare = { ...source, shape: undefined }
    const trimmed = serialize(route, [bare])
    expect(trimmed.sources[0].shape).toBeUndefined()
    expect(trimmed.sources[0].line.length).toBeLessThan(track.line.length)
  })

  it('a source no imported piece is cut from goes without its shape', async () => {
    const track = importTrack(5, 45, 40)
    const source = sourceFromImport(track)
    const route = routeFromSources([source], 0)
    // Every stretch of the file re-routed: only its two ends still refer to it
    const [first, last] = [route.points[0], route.points.at(-1)!]
    const rerouted = await remove(route, first, last, PROFILE)
    const state = serialize(rerouted, [source])
    expect(state.pieces.map((p) => p.mode)).toEqual([PlannerPieceMode.ROUTED])
    expect(state.sources[0]?.shape).toBeUndefined()
    expect(pieceShapes(state)).toEqual([shapes[0]])
  })

  it('giving the file back over a routed detour drops the detour shapes', async () => {
    const track = importTrack(5, 45, 40)
    const source = sourceFromImport(track)
    let route = routeFromSources([source], 0)
    const s = route.points.find((p) => p.sourceIdx === 8)!
    const e = route.points.find((p) => p.sourceIdx === 28)!
    route = await insert(route, s, { lng: 5.008, lat: 45.002 }, e, PROFILE)
    expect(pieceShapes(serialize(route, [source])).filter(Boolean)).toEqual([shapes[0], shapes[1]])
    route = restoreSourceSpan(route, s, e, source)
    const state = serialize(route, [source])
    expect(pieceShapes(state).filter(Boolean)).toEqual([])
    expect(state.pieces.every((p) => p.mode === PlannerPieceMode.IMPORTED)).toBe(true)
    expect(state.sources[0].shape).toBe(track.shape)
  })

  it('the routed join of an appended import carries its shape', async () => {
    const route = await drawn([A], [B])
    const source = sourceFromImport(importTrack(5.03, 45, 20))
    const joined = await appendImport(route, routeFromSources([source], 0), PROFILE, false)
    const state = serialize(joined, [source])
    expect(state.pieces.map((p) => p.mode)).toEqual([
      PlannerPieceMode.ROUTED,
      PlannerPieceMode.ROUTED,
      PlannerPieceMode.IMPORTED,
    ])
    expect(pieceShapes(state)).toEqual([shapes[0], shapes[1], undefined])
  })

  it('a loaded track of an existing route has no shape', () => {
    const coords = Array.from({ length: 30 }, (_, i) => [5 + i * 0.0005, 45, 100])
    const route = createRoute(coords)
    const state = serialize(route, [sourceOf(coords)])
    expect(state.sources[0].shape).toBeUndefined()
  })
})

describe('the size bound never costs the save', () => {
  /** A router whose shapes are `chars` characters long (a long, dense polyline). */
  function bigShapes(chars: number[]) {
    let call = 0
    routeMock.mockImplementation(async ({ from, to }: Request) => {
      const want = chars[call++] ?? 100
      // A point repeated: every repetition is a zero delta, two characters
      const head = encode2([[from.lng, from.lat]])
      const shape = head + '??'.repeat(Math.max(0, Math.ceil((want - head.length) / 2)))
      shapes.push(shape)
      return { route: { coordinates: bowed(from, to, 8) }, ascend: 8, shape }
    })
  }

  it('drops the largest shapes until the state fits', async () => {
    bigShapes([900_000, 950_000, 800_000])
    const route = await drawn([A], [B], [C], [D])
    const state = serialize(route)
    expect(stateChars(state)).toBeLessThanOrEqual(MAX_PLANNER_STATE_CHARS)
    // The 950 000 one goes, the two others fit
    expect(pieceShapes(state)).toEqual([shapes[0], undefined, shapes[2]])
  })

  it('drops them all when one alone is past the bound, and still saves', async () => {
    bigShapes([MAX_PLANNER_STATE_CHARS + 10])
    const route = await drawn([A], [B])
    const state = serialize(route)
    expect(pieceShapes(state)).toEqual([undefined])
    expect(stateChars(state)).toBeLessThanOrEqual(MAX_PLANNER_STATE_CHARS)
  })
})
