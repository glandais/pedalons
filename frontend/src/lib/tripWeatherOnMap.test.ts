import { describe, expect, it } from 'vitest'
import type { TripDto, TripStageDto, TripWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { weatherLeg } from '@/test/weatherFixtures'
import { combinedWindLegend, stageWindLeg, tripMapWinds } from './tripWeatherOnMap'

const stage = (id: string, timezone: string, routeSlug?: string): TripStageDto =>
  ({
    id,
    slug: id,
    name: id,
    timezone,
    route: routeSlug ? { slug: routeSlug } : undefined,
  }) as unknown as TripStageDto

const trip = (overrides: Partial<TripDto> = {}): TripDto =>
  ({
    id: 't1',
    slug: 'voyage',
    status: Status.PUBLISHED,
    finished: false,
    timezone: 'Europe/Paris',
    stages: [
      stage('s1', 'Europe/Paris', 'aller'),
      stage('s2', 'Europe/Madrid', 'retour'),
      stage('s3', 'Europe/Madrid'),
    ],
    ...overrides,
  }) as TripDto

const weather = (
  stages: { stageId?: string; leg: WeatherLegDto }[],
  status: WeatherStatus = WeatherStatus.OK
): TripWeatherDto => ({
  status,
  stages,
  attribution: { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' },
})

const tripWeather = weather([
  { stageId: 's1', leg: weatherLeg(undefined) },
  { stageId: 's2', leg: weatherLeg(undefined, { status: WeatherStatus.STALE }) },
  { stageId: 's3', leg: weatherLeg(undefined, { status: WeatherStatus.NO_LOCATION }) },
])

describe('stageWindLeg (WEB-118)', () => {
  it("is the stage's leg with a forecast", () => {
    expect(stageWindLeg(trip(), tripWeather, 's1')).toBe(tripWeather.stages[0].leg)
    expect(stageWindLeg(trip(), tripWeather, 's2')).toBe(tripWeather.stages[1].leg)
  })

  it('is none for a stage gone, without a route or not yet forecast', () => {
    const gone = weather([
      { stageId: 's1', leg: weatherLeg(undefined, { status: WeatherStatus.OUT_OF_RANGE }) },
      { stageId: 's2', leg: weatherLeg(undefined, { status: WeatherStatus.NOT_YET_AVAILABLE }) },
    ])
    expect(stageWindLeg(trip(), gone, 's1')).toBeUndefined()
    expect(stageWindLeg(trip(), gone, 's2')).toBeUndefined()
    expect(stageWindLeg(trip(), tripWeather, 's3')).toBeUndefined()
    expect(stageWindLeg(trip(), undefined, 's1')).toBeUndefined()
  })

  it('is none on a trip finished or cancelled', () => {
    expect(stageWindLeg(trip({ finished: true }), tripWeather, 's1')).toBeUndefined()
    expect(stageWindLeg(trip({ status: Status.CANCELLED }), tripWeather, 's1')).toBeUndefined()
  })
})

describe('tripMapWinds (WEB-118)', () => {
  it('gives every stage with a forecast its own leg, read in its own zone', () => {
    const winds = tripMapWinds(trip(), tripWeather)
    expect([...winds.keys()]).toEqual(['s1', 's2'])
    expect(winds.get('s1')).toEqual({
      leg: tripWeather.stages[0].leg,
      timezone: 'Europe/Paris',
    })
    expect(winds.get('s2')?.timezone).toBe('Europe/Madrid')
  })

  it('leaves out a stage gone, and gives nothing on a trip over or cancelled', () => {
    const someGone = weather([
      { stageId: 's1', leg: weatherLeg(undefined, { status: WeatherStatus.OUT_OF_RANGE }) },
      { stageId: 's2', leg: weatherLeg(undefined) },
    ])
    expect([...tripMapWinds(trip(), someGone).keys()]).toEqual(['s2'])
    expect(tripMapWinds(trip({ finished: true }), tripWeather).size).toBe(0)
    expect(tripMapWinds(trip({ status: Status.CANCELLED }), tripWeather).size).toBe(0)
    expect(tripMapWinds(trip(), undefined).size).toBe(0)
  })

  it("lays a trip without stages' single leg on its own route, never its stages' legs", () => {
    const single = weather([{ leg: weatherLeg(undefined) }])
    const own = trip({ routeSlug: 'grand-tour', stages: [] })
    expect(tripMapWinds(own, single).get('t1')).toEqual({
      leg: single.stages[0].leg,
      timezone: 'Europe/Paris',
    })
    // A trip drawn on its route but forecast stage by stage, along routes the map does not draw
    expect(tripMapWinds(trip({ routeSlug: 'grand-tour' }), tripWeather).size).toBe(0)
  })
})

describe('combinedWindLegend (WEB-118)', () => {
  it("adds up the stages' shares, old as soon as one is, at the default speed as soon as one is", () => {
    const legend = combinedWindLegend([
      weatherLeg(undefined, {
        windExposure: { head: 10_000, cross: 5_000, tail: 0 },
        speedIsDefault: false,
        averageSpeed: 30,
      }),
      weatherLeg(undefined, {
        status: WeatherStatus.STALE,
        windExposure: { head: 0, cross: 2_000, tail: 20_000 },
        speedIsDefault: true,
        averageSpeed: 25,
      }),
    ])
    expect(legend).toEqual({
      windExposure: { head: 10_000, cross: 7_000, tail: 20_000 },
      status: WeatherStatus.STALE,
      speedIsDefault: true,
      averageSpeed: 25,
    })
  })

  it('is none without a stage, fresh and at their own speed otherwise', () => {
    expect(combinedWindLegend([])).toBeUndefined()
    const legend = combinedWindLegend([
      weatherLeg(undefined, { speedIsDefault: false, averageSpeed: 22 }),
    ])
    expect(legend?.status).toBe(WeatherStatus.OK)
    expect(legend?.speedIsDefault).toBe(false)
    expect(legend?.averageSpeed).toBe(22)
  })
})
