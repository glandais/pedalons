import { afterEach, describe, expect, it } from 'vitest'
import { act, cleanup, render, screen } from '@testing-library/react'
import { createBrowserRouter, RouterProvider, useSearchParams } from 'react-router-dom'
import type { ViewStateChangeEvent } from 'react-map-gl/maplibre'
import { useMapViewParam } from './useMapViewParam'

let moveEnd: ((event: ViewStateChangeEvent) => void) | null = null

function MapPage() {
  const { initialView, onMoveEnd } = useMapViewParam()
  const [, setSearchParams] = useSearchParams()
  moveEnd = onMoveEnd
  return (
    <div>
      <span data-testid="initial">{initialView ? JSON.stringify(initialView) : 'none'}</span>
      <button
        data-testid="filter"
        onClick={() => setSearchParams({ distance: '50' }, { replace: true })}
      />
    </div>
  )
}

function renderAt(url: string) {
  window.history.replaceState(null, '', url)
  const router = createBrowserRouter([{ path: '/parcours/carte', element: <MapPage /> }])
  render(<RouterProvider router={router} />)
}

const move = (zoom: number, latitude: number, longitude: number) =>
  act(() => moveEnd!({ viewState: { zoom, latitude, longitude } } as ViewStateChangeEvent))

afterEach(() => {
  cleanup()
  moveEnd = null
})

describe('useMapViewParam', () => {
  it('opens on the camera the URL names', () => {
    renderAt('/parcours/carte?map=12/45.1885/5.7245')
    expect(JSON.parse(screen.getByTestId('initial').textContent!)).toEqual({
      zoom: 12,
      latitude: 45.1885,
      longitude: 5.7245,
    })
  })

  it('ignores a malformed camera', () => {
    renderAt('/parcours/carte?map=nowhere')
    expect(screen.getByTestId('initial').textContent).toBe('none')
  })

  it('writes the camera on the current entry, keeping the other parameters', () => {
    renderAt('/parcours/carte?distance=20')
    const length = window.history.length
    move(10, 45.18853, 5.72452)
    expect(window.location.search).toBe('?distance=20&map=10/45.189/5.725')
    move(11, 45.2, 5.7)
    expect(window.history.length).toBe(length)
  })

  it('puts the camera back after a router navigation drops it', async () => {
    renderAt('/parcours/carte')
    move(10, 45.18853, 5.72452)
    await act(async () => screen.getByTestId('filter').click())
    expect(new URLSearchParams(window.location.search).get('map')).toBe('10/45.189/5.725')
    expect(new URLSearchParams(window.location.search).get('distance')).toBe('50')
  })
})
