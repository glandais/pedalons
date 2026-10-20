import { createRef, useEffect, useState } from 'react'
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
const hookOptions = vi.hoisted(() => ({ last: undefined as unknown }))
const snapshotMock = vi.hoisted(() => vi.fn())
const importGpxMock = vi.hoisted(() => vi.fn())
const notificationShow = vi.hoisted(() => vi.fn())
const undoMock = vi.hoisted(() => vi.fn())
const waypointOps = vi.hoisted(() => ({
  addWaypoint: vi.fn((..._args: unknown[]): string | null => 'w-new'),
  updateWaypoint: vi.fn((..._args: unknown[]) => true),
  moveWaypoint: vi.fn(),
  removeWaypoint: vi.fn(),
}))

vi.mock('@mantine/notifications', () => ({
  notifications: { show: notificationShow, hide: vi.fn() },
}))

const plannerState = vi.hoisted(() => ({
  snapshot: () => snapshotMock(),
  isDirty: false,
  route: { points: [], dist: 0, ascend: 0 },
  controlPoints: [] as unknown[],
  routeGeoJson: null as { type: 'LineString'; coordinates: number[][] } | null,
  isLoading: false,
  error: null,
  routerProfile: 'BIKE',
  setRouterProfile: () => {},
  routerTuning: {},
  setRouterTuning: () => {},
  resetRouterTuning: () => {},
  clearRoute: () => {},
  waypoints: [] as unknown[],
  placedWaypoints: [] as unknown[],
  addWaypoint: (...args: unknown[]) => waypointOps.addWaypoint(...args),
  updateWaypoint: (...args: unknown[]) => waypointOps.updateWaypoint(...args),
  moveWaypoint: (...args: unknown[]) => waypointOps.moveWaypoint(...args),
  removeWaypoint: (...args: unknown[]) => waypointOps.removeWaypoint(...args),
  importGpx: (file: File, mode: string) => importGpxMock(file, mode),
  canUndo: false,
  canRedo: false,
  directStats: { total: 0, longest: 0, count: 0 },
  directMode: false,
  setDirectMode: () => {},
  routeLegsGeoJson: null,
  undo: () => undoMock(),
  redo: () => {},
}))

// The planner state is a plain object: no routing, no map. What is under test is where the view
// lives and that the state above it survives.
vi.mock('@/hooks/useRoutePlanner', () => ({
  useRoutePlanner: (options: unknown) => {
    hookOptions.last = options
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
    onImport,
    hoverPosition,
    onHoverIndex,
    onWaypointAdd,
  }: {
    planner: { route: unknown }
    layout: string
    active: boolean
    onExpand?: () => void
    onImport?: () => void
    hoverPosition?: { lng: number; lat: number } | null
    onHoverIndex?: (index: number) => void
    onWaypointAdd?: (at: { lng: number; lat: number; distance: number }) => void
  }) => {
    const [taps, setTaps] = useState(0)
    seenRoutes.push(planner.route)
    useEffect(() => {
      mounts()
      return () => unmounts()
    }, [])
    return (
      <div
        data-testid="planner"
        data-layout={layout}
        data-active={String(active)}
        data-hover-position={hoverPosition ? `${hoverPosition.lng},${hoverPosition.lat}` : ''}
      >
        <button onClick={() => onHoverIndex?.(1)}>map hover</button>
        <button onClick={() => setTaps((n) => n + 1)}>tap {taps}</button>
        {onExpand && <button onClick={onExpand}>expand</button>}
        {onImport && <button onClick={onImport}>map import</button>}
        <button onClick={() => onWaypointAdd?.({ lng: 5.001, lat: 45, distance: 80 })}>
          map add waypoint
        </button>
      </div>
    )
  },
}))

// The chart needs a canvas: the strip is replaced by a stub that exposes what the field gives it.
vi.mock('./PlannerElevationStrip', () => ({
  PlannerElevationStrip: ({
    hoveredIndex,
    onHoverIndex,
    collapsible,
    mappable,
    onSelectWaypoint,
  }: {
    hoveredIndex: number
    onHoverIndex: (index: number) => void
    collapsible?: { collapsed: boolean; onToggle: () => void }
    mappable?: { waypoints: unknown[] } | null
    onSelectWaypoint?: (waypoint: unknown) => void
  }) => (
    <div
      data-testid="strip"
      data-hovered={hoveredIndex}
      data-collapsed={String(collapsible?.collapsed)}
    >
      <button onClick={() => onHoverIndex(1)}>profile hover</button>
      <button onClick={() => onSelectWaypoint?.(mappable?.waypoints[0])}>profile waypoint</button>
      {collapsible && <button onClick={collapsible.onToggle}>toggle strip</button>}
    </div>
  ),
}))

import { computeRoute, createPoint, edgeKey } from '@/lib/planner'
import { RoutePlannerField, type RoutePlannerHandle } from './RoutePlannerField'

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
    plannerState.route = { points: [], dist: 0, ascend: 0 }
    plannerState.waypoints = []
    plannerState.placedWaypoints = []
    Object.values(waypointOps).forEach((op) => op.mockReset())
    undoMock.mockReset()
    importGpxMock.mockReset()
    notificationShow.mockClear()
    localStorage.clear()
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

  it('gives the hook the saved state, and the form the snapshot of the planner on demand', () => {
    setCoarse(false)
    const state = { version: 1 } as never
    const snapshot = { dirty: true, plannerState: null, points: [] }
    snapshotMock.mockReturnValue(snapshot)
    const ref = createRef<RoutePlannerHandle>()
    renderField({ initialState: state, plannerRef: ref, initialTrack: [[1, 2, 3]] })
    expect(hookOptions.last).toMatchObject({ initialState: state, initialTrack: [[1, 2, 3]] })
    // Taken at the call, not while drawing
    expect(snapshotMock).not.toHaveBeenCalled()
    expect(ref.current!.snapshot()).toBe(snapshot)
    expect(snapshotMock).toHaveBeenCalledTimes(1)
  })

  it('tells the form a calculation is in flight, and that it is over once unmounted', () => {
    setCoarse(false)
    const onBusyChange = vi.fn()
    plannerState.isLoading = true
    try {
      const { unmount } = renderField({ onBusyChange })
      expect(onBusyChange).toHaveBeenLastCalledWith(true)
      // A form that leaves the planner tab must not stay locked
      unmount()
      expect(onBusyChange).toHaveBeenLastCalledWith(false)
    } finally {
      plannerState.isLoading = false
    }
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

  describe('GPX import', () => {
    const gpx = () => new File(['<gpx/>'], 'sortie.gpx', { type: 'application/gpx+xml' })
    const info = (over = {}) => ({
      name: 'Boucle',
      droppedWaypoints: 0,
      elevationFallback: false,
      mode: 'replace',
      ...over,
    })
    function choose(file: File) {
      fireEvent.change(screen.getByTestId('planner-import-input'), { target: { files: [file] } })
    }
    function routeOfTwoPoints() {
      plannerState.route = { points: [{}, {}], dist: 1, ascend: 0 } as never
    }

    beforeEach(() => setCoarse(false))

    it('gives the map a button that opens the file picker', () => {
      renderField()
      const input = screen.getByTestId('planner-import-input') as HTMLInputElement
      const click = vi.spyOn(input, 'click')
      fireEvent.click(screen.getByText('map import'))
      expect(click).toHaveBeenCalledTimes(1)
    })

    it('replaces directly, without a question, when there is no route to lose', async () => {
      importGpxMock.mockResolvedValue(info())
      const onImportName = vi.fn()
      renderField({ onImportName })
      const file = gpx()
      choose(file)
      expect(screen.queryByRole('dialog')).toBeNull()
      expect(importGpxMock).toHaveBeenCalledWith(file, 'replace')
      await waitFor(() => expect(onImportName).toHaveBeenCalledWith('Boucle'))
    })

    it.each([
      ['planner.import.replace', 'replace'],
      ['planner.import.append', 'append'],
    ])('asks what to do with a route of two points: %s', async (label, mode) => {
      importGpxMock.mockResolvedValue(info({ mode }))
      routeOfTwoPoints()
      renderField()
      const file = gpx()
      choose(file)
      expect(importGpxMock).not.toHaveBeenCalled()
      await screen.findByRole('dialog')
      fireEvent.click(screen.getByRole('button', { name: label }))
      expect(importGpxMock).toHaveBeenCalledWith(file, mode)
      await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
    })

    it('imports nothing on cancel', async () => {
      routeOfTwoPoints()
      renderField()
      choose(gpx())
      await screen.findByRole('dialog')
      fireEvent.click(screen.getByRole('button', { name: 'actions.cancelAction' }))
      await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
      expect(importGpxMock).not.toHaveBeenCalled()
    })

    it('reports the elevation fallback and the route points left out, and no name when nothing was loaded', async () => {
      importGpxMock.mockResolvedValueOnce(info({ droppedWaypoints: 2, elevationFallback: true }))
      const onImportName = vi.fn()
      renderField({ onImportName })
      choose(gpx())
      await waitFor(() => expect(notificationShow).toHaveBeenCalledTimes(2))
      const messages = notificationShow.mock.calls.map((c) => c[0].message)
      expect(messages).toContain('planner.import.elevationFallback')
      expect(messages).toContain('planner.import.waypointsDropped')
      cleanup()
      notificationShow.mockClear()

      importGpxMock.mockResolvedValueOnce(null)
      const other = vi.fn()
      renderField({ onImportName: other })
      choose(gpx())
      await waitFor(() => expect(importGpxMock).toHaveBeenCalledTimes(2))
      expect(other).not.toHaveBeenCalled()
      expect(notificationShow).not.toHaveBeenCalled()
    })

    it('puts the button in the fullscreen header on a finger', async () => {
      setCoarse(true)
      renderField()
      fireEvent.click(screen.getByRole('button', { name: 'planner.draw' }))
      await screen.findByRole('dialog')
      const input = screen.getByTestId('planner-import-input') as HTMLInputElement
      const click = vi.spyOn(input, 'click')
      fireEvent.click(screen.getByRole('button', { name: 'planner.import' }))
      expect(click).toHaveBeenCalledTimes(1)
    })
  })

  describe('route points (C3e)', () => {
    const placed = {
      key: 'w-1',
      origin: 'AUTHOR',
      type: 'CAFE',
      name: 'Café',
      description: '',
      lng: 5.001,
      lat: 45,
      distance: 80,
    }
    function withWaypoint() {
      const start = createPoint(5, 45, 100)
      start.manual = true
      const end = createPoint(5.002, 45, 110)
      end.manual = true
      plannerState.route = computeRoute([start, end]) as never
      plannerState.placedWaypoints = [placed]
      plannerState.waypoints = [placed]
    }

    beforeEach(() => setCoarse(false))

    it('hands the saved route points and their length to the hook', () => {
      const initialWaypoints = [{ name: 'Café' }] as never
      renderField({ initialWaypoints, initialWaypointsTotal: 4200 })
      expect(hookOptions.last).toMatchObject({ initialWaypoints, initialWaypointsTotal: 4200 })
    })

    it('adds a route point from the place the map gives, with REGROUP pre-selected', async () => {
      const onFullscreenChange = vi.fn()
      renderField({ onFullscreenChange })
      fireEvent.click(await screen.findByText('map add waypoint'))
      await screen.findByRole('dialog')
      expect(onFullscreenChange).toHaveBeenLastCalledWith(true)
      fireEvent.change(screen.getByLabelText('planner.waypoint.form.name'), {
        target: { value: 'Pont' },
      })
      fireEvent.click(screen.getByRole('button', { name: 'planner.waypoint.form.add' }))
      expect(waypointOps.addWaypoint).toHaveBeenCalledWith(
        { lng: 5.001, lat: 45, distance: 80 },
        { type: 'REGROUP', name: 'Pont', description: '' }
      )
      await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
      expect(onFullscreenChange).toHaveBeenLastCalledWith(false)
    })

    it('opens the form of a route point from the profile and saves the edit', async () => {
      withWaypoint()
      renderField()
      fireEvent.click(await screen.findByText('profile waypoint'))
      await screen.findByRole('dialog')
      const name = screen.getByLabelText('planner.waypoint.form.name') as HTMLInputElement
      expect(name.value).toBe('Café')
      fireEvent.change(name, { target: { value: 'Café du Port' } })
      fireEvent.click(screen.getByRole('button', { name: 'actions.save' }))
      expect(waypointOps.updateWaypoint).toHaveBeenCalledWith('w-1', {
        type: 'CAFE',
        name: 'Café du Port',
        description: '',
      })
    })

    it('deletes a route point without a question, and offers to take it back', async () => {
      withWaypoint()
      waypointOps.removeWaypoint.mockImplementation(() => {
        plannerState.placedWaypoints = []
        plannerState.waypoints = []
        return true
      })
      renderField()
      fireEvent.click(await screen.findByText('profile waypoint'))
      fireEvent.click(await screen.findByRole('button', { name: 'planner.waypoint.form.delete' }))
      expect(waypointOps.removeWaypoint).toHaveBeenCalledWith('w-1')
      await waitFor(() => expect(notificationShow).toHaveBeenCalledTimes(1))
      const { message } = notificationShow.mock.calls[0][0]
      render(<MantineProvider>{message}</MantineProvider>)
      expect(screen.getByText('planner.waypoint.deleted')).toBeTruthy()
      fireEvent.click(screen.getByRole('button', { name: 'planner.cleared.undo' }))
      expect(undoMock).toHaveBeenCalledTimes(1)
    })

    it('says nothing when the removal was refused', async () => {
      withWaypoint()
      waypointOps.removeWaypoint.mockReturnValue(false)
      renderField()
      fireEvent.click(await screen.findByText('profile waypoint'))
      fireEvent.click(await screen.findByRole('button', { name: 'planner.waypoint.form.delete' }))
      expect(notificationShow).not.toHaveBeenCalled()
    })
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

    it('shows the elevation strip under the map, and hands its hover to the map', async () => {
      // A straight edge whose relief was read: the profile has a sample between the two points
      const start = createPoint(5, 45, 100)
      start.manual = true
      const end = createPoint(5.002, 45, 110, false, true)
      end.manual = true
      end.directProfile = {
        key: edgeKey(start, end),
        lngLat: [
          [5, 45],
          [5.001, 45],
          [5.002, 45],
        ],
        ele: [100, 130, 110],
        ascend: 30,
      }
      plannerState.route = computeRoute([start, end]) as never
      renderField()
      const strip = await screen.findByTestId('strip')
      expect(strip.dataset.collapsed).toBe('undefined')
      expect(screen.getByTestId('planner').dataset.hoverPosition).toBe('')

      // The sample of the profile is between the two ends: the marker goes there
      fireEvent.click(screen.getByText('profile hover'))
      expect(screen.getByTestId('planner').dataset.hoverPosition).toBe('5.001,45')
      expect(screen.getByTestId('strip').dataset.hovered).toBe('1')

      // and the other way round: the map reports a point of the route, the strip gets its entry
      // of the profile (the second point is the third entry)
      fireEvent.click(screen.getByText('map hover'))
      expect(screen.getByTestId('strip').dataset.hovered).toBe('2')
      expect(screen.getByTestId('planner').dataset.hoverPosition).toBe('')
    })

    it('shows one strip at a time while the editor is open', async () => {
      renderField()
      fireEvent.click(await screen.findByText('expand'))
      await screen.findByRole('dialog')
      expect(screen.getAllByTestId('strip')).toHaveLength(1)
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

    it('folds the strip above the bottom bar, and remembers the choice', async () => {
      renderField()
      fireEvent.click(screen.getByRole('button', { name: 'planner.draw' }))
      await screen.findByRole('dialog')
      expect(screen.getByTestId('strip').dataset.collapsed).toBe('false')

      fireEvent.click(screen.getByText('toggle strip'))
      expect(screen.getByTestId('strip').dataset.collapsed).toBe('true')
      expect(localStorage.setItem).toHaveBeenCalledWith('pedalons-planner-profile-collapsed', '1')

      fireEvent.click(screen.getByText('toggle strip'))
      expect(screen.getByTestId('strip').dataset.collapsed).toBe('false')
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
