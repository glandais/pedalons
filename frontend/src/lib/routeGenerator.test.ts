import { describe, expect, it } from 'vitest'
import { CompassPoint, ErrorCode, RouteGeneratorType } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { createServerI18n } from '@/i18n'
import {
  dominantGeneratorType,
  familiarityBand,
  generatedRouteName,
  generatorErrorMessage,
  gpxFromLine,
  isEndFar,
  isRetryableGeneratorError,
  normalizePointParam,
  pointFromParam,
  pointToParam,
  readGeneratedHandoff,
  routeGeneratorRequest,
} from './routeGenerator'

const START = { lat: 45, lng: 5 }
/** A point `km` east of START, on the same parallel. */
const east = (km: number) => ({ lat: 45, lng: 5 + km / (111.32 * Math.cos((45 * Math.PI) / 180)) })

describe('points in the query string', () => {
  it('round-trips with 5 decimals and drops garbage', () => {
    expect(pointToParam({ lat: 45.123456789, lng: 5.1 })).toBe('45.12346,5.10000')
    expect(pointFromParam('45.12346,5.1')).toEqual({ lat: 45.12346, lng: 5.1 })
    expect(normalizePointParam('45.123456789,5.1')).toBe('45.12346,5.10000')
    expect(pointFromParam('foo')).toBeUndefined()
    expect(pointFromParam('95,5')).toBeUndefined()
    expect(pointFromParam('45,200')).toBeUndefined()
    expect(pointFromParam(undefined)).toBeUndefined()
  })
})

describe('isEndFar', () => {
  it('is false without an end or a start', () => {
    expect(isEndFar(START, undefined, 50)).toBe(false)
    expect(isEndFar(undefined, east(40), 50)).toBe(false)
  })
  it('compares the straight distance with half the wished distance', () => {
    expect(isEndFar(START, east(24.9), 50)).toBe(false)
    expect(isEndFar(START, east(25.1), 50)).toBe(true)
  })
})

describe('routeGeneratorRequest', () => {
  const base = { distanceKm: 50, familiarity: 0.5, seed: 0 }
  it('leaves out start and end by default', () => {
    const request = routeGeneratorRequest(base, RouteGeneratorType.ROAD)
    expect(request).toEqual({
      distanceKm: 50,
      familiarity: 0.5,
      type: 'ROAD',
      seed: 0,
    })
    expect('start' in request).toBe(false)
    expect('end' in request).toBe(false)
    expect('bearing' in request).toBe(false)
  })
  it('keeps the bearing for a loop and a near end, drops it for a far end', () => {
    const loop = routeGeneratorRequest({ ...base, bearing: CompassPoint.N }, 'ROAD', START)
    expect(loop.bearing).toBe('N')
    const near = routeGeneratorRequest(
      { ...base, bearing: CompassPoint.N, end: pointToParam(east(10)) },
      'ROAD',
      START
    )
    expect(near.bearing).toBe('N')
    expect(near.end).toBeDefined()
    const far = routeGeneratorRequest(
      { ...base, bearing: CompassPoint.N, end: pointToParam(east(40)) },
      'ROAD',
      START
    )
    expect('bearing' in far).toBe(false)
    expect(far.end).toBeDefined()
  })
  it('measures the far end from the chosen start, not the team location', () => {
    const request = routeGeneratorRequest(
      {
        ...base,
        bearing: CompassPoint.S,
        start: pointToParam(east(100)),
        end: pointToParam(east(110)),
      },
      'ROAD',
      START
    )
    expect(request.bearing).toBe('S')
    expect(request.start).toBeDefined()
  })
  it('lets the URL type win over the dominant one, and passes the seed through', () => {
    const request = routeGeneratorRequest({ ...base, type: 'MTB', seed: 3 }, 'ROAD')
    expect(request.type).toBe('MTB')
    expect(request.seed).toBe(3)
  })
})

describe('dominantGeneratorType', () => {
  it('takes the largest count', () => {
    expect(dominantGeneratorType({ ROAD: 2, GRAVEL: 5, MTB: 1 })).toBe('GRAVEL')
    expect(dominantGeneratorType({ ROAD: 2, GRAVEL: 5, MTB: 9 })).toBe('MTB')
  })
  it('breaks a tie ROAD > GRAVEL > MTB, and gives ROAD for nothing', () => {
    expect(dominantGeneratorType({ ROAD: 3, GRAVEL: 3, MTB: 3 })).toBe('ROAD')
    expect(dominantGeneratorType({ ROAD: 1, GRAVEL: 4, MTB: 4 })).toBe('GRAVEL')
    expect(dominantGeneratorType({ ROAD: 0, GRAVEL: 0, MTB: 0 })).toBe('ROAD')
    expect(dominantGeneratorType({})).toBe('ROAD')
  })
})

describe('familiarityBand', () => {
  it('cuts at a third and two thirds', () => {
    expect(familiarityBand(0)).toBe('low')
    expect(familiarityBand(0.33)).toBe('low')
    expect(familiarityBand(0.34)).toBe('mid')
    expect(familiarityBand(0.66)).toBe('mid')
    expect(familiarityBand(0.67)).toBe('high')
    expect(familiarityBand(1)).toBe('high')
  })
})

describe('gpxFromLine', () => {
  it('writes a track that parses back to the same points, with the name escaped', () => {
    const coords = [
      [5.123456, 45.654321],
      [5.2, 45.7],
      [5.3, 45.8],
    ]
    const xml = gpxFromLine('A <b> & "c"', coords)
    const doc = new DOMParser().parseFromString(xml, 'application/xml')
    expect(doc.querySelector('parsererror')).toBeNull()
    expect(doc.querySelector('trk > name')?.textContent).toBe('A <b> & "c"')
    const points = [...doc.querySelectorAll('trkseg > trkpt')].map((p) => [
      Number(p.getAttribute('lon')),
      Number(p.getAttribute('lat')),
    ])
    expect(points).toEqual(coords)
  })
})

describe('readGeneratedHandoff', () => {
  it('reads a well-formed state and ignores anything else', () => {
    const generated = { polyline: 'abc', type: 'GRAVEL', distanceM: 1200 }
    expect(readGeneratedHandoff({ generated })).toEqual(generated)
    expect(readGeneratedHandoff(null)).toBeUndefined()
    expect(
      readGeneratedHandoff({ generated: { polyline: '', type: 'ROAD', distanceM: 1 } })
    ).toBeUndefined()
    expect(
      readGeneratedHandoff({ generated: { polyline: 'a', type: 'MIXED', distanceM: 1 } })
    ).toBeUndefined()
  })
})

describe('generatorErrorMessage and generatedRouteName (real catalogue)', () => {
  const fail = (code: ErrorCode, details?: unknown, retryAfter?: number) =>
    new ApiClientError(
      code === ErrorCode.ROUTE_GENERATOR_RATE_LIMITED ? 429 : 400,
      { code, errorDetails: details as never },
      retryAfter
    )
  const pending = (count: number) => ({
    type: 'GENERATOR_NETWORK_TOO_SMALL',
    routeCount: 2,
    pendingRouteCount: count,
    excludedRouteCount: 0,
    totalLengthM: 1000,
    incomplete: count > 0,
  })

  it('words every row of the table in French', async () => {
    const { t } = await createServerI18n('fr')
    const ctx = { distance: '120 km' }
    expect(generatorErrorMessage(fail(ErrorCode.GENERATOR_START_TOO_FAR), t, ctx)).toContain(
      'du départ'
    )
    expect(generatorErrorMessage(fail(ErrorCode.GENERATOR_END_TOO_FAR), t, ctx)).toContain(
      "de l'arrivée"
    )
    expect(generatorErrorMessage(fail(ErrorCode.GENERATOR_DISTANCE_TOO_SHORT), t, ctx)).toContain(
      '120 km'
    )
    expect(generatorErrorMessage(fail(ErrorCode.GENERATOR_NO_ROUTE), t, ctx)).toContain('120 km')
    expect(
      generatorErrorMessage(fail(ErrorCode.ROUTE_GENERATOR_BUSY, undefined), t, ctx)
    ).toContain('très demandé')
    expect(generatorErrorMessage(fail(ErrorCode.ROUTE_PLANNER_DISABLED), t, ctx)).toContain(
      "n'est pas activée"
    )
    expect(generatorErrorMessage(new Error('x'), t, ctx)).toBe('Génération impossible')
  })

  it('names the routes still being analysed, with the plural', async () => {
    const fr = await createServerI18n('fr')
    const one = generatorErrorMessage(
      fail(ErrorCode.GENERATOR_NETWORK_TOO_SMALL, pending(1)),
      fr.t,
      { distance: '50 km' }
    )
    expect(one).toContain('encore 1 parcours à traiter')
    const en = await createServerI18n('en')
    expect(
      generatorErrorMessage(fail(ErrorCode.GENERATOR_NETWORK_TOO_SMALL, pending(1)), en.t, {
        distance: '50 km',
      })
    ).toContain('1 route left')
    expect(
      generatorErrorMessage(fail(ErrorCode.GENERATOR_NETWORK_TOO_SMALL, pending(3)), en.t, {
        distance: '50 km',
      })
    ).toContain('3 routes left')
  })

  it('tells an empty complete network from a too small one', async () => {
    const { t } = await createServerI18n('fr')
    const empty = { ...pending(0), routeCount: 0 }
    expect(
      generatorErrorMessage(fail(ErrorCode.GENERATOR_NETWORK_TOO_SMALL, empty), t, {
        distance: '50 km',
      })
    ).toContain('pas encore de parcours')
    expect(
      generatorErrorMessage(fail(ErrorCode.GENERATOR_NETWORK_TOO_SMALL, pending(0)), t, {
        distance: '50 km',
      })
    ).toContain('ne suffisent pas pour 50 km')
  })

  it('gives the wait of a rate limit in minutes, rounded up, or the plain message without it', async () => {
    const { t } = await createServerI18n('fr')
    const ctx = { distance: '50 km' }
    expect(
      generatorErrorMessage(fail(ErrorCode.ROUTE_GENERATOR_RATE_LIMITED, undefined, 61), t, ctx)
    ).toContain('dans 2 minutes')
    expect(
      generatorErrorMessage(fail(ErrorCode.ROUTE_GENERATOR_RATE_LIMITED, undefined, 30), t, ctx)
    ).toContain('dans 1 minute.')
    expect(generatorErrorMessage(fail(ErrorCode.ROUTE_GENERATOR_RATE_LIMITED), t, ctx)).toBe(
      t('errors.api.ROUTE_GENERATOR_RATE_LIMITED')
    )
  })

  it('says « Pas de connexion » for a network failure', async () => {
    const { t } = await createServerI18n('fr')
    const offline = Object.assign(new Error('Network Error'), { isAxiosError: true })
    expect(generatorErrorMessage(offline, t, { distance: '50 km' })).toBe('Pas de connexion')
  })

  it('names a generated route after its distance', async () => {
    const { t } = await createServerI18n('fr')
    expect(generatedRouteName('82 km', t)).toBe('Parcours généré de 82 km')
  })

  it('offers « Réessayer » on a busy server and an unknown failure, not on a refusal', () => {
    expect(isRetryableGeneratorError(fail(ErrorCode.ROUTE_GENERATOR_BUSY))).toBe(true)
    expect(isRetryableGeneratorError(new Error('boom'))).toBe(true)
    expect(isRetryableGeneratorError(fail(ErrorCode.GENERATOR_NO_ROUTE))).toBe(false)
    expect(isRetryableGeneratorError(fail(ErrorCode.ROUTE_GENERATOR_RATE_LIMITED))).toBe(false)
  })
})
