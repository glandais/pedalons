import { useEffect, type Ref } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'

const snapshotMock = vi.hoisted(() => vi.fn())
const notify = vi.hoisted(() => vi.fn())
const fieldProps = vi.hoisted(() => ({ last: undefined as Record<string, unknown> | undefined }))

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (k: string) => k, i18n: { language: 'fr' } }),
}))
vi.mock('@/config/appConfig', () => ({ isGpxPlannerEnabled: () => true }))
vi.mock('@mantine/notifications', () => ({ notifications: { show: notify } }))
vi.mock('@/hooks/useResponsive', () => ({ useMediaMatch: () => false }))

// The planner itself is out of scope: a stand-in that has two points and gives a snapshot.
vi.mock('../planner/RoutePlannerField', () => ({
  RoutePlannerField: (props: {
    plannerRef?: Ref<{ snapshot: () => PlannerSnapshot }>
    onPointsChange: (points: { lng: number; lat: number }[]) => void
  }) => {
    fieldProps.last = props as never
    const { onPointsChange } = props
    useEffect(() => {
      onPointsChange([
        { lng: 5, lat: 45 },
        { lng: 5.1, lat: 45 },
      ])
    }, [onPointsChange])
    if (props.plannerRef && 'current' in props.plannerRef) {
      ;(props.plannerRef as { current: unknown }).current = { snapshot: snapshotMock }
    }
    return <div data-testid="field" />
  },
}))

// The departure fields have their own test: a stand-in with a button for each gesture.
vi.mock('./DepartureFields', () => ({
  DepartureFields: (props: {
    value: { departure?: string; averageSpeed?: number }
    onChange: (value: { departure?: string; averageSpeed?: number }) => void
  }) => (
    <div>
      <button onClick={() => props.onChange({ ...props.value, departure: '2026-11-08T09:30:00' })}>
        set-departure
      </button>
      <button onClick={() => props.onChange({ ...props.value, departure: undefined })}>
        clear-departure
      </button>
      <button onClick={() => props.onChange({ ...props.value, averageSpeed: 27.5 })}>
        set-speed
      </button>
      <button onClick={() => props.onChange({ ...props.value, averageSpeed: undefined })}>
        clear-speed
      </button>
    </div>
  ),
}))

import { GpxPreviewEditor } from './GpxPreviewEditor'
import { ApiClientError } from '@/lib/apiError'

const STATE = { version: 1, profile: 'GRAVEL', sources: [], junctions: [], pieces: [] } as never
const POINTS = [
  { lng: 5, lat: 45 },
  { lng: 5.1, lat: 45 },
]

function renderEditor(props: Partial<React.ComponentProps<typeof GpxPreviewEditor>> = {}) {
  const onSubmit = vi.fn()
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <GpxPreviewEditor
          initialName="Ma sortie"
          initialTrack={[[5, 45, 100]]}
          onSubmit={onSubmit}
          onCancel={() => {}}
          isPending={false}
          {...props}
        />
      </MantineProvider>
    </QueryClientProvider>
  )
  return onSubmit
}

const save = () => fireEvent.click(screen.getByRole('button', { name: 'actions.save' }))

describe('GpxPreviewEditor planner state (C4a)', () => {
  beforeEach(() => {
    snapshotMock.mockReset()
    notify.mockReset()
  })
  afterEach(cleanup)

  it('a rename of an untouched track sends neither points nor state', async () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit).toHaveBeenCalledWith('Ma sortie', undefined, undefined, undefined, {})
  })

  it('a changed track sends the state alone', async () => {
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit.mock.calls[0][1]).toEqual({ points: undefined, plannerState: STATE })
    expect(notify).not.toHaveBeenCalled()
  })

  it('a state past the bounds sends the points alone and says so', async () => {
    snapshotMock.mockReturnValue({ dirty: true, plannerState: null, points: POINTS })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit.mock.calls[0][1]).toEqual({ points: POINTS, plannerState: undefined })
    expect(notify).toHaveBeenCalledWith(
      expect.objectContaining({ message: 'planner.state.tooLarge' })
    )
  })

  it('a creation sends the state', async () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor({ create: true, initialTrack: undefined })
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit.mock.calls[0][1]).toEqual({ points: undefined, plannerState: STATE })
  })

  it('the route points edited alone go with no track: the track is left as it is', async () => {
    const waypoints = [{ position: { lng: 5.05, lat: 45 }, type: 'CAFE', name: 'Café' }]
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS, waypoints })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit).toHaveBeenCalledWith('Ma sortie', undefined, undefined, waypoints, {})
  })

  it('the route points ride along a changed track and an untouched import', async () => {
    const waypoints = [{ position: { lng: 5.05, lat: 45 }, type: 'CAFE', name: 'Café' }]
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS, waypoints })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit.mock.calls[0][1]).toEqual({ points: undefined, plannerState: STATE })
    expect(onSubmit.mock.calls[0][3]).toBe(waypoints)
    cleanup()

    const file = new File(['<gpx/>'], 'sortie.gpx')
    snapshotMock.mockReturnValue({
      dirty: true,
      plannerState: STATE,
      points: POINTS,
      file,
      waypoints,
    })
    const second = renderEditor({ create: true, initialTrack: undefined })
    save()
    await waitFor(() => expect(second).toHaveBeenCalled())
    expect(second).toHaveBeenCalledWith('Ma sortie', undefined, file, waypoints, {})
  })

  it('hands the saved route points and their length to the planner', () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    const initialWaypoints = [{ name: 'Café' }] as never
    renderEditor({ initialWaypoints, initialDistance: 12345 })
    expect(fieldProps.last?.initialWaypoints).toBe(initialWaypoints)
    expect(fieldProps.last?.initialWaypointsTotal).toBe(12345)
  })

  it('hands the saved state to the planner', () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    renderEditor({ initialPlannerState: STATE })
    expect(fieldProps.last?.initialState).toBe(STATE)
  })
})

describe('GpxPreviewEditor import in the planner (C4b)', () => {
  beforeEach(() => {
    snapshotMock.mockReset()
    notify.mockReset()
  })
  afterEach(cleanup)

  it('an import left untouched is submitted as the file, without points nor state', async () => {
    const file = new File(['<gpx/>'], 'sortie.gpx')
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS, file })
    const onSubmit = renderEditor({ create: true, initialTrack: undefined })
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit).toHaveBeenCalledWith('Ma sortie', undefined, file, undefined, {})
  })

  it('a modified import is submitted as the state', async () => {
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor({ create: true, initialTrack: undefined })
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit.mock.calls[0][1]).toEqual({ points: undefined, plannerState: STATE })
    expect(onSubmit.mock.calls[0][2]).toBeUndefined()
  })

  it('names the track after the file only when the name is empty', () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    renderEditor()
    act(() => (fieldProps.last!.onImportName as (n: string) => void)('Du fichier'))
    expect(screen.getByDisplayValue('Ma sortie')).toBeTruthy()
    cleanup()

    renderEditor({ initialName: '' })
    act(() => (fieldProps.last!.onImportName as (n: string) => void)('Du fichier'))
    expect(screen.getByDisplayValue('Du fichier')).toBeTruthy()
  })
})

describe('GpxPreviewEditor departure', () => {
  beforeEach(() => {
    snapshotMock.mockReset()
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
  })
  afterEach(cleanup)

  const lastChange = (onSubmit: ReturnType<typeof vi.fn>) => onSubmit.mock.calls[0][4]

  it('a creation sends the date and the speed that were typed', async () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor({ create: true, initialTrack: undefined })
    fireEvent.click(screen.getByText('set-departure'))
    fireEvent.click(screen.getByText('set-speed'))
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(lastChange(onSubmit)).toEqual({
      departure: '2026-11-08T09:30:00',
      averageSpeed: 27.5,
    })
  })

  it('leaves the change empty when the saved values are not touched', async () => {
    const onSubmit = renderEditor({
      initialDeparture: { departure: '2026-11-08T09:30:00', averageSpeed: 27.5 },
    })
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(lastChange(onSubmit)).toEqual({})
  })

  it('sends the new date alone when only the date moved', async () => {
    const onSubmit = renderEditor({
      initialDeparture: { departure: '2026-11-01T08:00:00', averageSpeed: 27.5 },
    })
    fireEvent.click(screen.getByText('set-departure'))
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(lastChange(onSubmit)).toEqual({ departure: '2026-11-08T09:30:00' })
  })

  it('asks to clear what was emptied, each field on its own', async () => {
    const onSubmit = renderEditor({
      initialDeparture: { departure: '2026-11-08T09:30:00', averageSpeed: 20 },
    })
    fireEvent.click(screen.getByText('clear-speed'))
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(lastChange(onSubmit)).toEqual({ clearAverageSpeed: true })
    cleanup()
    const second = renderEditor({
      initialDeparture: { departure: '2026-11-08T09:30:00', averageSpeed: 20 },
    })
    fireEvent.click(screen.getByText('clear-departure'))
    save()
    await waitFor(() => expect(second).toHaveBeenCalled())
    expect(lastChange(second)).toEqual({ clearDeparture: true })
  })
})

describe('GpxPreviewEditor planner quota (BILL-10)', () => {
  afterEach(cleanup)

  it('opens the dialog on a save refused at a spent personal quota', async () => {
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor()
    onSubmit.mockRejectedValue(
      new ApiClientError(403, {
        code: 'PLANNER_QUOTA_REACHED',
        errorDetails: {
          type: 'PLANNER_QUOTA_REACHED',
          scope: 'PERSONAL',
          limit: 10,
          current: 10,
          resetsOn: '2026-12-01',
        },
      })
    )
    save()
    expect(await screen.findByTestId('planner-quota-modal')).toBeTruthy()
    expect(screen.getByText('planner.quota.personal')).toBeTruthy()
    expect(screen.getByText('planner.quota.personalLift')).toBeTruthy()
  })
})
