import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { MappableRoute } from './RouteMapView'

// The map and its layers as plain DOM: what matters here is which markers the track carries.
vi.mock('react-map-gl/maplibre', () => ({
  Source: ({ children }: { children?: React.ReactNode }) => <>{children}</>,
  Layer: () => null,
}))
vi.mock('../map/PedalonsMap', () => ({
  PedalonsMap: ({ children }: { children?: React.ReactNode }) => <div>{children}</div>,
}))
vi.mock('@/hooks/useMapStyle', () => ({ useMapStyle: () => ({ darkBasemap: false }) }))
vi.mock('../map/HideTrackControl', () => ({ HideTrackControl: () => null }))
vi.mock('../map/WaypointLayer', () => ({ WAYPOINT_HIT_LAYER: 'hit', WaypointLayer: () => null }))
vi.mock('../map/MapMarkers', () => ({
  StartMarker: () => null,
  EndMarker: () => null,
  HoverMarker: () => null,
  KmMarkersLayer: () => <span data-testid="km-markers" />,
}))

import { RouteTrackMap } from './RouteTrackMap'

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

function show(props: Partial<Parameters<typeof RouteTrackMap>[0]> = {}) {
  return render(
    <MantineProvider>
      <RouteTrackMap
        route={ROUTE}
        mapRef={{ current: null }}
        hoveredPointIndex={-1}
        onHoverPoint={() => {}}
        {...props}
      />
    </MantineProvider>
  )
}

describe('RouteTrackMap', () => {
  afterEach(cleanup)

  it('shows the km markers by default', () => {
    show()
    expect(screen.getByTestId('km-markers')).toBeTruthy()
  })

  it('hides the km markers when asked, drawing the caller overlays (WEB-116)', () => {
    show({ kmMarkers: false, overlays: <span data-testid="overlay" /> })
    expect(screen.queryByTestId('km-markers')).toBeNull()
    expect(screen.getByTestId('overlay')).toBeTruthy()
  })
})
