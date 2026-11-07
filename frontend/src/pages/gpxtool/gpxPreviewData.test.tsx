import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, renderHook } from '@testing-library/react'
import { QueryClient } from '@tanstack/react-query'
import type { GpxPreviewDto, RideWeatherDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'

const api = vi.hoisted(() => ({
  useGetPreviewWeather: vi.fn(),
  prefetchGetPreviewQuery: vi.fn(),
  prefetchGetPreviewWeatherQuery: vi.fn(),
  refetch: vi.fn(),
  data: undefined as unknown,
}))

vi.mock('@/api/endpoints/gpx-previews/gpx-previews', () => ({
  useGetPreview: vi.fn(),
  getGetPreviewQueryKey: (id: string) => [`/api/gpx-previews/${id}`],
  prefetchGetPreviewQuery: api.prefetchGetPreviewQuery,
  prefetchGetPreviewWeatherQuery: api.prefetchGetPreviewWeatherQuery,
  useGetPreviewWeather: (id: string, options: unknown) => {
    api.useGetPreviewWeather(id, options)
    return { data: api.data, refetch: api.refetch }
  },
}))
vi.mock('@/api/endpoints/gps-services/gps-services', () => ({
  prefetchGetAvailableServicesQuery: vi.fn(),
}))
vi.mock('@/hooks/useElevationRefetchInterval', () => ({ useElevationRefetchInterval: () => false }))

import { prefetchGpxPreview, previewWindLeg, useGpxPreviewWeather } from './gpxPreviewData'
import { weatherLeg } from '@/test/weatherFixtures'

const dated = { id: 'p1', departureTime: '2026-11-08T08:30:00Z' } as GpxPreviewDto
const undated = { id: 'p2' } as GpxPreviewDto

type Options = {
  query: {
    enabled: boolean
    refetchInterval: (q: { state: { data?: Partial<RideWeatherDto> } }) => number | false
  }
}
const options = () => api.useGetPreviewWeather.mock.calls.at(-1)?.[1] as Options
const interval = (status?: WeatherStatus) =>
  options().query.refetchInterval({ state: { data: status ? { status } : undefined } })

beforeEach(() => {
  vi.useFakeTimers()
  api.data = undefined
})
afterEach(() => {
  cleanup()
  vi.useRealTimers()
  vi.clearAllMocks()
})

describe('useGpxPreviewWeather', () => {
  it('asks nothing without a departure date', () => {
    renderHook(() => useGpxPreviewWeather(undated))
    expect(options().query.enabled).toBe(false)
    renderHook(() => useGpxPreviewWeather(dated))
    expect(options().query.enabled).toBe(true)
  })

  it('asks again every 15 s while the cache is empty or the track partly there, and stops at OK', () => {
    renderHook(() => useGpxPreviewWeather(dated))
    expect(interval(WeatherStatus.UNAVAILABLE)).toBe(15_000)
    expect(interval(WeatherStatus.STALE)).toBe(15_000)
    expect(interval(WeatherStatus.OK)).toBe(false)
    expect(interval(WeatherStatus.NOT_YET_AVAILABLE)).toBe(false)
    expect(interval()).toBe(false)
  })

  it('gives up after 3 minutes, and a retry reopens the window', () => {
    api.data = { status: WeatherStatus.UNAVAILABLE }
    const { result } = renderHook(() => useGpxPreviewWeather(dated))
    expect(result.current.polling).toBe(true)
    act(() => {
      vi.advanceTimersByTime(3 * 60_000)
    })
    expect(interval(WeatherStatus.UNAVAILABLE)).toBe(false)
    expect(result.current.polling).toBe(false)
    act(() => result.current.retry())
    expect(api.refetch).toHaveBeenCalledTimes(1)
    expect(interval(WeatherStatus.UNAVAILABLE)).toBe(15_000)
    expect(result.current.polling).toBe(true)
  })

  it('shows no forecast once the date is gone, even if the cache still holds one', () => {
    api.data = { status: WeatherStatus.OK, legs: [weatherLeg(undefined)] }
    const { result } = renderHook(() => useGpxPreviewWeather(undated))
    expect(result.current.weather.data).toBeUndefined()
    expect(previewWindLeg(result.current.weather.data)).toBeUndefined()
    expect(result.current.polling).toBe(false)
    const withDate = renderHook(() => useGpxPreviewWeather(dated))
    expect(withDate.result.current.weather.data).toBeDefined()
  })

  it('does not call a stale forecast "polling": it already has something to show', () => {
    api.data = { status: WeatherStatus.STALE }
    const { result } = renderHook(() => useGpxPreviewWeather(dated))
    expect(result.current.polling).toBe(false)
  })
})

describe('previewWindLeg', () => {
  it('gives the single leg only when it has a forecast', () => {
    const leg = weatherLeg(undefined)
    expect(previewWindLeg({ legs: [leg] } as RideWeatherDto)).toBe(leg)
    expect(previewWindLeg({ legs: [] } as unknown as RideWeatherDto)).toBeUndefined()
    expect(
      previewWindLeg({
        legs: [weatherLeg(undefined, { status: WeatherStatus.NO_LOCATION })],
      } as RideWeatherDto)
    ).toBeUndefined()
    expect(previewWindLeg(undefined)).toBeUndefined()
  })
})

describe('prefetchGpxPreview', () => {
  const run = async (preview: GpxPreviewDto | undefined) => {
    const queryClient = new QueryClient()
    if (preview) queryClient.setQueryData([`/api/gpx-previews/${preview.id}`], preview)
    await prefetchGpxPreview(queryClient, preview?.id ?? 'p9')
  }

  it('reads the weather after the preview when it has a departure date', async () => {
    await run(dated)
    expect(api.prefetchGetPreviewWeatherQuery).toHaveBeenCalledWith(
      expect.anything(),
      'p1',
      expect.objectContaining({ request: { skipErrorToast: true } })
    )
  })

  it('reads no weather without a date, nor for a preview that could not be read', async () => {
    await run(undated)
    await run(undefined)
    expect(api.prefetchGetPreviewQuery).toHaveBeenCalledTimes(2)
    expect(api.prefetchGetPreviewWeatherQuery).not.toHaveBeenCalled()
  })
})
