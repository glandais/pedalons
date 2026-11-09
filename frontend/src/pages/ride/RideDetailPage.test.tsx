import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { RideDto, RideGroupDto, RideWeatherDto, TeamDetailDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { okWeather, plain, weatherLeg } from '@/test/weatherFixtures'
import { pathVariants, paths } from '@/config/paths'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({
  team: undefined as unknown,
  ride: undefined as unknown,
  weather: undefined as unknown,
  join: (() => {}) as (groupId: string) => void,
  map: {} as Record<string, unknown>,
}))

vi.mock('./rideDetailData', async (importOriginal) => {
  const actual = await importOriginal<typeof import('./rideDetailData')>()
  return {
    ...actual,
    useRideDetailData: () => {
      const ride = state.ride as RideDto
      const weather = state.weather as RideWeatherDto | undefined
      const solo = actual.soloGroup(ride)
      return {
        team: { data: state.team, isLoading: false },
        ride: { data: ride, isLoading: false, error: null, refetch: () => {} },
        weather: { data: weather, isLoading: false, isFetching: false, refetch: () => {} },
        routes: { data: undefined },
        routesBySlug: new Map([['boucle', { slug: 'boucle', tracks: [], waypoints: [] }]]),
        soloGroup: solo,
        soloLeg: solo ? actual.ownLeg(ride, weather) : undefined,
      }
    },
  }
})
vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({ isAuthenticated: true }),
}))
vi.mock('@/hooks/useRideGroupMembership', () => ({
  useRideGroupMembership: () => ({
    join: (groupId: string) => state.join(groupId),
    leave: () => {},
    isPending: false,
    error: null,
  }),
}))
vi.mock('@/components/ride/ParticipantList', () => ({
  ParticipantList: (props: { source: { groupId?: string } }) => (
    <div data-testid="participant-list">{props.source.groupId}</div>
  ),
}))
vi.mock('@/components/ride/RideGroupRouteActions', () => ({
  RideGroupRouteActions: () => <div data-testid="route-actions" />,
}))
vi.mock('@/components/route/RoutesMapView', () => ({
  RoutesMapView: (props: { kmMarkers?: boolean }) => (
    <div data-testid="routes-map" data-km-markers={String(!!props.kmMarkers)} />
  ),
}))
vi.mock('@/components/route/RouteMapView', () => ({
  RouteMapView: (props: Record<string, unknown>) => {
    state.map = props
    return <div data-testid="route-map" />
  },
}))
vi.mock('@/components/comment', () => ({ CommentSection: () => null }))
vi.mock('@/components/moderation/ContentActionsMenu', () => ({ ContentActionsMenu: () => null }))
vi.mock('@/components/team/TeamContextBanner', () => ({ TeamContextBanner: () => null }))
vi.mock('@/components/common/MediaDisplay', () => ({
  MediaDisplay: () => <div data-testid="media-display" />,
}))

import { RideDetailPage } from './RideDetailPage'

const group = (overrides: Partial<RideGroupDto> = {}): RideGroupDto =>
  ({
    id: 'g1',
    name: 'Rapide',
    startAt: '2026-10-08T06:40:00Z',
    averageSpeed: 28,
    distance: 82_000,
    elevationGain: 950,
    maxParticipants: 12,
    countParticipants: 11,
    participants: [],
    registered: false,
    full: false,
    ...overrides,
  }) as RideGroupDto

const ride = (overrides: Partial<RideDto> = {}): RideDto =>
  ({
    id: 'r1',
    slug: 'sortie',
    name: 'Sortie du samedi',
    status: Status.PUBLISHED,
    finished: false,
    registered: false,
    dateTime: '2026-10-08T06:40:00Z',
    timezone: 'UTC',
    routeSlug: 'boucle',
    participantCount: 11,
    media: { markdown: '', assets: { images: [], attachments: [] } },
    team: { slug: 'np', name: 'N Peloton' },
    tags: [],
    createdBy: { id: 'u9', displayName: 'Créatrice de la sortie' },
    groups: [group()],
    ...overrides,
  }) as unknown as RideDto

const member = { slug: 'np', name: 'N Peloton', role: 'MEMBER' } as TeamDetailDto

function renderPage() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[paths.ride('np', 'sortie')]}>
          <Routes>
            {Object.values(pathVariants.ride(':teamSlug', ':rideSlug')).map((path) => (
              <Route key={path} path={path} element={<RideDetailPage />} />
            ))}
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const groupLinks = () =>
  screen
    .queryAllByRole('link')
    .filter((a) => /\/(groupes|groups)\//.test(a.getAttribute('href') ?? ''))

describe('RideDetailPage — a ride with one group is its group page (WEB-79)', () => {
  beforeEach(() => {
    state.team = member
    state.ride = ride()
    state.weather = { ...okWeather, legs: [weatherLeg('g1')] }
    state.join = vi.fn()
  })
  afterEach(cleanup)

  it('names the group as a block, with no link to a group page', () => {
    renderPage()
    expect(screen.getByRole('heading', { level: 3, name: 'Rapide' })).toBeTruthy()
    expect(groupLinks()).toHaveLength(0)
    expect(screen.queryByRole('link', { name: /Voir le groupe/ })).toBeNull()
  })

  it("carries the group's places, figures and inline participants", async () => {
    renderPage()
    expect(plain(screen.getByTestId('group-places').textContent)).toContain('11/12 personnes')
    const stats = plain(screen.getByTestId('group-stats').textContent)
    expect(stats).toContain('28 km/h')
    expect(stats).toContain('Arrivée estimée')
    expect(screen.getByTestId('participant-list').textContent).toBe('g1')
    // One section only: the group's.
    expect(screen.getAllByRole('region', { name: 'Personnes inscrites' })).toHaveLength(1)
    expect(await screen.findByTestId('route-map')).toBeTruthy()
  })

  it('draws no track colour bar: its single-route map has no coloured trace', () => {
    renderPage()
    expect(screen.queryByTestId('group-track-color')).toBeNull()
  })

  it('joins the group', () => {
    renderPage()
    fireEvent.click(screen.getByRole('button', { name: 'Rejoindre' }))
    expect(state.join).toHaveBeenCalledWith('g1')
  })

  it('shows no leader without one — never the ride creator', () => {
    renderPage()
    expect(screen.queryByTestId('group-leader')).toBeNull()
    expect(screen.queryByText('Capitaine')).toBeNull()
    expect(screen.queryByText('Créatrice de la sortie')).toBeNull()
  })

  it('shows the designated leader', () => {
    state.ride = ride({
      groups: [
        group({ leader: { id: 'u1', displayName: 'Léa Meneuse' } as RideGroupDto['leader'] }),
      ],
    })
    renderPage()
    expect(plain(screen.getByTestId('group-leader').textContent)).toContain('Léa Meneuse')
  })

  it("unrolls the group's route weather under #meteo, no « Météo au départ », before the comments", () => {
    const { container } = renderPage()
    const weather = container.querySelectorAll('#meteo')
    expect(weather).toHaveLength(1)
    expect(weather[0].textContent).toContain('Météo du parcours')
    expect(weather[0].textContent).not.toContain('Météo au départ')
    // Full width, out of the side column, beside which the map stands
    expect(weather[0].closest('.detail-side')).toBeNull()
  })

  it("offers the Météo mode on its map, its fullscreen map the ride's own in that mode (WEB-118)", async () => {
    renderPage()
    await screen.findByTestId('route-map')
    // The grade by default, the ride's map opened without a mode
    expect(state.map.fullscreenPath).toBe(paths.rideMap('np', 'sortie'))
    expect(state.map.lineColorAt).toBeUndefined()
    fireEvent.click(screen.getByLabelText('Météo'))
    expect(state.map.fullscreenPath).toBe(`${paths.rideMap('np', 'sortie')}?color=wind`)
    expect(state.map.lineColorAt).toBeTypeOf('function')
    expect(state.map.kmMarkers).toBe(false)
    expect(state.map.overlays).toBeTruthy()
    expect(screen.getByTestId('wind-map-legend')).toBeTruthy()
  })

  it('offers no Météo mode without a forecast, nor on a finished or cancelled ride', async () => {
    state.weather = {
      ...okWeather,
      legs: [weatherLeg('g1', { status: WeatherStatus.NOT_YET_AVAILABLE })],
    }
    renderPage()
    await screen.findByTestId('route-map')
    expect(screen.queryByLabelText('Météo')).toBeNull()
    cleanup()
    state.weather = { ...okWeather, legs: [weatherLeg('g1')] }
    for (const over of [{ finished: true }, { status: Status.CANCELLED }]) {
      state.ride = ride(over)
      renderPage()
      await screen.findByTestId('route-map')
      expect(screen.queryByLabelText('Météo')).toBeNull()
      expect(state.map.fullscreenPath).toBe(paths.rideMap('np', 'sortie'))
      cleanup()
    }
  })

  it('keeps one linked card per group on a ride with two', async () => {
    state.ride = ride({ groups: [group(), group({ id: 'g2', name: 'Cool' })] })
    state.weather = okWeather
    renderPage()
    expect(screen.getByRole('link', { name: 'Rapide' })).toBeTruthy()
    expect(screen.getByRole('link', { name: 'Cool' })).toBeTruthy()
    expect(screen.queryByTestId('group-stats')).toBeNull()
    // Everyone on the ride, under the groups, in their column — the solo ride's section.
    const section = screen.getByRole('region', { name: 'Personnes inscrites' })
    expect(plain(section.textContent)).toContain('11 personnes')
    expect(screen.getByTestId('ride-groups').contains(section)).toBe(true)
    expect(await screen.findByTestId('routes-map')).toBeTruthy()
  })
})

describe('RideDetailPage — one trace per route, shared by the groups that ride it', () => {
  beforeEach(() => {
    state.team = member
    state.weather = okWeather
    // Rapide and Cool ride the ride's route, Col its own.
    state.ride = ride({
      groups: [
        group(),
        group({ id: 'g2', name: 'Cool' }),
        group({ id: 'g3', name: 'Col', routeSlug: 'col' }),
      ],
    })
  })
  afterEach(cleanup)

  const card = (name: string) =>
    screen.getByRole('link', { name }).closest<HTMLElement>('.mantine-Paper-root')!
  const bar = (name: string) =>
    within(card(name)).getByTestId('group-track-color').style.backgroundColor
  const isLit = (name: string) =>
    card(name).style.backgroundColor === 'var(--mantine-primary-color-light)'

  it('gives the groups on the same route the same colour', () => {
    renderPage()
    expect(bar('Rapide')).toBe(bar('Cool'))
    expect(bar('Col')).not.toBe(bar('Rapide'))
  })

  it("lights every card on the hovered group's route", () => {
    renderPage()
    fireEvent.mouseEnter(card('Rapide'))
    expect(isLit('Rapide')).toBe(true)
    expect(isLit('Cool')).toBe(true)
    expect(isLit('Col')).toBe(false)
    fireEvent.mouseLeave(card('Rapide'))
    expect(isLit('Cool')).toBe(false)
  })
})

describe('RideDetailPage — km markers on a multi-group map (WEB-145)', () => {
  const kmMarkers = async () =>
    (await screen.findByTestId('routes-map')).getAttribute('data-km-markers')

  it('shows them when every group rides the same route', async () => {
    state.ride = ride({ groups: [group(), group({ id: 'g2', name: 'Cool' })] })
    renderPage()
    expect(await kmMarkers()).toBe('true')
  })

  it('not when the groups ride different routes', async () => {
    state.ride = ride({
      groups: [group(), group({ id: 'g2', name: 'Cool', routeSlug: 'col' })],
    })
    renderPage()
    expect(await kmMarkers()).toBe('false')
  })
})

describe('RideDetailPage — layout A: instructions beside a sticky map (WEB-134)', () => {
  beforeEach(() => {
    state.team = member
    state.weather = okWeather
    state.ride = ride({ groups: [group(), group({ id: 'g2', name: 'Cool' })] })
  })
  afterEach(cleanup)

  const asset = { id: 'a1', url: 'https://x/a.pdf', fileName: 'a.pdf' }
  const media = (markdown: string, images: unknown[] = [], attachments: unknown[] = []) =>
    ({ markdown, assets: { images, attachments } }) as unknown as RideDto['media']

  it('leaves the instructions out when the organiser wrote and attached nothing', () => {
    // An image no text references draws nothing either: MediaDisplay only shows referenced ones.
    for (const empty of [media(''), media('  \n '), media('', [asset])]) {
      state.ride = ride({ media: empty })
      renderPage()
      expect(screen.queryByTestId('ride-instructions')).toBeNull()
      expect(screen.queryByTestId('media-display')).toBeNull()
      cleanup()
    }
  })

  it('shows the instructions, untitled but named, as a section, for a text or an attachment', () => {
    for (const full of [media('Rendez-vous au parking'), media('', [], [asset])]) {
      state.ride = ride({ media: full })
      renderPage()
      const section = screen.getByTestId('ride-instructions')
      expect(within(section).queryByRole('heading', { name: 'Consignes' })).toBeNull()
      expect(screen.getByRole('region', { name: 'Consignes' })).toBe(section)
      expect(within(section).getByTestId('media-display')).toBeTruthy()
      cleanup()
    }
  })

  it('puts the map in its own sticky column, after the groups in the page order', async () => {
    const { container } = renderPage()
    await screen.findByTestId('routes-map')
    const layout = container.querySelector('.detail-layout')!
    expect(layout.classList.contains('detail-layout--no-map')).toBe(false)
    const map = layout.querySelector(':scope > .detail-map')!
    const side = layout.querySelector(':scope > .detail-side')!
    // Focus and reading order follow the md+ layout (column left, map right); CSS puts the map
    // first below md.
    expect(side.compareDocumentPosition(map) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
    expect(within(side as HTMLElement).getByTestId('ride-groups')).toBeTruthy()
    expect(side.querySelector('#meteo')).toBeTruthy()
  })

  it('gives the column the full width when there is no map', () => {
    state.ride = ride({
      routeSlug: undefined,
      groups: [group(), group({ id: 'g2', name: 'Cool' })],
    })
    const { container } = renderPage()
    expect(container.querySelector('.detail-layout--no-map')).toBeTruthy()
    expect(container.querySelector('.detail-map')).toBeNull()
    expect(screen.getByTestId('ride-groups')).toBeTruthy()
  })
})

// docs/BRANDING.md §7.8, docs/LEDGER_*.md WEB-137.
describe('RideDetailPage — the departure block', () => {
  const two = () => [
    group(),
    group({ id: 'g2', name: 'Cool', startAt: '2026-10-08T07:10:00Z', registered: true }),
  ]
  const block = () => screen.getByRole('region', { name: 'Date et heure de départ' })

  beforeEach(() => {
    state.team = member
    state.weather = okWeather
  })
  afterEach(cleanup)

  it('comes before the instructions, with the ride’s time and its return', () => {
    state.ride = ride({
      groups: two(),
      endDateTime: '2026-10-08T11:00:00Z',
      media: {
        markdown: 'Rendez-vous au parking',
        assets: { images: [], attachments: [] },
      } as unknown as RideDto['media'],
    })
    renderPage()
    const section = block()
    expect(within(section).getByText('Départ 06:40')).toBeTruthy()
    expect(section.textContent).not.toContain('retour vers')
    const instructions = screen.getByTestId('ride-instructions')
    expect(
      section.compareDocumentPosition(instructions) & Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy()
  })

  it('names the reader’s group beside it when that group leaves at its own time', () => {
    state.ride = ride({ groups: two(), registered: true, registeredGroupId: 'g2' })
    renderPage()
    expect(within(block()).getByText('Départ 06:40')).toBeTruthy()
    expect(within(block()).getByTestId('departure-group').textContent).toBe(
      'Votre groupeCool · 07:10'
    )
  })

  it('names no group for a group leaving with the ride, nor for a reader not registered', () => {
    state.ride = ride({ groups: two(), registered: true, registeredGroupId: 'g1' })
    renderPage()
    expect(screen.queryByTestId('departure-group')).toBeNull()
    cleanup()
    state.ride = ride({ groups: two() })
    renderPage()
    expect(screen.queryByTestId('departure-group')).toBeNull()
  })

  it('carries the start place, written once on the page', () => {
    state.ride = ride({
      groups: two(),
      startPlace: { id: 'p1', name: 'Parking de la gare', startPlace: true, endPlace: false },
    } as Partial<RideDto>)
    renderPage()
    expect(within(block()).getByText('Parking de la gare')).toBeTruthy()
    expect(screen.getAllByText('Parking de la gare')).toHaveLength(1)
  })
})
