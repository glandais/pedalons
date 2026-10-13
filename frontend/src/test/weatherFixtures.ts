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
