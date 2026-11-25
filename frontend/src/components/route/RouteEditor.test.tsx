import { useEffect, type Ref } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TeamDetailDto } from '@/api/dto'
import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'

const snapshotMock = vi.hoisted(() => vi.fn())
const notify = vi.hoisted(() => vi.fn())
const fieldProps = vi.hoisted(() => ({
  last: undefined as Record<string, unknown> | undefined,
  // every import request a mounted field took, in order
  taken: [] as { seq: number; polyline: string }[],
}))

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (k: string) => k, i18n: { language: 'fr' } }),
}))
vi.mock('@mantine/notifications', () => ({ notifications: { show: notify } }))
vi.mock('@/hooks/useResponsive', () => ({ useMediaMatch: () => false }))
vi.mock('../common/MediaEditor', () => ({ MediaEditor: () => <div /> }))
vi.mock('../common/SlugEditor', () => ({ SlugEditor: () => <div /> }))
vi.mock('@/components/tag', () => ({ TagPicker: () => <div /> }))
// The generator is out of scope here: a stand-in that offers one candidate.
vi.mock('../routeGenerator/RouteGeneratorModal', () => ({
  RouteGeneratorModal: (props: {
    opened: boolean
    onUse: (candidate: unknown, type: string) => void
  }) =>
    props.opened ? (
      <button
        onClick={() =>
          props.onUse({ polyline: 'POLY', distanceM: 82000, ascentM: 600, bounds: {} }, 'GRAVEL')
        }
      >
        use generated
      </button>
    ) : null,
}))

// The planner itself is out of scope: a stand-in that has two points and gives a snapshot.
vi.mock('../planner/RoutePlannerField', () => ({
  RoutePlannerField: (props: {
    plannerRef?: Ref<{ snapshot: () => PlannerSnapshot }>
    onPointsChange: (points: { lng: number; lat: number }[]) => void
    importRequest?: { seq: number; polyline: string }
    onImportHandled?: (seq: number) => void
  }) => {
    fieldProps.last = props as never
    const { onPointsChange, importRequest, onImportHandled } = props
    // As the real field: a request is taken once, and the host is told
    useEffect(() => {
      if (!importRequest) return
      fieldProps.taken.push(importRequest)
      onImportHandled?.(importRequest.seq)
    }, [importRequest, onImportHandled])
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
import { ApiClientError } from '@/lib/apiError'
import { useAuthStore } from '@/store/authStore'
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
  // A private team without public content: « Équipe » only, so no visibility field (WEB-166).
  allowedContentVisibilities: { route: ['TEAM'] },
  defaultContentVisibility: 'TEAM',
} as unknown as TeamDetailDto

function renderEditor(props: Partial<React.ComponentProps<typeof RouteEditor>> = {}) {
  const onSubmit = vi.fn()
  render(
    <QueryClientProvider client={new QueryClient()}>
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
    </QueryClientProvider>
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

describe('surface type suggestion (C1c)', () => {
  beforeEach(() => {
    snapshotMock.mockReset()
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
  })
  afterEach(cleanup)

  const field = () =>
    screen
      .getAllByLabelText(/routes.create.form.surfaceType/)
      .find((e) => e.tagName === 'INPUT') as HTMLInputElement
  const badge = () => screen.queryByTestId('route-surface-type-suggestion')

  it('shows the badge when the suggestion differs from the value', () => {
    renderEditor({ suggestedSurfaceType: 'GRAVEL' as never })
    expect(badge()?.textContent).toBe('routes.surfaceTypeSuggestion.label')
  })

  it('is absent when equal, without a prop, and in create mode', () => {
    renderEditor({ suggestedSurfaceType: 'ROAD' as never })
    expect(badge()).toBeNull()
    cleanup()
    renderEditor()
    expect(badge()).toBeNull()
    cleanup()
    renderEditor({ suggestedSurfaceType: 'GRAVEL' as never, isCreateMode: true })
    expect(badge()).toBeNull()
  })

  it('a click applies it, hides the badge, and the submission carries it', async () => {
    const onSubmit = renderEditor({ suggestedSurfaceType: 'GRAVEL' as never })
    expect(field().value).toBe('routes.surfaceType.ROAD')
    fireEvent.click(badge()!)
    expect(field().value).toBe('routes.surfaceType.GRAVEL')
    expect(badge()).toBeNull()
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit.mock.calls[0][0].surfaceType).toBe('GRAVEL')
  })

  it('is absent once a GPX file is chosen', async () => {
    const { container } = renderGpx()
    expect(badge()).not.toBeNull()
    const input = container.querySelector('input[type="file"]') as HTMLInputElement
    fireEvent.change(input, {
      target: { files: [new File(['<gpx/>'], 'sortie.gpx', { type: 'application/gpx+xml' })] },
    })
    await waitFor(() => expect(badge()).toBeNull())
  })

  function renderGpx() {
    return render(
      <QueryClientProvider client={new QueryClient()}>
        <MantineProvider>
          <RouteEditor
            team={{ ...TEAM, enableRoutePlanner: false } as unknown as TeamDetailDto}
            teamSlug="club"
            initialValues={{
              name: 'Boucle du lac',
              media: defaultMedia(),
              surfaceType: 'ROAD',
              visibility: 'TEAM',
              tagIds: [],
            }}
            initialTrack={[[5, 45, 100]]}
            suggestedSurfaceType={'GRAVEL' as never}
            submitButtonText="save"
            onSubmit={vi.fn()}
            onCancel={() => {}}
            isPending={false}
          />
        </MantineProvider>
      </QueryClientProvider>
    )
  }
})

describe('names read from the GPX file', () => {
  afterEach(cleanup)

  const XML =
    '<gpx xmlns="http://www.topografix.com/GPX/1/1"><trk><name>Aller</name><trkseg>' +
    '<trkpt lat="45" lon="6"/></trkseg></trk><trk><name>Retour</name><trkseg>' +
    '<trkpt lat="45" lon="6"/></trkseg></trk></gpx>'

  it('names the route after the first track and offers the other names', async () => {
    renderEditor({
      isCreateMode: true,
      initialTrack: undefined,
      team: { ...TEAM, enableRoutePlanner: false } as TeamDetailDto,
      initialValues: {
        name: '',
        media: defaultMedia(),
        surfaceType: 'ROAD',
        visibility: 'TEAM',
        tagIds: [],
      },
    })
    const input = document.querySelector('input[type="file"]') as HTMLInputElement
    const file = new File([XML], 'export.gpx', { type: 'application/gpx+xml' })
    fireEvent.change(input, { target: { files: [file] } })

    const name = () => (screen.getByLabelText(/routes.create.form.name/) as HTMLInputElement).value
    await waitFor(() => expect(name()).toBe('Aller'))
    expect(screen.getByText('routes.create.form.nameSuggestions')).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'export' }))
    expect(name()).toBe('export')
    expect(screen.getByRole('button', { name: 'Retour' })).toBeTruthy()
  })
})

describe('planner quota (BILL-10)', () => {
  const SPENT = { limit: 20, used: 20, resetsOn: '2026-12-01' }
  afterEach(() => {
    cleanup()
    useAuthStore.setState({ user: null })
  })

  it('disables « Tracer sur la carte » with the reason once the quota is spent; the file stays', () => {
    renderEditor({
      team: { ...TEAM, name: 'Club', plannerQuota: SPENT } as unknown as TeamDetailDto,
      isCreateMode: true,
      initialTrack: undefined,
    })
    const planner = screen.getByRole('button', { name: 'routes.create.form.sourceModePlanner' })
    expect((planner as HTMLButtonElement).disabled).toBe(true)
    expect(screen.getByText('planner.quota.team')).toBeTruthy()
    expect(screen.getByText('planner.quota.alternative')).toBeTruthy()
    expect(screen.getByText('routes.create.form.gpxFile')).toBeTruthy()
  })

  it('keeps the option open below the quota and for the platform admin', () => {
    renderEditor({
      team: { ...TEAM, plannerQuota: { ...SPENT, used: 19 } } as unknown as TeamDetailDto,
      isCreateMode: true,
      initialTrack: undefined,
    })
    const below = screen.getByRole('button', { name: 'routes.create.form.sourceModePlanner' })
    expect((below as HTMLButtonElement).disabled).toBe(false)
    cleanup()

    useAuthStore.setState({ user: { platformRole: 'PLATFORM_ADMIN' } as never })
    renderEditor({
      team: { ...TEAM, plannerQuota: SPENT } as unknown as TeamDetailDto,
      isCreateMode: true,
      initialTrack: undefined,
    })
    const admin = screen.getByRole('button', { name: 'routes.create.form.sourceModePlanner' })
    expect((admin as HTMLButtonElement).disabled).toBe(false)
    expect(screen.queryByTestId('planner-quota-message')).toBeNull()
  })

  it('opens the dialog when the save is refused at a quota spent in the meantime', async () => {
    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS })
    const onSubmit = renderEditor()
    onSubmit.mockRejectedValue(
      new ApiClientError(403, {
        code: 'PLANNER_QUOTA_REACHED',
        errorDetails: {
          type: 'PLANNER_QUOTA_REACHED',
          scope: 'TEAM',
          limit: 20,
          current: 20,
          resetsOn: '2026-12-01',
          teamName: 'Club',
        },
      })
    )
    save()
    expect(await screen.findByTestId('planner-quota-modal')).toBeTruthy()
    expect(screen.getByText('planner.quota.teamLift')).toBeTruthy()
    // Not saved: the warning about a dropped state is not given
    expect(notify).not.toHaveBeenCalled()
  })
})

describe('route generator (WEB-179)', () => {
  const SPENT = { limit: 20, used: 20, resetsOn: '2026-12-01' }
  const GENERATE = 'routes.create.form.sourceModeGenerator'
  const BOX = 'routes.create.form.excludedFromGenerator'
  beforeEach(() => {
    snapshotMock.mockReset()
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    fieldProps.taken.length = 0
  })
  afterEach(cleanup)

  it('shows the exclusion box only on a team with the planner, and sends its value', async () => {
    const onSubmit = renderEditor()
    const box = screen.getByLabelText(BOX) as HTMLInputElement
    expect(box.checked).toBe(false)
    fireEvent.click(box)
    save()
    await waitFor(() => expect(onSubmit).toHaveBeenCalled())
    expect(onSubmit.mock.calls[0][0].excludedFromGenerator).toBe(true)
    cleanup()
    renderEditor({ team: { ...TEAM, enableRoutePlanner: false } as unknown as TeamDetailDto })
    expect(screen.queryByLabelText(BOX)).toBeNull()
  })

  it('starts the box from the route on an edit', () => {
    renderEditor({
      initialValues: {
        name: 'Boucle du lac',
        media: defaultMedia(),
        surfaceType: 'ROAD',
        visibility: 'TEAM',
        tagIds: [],
        excludedFromGenerator: true,
      },
    })
    expect((screen.getByLabelText(BOX) as HTMLInputElement).checked).toBe(true)
  })

  it('offers « Générer un parcours » on a creation only, disabled at a spent quota', () => {
    renderEditor({ isCreateMode: true, initialTrack: undefined })
    expect((screen.getByRole('button', { name: GENERATE }) as HTMLButtonElement).disabled).toBe(
      false
    )
    cleanup()
    renderEditor({
      isCreateMode: true,
      initialTrack: undefined,
      team: { ...TEAM, name: 'Club', plannerQuota: SPENT } as unknown as TeamDetailDto,
    })
    expect((screen.getByRole('button', { name: GENERATE }) as HTMLButtonElement).disabled).toBe(
      true
    )
    cleanup()
    renderEditor()
    expect(screen.queryByRole('button', { name: GENERATE })).toBeNull()
  })

  it('a candidate chosen in the dialog goes to the planner and presets the type', async () => {
    renderEditor({ isCreateMode: true, initialTrack: undefined })
    fireEvent.click(screen.getByRole('button', { name: GENERATE }))
    fireEvent.click(await screen.findByRole('button', { name: 'use generated' }))
    await screen.findByTestId('field')
    expect(fieldProps.taken).toMatchObject([{ seq: 1, polyline: 'POLY' }])
    const surface = screen
      .getAllByLabelText(/routes.create.form.surfaceType/)
      .find((e) => e.tagName === 'INPUT') as HTMLInputElement
    expect(surface.value).toBe('routes.surfaceType.GRAVEL')
  })

  it('a hand-off from the generator page opens the planner on it', async () => {
    renderEditor({
      isCreateMode: true,
      initialTrack: undefined,
      initialGenerated: { polyline: 'POLY', type: 'GRAVEL', distanceM: 82000 },
    })
    await screen.findByTestId('field')
    expect(fieldProps.taken).toMatchObject([{ seq: 1, polyline: 'POLY' }])
  })

  it('does not load the generated route again when the planner comes back after the GPX source', async () => {
    renderEditor({ isCreateMode: true, initialTrack: undefined })
    fireEvent.click(screen.getByRole('button', { name: GENERATE }))
    fireEvent.click(await screen.findByRole('button', { name: 'use generated' }))
    await screen.findByTestId('field')
    expect(fieldProps.taken).toHaveLength(1)
    fireEvent.click(screen.getByRole('button', { name: 'routes.create.form.sourceModeGpx' }))
    expect(screen.queryByTestId('field')).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: 'routes.create.form.sourceModePlanner' }))
    await screen.findByTestId('field')
    expect(fieldProps.taken).toHaveLength(1)
    expect(fieldProps.last?.importRequest).toBeUndefined()
    // A second choice is still taken
    fireEvent.click(screen.getByRole('button', { name: GENERATE }))
    fireEvent.click(await screen.findByRole('button', { name: 'use generated' }))
    await waitFor(() => expect(fieldProps.taken).toHaveLength(2))
    expect(fieldProps.taken[1].seq).toBe(2)
  })

  it('ignores a hand-off at a spent quota: the file input stays', () => {
    renderEditor({
      isCreateMode: true,
      initialTrack: undefined,
      team: { ...TEAM, name: 'Club', plannerQuota: SPENT } as unknown as TeamDetailDto,
      initialGenerated: { polyline: 'POLY', type: 'GRAVEL', distanceM: 82000 },
    })
    expect(screen.queryByTestId('field')).toBeNull()
  })
})

describe('leave guard probe (WEB-213)', () => {
  beforeEach(() => snapshotMock.mockReset())
  afterEach(cleanup)

  it('says nothing is lost on an untouched form, and something once a field or the track moved', async () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    const dirtyRef: { current: (() => boolean) | null } = { current: null }
    renderEditor({ dirtyRef })
    await screen.findByTestId('field')
    expect(dirtyRef.current?.()).toBe(false)

    snapshotMock.mockReturnValue({ dirty: true, plannerState: STATE, points: POINTS })
    expect(dirtyRef.current?.()).toBe(true)

    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    fireEvent.change(screen.getByDisplayValue('Boucle du lac'), {
      target: { value: 'Tour du lac' },
    })
    await waitFor(() => expect(dirtyRef.current?.()).toBe(true))
  })

  it('counts a handed-over proposal as work until it is saved', async () => {
    snapshotMock.mockReturnValue({ dirty: false, plannerState: STATE, points: POINTS })
    const dirtyRef: { current: (() => boolean) | null } = { current: null }
    renderEditor({
      dirtyRef,
      initialGenerated: { polyline: 'POLY', type: 'ROAD', distanceM: 50000 },
    })
    await screen.findByTestId('field')
    expect(dirtyRef.current?.()).toBe(true)
  })
})
