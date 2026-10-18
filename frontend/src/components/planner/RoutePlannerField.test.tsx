import { useEffect, useState } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

const mounts = vi.fn()
const unmounts = vi.fn()
const onPointsChange = vi.fn()
/** The route objects the planner view received, one entry per render. */
const seenRoutes: unknown[] = []
/** Times the planner hook was mounted: it must stay above the view that moves. */
const hookMounts = vi.fn()

// One state object for the whole file, as the real hook returns one per component instance.
const plannerState = vi.hoisted(() => ({
  route: { points: [], dist: 0, ascend: 0 },
  controlPoints: [] as unknown[],
  routeGeoJson: null as { type: 'LineString'; coordinates: number[][] } | null,
  isLoading: false,
  error: null,
  routerProfile: 'BIKE',
  setRouterProfile: () => {},
  clearRoute: () => {},
  canUndo: false,
  canRedo: false,
  directStats: { total: 0, longest: 0, count: 0 },
  directMode: false,
  setDirectMode: () => {},
  routeLegsGeoJson: null,
  undo: () => {},
  redo: () => {},
}))

// The planner state is a plain object: no routing, no map. What is under test is where the view
// lives and that the state above it survives.
vi.mock('@/hooks/useRoutePlanner', () => ({
  useRoutePlanner: () => {
    useEffect(() => {
      hookMounts()
    }, [])
    return plannerState
  },
}))

vi.mock('@/hooks/useUnits', () => ({
  useUnits: () => ({
    distance: (m: number) => `${m / 1000} km`,
    elevation: (m: number) => `${m} m`,
  }),
}))

vi.mock('./RoutePlanner', () => ({
  RoutePlanner: ({
    planner,
    layout,
    active,
    onExpand,
  }: {
    planner: { route: unknown }
    layout: string
    active: boolean
    onExpand?: () => void
  }) => {
    const [taps, setTaps] = useState(0)
    seenRoutes.push(planner.route)
    useEffect(() => {
      mounts()
      return () => unmounts()
    }, [])
    return (
      <div data-testid="planner" data-layout={layout} data-active={String(active)}>
        <button onClick={() => setTaps((n) => n + 1)}>tap {taps}</button>
        {onExpand && <button onClick={onExpand}>expand</button>}
      </div>
    )
  },
}))

import { RoutePlannerField } from './RoutePlannerField'

function setCoarse(coarse: boolean) {
  window.matchMedia = vi.fn().mockImplementation((query: string) => ({
    matches: query.includes('pointer: coarse') ? coarse : false,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })) as unknown as typeof window.matchMedia
}

function renderField(props: Partial<React.ComponentProps<typeof RoutePlannerField>> = {}) {
  return render(
    <MantineProvider>
      <RoutePlannerField onPointsChange={onPointsChange} title="Ma sortie" {...props} />
    </MantineProvider>
  )
}

describe('RoutePlannerField', () => {
  beforeEach(() => {
    mounts.mockClear()
    hookMounts.mockClear()
    unmounts.mockClear()
    onPointsChange.mockClear()
    seenRoutes.length = 0
    plannerState.routeGeoJson = null
    plannerState.directStats = { total: 0, longest: 0, count: 0 }
  })
  afterEach(() => {
    cleanup()
    window.history.replaceState(null, '', '/')
  })

  it('reports an empty path to the form', () => {
    setCoarse(false)
    renderField()
    expect(onPointsChange).toHaveBeenCalledWith([])
  })

  it('reports the computed path to the form, as lng/lat points', () => {
    setCoarse(false)
    plannerState.routeGeoJson = {
      type: 'LineString',
      coordinates: [
        [2.35, 48.85, 30],
        [2.4, 48.9, 35],
      ],
    }
    renderField()
    expect(onPointsChange).toHaveBeenLastCalledWith([
      { lng: 2.35, lat: 48.85 },
      { lng: 2.4, lat: 48.9 },
    ])
  })

  it('warns about a long straight leg, and not about a short one', () => {
    setCoarse(false)
    plannerState.directStats = { total: 200, longest: 200, count: 1 }
    renderField()
    expect(screen.queryByText('planner.directWarning')).toBeNull()
    cleanup()

    plannerState.directStats = { total: 400, longest: 400, count: 1 }
    renderField()
    expect(screen.getByText('planner.directWarning')).toBeTruthy()
  })

  describe('with a mouse', () => {
    beforeEach(() => setCoarse(false))

    it('moves the same planner between the form and the dialog, state kept', async () => {
      renderField()
      const planner = await screen.findByTestId('planner')
      expect(planner.dataset.layout).toBe('inline')
      fireEvent.click(screen.getByText('tap 0'))
      expect(screen.getByText('tap 1')).toBeTruthy()

      fireEvent.click(screen.getByText('expand'))
      const dialog = await screen.findByRole('dialog')
      await waitFor(() => expect(dialog.contains(screen.getByTestId('planner'))).toBe(true))
      expect(screen.getByTestId('planner')).toBe(planner)
      expect(planner.dataset.layout).toBe('fullscreen')
      expect(screen.getByText('tap 1')).toBeTruthy()

      fireEvent.click(screen.getByRole('button', { name: 'planner.done' }))
      await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
      expect(screen.getByTestId('planner').dataset.layout).toBe('inline')
      expect(screen.getByText('tap 1')).toBeTruthy()
      expect(mounts).toHaveBeenCalledTimes(1)
      expect(unmounts).not.toHaveBeenCalled()
      // The planner state is mounted once: opening and closing recompute nothing (no routing).
      expect(hookMounts).toHaveBeenCalledTimes(1)
    })

    it('Escape does not close the fullscreen editor', async () => {
      renderField()
      fireEvent.click(await screen.findByText('expand'))
      await screen.findByRole('dialog')
      fireEvent.keyDown(document.body, { key: 'Escape' })
      fireEvent.keyDown(window, { key: 'Escape' })
      await new Promise((r) => setTimeout(r, 30))
      expect(screen.getByRole('dialog')).toBeTruthy()
    })

    it('tells the form while the editor is open, and the browser back closes it', async () => {
      const onFullscreenChange = vi.fn()
      renderField({ onFullscreenChange })
      fireEvent.click(await screen.findByText('expand'))
      await screen.findByRole('dialog')
      expect(onFullscreenChange).toHaveBeenLastCalledWith(true)

      act(() => window.history.back())
      await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
      expect(onFullscreenChange).toHaveBeenLastCalledWith(false)
    })
  })

  describe('with a finger', () => {
    beforeEach(() => setCoarse(true))

    it('shows a preview and builds no map until the editor is opened', async () => {
      renderField()
      expect(screen.queryByTestId('planner')).toBeNull()
      expect(mounts).not.toHaveBeenCalled()

      fireEvent.click(screen.getByRole('button', { name: 'planner.draw' }))
      const dialog = await screen.findByRole('dialog')
      const planner = await screen.findByTestId('planner')
      expect(dialog.contains(planner)).toBe(true)
      expect(planner.dataset.active).toBe('true')
      expect(screen.getByRole('button', { name: 'planner.done' })).toBeTruthy()
      expect(screen.getByRole('dialog', { name: 'Ma sortie' })).toBeTruthy()
    })

    it('keeps the planner mounted, off screen and inactive, after closing', async () => {
      renderField()
      fireEvent.click(screen.getByRole('button', { name: 'planner.draw' }))
      const planner = await screen.findByTestId('planner')
      fireEvent.click(screen.getByText('tap 0'))

      fireEvent.click(screen.getByRole('button', { name: 'planner.done' }))
      await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
      expect(document.body.contains(planner)).toBe(false)
      expect(planner.dataset.active).toBe('false')
      expect(unmounts).not.toHaveBeenCalled()

      fireEvent.click(screen.getByRole('button', { name: 'planner.draw' }))
      await screen.findByRole('dialog')
      expect(screen.getByTestId('planner')).toBe(planner)
      expect(screen.getByText('tap 1')).toBeTruthy()
      expect(mounts).toHaveBeenCalledTimes(1)
      expect(hookMounts).toHaveBeenCalledTimes(1)
    })

    it('opens on a gesture of the form, never on load', async () => {
      const { rerender } = renderField({ openRequest: 0 })
      expect(screen.queryByRole('dialog')).toBeNull()
      rerender(
        <MantineProvider>
          <RoutePlannerField onPointsChange={onPointsChange} openRequest={1} />
        </MantineProvider>
      )
      await screen.findByRole('dialog')
    })
  })
})
