import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { renderHook } from '@testing-library/react'
import type { MapRef } from 'react-map-gl/maplibre'
import { useMapChartZoomSync } from './useMapChartZoomSync'
import type { MappableRoute } from '../components/route/RouteMapView'

const route = {
  tracks: [
    {
      line: {
        type: 'LineString',
        coordinates: [
          [0, 0, 10, 0],
          [0.01, 0, 20, 1000],
          [0.02, 0, 30, 2000],
          [0.03, 0, 40, 3000],
        ],
      },
      climbs: [],
    },
  ],
  waypoints: [],
  distance: 3000,
} as unknown as MappableRoute

function setUp() {
  const { result } = renderHook(() => useMapChartZoomSync(route))
  const sync = result.current
  const fitBounds = vi.fn()
  sync.mapRef.current = {
    fitBounds,
    getBounds: () => ({
      getWest: () => 0.005,
      getEast: () => 0.025,
      getSouth: () => -1,
      getNorth: () => 1,
    }),
  } as unknown as MapRef
  const setXRange = vi.fn()
  sync.chartRef.current = { setXRange, resetXRange: vi.fn() }
  /** The eventData the last induced fitBounds carried, as MapLibre copies it onto moveend. */
  const inducedEvent = () => fitBounds.mock.calls.at(-1)?.[2] as object
  return { sync, fitBounds, setXRange, inducedEvent }
}

describe('useMapChartZoomSync', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('drives the chart from a user map move, edges clipped', () => {
    const { sync, setXRange } = setUp()
    sync.onMapMoveEnd({})
    expect(setXRange).toHaveBeenCalledWith(expect.closeTo(500), expect.closeTo(2500))
  })

  it('never feeds the move the chart induced back into the chart, however late it ends', () => {
    const { sync, setXRange, fitBounds, inducedEvent } = setUp()
    sync.onChartMoveStart()
    sync.onChartMoveComplete(1200, 1800)
    expect(fitBounds).toHaveBeenCalledOnce()

    vi.advanceTimersByTime(1000) // a slow frame: the old 400 ms timer would have let it through
    expect(sync.chartMoving.current).toBe(true)
    sync.onMapMoveEnd(inducedEvent())
    expect(setXRange).not.toHaveBeenCalled()
    expect(sync.chartMoving.current).toBe(false)
  })

  it('releases the guard only on the latest induced move', () => {
    const { sync, inducedEvent } = setUp()
    sync.onChartMoveStart()
    sync.onChartMoveComplete(0, 1500)
    const first = inducedEvent()
    sync.onChartMoveStart()
    sync.onChartMoveComplete(500, 2000)

    sync.onMapMoveEnd(first) // the interrupted animation ends first
    expect(sync.chartMoving.current).toBe(true)
    sync.onMapMoveEnd(inducedEvent())
    expect(sync.chartMoving.current).toBe(false)
  })

  it('still lets a user map move drive the chart while the induced move runs', () => {
    const { sync, setXRange } = setUp()
    sync.onChartMoveStart()
    sync.onChartMoveComplete(1200, 1800)
    sync.onMapMoveEnd({})
    expect(setXRange).toHaveBeenCalledOnce()
  })

  it('releases the guard on a timer when the induced move never ends', () => {
    const { sync } = setUp()
    sync.onChartMoveStart()
    sync.onChartMoveComplete(1200, 1800)
    vi.advanceTimersByTime(1500)
    expect(sync.chartMoving.current).toBe(false)
  })
})
