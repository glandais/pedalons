import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, cleanup, waitFor } from '@testing-library/react'
import { useEffect } from 'react'
import { MantineProvider } from '@mantine/core'
import type { MappableRoute } from './RouteMapView'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))
vi.mock('chartjs-plugin-zoom', () => ({ default: { id: 'zoom' } }))

// react-chartjs-2 reads `plugins` once, when it creates the chart: record what each mount got.
const mounts: string[][] = []
vi.mock('react-chartjs-2', () => ({
  Line: function Line({ plugins }: { plugins?: { id: string }[] }) {
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
    await waitFor(() => expect(mounts.at(-1)).toEqual(['crosshair', 'zoom']))
  })

  it('never loads the zoom plugin for a chart without zoom', async () => {
    renderChart()
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(mounts).toEqual([['crosshair']])
  })
})
