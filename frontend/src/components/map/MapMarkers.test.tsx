import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { kmMarkerRank } from './mapUtils'

const mapHandle = vi.hoisted(() => ({ current: undefined as unknown }))

vi.mock('react-map-gl/maplibre', () => ({
  useMap: () => ({ current: mapHandle.current }),
  Marker: ({ children }: { children?: React.ReactNode }) => <div>{children}</div>,
}))

import { KmMarkersLayer } from './MapMarkers'

/** 200 km plein nord. */
const COORDS = Array.from({ length: 201 }, (_, i) => [5, 45 + i * 0.009, 0, i * 1000])

/** A map where `pixels` separate two km of the route. */
const mapOf = (pixelsPerKm: number) => {
  const map = {
    project: ([, latitude]: [number, number]) => ({
      x: 0,
      y: ((latitude - 45) / 0.009) * pixelsPerKm,
    }),
    on: vi.fn(),
    off: vi.fn(),
  }
  return { getMap: () => map }
}

const labels = () => screen.queryAllByText(/^\d+$/).map((label) => Number(label.textContent))

function show(pixelsPerKm?: number) {
  mapHandle.current = pixelsPerKm === undefined ? undefined : mapOf(pixelsPerKm)
  return render(
    <MantineProvider>
      <KmMarkersLayer coords={COORDS} totalDistanceM={200_500} />
    </MantineProvider>
  )
}

describe('KmMarkersLayer (WEB-144)', () => {
  afterEach(() => {
    cleanup()
    mapHandle.current = undefined
  })

  it('shows every marker that has its room', () => {
    show(3)
    expect(labels()).toHaveLength(20)
  })

  it('keeps the roundest distances when they would touch', () => {
    show(0.6)
    expect(labels()).toEqual([50, 100, 150, 200])
  })

  it('shows them all outside a map, with nothing to measure', () => {
    show()
    expect(labels()).toHaveLength(20)
  })
})

describe('kmMarkerRank', () => {
  it('puts the roundest distances first', () => {
    expect([100, 50, 150, 20, 10, 5, 2, 1, 7].map(kmMarkerRank)).toEqual([
      0, 1, 1, 2, 3, 4, 5, 6, 6,
    ])
  })
})
