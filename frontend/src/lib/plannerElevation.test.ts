import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ApiClientError } from '@/lib/apiError'
import { ErrorCode } from '@/api/dto'
import { encode1, encode2 } from '@/lib/polyline'

const lineElevationMock = vi.hoisted(() => vi.fn())
vi.mock('@/api/endpoints/router/router', () => ({ lineElevation: lineElevationMock }))

import {
  chunkEdges,
  decodeProfile,
  isElevationUnsupported,
  readDirectProfiles,
} from './plannerElevation'
import { computeRoute, createPoint, edgeKey, straightEdgesMissingProfile } from './planner'
import type { DirectProfile, StraightEdge } from './planner'

function edge(i: number, meters = 1000): StraightEdge {
  return {
    key: `k${i}`,
    from: { lng: 5 + i * 0.01, lat: 45 },
    to: { lng: 5.005 + i * 0.01, lat: 45 },
    meters,
  }
}

function track(from: { lng: number; lat: number }, to: { lng: number; lat: number }) {
  return {
    line: encode2([
      [from.lng, from.lat],
      [(from.lng + to.lng) / 2, from.lat],
      [to.lng, to.lat],
    ]),
    ele: encode1([100, 130, 110]),
    climb: encode1([0, 30, 30]),
    dist: 500,
    ascend: 30,
  }
}

describe('straight edges to read', () => {
  /** Straight line from the first point to each of the others. */
  function lineOf(...lngs: number[]) {
    const points = lngs.map((lng, i) => {
      const p = createPoint(lng, 45, undefined, false, i > 0)
      p.manual = true
      return p
    })
    return computeRoute(points)
  }

  it('selects 10 m to 100 km, and leaves out what has a valid profile', () => {
    // 5.0 -> 5.00005 is 4 m; 5.00005 -> 5.01 is ~700 m; 5.01 -> 8.0 is ~235 km
    const route = lineOf(5.0, 5.00005, 5.01, 8.0)
    expect(straightEdgesMissingProfile(route).map((e) => e.key)).toEqual([
      edgeKey(route.points[1], route.points[2]),
    ])
    const profile: DirectProfile = {
      key: edgeKey(route.points[1], route.points[2]),
      lngLat: [],
      ele: [],
      ascend: 0,
    }
    route.points[2].directProfile = profile
    expect(straightEdgesMissingProfile(route)).toEqual([])
  })
})

describe('chunkEdges', () => {
  it('cuts at 50 lines', () => {
    const chunks = chunkEdges(Array.from({ length: 120 }, (_, i) => edge(i)))
    expect(chunks.map((c) => c.length)).toEqual([50, 50, 20])
  })

  it('cuts at 200 km and never sends an empty chunk', () => {
    const chunks = chunkEdges([edge(0, 90_000), edge(1, 90_000), edge(2, 90_000), edge(3, 50_000)])
    expect(chunks.map((c) => c.map((e) => e.key))).toEqual([
      ['k0', 'k1'],
      ['k2', 'k3'],
    ])
    expect(chunkEdges([])).toEqual([])
  })
})

describe('decodeProfile', () => {
  it('decodes the samples, elevations and climb', () => {
    const e = edge(0)
    const profile = decodeProfile('x', track(e.from, e.to))!
    expect(profile.key).toBe('x')
    expect(profile.lngLat).toHaveLength(3)
    expect(profile.lngLat[0][0]).toBeCloseTo(e.from.lng, 6)
    expect(profile.ele).toEqual([100, 130, 110])
    expect(profile.ascend).toBe(30)
  })

  it('refuses an answer it cannot read', () => {
    const e = edge(0)
    expect(decodeProfile('x', { ...track(e.from, e.to), ele: undefined })).toBeNull()
    expect(decodeProfile('x', { ...track(e.from, e.to), ele: encode1([1, 2]) })).toBeNull()
    expect(decodeProfile('x', { ...track(e.from, e.to), line: '~~~' })).toBeNull()
  })
})

describe('readDirectProfiles', () => {
  beforeEach(() => {
    lineElevationMock.mockReset()
  })

  it('sends one request per chunk with the team, silently, and keys the answers', async () => {
    lineElevationMock.mockImplementation(async (body: { lines: { from: never; to: never }[] }) => ({
      lines: body.lines.map((l) => track(l.from, l.to)),
      elevationFallback: false,
    }))
    const edges = Array.from({ length: 51 }, (_, i) => edge(i))
    const into = new Map<string, DirectProfile>()
    await readDirectProfiles(edges, 'club', into)
    expect(lineElevationMock).toHaveBeenCalledTimes(2)
    expect(lineElevationMock.mock.calls[0][0].teamSlug).toBe('club')
    expect(lineElevationMock.mock.calls[0][0].lines).toHaveLength(50)
    expect(lineElevationMock.mock.calls[0][1]).toEqual({ skipErrorToast: true })
    expect(into.size).toBe(51)
    expect(into.get('k7')!.ascend).toBe(30)
  })

  it('keeps the chunks answered before a failure', async () => {
    lineElevationMock
      .mockImplementationOnce(async (body: { lines: { from: never; to: never }[] }) => ({
        lines: body.lines.map((l) => track(l.from, l.to)),
        elevationFallback: false,
      }))
      .mockRejectedValueOnce(new Error('boom'))
    const into = new Map<string, DirectProfile>()
    await expect(
      readDirectProfiles(
        Array.from({ length: 51 }, (_, i) => edge(i)),
        undefined,
        into
      )
    ).rejects.toThrow('boom')
    expect(into.size).toBe(50)
  })
})

describe('isElevationUnsupported', () => {
  it('is a 404 or a 405 only', () => {
    expect(isElevationUnsupported(new ApiClientError(404, { code: ErrorCode.NOT_FOUND }))).toBe(
      true
    )
    expect(isElevationUnsupported(new ApiClientError(405, { code: ErrorCode.UNKNOWN }))).toBe(true)
    expect(isElevationUnsupported(new ApiClientError(503, { code: ErrorCode.UNKNOWN }))).toBe(false)
    expect(isElevationUnsupported(new Error('network'))).toBe(false)
  })
})
