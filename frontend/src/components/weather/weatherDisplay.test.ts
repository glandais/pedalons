import { describe, expect, it } from 'vitest'
import { IconCloud, IconCloudRain, IconMoon, IconSun } from '@tabler/icons-react'
import { WeatherCondition, WeatherStatus } from '@/api/dto'
import type { RideWeatherSummaryDto, WindSegmentDto } from '@/api/dto'
import {
  exposureSections,
  hasForecast,
  relativeWindColor,
  showsDetailBlock,
  showsSummary,
  temperatureRange,
  weatherIcon,
  windArrowRotation,
} from './weatherDisplay'

describe('weatherIcon', () => {
  it('draws the sun by day and the moon by night for a clear sky', () => {
    expect(weatherIcon(WeatherCondition.CLEAR, true)).toBe(IconSun)
    expect(weatherIcon(WeatherCondition.CLEAR, false)).toBe(IconMoon)
  })

  it('keeps the rain icon whatever the hour', () => {
    expect(weatherIcon(WeatherCondition.RAIN, true)).toBe(IconCloudRain)
    expect(weatherIcon(WeatherCondition.RAIN, false)).toBe(IconCloudRain)
  })

  it('falls back to a plain cloud for a condition this build does not know', () => {
    expect(weatherIcon('VOLCANIC_ASH', true)).toBe(IconCloud)
    expect(weatherIcon(undefined)).toBe(IconCloud)
  })

  it('has an icon for every condition of the contract', () => {
    for (const condition of Object.values(WeatherCondition)) {
      expect(weatherIcon(condition, true)).toBeTruthy()
      expect(weatherIcon(condition, false)).toBeTruthy()
    }
  })

  it('does not take an inherited property for a condition', () => {
    expect(weatherIcon('toString')).toBe(IconCloud)
  })
})

describe('statuses', () => {
  it('shows a forecast for OK and STALE only', () => {
    expect(hasForecast(WeatherStatus.OK)).toBe(true)
    expect(hasForecast(WeatherStatus.STALE)).toBe(true)
    expect(hasForecast(WeatherStatus.NOT_YET_AVAILABLE)).toBe(false)
    expect(hasForecast(WeatherStatus.UNAVAILABLE)).toBe(false)
  })

  it('hides OUT_OF_RANGE and unknown statuses, NO_LOCATION but for organisers', () => {
    expect(showsDetailBlock(WeatherStatus.OUT_OF_RANGE, true)).toBe(false)
    expect(showsDetailBlock('SOMETHING_NEW', true)).toBe(false)
    expect(showsDetailBlock(WeatherStatus.NO_LOCATION, false)).toBe(false)
    expect(showsDetailBlock(WeatherStatus.NO_LOCATION, true)).toBe(true)
    expect(showsDetailBlock(WeatherStatus.UNAVAILABLE, false)).toBe(true)
    expect(showsDetailBlock(WeatherStatus.NOT_YET_AVAILABLE, false)).toBe(true)
  })

  it('says nothing on a card without summary, or before the forecast opens without its date', () => {
    expect(showsSummary(undefined)).toBe(false)
    expect(showsSummary({ status: WeatherStatus.NOT_YET_AVAILABLE })).toBe(false)
    expect(
      showsSummary({
        status: WeatherStatus.NOT_YET_AVAILABLE,
        availableFrom: '2026-10-10T07:00:00Z',
      })
    ).toBe(true)
    expect(showsSummary({ status: WeatherStatus.OK })).toBe(true)
    expect(showsSummary({ status: 'SOMETHING_NEW' as WeatherStatus })).toBe(false)
  })
})

describe('temperatureRange', () => {
  const summary = (overrides: Partial<RideWeatherSummaryDto>): RideWeatherSummaryDto => ({
    status: WeatherStatus.OK,
    ...overrides,
  })

  it('reads min → max over the window', () => {
    expect(
      temperatureRange(summary({ temperature: 9, temperatureMin: 8, temperatureMax: 14 }))
    ).toEqual({ min: 8, max: 14 })
  })

  it('falls back to the departure temperature', () => {
    expect(temperatureRange(summary({ temperature: 11 }))).toEqual({ min: 11, max: 11 })
  })

  it('has nothing to say without any temperature', () => {
    expect(temperatureRange(summary({}))).toBeUndefined()
  })
})

describe('windArrowRotation', () => {
  it('points ahead with the wind in the back and back at the rider with it in the face', () => {
    expect(windArrowRotation(0)).toBe(0)
    expect(windArrowRotation(180)).toBe(180)
  })

  it('normalises any angle into 0–360', () => {
    expect(windArrowRotation(-90)).toBe(270)
    expect(windArrowRotation(450)).toBe(90)
  })
})

describe('relative wind and exposure', () => {
  it('takes the generated colour families, gray for an unknown kind', () => {
    expect(relativeWindColor('TAIL')).toBe('teal')
    expect(relativeWindColor('CROSS')).toBe('gray')
    expect(relativeWindColor('HEAD')).toBe('orange')
    expect(relativeWindColor('SIDEWAYS')).toBe('gray')
  })

  it('splits the route into shares, in route order, dropping unknown and empty stretches', () => {
    const segments = [
      { fromDistance: 0, toDistance: 25_000, relativeWind: 'HEAD', headwind: 10 },
      { fromDistance: 25_000, toDistance: 25_000, relativeWind: 'CROSS', headwind: 0 },
      { fromDistance: 25_000, toDistance: 50_000, relativeWind: 'SIDEWAYS', headwind: 0 },
      { fromDistance: 50_000, toDistance: 100_000, relativeWind: 'TAIL', headwind: -8 },
    ] as WindSegmentDto[]

    expect(exposureSections(segments, 100_000)).toEqual([
      { relativeWind: 'HEAD', fromDistance: 0, toDistance: 25_000, percent: 25 },
      { relativeWind: 'TAIL', fromDistance: 50_000, toDistance: 100_000, percent: 50 },
    ])
  })

  it('draws nothing for a leg of no length', () => {
    expect(exposureSections([], 0)).toEqual([])
  })
})
