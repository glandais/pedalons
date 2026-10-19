import { beforeEach, describe, expect, it, vi } from 'vitest'
import { RouterProfile, type GpxImportTrack } from '@/api/dto'

const routeMock = vi.hoisted(() => vi.fn())
vi.mock('@/api/endpoints/router/router', () => ({ route: routeMock }))

import {
  add,
  appendImport,
  computeRoute,
  createPoint,
  edgeMode,
  restoreSourceSpan,
  routeFromSources,
  sourceFromImport,
  type Point,
  type RouterSettings,
} from './planner'
import { restorePlannerState, serializePlannerState } from './plannerState'
import { decode1, decode2, encode1, encode2 } from './polyline'

const PROFILE: RouterSettings = { profile: RouterProfile.GRAVEL }

/** A track as the import endpoint answers it: a line going east, rising 2 m per point. */
function importTrack(opts: { lng: number; lat: number; n: number; withClimb?: boolean }) {
  const { lng, lat, n, withClimb = true } = opts
  const coords = Array.from({ length: n }, (_, i) => [lng + i * 0.0005, lat])
  const ele = Array.from({ length: n }, (_, i) => 100 + 2 * i)
  const climb = Array.from({ length: n }, (_, i) => 2 * i - (i > 0 ? 1 : 0)) // dead-band: 1 m lost
  const track: GpxImportTrack = {
    line: encode2(coords),
    ele: encode1(ele),
    ...(withClimb && { climb: encode1(climb) }),
    dist: (n - 1) * 39,
    ascend: climb[n - 1],
  }
  return { track, climb }
}

beforeEach(() => {
  routeMock.mockReset()
  routeMock.mockImplementation(async ({ from, to }: { from: Point; to: Point }) => ({
    route: {
      coordinates: [
        [from.lng, from.lat, 150],
        [(from.lng + to.lng) / 2, (from.lat + to.lat) / 2 + 0.0005, 160],
        [to.lng, to.lat, 155],
      ],
    },
    ascend: 12,
  }))
})

describe('sourceFromImport', () => {
  it('reads the server climb as the cumulative climb, unscaled', () => {
    const { track, climb } = importTrack({ lng: 5, lat: 45, n: 6 })
    const source = sourceFromImport(track)
    expect(source.coords).toHaveLength(6)
    expect(source.coords[3][2]).toBe(106)
    expect(source.cumul).toEqual(decode1(track.climb!))
    expect(source.cumul[5]).toBeCloseTo(climb[5], 5)
    expect(source.ascendScale).toBe(1)
    expect(source.serverClimb).toBe(true)
  })

  it('falls back on the raw climb without a server one', () => {
    const { track } = importTrack({ lng: 5, lat: 45, n: 6, withClimb: false })
    const source = sourceFromImport(track)
    expect(source.serverClimb).toBeUndefined()
    expect(source.cumul[5]).toBeCloseTo(10, 5)
  })

  it('refuses a track whose climb does not match its line', () => {
    const { track } = importTrack({ lng: 5, lat: 45, n: 6 })
    expect(() => sourceFromImport({ ...track, climb: encode1([0, 1]) })).toThrow()
  })
})

describe('routeFromSources', () => {
  it('replaces the route with the track: provenance, imported climb, D+ = last climb', () => {
    const { track, climb } = importTrack({ lng: 5, lat: 45, n: 30 })
    const route = routeFromSources([sourceFromImport(track)], 3)
    const first = route.points[0]
    const last = route.points.at(-1)!
    expect(first.sourceId).toBe(3)
    expect(first.sourceIdx).toBe(0)
    expect(last.sourceIdx).toBe(29)
    expect(last.importAscend).toBeCloseTo(climb[29], 5)
    expect(route.ascend).toBeCloseTo(climb[29], 5)
    expect(route.points.every((p) => p.imported)).toBe(true)
    expect(first.manual && last.manual).toBe(true)
  })

  it('joins several tracks by straight lines, the ends being control points', () => {
    const a = sourceFromImport(importTrack({ lng: 5, lat: 45, n: 20 }).track)
    const b = sourceFromImport(importTrack({ lng: 5.1, lat: 45.1, n: 20 }).track)
    const route = routeFromSources([a, b], 0)
    const startOfB = route.points.find((p) => p.sourceId === 1 && p.sourceIdx === 0)!
    expect(startOfB.direct).toBe(true)
    expect(startOfB.manual).toBe(true)
    expect(edgeMode(route.points, startOfB.idx)).toBe('DIRECT')
    const endOfA = route.points.find((p) => p.sourceId === 0 && p.sourceIdx === 19)!
    expect(endOfA.manual).toBe(true)
    expect(route.points.filter((p) => p.direct)).toHaveLength(1)
    expect(route.points[0].direct).toBe(false)
    expect(routeMock).not.toHaveBeenCalled()
  })

  it('gives the file back between the two ends of a track', () => {
    const source = sourceFromImport(importTrack({ lng: 5, lat: 45, n: 60 }).track)
    const route = routeFromSources([source], 0)
    const start = route.points[0]
    const end = route.points.at(-1)!
    const next = restoreSourceSpan(route, start, end, source)
    expect(next.points[0].sourceIdx).toBe(0)
    expect(next.points.at(-1)!.importAscend).toBeCloseTo(source.cumul[59], 5)
  })
})

describe('appendImport', () => {
  async function drawn() {
    let route = await add(
      { points: [], dist: 0, ascend: 0, index: undefined as never },
      { lng: 5, lat: 45 },
      PROFILE
    )
    route = await add(route, { lng: 5.01, lat: 45 }, PROFILE, true)
    routeMock.mockClear()
    return route
  }

  it('joins in a straight line without any request', async () => {
    const route = await drawn()
    const imported = routeFromSources(
      [sourceFromImport(importTrack({ lng: 5.05, lat: 45.01, n: 20 }).track)],
      0
    )
    const next = await appendImport(route, imported, PROFILE, true)
    expect(routeMock).not.toHaveBeenCalled()
    const first = next.points.find((p) => p.sourceId === 0 && p.sourceIdx === 0)!
    expect(first.direct).toBe(true)
    expect(first.legAscend).toBeUndefined()
    expect(next.points.length).toBe(route.points.length + imported.points.length)
  })

  it('joins with one routed call and stores the leg climb on the first imported point', async () => {
    const route = await drawn()
    const imported = routeFromSources(
      [sourceFromImport(importTrack({ lng: 5.05, lat: 45.01, n: 20 }).track)],
      0
    )
    const next = await appendImport(route, imported, PROFILE, false, undefined, 'club')
    expect(routeMock).toHaveBeenCalledTimes(1)
    expect(routeMock.mock.calls[0][0]).toMatchObject({ teamSlug: 'club' })
    const first = next.points.find((p) => p.sourceId === 0 && p.sourceIdx === 0)!
    expect(first.direct).toBe(false)
    expect(first.legAscend).toBe(12)
    expect(edgeMode(next.points, first.idx)).toBe('ROUTED')
    // the file keeps its own coordinates, the router's last point is dropped
    expect(first.lng).toBeCloseTo(5.05, 6)
  })

  it('makes no call when the two ends are under 5 m apart', async () => {
    const route = await drawn()
    const last = route.points.at(-1)!
    const imported = routeFromSources(
      [sourceFromImport(importTrack({ lng: last.lng + 0.00001, lat: last.lat, n: 20 }).track)],
      0
    )
    const next = await appendImport(route, imported, PROFILE, false)
    expect(routeMock).not.toHaveBeenCalled()
    const first = next.points.find((p) => p.sourceId === 0 && p.sourceIdx === 0)!
    expect(first.legAscend).toBe(0)
  })

  it('leaves the route intact when the router fails', async () => {
    const route = await drawn()
    const before = route.points.map((p) => [p.lng, p.lat, p.manual])
    routeMock.mockRejectedValueOnce(new Error('boom'))
    const imported = routeFromSources(
      [sourceFromImport(importTrack({ lng: 5.05, lat: 45.01, n: 20 }).track)],
      0
    )
    await expect(appendImport(route, imported, PROFILE, false)).rejects.toThrow('boom')
    expect(route.points.map((p) => [p.lng, p.lat, p.manual])).toEqual(before)
  })

  it('is the imported route itself on an empty one', async () => {
    const imported = routeFromSources(
      [sourceFromImport(importTrack({ lng: 5, lat: 45, n: 20 }).track)],
      0
    )
    const next = await appendImport(
      { points: [], dist: 0, ascend: 0, index: undefined as never },
      imported,
      PROFILE,
      false
    )
    expect(next).toBe(imported)
  })
})

describe('planner state of an imported source', () => {
  function importedRoute() {
    const source = sourceFromImport(importTrack({ lng: 5, lat: 45, n: 60 }).track)
    return { source, route: routeFromSources([source], 0) }
  }

  it('saves the climb and reads it back', () => {
    const { source, route } = importedRoute()
    const state = serializePlannerState(route, [source], RouterProfile.GRAVEL)!
    expect(state.sources[0].climb).toBeDefined()
    expect(decode1(state.sources[0].climb!)).toHaveLength(60)
    const restored = restorePlannerState(state)
    expect(restored.sources[0].serverClimb).toBe(true)
    expect(restored.sources[0].ascendScale).toBe(1)
    expect(restored.route.ascend).toBeCloseTo(route.ascend, 1)
  })

  it('serialize(restore(s)) == s', () => {
    const { source, route } = importedRoute()
    const state = serializePlannerState(route, [source], RouterProfile.GRAVEL)!
    const again = restorePlannerState(state)
    expect(serializePlannerState(again.route, again.sources, RouterProfile.GRAVEL)).toEqual(state)
  })

  it('trims the climb to the range in use and rebases it on its first point', () => {
    const { source } = importedRoute()
    const from = 10
    const to = 40
    const points = source.coords.slice(from, to + 1).map((c, k) => {
      const p = createPoint(c[0], c[1], c[2], true)
      p.sourceId = 0
      p.sourceIdx = from + k
      p.importAscend = source.cumul[from + k]
      return p
    })
    const cut = computeRoute(points)
    const state = serializePlannerState(cut, [source], RouterProfile.GRAVEL)!
    const climb = decode1(state.sources[0].climb!)
    const n = decode2(state.sources[0].line).length
    expect(n).toBe(to - from + 1)
    expect(climb).toHaveLength(n)
    expect(climb[0]).toBe(0)
    expect(climb[n - 1]).toBeCloseTo(source.cumul[to] - source.cumul[from], 5)
  })

  it('keeps the ratio to the raw sum as ascendScale, within half a metre of the total', () => {
    const { source, route } = importedRoute()
    const state = serializePlannerState(route, [source], RouterProfile.GRAVEL)!
    const ele = decode1(state.sources[0].ele!)
    let raw = 0
    for (let i = 1; i < ele.length; i++) raw += Math.max(0, ele[i] - ele[i - 1])
    const climb = decode1(state.sources[0].climb!)
    expect(Math.abs(raw * state.sources[0].ascendScale - climb[climb.length - 1])).toBeLessThan(0.5)
  })

  it('a state without climb restores as before', () => {
    const { source, route } = importedRoute()
    const state = serializePlannerState(route, [source], RouterProfile.GRAVEL)!
    delete state.sources[0].climb
    const restored = restorePlannerState(state)
    expect(restored.sources[0].serverClimb).toBeUndefined()
  })
})
