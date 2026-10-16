import type { RideDto, RideWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'

/** Test data of a ride's weather, shared by the weather components' and the group page's tests. */

/** Non-breaking spaces (units, « : ») read as plain ones. */
export const plain = (s: string | null | undefined) => (s ?? '').replace(/[\u00a0\u202f]/g, ' ')

export const weatherRide = (overrides: Partial<RideDto> = {}): RideDto =>
  ({
    status: Status.PUBLISHED,
    finished: false,
    // A 6:40 meeting: the forecast's own hour (conditions.time) is the round 7:00.
    dateTime: '2026-10-08T06:40:00Z',
    registeredGroupId: 'g2',
    groups: [
      { id: 'g1', name: 'Rapide' },
      { id: 'g2', name: 'Cool' },
    ],
    ...overrides,
  }) as RideDto

export const conditions = {
  time: '2026-10-08T07:00:00Z',
  weatherCode: 0,
  condition: 'CLEAR' as const,
  daylight: true,
  temperature: 12,
  apparentTemperature: 10,
  precipitationProbability: 10,
  precipitation: 0,
  wind: { speed: 15, direction: 225, compass: 'SW' as const },
}

export const weatherLeg = (
  groupId: string | undefined,
  overrides: Partial<WeatherLegDto> = {}
): WeatherLegDto => ({
  groupId,
  status: WeatherStatus.OK,
  startTime: '2026-10-08T07:00:00Z',
  averageSpeed: 25,
  speedIsDefault: true,
  distance: 50_000,
  arrivalTime: '2026-10-08T09:00:00Z',
  checkpoints: [
    {
      index: 0,
      kind: 'START',
      distance: 0,
      time: '2026-10-08T07:00:00Z',
      weather: conditions,
      relativeWind: 'HEAD',
      headwind: 12,
      relativeWindAngle: 180,
    },
    {
      index: 1,
      kind: 'FINISH',
      distance: 50_000,
      time: '2026-10-08T09:00:00Z',
      weather: conditions,
      relativeWind: 'TAIL',
      headwind: -10,
      relativeWindAngle: 0,
    },
  ],
  segments: [{ fromDistance: 0, toDistance: 50_000, relativeWind: 'HEAD', headwind: 12 }],
  windExposure: { head: 50_000, cross: 0, tail: 0 },
  ...overrides,
})

export const okWeather: RideWeatherDto = {
  status: WeatherStatus.OK,
  fetchedAt: '2026-10-07T18:00:00Z',
  departure: { status: WeatherStatus.OK, conditions },
  legs: [weatherLeg('g1', { speedIsDefault: false, averageSpeed: 30 }), weatherLeg('g2')],
  attribution: { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' },
}

const ROUTE_START = Date.UTC(2026, 9, 18, 6, 30)
/** Passages every 30 minutes from 08:30 Paris time, a point every 15 km. */
const passage = (i: number) => new Date(ROUTE_START + i * 30 * 60_000).toISOString()
const ROUTE_TEMPERATURES = [8, 7, 9, 12, 16, 15, 14]
const ROUTE_RAIN = [0, 0, 13, 5, 13, 0, 3]
const ROUTE_GUSTS = [20, 25, 32, 22, 24, 21, 20]
const ROUTE_WIND = ['CROSS', 'HEAD', 'HEAD', 'CROSS', 'TAIL', 'TAIL', 'TAIL'] as const
const ROUTE_ANGLE = { HEAD: 180, CROSS: 90, TAIL: 0 } as const

/**
 * A 90 km leg in the shape of a real one: across, then face to km 45, across, then behind from
 * km 60 — seven points, rain peaking at 13 % twice, the warmest at 10:30, arriving 29 min before
 * sunset (`routeWeather`).
 */
export const routeLeg = (overrides: Partial<WeatherLegDto> = {}): WeatherLegDto => ({
  groupId: 'g2',
  status: WeatherStatus.OK,
  startTime: passage(0),
  averageSpeed: 30,
  speedIsDefault: false,
  distance: 90_000,
  arrivalTime: passage(6),
  checkpoints: ROUTE_TEMPERATURES.map((temperature, i) => ({
    index: i,
    kind: i === 0 ? 'START' : i === ROUTE_TEMPERATURES.length - 1 ? 'FINISH' : 'EN_ROUTE',
    distance: i * 15_000,
    time: passage(i),
    weather: {
      ...conditions,
      time: passage(i),
      condition: 'PARTLY_CLOUDY' as const,
      temperature,
      apparentTemperature: temperature - 2,
      precipitationProbability: ROUTE_RAIN[i],
      precipitation: 0,
      wind: { speed: 12 + i, gusts: ROUTE_GUSTS[i], direction: 0, compass: 'N' as const },
    },
    relativeWind: ROUTE_WIND[i],
    headwind: 0,
    relativeWindAngle: ROUTE_ANGLE[ROUTE_WIND[i]],
  })),
  segments: ROUTE_WIND.slice(0, -1).map((relativeWind, i) => ({
    fromDistance: i * 15_000,
    toDistance: (i + 1) * 15_000,
    relativeWind,
    headwind: 0,
  })),
  windExposure: { head: 30_000, cross: 30_000, tail: 30_000 },
  prevailingWind: { speed: 14, gusts: 32, direction: 0, compass: 'N' },
  ...overrides,
})

export const routeWeather: RideWeatherDto = {
  status: WeatherStatus.OK,
  fetchedAt: '2026-10-16T08:32:00Z',
  departure: {
    status: WeatherStatus.OK,
    conditions: { ...conditions, temperature: 8, apparentTemperature: 5 },
    sunrise: '2026-10-18T06:28:38Z',
    sunset: new Date(ROUTE_START + 6 * 30 * 60_000 + 29 * 60_000).toISOString(),
  },
  legs: [weatherLeg('g1'), routeLeg()],
  attribution: { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' },
}
