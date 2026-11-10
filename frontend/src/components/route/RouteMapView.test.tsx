import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { MappableRoute } from './RouteMapView'

// The map and the chart as plain DOM: what matters is the inset the map is handed and the
// profile's own height (docs/LEDGER_*.md WEB-157).
vi.mock('./RouteTrackMap', () => ({
  RouteTrackMap: ({
    bottomInset,
    children,
  }: {
    bottomInset?: string
    children?: React.ReactNode
  }) => (
    <div data-testid="track-map" data-bottom-inset={bottomInset ?? ''}>
      {children}
    </div>
  ),
}))
vi.mock('@/hooks/useRouteSurfaceColors', () => ({
  useRouteSurfaceColors: () => ({ surfaceAt: undefined, lineColorAt: undefined }),
}))
vi.mock('./ElevationChart', () => ({
  ElevationChart: () => <span data-testid="profile" />,
}))

import { RouteMapView } from './RouteMapView'

const ROUTE = {
  waypoints: [],
  distance: 20_000,
  tracks: [
    {
      line: {
        type: 'LineString',
        coordinates: [
          [5, 45, 300, 0],
          [5, 45.18, 300, 20_000],
        ],
      },
      climbs: [],
    },
  ],
} as unknown as MappableRoute

function show(profilePlacement?: 'below' | 'overlay') {
  return render(
    <MantineProvider>
      <RouteMapView route={ROUTE} profilePlacement={profilePlacement} />
    </MantineProvider>
  )
}

describe('RouteMapView bottom inset (WEB-157)', () => {
  afterEach(cleanup)

  it('lifts the bottom line by the height of a profile laid over the map', () => {
    show('overlay')
    const map = screen.getByTestId('track-map')
    expect(map.dataset.bottomInset).toBe('clamp(110px, 38%, 200px)')
    // One expression for both: the profile's box is as tall as the inset
    const profileBox = screen.getByTestId('profile').parentElement!
    expect(map.contains(profileBox)).toBe(true)
    expect(profileBox.style.height).toBe(map.dataset.bottomInset)
  })

  it('lifts nothing when the profile sits under the map', () => {
    show('below')
    expect(screen.getByTestId('track-map').dataset.bottomInset).toBe('')
  })
})
