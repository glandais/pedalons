import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, cleanup, waitFor } from '@testing-library/react'
import { useEffect } from 'react'
import { MantineProvider } from '@mantine/core'
import { RelativeWind, type WaypointDto } from '@/api/dto'
import { NEUTRAL_COLOR } from '../map/mapUtils'
import type { MappableRoute } from './RouteMapView'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))
vi.mock('chartjs-plugin-zoom', () => ({ default: { id: 'zoom' } }))

// react-chartjs-2 reads `plugins` once, when it creates the chart: record what each mount got.
const mounts: string[][] = []
const lastData = vi.hoisted(() => ({ value: null as null | Record<string, unknown> }))
const lastOptions = vi.hoisted(() => ({ value: null as null | Record<string, unknown> }))
vi.mock('react-chartjs-2', () => ({
  Line: function Line({
    plugins,
    data,
    options,
  }: {
    plugins?: { id: string }[]
    data?: Record<string, unknown>
    options?: Record<string, unknown>
  }) {
    lastData.value = data ?? null
    lastOptions.value = options ?? null
    useEffect(() => {
      mounts.push((plugins ?? []).map((p) => p.id))
      // eslint-disable-next-line react-hooks/exhaustive-deps -- mount only, like react-chartjs-2
    }, [])
    return null
  },
}))

import { ElevationChart } from './ElevationChart'

const route = {
  tracks: [
    {
      line: {
        type: 'LineString',
        coordinates: [
          [0, 0, 10, 0],
          [0.01, 0, 20, 1000],
        ],
      },
      climbs: [],
    },
  ],
  waypoints: [],
  distance: 1000,
} as unknown as MappableRoute

function renderChart(zoom?: { onMoveStart: () => void; onMoveComplete: () => void }) {
  render(
    <MantineProvider>
      <ElevationChart route={route} hoveredPointIndex={-1} onHoverPoint={() => {}} zoom={zoom} />
    </MantineProvider>
  )
}

describe('ElevationChart', () => {
  afterEach(() => {
    cleanup()
    mounts.length = 0
  })

  it('creates the chart with the zoom plugin once it has loaded', async () => {
    renderChart({ onMoveStart: vi.fn(), onMoveComplete: vi.fn() })
    await waitFor(() =>
      expect(mounts.at(-1)).toEqual(['crosshair', 'waypointMarkers', 'windBand', 'zoom'])
    )
  })

  it('never loads the zoom plugin for a chart without zoom', async () => {
    renderChart()
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(mounts).toEqual([['crosshair', 'waypointMarkers', 'windBand']])
  })

  it('colours the segments by surface when asked, and by grade otherwise', async () => {
    const surfaceAt = (i: number) => (i === 0 ? '#aa0000' : '#00aa00')
    const segmentColor = () => {
      // Before the first layout there is no axis to build the gradient on: the first colour.
      const datasets = lastData.value?.datasets as {
        borderColor: (ctx: { chart: Record<string, unknown> }) => string
      }[]
      return datasets[0].borderColor({ chart: {} })
    }
    render(
      <MantineProvider>
        <ElevationChart
          route={route}
          hoveredPointIndex={-1}
          onHoverPoint={() => {}}
          colorBy="surface"
          surfaceAt={surfaceAt}
        />
      </MantineProvider>
    )
    await waitFor(() => expect(lastData.value).not.toBeNull())
    expect(segmentColor()).toBe('#aa0000')
    cleanup()
    lastData.value = null
    render(
      <MantineProvider>
        <ElevationChart
          route={route}
          hoveredPointIndex={-1}
          onHoverPoint={() => {}}
          surfaceAt={surfaceAt}
        />
      </MantineProvider>
    )
    await waitFor(() => expect(lastData.value).not.toBeNull())
    expect(segmentColor()).not.toBe('#aa0000')
  })

  it('puts only the waypoints on the track on the profile', async () => {
    const wp = (name: string, distance?: number) =>
      ({
        name,
        type: 'WATER',
        origin: 'AUTHOR',
        distance,
        geometry: { type: 'Point', coordinates: [0, 0] },
      }) as unknown as WaypointDto
    const withWaypoints = {
      ...route,
      waypoints: [wp('Fontaine', 500), wp('Loin'), wp('Début', 0)],
    } as MappableRoute
    render(
      <MantineProvider>
        <ElevationChart route={withWaypoints} hoveredPointIndex={-1} onHoverPoint={() => {}} />
      </MantineProvider>
    )
    await waitFor(() => expect(lastOptions.value).not.toBeNull())
    const plugins = lastOptions.value?.plugins as {
      waypointMarkers: { markers: WaypointDto[] }
    }
    expect(plugins.waypointMarkers.markers.map((w) => w.name)).toEqual(['Début', 'Fontaine'])
  })

  describe('the wind band (WEB-129)', () => {
    const colors = {
      [RelativeWind.TAIL]: '#tail',
      [RelativeWind.CROSS]: '#cross',
      [RelativeWind.HEAD]: '#head',
    }
    // Two tracks whose own distance restarts at 0 (ledger WEB-81): 0 → 1 km, then 0 → 1 km
    const twoTracks = {
      tracks: [
        {
          line: {
            type: 'LineString',
            coordinates: [
              [0, 0, 10, 0],
              [0.005, 0, 15, 500],
              [0.01, 0, 20, 1000],
            ],
          },
          climbs: [],
        },
        {
          line: {
            type: 'LineString',
            coordinates: [
              [0.02, 0, 20, 0],
              [0.03, 0, 30, 1000],
            ],
          },
          climbs: [],
        },
      ],
      waypoints: [],
      distance: 2000,
    } as unknown as MappableRoute

    type Options = {
      plugins: {
        windBand: { runs: { from: number; to: number; color: string }[] }
        tooltip: {
          callbacks: { afterLabel: (item: { dataIndex: number }) => string[] }
        }
      }
      scales: { x: { ticks: { padding?: number }; grid: { drawTicks?: boolean } } }
    }
    const options = () => lastOptions.value as unknown as Options

    function renderWind(wind?: Parameters<typeof ElevationChart>[0]['wind']) {
      render(
        <MantineProvider>
          <ElevationChart
            route={twoTracks}
            hoveredPointIndex={-1}
            onHoverPoint={() => {}}
            wind={wind}
          />
        </MantineProvider>
      )
    }

    it('lays the band on the points of each track, never across two, the unknown in the neutral blue', async () => {
      renderWind({
        // Flat, as the profile indexes them: head, then unknown, on the first track; tail on the second
        winds: [RelativeWind.HEAD, undefined, undefined, RelativeWind.TAIL, RelativeWind.TAIL],
        colors,
      })
      await waitFor(() => expect(lastOptions.value).not.toBeNull())
      expect(options().plugins.windBand.runs).toEqual([
        { from: 0, to: 500, color: '#head' },
        { from: 500, to: 1000, color: NEUTRAL_COLOR },
        // The second track at its own points, where the profile draws them
        { from: 0, to: 1000, color: '#tail' },
      ])
      // Room for it between the plot and the axis labels
      expect(options().scales.x.ticks.padding).toBeGreaterThan(0)
      expect(options().scales.x.grid.drawTicks).toBe(false)
    })

    it("says the point's wind in the tooltip, and « Vent inconnu » where none is known", async () => {
      renderWind({
        winds: [RelativeWind.HEAD, undefined, undefined, RelativeWind.TAIL, RelativeWind.TAIL],
        colors,
      })
      await waitFor(() => expect(lastOptions.value).not.toBeNull())
      const afterLabel = options().plugins.tooltip.callbacks.afterLabel
      expect(afterLabel({ dataIndex: 0 })).toEqual(['rides.weather.relativeWind.HEAD'])
      expect(afterLabel({ dataIndex: 1 })).toEqual(['rides.weather.relativeWindUnknown'])
      expect(afterLabel({ dataIndex: 3 })).toEqual(['rides.weather.relativeWind.TAIL'])
    })

    it('draws no band and says no wind outside the Météo mode', async () => {
      renderWind()
      await waitFor(() => expect(lastOptions.value).not.toBeNull())
      expect(options().plugins.windBand.runs).toEqual([])
      expect(options().plugins.tooltip.callbacks.afterLabel({ dataIndex: 0 })).toEqual([])
      expect(options().scales.x.ticks.padding).toBeUndefined()
    })
  })
})
