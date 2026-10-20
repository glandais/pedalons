import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

const map = vi.hoisted(() => {
  const listeners: Array<() => void> = []
  return {
    zoom: 9,
    listeners,
    getZoom() {
      return this.zoom
    },
    on(_: string, fn: () => void) {
      listeners.push(fn)
    },
    off(_: string, fn: () => void) {
      listeners.splice(listeners.indexOf(fn), 1)
    },
    zoomTo(zoom: number) {
      this.zoom = zoom
      for (const fn of [...listeners]) fn()
    },
  }
})

vi.mock('react-map-gl/maplibre', () => ({
  Marker: ({ children }: { children?: React.ReactNode }) => <div>{children}</div>,
  useMap: () => ({ current: { getZoom: () => map.getZoom(), getMap: () => map } }),
}))

import { WAYPOINT_LABEL_MIN_ZOOM, WaypointMarker } from './MapMarkers'

function renderMarker(name?: string) {
  render(
    <MantineProvider>
      <WaypointMarker longitude={3.2} latitude={50.6} name={name} />
    </MantineProvider>
  )
}

describe('WaypointMarker', () => {
  afterEach(() => {
    cleanup()
    map.zoom = 9
  })

  it('keeps the label out of the flow, so the marker centres the dot alone on the point', () => {
    map.zoom = WAYPOINT_LABEL_MIN_ZOOM
    renderMarker('Secteur de Willems à Hem')
    const dot = screen.getByTestId('waypoint-dot')
    const label = screen.getByText('Secteur de Willems à Hem')
    expect(dot.contains(label)).toBe(true)
    expect(label.style.position).toBe('absolute')
  })

  it('hides the name when zoomed out, shows it on hover or tap', () => {
    renderMarker('Secteur de Willems à Hem')
    expect(screen.queryByText('Secteur de Willems à Hem')).toBeNull()

    fireEvent.mouseEnter(screen.getByTestId('waypoint-dot'))
    expect(screen.getByText('Secteur de Willems à Hem')).toBeTruthy()
    fireEvent.mouseLeave(screen.getByTestId('waypoint-dot'))
    expect(screen.queryByText('Secteur de Willems à Hem')).toBeNull()

    // A tap emulates mouseenter then click: the click must not close what the enter opened
    fireEvent.mouseEnter(screen.getByTestId('waypoint-dot'))
    fireEvent.click(screen.getByTestId('waypoint-dot'))
    expect(screen.getByText('Secteur de Willems à Hem')).toBeTruthy()
  })

  it('shows the name once the map is zoomed in, and hides it again when zoomed out', () => {
    renderMarker('Secteur de Willems à Hem')
    act(() => map.zoomTo(WAYPOINT_LABEL_MIN_ZOOM))
    expect(screen.getByText('Secteur de Willems à Hem')).toBeTruthy()
    act(() => map.zoomTo(WAYPOINT_LABEL_MIN_ZOOM - 0.5))
    expect(screen.queryByText('Secteur de Willems à Hem')).toBeNull()
  })
})
