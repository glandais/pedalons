import { useEffect, type Ref } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'

const snapshotMock = vi.hoisted(() => vi.fn())
const notify = vi.hoisted(() => vi.fn())
const fieldProps = vi.hoisted(() => ({ last: undefined as Record<string, unknown> | undefined }))

vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))
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

import { GpxPreviewEditor } from './GpxPreviewEditor'

const STATE = { version: 1, profile: 'GRAVEL', sources: [], junctions: [], pieces: [] } as never
const POINTS = [
  { lng: 5, lat: 45 },
  { lng: 5.1, lat: 45 },
]

function renderEditor(props: Partial<React.ComponentProps<typeof GpxPreviewEditor>> = {}) {
  const onSubmit = vi.fn()
  render(
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
    expect(onSubmit).toHaveBeenCalledWith('Ma sortie', undefined, undefined)
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
    expect(onSubmit).toHaveBeenCalledWith('Ma sortie', undefined, file)
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
