import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { RideDto, RideGroupDto, RideWeatherDto, TeamDetailDto } from '@/api/dto'
import { Status } from '@/api/dto'
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
  RoutesMapView: () => <div data-testid="routes-map" />,
}))
vi.mock('@/components/route/RouteMapView', () => ({
  RouteMapView: () => <div data-testid="route-map" />,
}))
vi.mock('@/components/comment', () => ({ CommentSection: () => null }))
vi.mock('@/components/moderation/ContentActionsMenu', () => ({ ContentActionsMenu: () => null }))
vi.mock('@/components/team/TeamContextBanner', () => ({ TeamContextBanner: () => null }))
vi.mock('@/components/common/MediaDisplay', () => ({ MediaDisplay: () => null }))

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
    media: { markdown: '', assets: {} },
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
    expect(plain(screen.getByTestId('group-places').textContent)).toContain('11/12 participants')
    const stats = plain(screen.getByTestId('group-stats').textContent)
    expect(stats).toContain('28 km/h')
    expect(stats).toContain('avec la sortie')
    expect(stats).toContain('Arrivée estimée')
    expect(screen.getByTestId('participant-list').textContent).toBe('g1')
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
    expect(screen.queryByText('Meneur')).toBeNull()
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

  it("unrolls the group's weather under #meteo", () => {
    const { container } = renderPage()
    const weather = container.querySelector('#meteo')
    expect(weather?.textContent).toContain('Météo au départ')
    expect(weather?.textContent).toContain('Exposition au vent')
  })

  it('keeps one linked card per group on a ride with two', async () => {
    state.ride = ride({ groups: [group(), group({ id: 'g2', name: 'Cool' })] })
    state.weather = okWeather
    renderPage()
    expect(screen.getByRole('link', { name: 'Rapide' })).toBeTruthy()
    expect(screen.getByRole('link', { name: 'Cool' })).toBeTruthy()
    expect(screen.queryByTestId('group-stats')).toBeNull()
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
