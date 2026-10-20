import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, cleanup, waitFor } from '@testing-library/react'
import { useEffect } from 'react'
import { MantineProvider } from '@mantine/core'
import type { WaypointDto } from '@/api/dto'
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
    await waitFor(() => expect(mounts.at(-1)).toEqual(['crosshair', 'waypointMarkers', 'zoom']))
  })

  it('never loads the zoom plugin for a chart without zoom', async () => {
    renderChart()
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(mounts).toEqual([['crosshair', 'waypointMarkers']])
  })

  it('colours the segments by surface when asked, and by grade otherwise', async () => {
    const surfaceAt = (i: number) => (i === 0 ? '#aa0000' : '#00aa00')
    const segmentColor = () => {
      const datasets = lastData.value?.datasets as {
        segment: { borderColor: (ctx: { p0DataIndex: number }) => string }
      }[]
      return datasets[0].segment.borderColor({ p0DataIndex: 0 })
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
})
