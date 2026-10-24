import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type {
  RideDto,
  RideGroupDto,
  RideWeatherDto,
  RouteDetailDto,
  TeamDetailDto,
} from '@/api/dto'
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
  routes: new Map<string, unknown>(),
  isAuthenticated: true,
  join: (() => {}) as (groupId: string) => void,
  leave: (() => {}) as (groupId: string) => void,
}))

vi.mock('./rideGroupData', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./rideGroupData')>()),
  useRideGroupData: (_team: string, _ride: string, groupId: string) => {
    const ride = state.ride as RideDto | undefined
    const weather = state.weather as RideWeatherDto | undefined
    return {
      team: { data: state.team, isLoading: false },
      ride: { data: ride, isLoading: false, error: null, refetch: () => {} },
      weather: {
        data: weather,
        isLoading: false,
        isFetching: false,
        refetch: () => {},
      },
      routes: { data: undefined },
      routesBySlug: state.routes,
      group: ride?.groups.find((g) => g.id === groupId),
      leg: weather?.legs.find((l) => l.groupId === groupId),
    }
  },
}))
vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({ isAuthenticated: state.isAuthenticated }),
}))
vi.mock('@/hooks/useRideGroupMembership', () => ({
  useRideGroupMembership: () => ({
    join: (groupId: string) => state.join(groupId),
    leave: (groupId: string) => state.leave(groupId),
    isPending: false,
    error: null,
  }),
}))
vi.mock('@/components/ride/ParticipantList', () => ({
  ParticipantList: (props: { source: { groupId?: string }; searchPlaceholder?: string }) => (
    <div data-testid="participant-list">
      {props.source.groupId} {props.searchPlaceholder}
    </div>
  ),
}))
// The map is lazy and pulls map vendors: a stand-in saying whether the wind colours the line,
// where its fullscreen button leads, and holding the forecast's badges it is handed.
vi.mock('@/components/route/RouteMapView', () => ({
  RouteMapView: ({
    lineColorAt,
    fullscreenPath,
    overlays,
  }: {
    lineColorAt?: unknown
    fullscreenPath?: string
    overlays?: React.ReactNode
  }) => (
    <>
      <div data-testid="map">{lineColorAt ? 'wind' : 'plain'}</div>
      <span data-testid="map-fullscreen">{fullscreenPath}</span>
      {overlays}
    </>
  ),
}))
// The badges pull react-map-gl: a stand-in saying which popup is open, and a badge to press.
vi.mock('@/components/weather/WeatherCheckpointMarkers', () => ({
  WeatherCheckpointMarkers: ({
    openIndex,
    onOpenChange,
  }: {
    openIndex?: number | null
    onOpenChange?: (index: number | null) => void
  }) => (
    <>
      <span data-testid="markers-open">{String(openIndex)}</span>
      <button type="button" onClick={() => onOpenChange?.(1)}>
        Pastille 1
      </button>
      <button type="button" onClick={() => onOpenChange?.(null)}>
        Fermer la bulle
      </button>
    </>
  ),
}))
vi.mock('@/components/ride/RideGroupRouteActions', () => ({
  RideGroupRouteActions: () => <div data-testid="route-actions" />,
}))

import { RideGroupPage } from './RideGroupPage'

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

/** The other group: the page is a ride's with several groups (WEB-79: a solo ride has none). */
const cool = () => group({ id: 'g2', name: 'Cool', countParticipants: 4 })

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
    groups: [group(), cool()],
    ...overrides,
  }) as RideDto

const member = { slug: 'np', name: 'N Peloton', role: 'MEMBER' } as TeamDetailDto

/** Where a solo ride's group page leads: the ride's, its URL in full. */
function RideProbe() {
  const location = useLocation()
  return <div data-testid="ride-page">{location.pathname + location.search + location.hash}</div>
}

function pageTree(groupId = 'g1', suffix = '') {
  return (
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[paths.rideGroup('np', 'sortie', groupId) + suffix]}>
          <Routes>
            {Object.values(pathVariants.ride(':teamSlug', ':rideSlug')).map((path) => (
              <Route key={path} path={path} element={<RideProbe />} />
            ))}
            {Object.values(pathVariants.rideGroup(':teamSlug', ':rideSlug', ':groupId')).map(
              (path) => (
                <Route key={path} path={path} element={<RideGroupPage />} />
              )
            )}
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

function renderPage(groupId = 'g1', suffix = '') {
  return render(pageTree(groupId, suffix))
}

describe('RideGroupPage (WEB-77)', () => {
  beforeEach(() => {
    state.team = member
    state.ride = ride()
    state.weather = okWeather
    state.routes = new Map()
    state.isAuthenticated = true
    state.join = vi.fn()
    state.leave = vi.fn()
  })
  afterEach(cleanup)

  it('titles the group under its ride, with its places, stats and participants', () => {
    renderPage()
    expect(screen.getByRole('heading', { level: 1, name: 'Groupe Rapide' })).toBeTruthy()
    const text = plain(document.body.textContent)
    expect(text).toContain('Sortie du samedi · ')
    expect(text).toContain('11/12 personnes')
    expect(text).toContain('1 place restante')
    expect(text).toContain('Départ')
    expect(text).toContain('avec la sortie')
    expect(text).toContain('Allure moyenne')
    expect(text).toContain('28 km/h')
    expect(text).toContain('Dénivelé positif')
    expect(screen.getByRole('link', { name: /Retour à la sortie/ })).toBeTruthy()
    expect(plain(screen.getByTestId('participant-list').textContent)).toBe('g1 Rechercher par nom…')
  })

  it('leaves out a stat the group does not have', () => {
    state.ride = ride({
      groups: [
        group({ averageSpeed: undefined, elevationGain: undefined, maxParticipants: undefined }),
        cool(),
      ],
    })
    renderPage()
    const text = plain(document.body.textContent)
    expect(text).not.toContain('Allure moyenne')
    expect(text).not.toContain('Dénivelé positif')
    expect(text).toContain('Distance')
    expect(screen.queryByTestId('group-places')).toBeNull()
  })

  it('says when the group leaves before or after the ride', () => {
    state.ride = ride({ groups: [group({ startAt: '2026-10-08T07:10:00Z' }), cool()] })
    renderPage()
    expect(plain(document.body.textContent)).toContain('après la sortie')
  })

  it('renders no leader when the group has none — never the ride creator', () => {
    state.ride = ride({
      createdBy: { id: 'u9', displayName: 'Créatrice de la sortie' },
    } as Partial<RideDto>)
    renderPage()
    expect(screen.queryByTestId('group-leader')).toBeNull()
    expect(screen.queryByText('Capitaine')).toBeNull()
    expect(screen.queryByText('Créatrice de la sortie')).toBeNull()
  })

  it('renders the designated leader', () => {
    state.ride = ride({
      groups: [
        group({ leader: { id: 'u1', displayName: 'Léa Meneuse' } as RideGroupDto['leader'] }),
        cool(),
      ],
    })
    renderPage()
    const leader = plain(screen.getByTestId('group-leader').textContent)
    expect(leader).toContain('Léa Meneuse')
    expect(leader).toContain('Capitaine')
  })

  it('offers a member « Rejoindre », the one filled button', () => {
    renderPage()
    fireEvent.click(screen.getByRole('button', { name: 'Rejoindre' }))
    expect(state.join).toHaveBeenCalledWith('g1')
    expect(screen.queryByRole('button', { name: 'Quitter' })).toBeNull()
  })

  it('offers « Quitter » to a rider of the group', () => {
    state.ride = ride({
      registered: true,
      registeredGroupId: 'g1',
      groups: [group({ registered: true }), cool()],
    })
    renderPage()
    expect(screen.getByText("J'y vais")).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Quitter' }))
    expect(state.leave).toHaveBeenCalledWith('g1')
    expect(screen.queryByRole('button', { name: 'Rejoindre' })).toBeNull()
  })

  it('offers nothing but its badge on a full group', () => {
    state.ride = ride({ groups: [group({ full: true, countParticipants: 12 }), cool()] })
    renderPage()
    expect(screen.getByText('Complet')).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'Rejoindre' })).toBeNull()
    expect(plain(document.body.textContent)).toContain('Aucune place restante')
  })

  it('tells a rider of another group where they are, and offers no join (one group per ride)', () => {
    state.ride = ride({ registered: true, registeredGroupId: 'g2' })
    renderPage()
    expect(screen.queryByRole('button', { name: 'Rejoindre' })).toBeNull()
    const notice = screen.getByTestId('registered-elsewhere')
    expect(plain(notice.textContent)).toContain('Votre inscription est dans le groupe Cool.')
    expect(notice.querySelector('a')?.getAttribute('href')).toMatch(/\/(groupes|groups)\/g2$/)
  })

  it('invites a signed-out visitor to sign in, with no join', () => {
    state.isAuthenticated = false
    state.team = { ...member, role: undefined }
    renderPage()
    expect(screen.getByText(/Connectez-vous pour rejoindre ce groupe/)).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'Rejoindre' })).toBeNull()
  })

  it('offers no join on a finished ride', () => {
    state.ride = ride({ finished: true })
    renderPage()
    expect(screen.queryByRole('button', { name: 'Rejoindre' })).toBeNull()
  })

  it("holds the group's whole weather under #meteo, and none on a finished ride", () => {
    const { container } = renderPage()
    const weather = container.querySelector('#meteo')
    expect(weather?.textContent).toContain('Météo du parcours')
    expect(weather?.querySelector('[aria-label="Le vent, tronçon par tronçon"]')).not.toBeNull()
    expect(weather?.textContent).toContain('Heure par heure, à votre passage')
    cleanup()
    state.ride = ride({ finished: true })
    const { container: finished } = renderPage()
    expect(finished.querySelector('#meteo section')).toBeNull()
  })

  describe('the wind on the map (WEB-115)', () => {
    const boucle = {
      waypoints: [],
      tracks: [
        {
          line: {
            type: 'LineString',
            coordinates: Array.from({ length: 6 }, (_, i) => [5, 45 + i * 0.09, 300, i * 10_000]),
          },
          climbs: [],
        },
      ],
    } as unknown as RouteDetailDto

    const weatherWith = (status: WeatherStatus): RideWeatherDto => ({
      ...okWeather,
      status,
      legs: [weatherLeg('g1', { status }), weatherLeg('g2')],
    })

    /** The map is lazy: under a loaded full run its stand-in can take more than the default second. */
    const findMap = () => screen.findByTestId('map', {}, { timeout: 5_000 })

    beforeEach(() => {
      state.routes = new Map([['boucle', boucle]])
    })

    it('offers « Météo » beside « Pente » when the group has a forecast', async () => {
      renderPage()
      expect((await findMap()).textContent).toBe('plain')
      fireEvent.click(screen.getByLabelText('Météo'))
      expect(screen.getByTestId('map').textContent).toBe('wind')
      expect(screen.getByTestId('wind-map-legend')).toBeTruthy()
    })

    it('offers it on an old forecast, flagged as such', async () => {
      state.weather = weatherWith(WeatherStatus.STALE)
      renderPage()
      await findMap()
      fireEvent.click(screen.getByLabelText('Météo'))
      expect(plain(screen.getByTestId('wind-map-legend').textContent)).toContain(
        'Prévision ancienne'
      )
    })

    it('offers nothing before the forecast opens', async () => {
      state.weather = weatherWith(WeatherStatus.NOT_YET_AVAILABLE)
      renderPage()
      await findMap()
      expect(screen.queryByLabelText('Météo')).toBeNull()
      expect(screen.queryByTestId('route-color-by')).toBeNull()
    })

    /** The « Heure par heure » table's columns, one button per point. */
    const columns = () =>
      within(screen.getByRole('group', { name: 'Prévisions à chaque passage' })).getAllByRole(
        'button'
      )

    it('opens its own fullscreen map, in the mode the line is in (WEB-117)', async () => {
      renderPage()
      await findMap()
      const map = paths.rideGroupMap('np', 'sortie', 'g1')
      expect(screen.getByTestId('map-fullscreen').textContent).toBe(map)
      fireEvent.click(screen.getByLabelText('Météo'))
      expect(screen.getByTestId('map-fullscreen').textContent).toBe(`${map}?color=wind`)
    })

    it("lights the table's row on the map in the Météo mode, never switching to it (WEB-117)", async () => {
      renderPage()
      await findMap()
      fireEvent.click(columns()[1])
      // Still on the grade: nothing switched by itself
      expect(screen.getByTestId('map').textContent).toBe('plain')
      expect(screen.queryByTestId('markers-open')).toBeNull()
      fireEvent.click(screen.getByLabelText('Météo'))
      expect((await screen.findByTestId('markers-open')).textContent).toBe('1')
      fireEvent.click(columns()[0])
      expect(screen.getByTestId('markers-open').textContent).toBe('0')
    })

    it("selects a badge's row in the table, and keeps it when its popup closes (WEB-117)", async () => {
      renderPage()
      await findMap()
      fireEvent.click(screen.getByLabelText('Météo'))
      expect((await screen.findByTestId('markers-open')).textContent).toBe('null')
      expect(columns()[0].getAttribute('aria-pressed')).toBe('true')
      fireEvent.click(screen.getByRole('button', { name: 'Pastille 1' }))
      expect(screen.getByTestId('markers-open').textContent).toBe('1')
      expect(columns()[1].getAttribute('aria-pressed')).toBe('true')
      fireEvent.click(screen.getByRole('button', { name: 'Fermer la bulle' }))
      expect(screen.getByTestId('markers-open').textContent).toBe('null')
      expect(columns()[1].getAttribute('aria-pressed')).toBe('true')
    })

    it('offers nothing on a finished or cancelled ride', async () => {
      state.ride = ride({ finished: true })
      renderPage()
      await findMap()
      expect(screen.queryByLabelText('Météo')).toBeNull()
      cleanup()
      state.ride = ride({ status: Status.CANCELLED })
      renderPage()
      await findMap()
      expect(screen.queryByLabelText('Météo')).toBeNull()
    })
  })

  it('switches group by going to its page', () => {
    renderPage()
    expect(screen.getByText('Cool · 4/12')).toBeTruthy()
    fireEvent.click(screen.getByText('Cool · 4/12'))
    expect(screen.getByRole('heading', { level: 1, name: 'Groupe Cool' })).toBeTruthy()
  })

  it('says a group the ride no longer has is gone, with a way back to the ride', () => {
    renderPage('gone')
    expect(screen.getByText("Ce groupe n'existe plus")).toBeTruthy()
    expect(screen.getByRole('link', { name: 'Retour à la sortie' })).toBeTruthy()
  })

  describe('a ride with at most one group has no group page (WEB-79)', () => {
    it("replaces a solo ride's group URL with the ride's, query string and #meteo kept", async () => {
      state.ride = ride({ groups: [group()] })
      renderPage('g1', '?q=a#meteo')
      const probe = await screen.findByTestId('ride-page')
      expect(probe.textContent).toBe(paths.ride('np', 'sortie') + '?q=a#meteo')
    })

    it('never shows the group page meanwhile', () => {
      state.ride = ride({ groups: [group()] })
      renderPage()
      expect(screen.queryByRole('heading', { level: 1, name: 'Groupe Rapide' })).toBeNull()
      expect(screen.queryByText("Ce groupe n'existe plus")).toBeNull()
    })

    it('leaves for the ride from a group a solo ride does not have, or a ride without groups', async () => {
      state.ride = ride({ groups: [group()] })
      renderPage('gone')
      expect((await screen.findByTestId('ride-page')).textContent).toBe(paths.ride('np', 'sortie'))
      cleanup()
      state.ride = ride({ groups: [] })
      renderPage('g1')
      expect((await screen.findByTestId('ride-page')).textContent).toBe(paths.ride('np', 'sortie'))
    })

    it('still leaves when the ride, first read with two groups, comes back with one', async () => {
      const { rerender } = renderPage()
      expect(screen.getByRole('heading', { level: 1, name: 'Groupe Rapide' })).toBeTruthy()
      state.ride = ride({ groups: [group()] })
      rerender(pageTree())
      expect((await screen.findByTestId('ride-page')).textContent).toBe(paths.ride('np', 'sortie'))
    })
  })
})
