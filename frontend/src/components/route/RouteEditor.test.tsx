import { useEffect, type Ref } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { TeamDetailDto } from '@/api/dto'
import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'

const snapshotMock = vi.hoisted(() => vi.fn())
const notify = vi.hoisted(() => vi.fn())
const fieldProps = vi.hoisted(() => ({ last: undefined as Record<string, unknown> | undefined }))

vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))
vi.mock('@mantine/notifications', () => ({ notifications: { show: notify } }))
vi.mock('@/hooks/useResponsive', () => ({ useMediaMatch: () => false }))
vi.mock('../common/MediaEditor', () => ({ MediaEditor: () => <div /> }))
vi.mock('../common/SlugEditor', () => ({ SlugEditor: () => <div /> }))
vi.mock('@/components/tag', () => ({ TagPicker: () => <div /> }))

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

import { RouteEditor } from './RouteEditor'
import { defaultMedia } from '@/lib/apiUtils'

const STATE = { version: 1, profile: 'GRAVEL', sources: [], junctions: [], pieces: [] } as never
const POINTS = [
  { lng: 5, lat: 45 },
  { lng: 5.1, lat: 45 },
]
const TEAM = {
  slug: 'club',
  visibility: 'TEAM',
  enableRoutePlanner: true,
  geometry: null,
} as unknown as TeamDetailDto

function renderEditor(props: Partial<React.ComponentProps<typeof RouteEditor>> = {}) {
  const onSubmit = vi.fn()
  render(
    <MantineProvider>
      <RouteEditor
        team={TEAM}
        teamSlug="club"
        initialValues={{
          name: 'Boucle du lac',
          media: defaultMedia(),
          surfaceType: 'ROAD',
          visibility: 'TEAM',
          tagIds: [],
        }}
        initialTrack={[[5, 45, 100]]}
        submitButtonText="save"
        onSubmit={onSubmit}
        onCancel={() => {}}
        isPending={false}
        {...props}
      />
    </MantineProvider>
  )
  return onSubmit
}

const save = () => fireEvent.click(screen.getByRole('button', { name: 'save' }))

describe('RouteEditor planner state (C4a)', () => {
  beforeEach(() => {
    snapshotMock.mockReset()
    notify.mockReset()
  })
  afterEach(cleanup)

  it('a change of title on an untouched track sends neither points nor state', async () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    const [data, file] = onSubmit.mock.calls[0]
    expect(data.points).toBeUndefined()
    expect(data.plannerState).toBeUndefined()
    expect(file).toBeUndefined()
  })

  it('a changed track sends the state alone', async () => {
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    const [data] = onSubmit.mock.calls[0]
    expect(data.plannerState).toBe(STATE)
    expect(data.points).toBeUndefined()
  })

  it('a state past the bounds sends the points alone and says so', async () => {
    snapshotMock.mockReturnValue({ dirty: true, plannerState: null, points: POINTS })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    const [data] = onSubmit.mock.calls[0]
    expect(data.points).toEqual(POINTS)
    expect(data.plannerState).toBeUndefined()
    expect(notify).toHaveBeenCalledWith(
      expect.objectContaining({ message: 'planner.state.tooLarge' })
    )
  })

  it('a creation sends the state', async () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor({ isCreateMode: true, initialTrack: undefined })
    // Creation starts from the file input: switch to the planner
    fireEvent.click(screen.getByRole('button', { name: 'routes.create.form.sourceModePlanner' }))
    await screen.findByTestId('field')
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    const [data] = onSubmit.mock.calls[0]
    expect(data.plannerState).toBe(STATE)
    expect(data.points).toBeUndefined()
  })
})

describe('RouteEditor import in the planner (C4b)', () => {
  beforeEach(() => {
    snapshotMock.mockReset()
    notify.mockReset()
  })
  afterEach(cleanup)

  it('an import left untouched is submitted as the file, without points nor state', async () => {
    const file = new File(['<gpx/>'], 'sortie.gpx')
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS, file })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    const [data, sent] = onSubmit.mock.calls[0]
    expect(sent).toBe(file)
    expect(data.points).toBeUndefined()
    expect(data.plannerState).toBeUndefined()
  })

  it('a modified import is submitted as the state', async () => {
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    const [data, sent] = onSubmit.mock.calls[0]
    expect(sent).toBeUndefined()
    expect(data.plannerState).toBe(STATE)
  })

  it('names the route after the file only when the name is empty', async () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    renderEditor()
    act(() => (fieldProps.last!.onImportName as (n: string) => void)('Du fichier'))
    expect((screen.getByLabelText(/routes.create.form.name/) as HTMLInputElement).value).toBe(
      'Boucle du lac'
    )
    cleanup()

    renderEditor({
      initialValues: {
        name: '',
        media: defaultMedia(),
        surfaceType: 'ROAD',
        visibility: 'TEAM',
        tagIds: [],
      },
    })
    act(() => (fieldProps.last!.onImportName as (n: string) => void)('Du fichier'))
    expect((screen.getByLabelText(/routes.create.form.name/) as HTMLInputElement).value).toBe(
      'Du fichier'
    )
  })
})
