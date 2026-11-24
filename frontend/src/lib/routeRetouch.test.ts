import { describe, expect, it } from 'vitest'
import { ErrorCode, RetouchKind, RouteGeneratorType, type RouteRetouchOfferDto } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { frenchT } from '@/test/frenchT'
import {
  changedCoords,
  circleCoords,
  clampTarget,
  generatorLinkFor,
  isDeadZone,
  isNoShorter,
  isOutOfRange,
  isRetryableRetouchError,
  isShortening,
  retouchBounds,
  retouchErrorTone,
  isOtherSeedUseful,
  retouchHandoff,
  routeRetouchErrorMessage,
  routeRetouchRequest,
} from './routeRetouch'
import { readGeneratedHandoff } from './routeGenerator'

const OFFER: RouteRetouchOfferDto = {
  available: true,
  operations: ['RESIZE', 'MOVE_END'],
  originalDistanceM: 82_400,
  minDistanceKm: 57.7,
  maxDistanceKm: 107.1,
  minChangeKm: 1,
  maxChangeShare: 0.3,
  endSnapM: 500,
  proposalsMax: 3,
  rideType: 'ROAD',
}

const TEXTS = { distance: '70 km', current: '82,4 km', min: '1 km', percent: '30 %' }
const t = frenchT as never

const err = (code: string, status = 400) => new ApiClientError(status, { code } as never)

describe('retouchBounds', () => {
  it('reads every bound from the offer', () => {
    expect(retouchBounds(OFFER)).toEqual({
      currentKm: 82.4,
      minKm: 57.7,
      maxKm: 107.1,
      minChangeKm: 1,
      maxChangeShare: 0.3,
    })
  })

  it('has none for an unavailable or incomplete offer', () => {
    expect(retouchBounds(undefined)).toBeUndefined()
    expect(retouchBounds({ available: false, operations: [] })).toBeUndefined()
    expect(retouchBounds({ ...OFFER, minDistanceKm: undefined })).toBeUndefined()
  })
})

describe('target rules', () => {
  const bounds = retouchBounds(OFFER)!

  it('refuses a target too close to the length (the dead zone)', () => {
    expect(isDeadZone(82.9, bounds)).toBe(true)
    expect(isDeadZone(81.5, bounds)).toBe(true)
    expect(isDeadZone(83.4, bounds)).toBe(false)
    expect(isDeadZone(81.4, bounds)).toBe(false)
  })

  it('refuses a target out of the range, with a display-rounding tolerance', () => {
    expect(isOutOfRange(57.0, bounds)).toBe(true)
    expect(isOutOfRange(57.68, bounds)).toBe(false)
    expect(isOutOfRange(108, bounds)).toBe(true)
  })

  it('clamps into the range', () => {
    expect(clampTarget(57.69, bounds)).toBe(57.7)
    expect(clampTarget(200, bounds)).toBe(107.1)
    expect(clampTarget(90, bounds)).toBe(90)
  })

  it('tells a shortening', () => {
    expect(isShortening(70, 82.4)).toBe(true)
    expect(isShortening(90, 82.4)).toBe(false)
  })
})

describe('routeRetouchRequest', () => {
  it('sends the distance and no end', () => {
    const request = routeRetouchRequest({ mode: 'resize', targetKm: 90.04 }, 0)
    expect(request).toEqual({ targetDistanceKm: 90, discovery: 0.25, seed: 0 })
    expect(request.end).toBeUndefined()
  })

  it('sends a point as the end, and no distance', () => {
    const request = routeRetouchRequest({ mode: 'moveEnd', point: { lat: 45, lng: 6 } }, 2)
    expect(request).toEqual({ end: { point: { lat: 45, lng: 6 } }, discovery: 0.25, seed: 2 })
    expect(request.targetDistanceKm).toBeUndefined()
  })

  it('sends a place of the team as the end, and only the place', () => {
    const request = routeRetouchRequest({ mode: 'moveEnd', placeId: 'p1' }, 0)
    expect(request.end).toEqual({ placeId: 'p1' })
  })
})

describe('changedCoords', () => {
  const coords = [0, 1, 2, 3, 4, 5].map((i) => [i, i])

  it('takes both bounds included', () => {
    expect(changedCoords(coords, 2, 4)).toEqual([
      [2, 2],
      [3, 3],
      [4, 4],
    ])
  })

  it('clamps to the line', () => {
    expect(changedCoords(coords, -3, 99)).toHaveLength(6)
  })

  it('is empty for a truncation or an empty line', () => {
    expect(changedCoords(coords, 5, 3)).toEqual([])
    expect(changedCoords([], 0, 0)).toEqual([])
  })
})

describe('circleCoords', () => {
  it('closes the ring at the given radius', () => {
    const ring = circleCoords({ lat: 45, lng: 6 }, 500, 8)
    expect(ring).toHaveLength(9)
    expect(ring[0]).toEqual(ring[8])
    // East point: 500 m of longitude at 45 degrees
    expect(ring[0][0] - 6).toBeCloseTo(500 / (111_195 * Math.cos((45 * Math.PI) / 180)), 4)
  })
})

describe('retouchHandoff', () => {
  it('is read back by the planner import, with its name and type', () => {
    const handoff = retouchHandoff(
      { polyline: '_p~iF~ps|U', distanceM: 70_000, kind: RetouchKind.SHORTEN } as never,
      RouteGeneratorType.GRAVEL,
      'Sortie (retouché)'
    )
    expect(readGeneratedHandoff({ generated: handoff })).toEqual({
      polyline: '_p~iF~ps|U',
      type: 'GRAVEL',
      distanceM: 70_000,
      name: 'Sortie (retouché)',
    })
  })

  it('falls back on a road ride without a type', () => {
    const handoff = retouchHandoff({ polyline: 'x', distanceM: 1 } as never, undefined, 'n')
    expect(handoff.type).toBe('ROAD')
  })
})

describe('generatorLinkFor', () => {
  it('carries the distance rounded into 10 to 200, the start and the type', () => {
    expect(generatorLinkFor('/g', [5.123456, 45.654321], 82.4, RouteGeneratorType.ROAD)).toBe(
      '/g?d=82&s=45.65432%2C5.12346&t=ROAD'
    )
    expect(generatorLinkFor('/g', undefined, 3, undefined)).toBe('/g?d=10')
    expect(generatorLinkFor('/g', undefined, 900, undefined)).toBe('/g?d=200')
  })

  it('is the bare path with nothing to carry', () => {
    expect(generatorLinkFor('/g', undefined, undefined, undefined)).toBe('/g')
  })
})

describe('errors', () => {
  it.each([
    [ErrorCode.ROUTE_RETOUCH_NOT_READY, /encore en cours d'analyse/],
    [ErrorCode.ROUTE_RETOUCH_UNSUPPORTED, /ne peut pas être retouché/],
    [ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY, /repasse sur elle-même/],
    [ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL, /au moins 1 km de plus ou de moins que 82,4 km/],
    [ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE, /au plus 30 %/],
    [ErrorCode.ROUTE_RETOUCH_NO_SHORTER, /ne se raccourcit pas à 70 km/],
    [ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL, /Aucune proposition/],
    [ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE, /sans demi-tour/],
    [ErrorCode.GENERATOR_END_TOO_FAR, /près de cette arrivée/],
    [ErrorCode.GENERATOR_OUT_OF_COVERAGE, /sort de la carte/],
    [ErrorCode.GENERATOR_UNAVAILABLE, /indisponible/],
    [ErrorCode.ROUTE_GENERATOR_BUSY, /très demandé/],
    [ErrorCode.ROUTE_PLANNER_DISABLED, /pas activée/],
    [ErrorCode.VALIDATION, /n'accepte pas ces réglages/],
    [ErrorCode.INTERNAL_ERROR, /Retouche impossible/],
  ])('words %s', (code, message) => {
    expect(routeRetouchErrorMessage(err(code), t, TEXTS)).toMatch(message)
  })

  it('names the wait of a rate limit in minutes', () => {
    const error = err(ErrorCode.ROUTE_GENERATOR_RATE_LIMITED, 429)
    error.retryAfterSeconds = 130
    expect(routeRetouchErrorMessage(error, t, TEXTS)).toMatch(/dans 3 minutes/)
  })

  it('shows a refused shortening in blue, never as a failure', () => {
    for (const code of [
      ErrorCode.ROUTE_RETOUCH_NO_SHORTER,
      ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE,
      ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY,
      ErrorCode.ROUTE_RETOUCH_UNSUPPORTED,
      ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL,
      ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE,
      ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL,
    ]) {
      expect(retouchErrorTone(err(code))).toBe('info')
    }
    expect(retouchErrorTone(err(ErrorCode.ROUTE_GENERATOR_BUSY, 503))).toBe('error')
    expect(isNoShorter(err(ErrorCode.ROUTE_RETOUCH_NO_SHORTER))).toBe(true)
    expect(isNoShorter(err(ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL))).toBe(false)
    expect(isOtherSeedUseful(err(ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL))).toBe(true)
    expect(isOtherSeedUseful(err(ErrorCode.ROUTE_RETOUCH_NO_SHORTER))).toBe(true)
    expect(isOtherSeedUseful(err(ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY))).toBe(false)
  })

  it('offers a retry only where a second request may pass', () => {
    const retryable = [ErrorCode.ROUTE_GENERATOR_BUSY, ErrorCode.GENERATOR_UNAVAILABLE]
    const not = [
      ErrorCode.ROUTE_RETOUCH_NOT_READY,
      ErrorCode.ROUTE_RETOUCH_UNSUPPORTED,
      ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY,
      ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL,
      ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE,
      ErrorCode.ROUTE_RETOUCH_NO_SHORTER,
      ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL,
      ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE,
      ErrorCode.GENERATOR_END_TOO_FAR,
      ErrorCode.GENERATOR_OUT_OF_COVERAGE,
      ErrorCode.ROUTE_GENERATOR_RATE_LIMITED,
      ErrorCode.ROUTE_PLANNER_DISABLED,
      ErrorCode.VALIDATION,
    ]
    for (const code of retryable) expect(isRetryableRetouchError(err(code, 503))).toBe(true)
    for (const code of not) expect(isRetryableRetouchError(err(code))).toBe(false)
    expect(isRetryableRetouchError(new Error('boom'))).toBe(true)
  })
})
