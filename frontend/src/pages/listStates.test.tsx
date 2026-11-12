import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import type { CalendarEventDto, TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'

/**
 * The states of the site's lists (audit des listes, lot 0): a failure shows « Chargement
 * impossible » with « Réessayer », never the empty state (DL11, DL12, DL13); a team that fails to
 * load on a 5xx says so instead of sending to the team list (DL14); a page past the last one says
 * so (DL15); a filtered empty state has its way out (DL20); the personal calendar filters its kind
 * (DL18).
 */

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
    Translation: ({ children }: { children: (t: typeof frenchT) => ReactNode }) =>
      children(frenchT),
  }
})
vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({ isAuthenticated: true, user: { id: 'me' } }),
}))
vi.mock('@/hooks/useCanonicalPath', () => ({ useCanonicalPath: () => {} }))
vi.mock('@/components/team/TeamLayout', () => ({
  TeamLayout: ({ children }: { children: ReactNode }) => <div>{children}</div>,
}))
vi.mock('@/components/team/TeamAdminLayout', () => ({
  TeamAdminLayout: ({ children }: { children: ReactNode }) => <div>{children}</div>,
}))
vi.mock('@/components/team/TeamInvitationList', () => ({ TeamInvitationList: () => null }))
vi.mock('@/components/tag', () => ({
  TagFilter: () => null,
  TagPicker: () => null,
  useTagLabels: () => [],
}))
vi.mock('@/components/calendar/IcsFeedSettings', () => ({ IcsFeedSettings: () => null }))
vi.mock('@/components/calendar/CalendarView', () => ({
  CalendarView: ({ events }: { events: CalendarEventDto[] }) => (
    <ul aria-label="grille">
      {events.map((event) => (
        <li key={event.id}>{event.title}</li>
      ))}
    </ul>
  ),
}))
vi.mock('@/components/route/RouteFilterPanel', () => ({ RouteFilterPanel: () => null }))
vi.mock('@/components/route/RouteViewSwitch', () => ({ RouteViewSwitch: () => null }))

/** What each mocked list or team query returns, set per test. */
const state = vi.hoisted(() => ({
  team: {} as Record<string, unknown>,
  list: {} as Record<string, unknown>,
  filters: {} as Record<string, unknown>,
  setFilters: (() => {}) as (patch: Record<string, unknown>) => void,
  templatesAsked: [] as boolean[],
}))

vi.mock('@/pages/team/teamPostsData', () => ({
  useTeamPostsData: () => ({
    filters: { page: 0, ...state.filters },
    setFilters: state.setFilters,
    team: state.team,
    publications: state.list,
    totalPages: 1,
  }),
}))
vi.mock('@/pages/team/teamAgendaData', async () => {
  const { agendaFiltersSchema } = await import('@/hooks/filters/agendaFilters')
  return {
    useTeamAgendaData: () => ({
      filters: { ...agendaFiltersSchema.parse({}), ...state.filters },
      setFilters: state.setFilters,
      team: state.team,
      publications: state.list,
      totalPages: 1,
    }),
  }
})
vi.mock('@/pages/route/routeListData', async () => {
  const { teamRouteFiltersSchema } = await import('@/hooks/filters/routeFilters')
  return {
    useRouteListData: () => ({
      filters: { ...teamRouteFiltersSchema.parse({}), ...state.filters },
      setFilters: state.setFilters,
      filtersOpen: false,
      setFiltersOpen: () => {},
      handleFiltersChange: () => {},
      handlePageChange: (page: number) => state.setFilters({ page }),
      hasFiltersOrSearch: false,
      clearFilters: () => {},
      team: state.team,
      routes: state.list,
      totalPages: 1,
    }),
  }
})
vi.mock('@/pages/ad/adListData', async () => {
  const { adFiltersSchema } = await import('@/hooks/filters/adFilters')
  return {
    useAdListData: () => ({
      filters: { ...adFiltersSchema.parse({}), ...state.filters },
      setFilters: state.setFilters,
      team: state.team,
      ads: state.list,
      totalPages: 1,
    }),
  }
})
vi.mock('@/pages/ridetemplate/rideTemplateListData', async () => {
  const { rideTemplateFiltersSchema } = await import('@/hooks/filters/rideTemplateFilters')
  return {
    useRideTemplateListData: (_slug: string, canRead: boolean) => {
      state.templatesAsked.push(canRead)
      return {
        filters: { ...rideTemplateFiltersSchema.parse({}), ...state.filters },
        setFilters: state.setFilters,
        templates: state.list,
        totalPages: 1,
      }
    },
  }
})
vi.mock('@/pages/team/teamMembersData', async () => {
  const { teamMemberFiltersSchema } = await import('@/hooks/filters/teamMemberFilters')
  return {
    useTeamMembersData: () => ({
      filters: { ...teamMemberFiltersSchema.parse({}), ...state.filters },
      setFilters: state.setFilters,
      members: state.list,
      totalPages: 1,
    }),
  }
})
vi.mock('@/pages/calendar/teamCalendarData', () => ({
  useTeamCalendarData: () => ({
    team: state.team,
    events: state.list,
    dateRange: { from: '2026-10-01T00:00:00.000Z', to: '2027-06-01T00:00:00.000Z' },
    handleDateRangeChange: () => {},
  }),
}))
vi.mock('@/api/endpoints/calendar/calendar', () => ({
  useGetEvents: () => state.list,
  useGetTeamEvents: () => state.list,
}))
vi.mock('@/components/team/teamSwitcherData', () => ({
  useTeamSwitcherTeams: () => ({ data: undefined }),
}))
vi.mock('@/api/endpoints/teams/teams', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/endpoints/teams/teams')>()),
  useGetTeam: () => state.team,
}))
vi.mock('@/pages/notification/notificationListData', () => ({
  useNotificationListData: () => ({
    filters: { page: 0, unreadOnly: false, ...state.filters },
    setFilters: state.setFilters,
    notifications: state.list,
    totalPages: 1,
  }),
}))
vi.mock('@/hooks/useNotifications', () => ({
  useNotificationActions: () => ({ markRead: () => {}, markAllRead: () => {} }),
}))
vi.mock('@/pages/team/teamListData', () => ({
  useTeamListData: () => ({
    membershipDefault: 'all',
    filters: { page: 0, membership: 'all', ...state.filters },
    setFilters: state.setFilters,
    teams: state.list,
    totalPages: 1,
  }),
}))
vi.mock('@/api/endpoints/moderation/moderation', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/endpoints/moderation/moderation')>()),
  useListMyBlockedUsers: () => state.list,
}))

import { TeamPostsPage } from './team/TeamPostsPage'
import { TeamAgendaPage } from './team/TeamAgendaPage'
import { RouteListPage } from './route/RouteListPage'
import { AdListPage } from './ad/AdListPage'
import { RideTemplateListPage } from './ridetemplate/RideTemplateListPage'
import { TeamMembersPage } from './team/TeamMembersPage'
import { TeamDirectoryPage } from './team/TeamDirectoryPage'
import { TeamCalendarPage } from './calendar/TeamCalendarPage'
import { CalendarPage } from './calendar/CalendarPage'
import { NotificationListPage } from './notification/NotificationListPage'
import { TeamListPage } from './team/TeamListPage'
import { BlockedUsers } from '@/components/profile/BlockedUsers'

const TEAM = {
  id: 't1',
  name: 'VC Craponne',
  slug: 'vc',
  about: { markdown: '', assets: {} },
  visibility: 'PUBLIC',
  enableTrips: true,
  enableAds: true,
  enablePosts: true,
  enableRides: true,
  enableRoutes: true,
  enableMemberDirectory: true,
  addMemberAllowed: false,
  memberCount: 3,
  role: 'ADMIN',
} as unknown as TeamDetailDto

const query = (over: Record<string, unknown> = {}) => ({
  data: undefined,
  isLoading: false,
  isPending: false,
  isFetching: false,
  isError: false,
  error: null,
  refetch: vi.fn(),
  ...over,
})
const failed = () => query({ isError: true, error: new Error('Network Error') })

function renderAt(element: ReactNode) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={['/equipes/vc/liste']}>
          <Routes>
            <Route path="/equipes/:teamSlug/liste" element={element} />
            <Route path={paths.teams()} element={<p>liste des équipes</p>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

beforeEach(() => {
  state.team = query({ data: TEAM })
  state.list = query()
  state.filters = {}
  state.setFilters = vi.fn()
})
afterEach(cleanup)

function expectRetryable(empty: string | RegExp) {
  expect(screen.getByText('Chargement impossible')).toBeTruthy()
  expect(screen.queryByText(empty)).toBeNull()
  fireEvent.click(screen.getByRole('button', { name: 'Réessayer' }))
  expect((state.list as { refetch: () => void }).refetch).toHaveBeenCalled()
}

describe('a failed list says so and offers « Réessayer » (DL11, DL13)', () => {
  const cases: [string, ReactNode, string | RegExp, Record<string, unknown>?][] = [
    ['team posts', <TeamPostsPage />, 'Aucune publication pour le moment'],
    ['agenda', <TeamAgendaPage />, "Rien à l'agenda pour le moment"],
    ['team routes', <RouteListPage />, 'Aucun parcours'],
    ['ads', <AdListPage />, 'Aucune annonce'],
    ['ride templates', <RideTemplateListPage />, 'Aucun modèle'],
    ['members admin', <TeamMembersPage />, 'Aucun membre trouvé.'],
    ['team calendar', <TeamCalendarPage />, 'grille'],
    ['personal calendar', <CalendarPage />, 'grille'],
    ['teams', <TeamListPage />, 'Aucune équipe'],
    ['blocked people', <BlockedUsers />, "Vous n'avez bloqué personne."],
  ]
  for (const [name, element, empty] of cases)
    it(name, () => {
      state.list = failed()
      renderAt(element)
      expectRetryable(empty)
      // The calendar grid stands in for its empty state: it is gone too.
      expect(screen.queryByRole('list', { name: 'grille' })).toBeNull()
    })
})

describe('a team that fails on a 5xx is not sent to the team list (DL14)', () => {
  const pages: [string, ReactNode][] = [
    ['team routes', <RouteListPage />],
    ['ads', <AdListPage />],
    ['members admin', <TeamMembersPage />],
    ['ride templates', <RideTemplateListPage />],
    ['team calendar', <TeamCalendarPage />],
    ['directory', <TeamDirectoryPage />],
  ]
  for (const [name, element] of pages)
    it(name, () => {
      const team = failed()
      state.team = team
      renderAt(element)
      expect(screen.getByText('Chargement impossible')).toBeTruthy()
      expect(screen.queryByText('liste des équipes')).toBeNull()
      fireEvent.click(screen.getByRole('button', { name: 'Réessayer' }))
      expect(team.refetch).toHaveBeenCalled()
    })

  it('a team that does not exist still sends to the team list', () => {
    state.team = query({ isError: false, data: undefined })
    renderAt(<RouteListPage />)
    expect(screen.getByText('liste des équipes')).toBeTruthy()
  })
})

describe('a page past the last one says so (DL15)', () => {
  const lists: [string, ReactNode, unknown, string][] = [
    ['team routes', <RouteListPage />, { routes: [], total: 3 }, 'Aucun parcours'],
    ['ride templates', <RideTemplateListPage />, { templates: [], total: 3 }, 'Aucun modèle'],
    ['members admin', <TeamMembersPage />, { members: [], total: 3 }, 'Aucun membre trouvé.'],
    ['directory', <TeamDirectoryPage />, { members: [], total: 3 }, 'Aucun membre trouvé.'],
    [
      'notifications',
      <NotificationListPage />,
      { items: [], total: 3, unreadCount: 0 },
      'Aucune notification',
    ],
  ]
  for (const [name, element, data, empty] of lists)
    it(name, () => {
      state.list = query({ data })
      state.filters = { page: 4 }
      renderAt(element)
      expect(screen.getByText("Cette page n'existe pas")).toBeTruthy()
      expect(screen.queryByText(empty)).toBeNull()
      fireEvent.click(screen.getByRole('button', { name: 'Revenir à la première page' }))
      expect(state.setFilters).toHaveBeenCalledWith({ page: 0 })
    })
})

describe('a filtered empty list has its way out (DL20, RL10)', () => {
  it('ride templates: names the search, « Effacer les filtres »', () => {
    state.list = query({ data: { templates: [], total: 0 } })
    state.filters = { search: 'col' }
    renderAt(<RideTemplateListPage />)
    expect(screen.getByRole('heading', { name: 'Aucun modèle pour ces filtres' })).toBeTruthy()
    expect(screen.getByText('Rien ne correspond à : « col ».')).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Effacer les filtres' }))
    expect(state.setFilters).toHaveBeenCalledWith({ search: undefined, page: 0 })
  })

  it('members admin: « Effacer les filtres »', () => {
    state.list = query({ data: { members: [], total: 0 } })
    state.filters = { role: 'ORGANIZER' }
    renderAt(<TeamMembersPage />)
    fireEvent.click(screen.getByRole('button', { name: 'Effacer les filtres' }))
    expect(state.setFilters).toHaveBeenCalledWith({ search: undefined, role: undefined, page: 0 })
  })
})

describe('the personal calendar filters its kind (DL18)', () => {
  const events = [
    { id: 'r', title: 'Sortie du mardi', type: 'RIDE' },
    { id: 's', title: 'Étape 1', type: 'TRIP_STAGE' },
  ] as CalendarEventDto[]

  it('« Sorties » keeps the rides, « Voyages » the stages', () => {
    state.list = query({ data: { events } })
    const { unmount } = render(
      <MantineProvider>
        <MemoryRouter initialEntries={['/calendrier?type=ride']}>
          <CalendarPage />
        </MemoryRouter>
      </MantineProvider>
    )
    expect(screen.getByText('Sortie du mardi')).toBeTruthy()
    expect(screen.queryByText('Étape 1')).toBeNull()
    expect(screen.getByRole('radio', { name: 'Sorties' })).toBeTruthy()
    unmount()

    render(
      <MantineProvider>
        <MemoryRouter initialEntries={['/calendrier?type=trip']}>
          <CalendarPage />
        </MemoryRouter>
      </MantineProvider>
    )
    expect(screen.queryByText('Sortie du mardi')).toBeNull()
    expect(screen.getByText('Étape 1')).toBeTruthy()
  })
})

describe('a count under every paginated list, masked at zero (RL8, RL5)', () => {
  const lists: [string, ReactNode, unknown, string][] = [
    ['teams, mine by name', <TeamListPage />, { teams: [], total: 0 }, ''],
    ['ride templates', <RideTemplateListPage />, { templates: [], total: 47 }, '47 modèles'],
    ['members admin', <TeamMembersPage />, { members: [], total: 24 }, '24 membres'],
    ['directory', <TeamDirectoryPage />, { members: [], total: 24 }, '24 membres'],
  ]
  for (const [name, element, data, count] of lists)
    it(name, () => {
      state.list = query({ data })
      state.filters = { page: 4 }
      renderAt(element)
      if (count) expect(screen.getByText(count)).toBeTruthy()
      else expect(screen.queryByText(/^0 équipe/)).toBeNull()
    })

  it('teams: the order follows the scope, said beside the count', () => {
    state.list = query({ data: { teams: [], total: 2 } })
    state.filters = { page: 4, membership: 'member' }
    const { unmount } = renderAt(<TeamListPage />)
    expect(screen.getByText('2 équipes · triées par nom')).toBeTruthy()
    unmount()
    state.filters = { page: 4, membership: 'all' }
    renderAt(<TeamListPage />)
    expect(screen.getByText('2 équipes · triées par nombre de membres')).toBeTruthy()
  })
})

describe('the agenda’s filtered empty state names its filters (RL10)', () => {
  it('« Je participe » is a filter; one gesture lifts everything', () => {
    state.list = query({ data: { publications: [], total: 0, upcomingTotal: 0 } })
    state.filters = { scope: 'me', filter: 'trip', search: 'monts' }
    renderAt(<TeamAgendaPage />)
    expect(screen.getByRole('heading', { name: 'Aucun voyage pour ces filtres' })).toBeTruthy()
    expect(
      screen.getByText('Rien ne correspond à : « monts » · Je participe · Voyages.')
    ).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Effacer les filtres' }))
    expect(state.setFilters).toHaveBeenCalledWith({
      search: undefined,
      filter: 'all',
      scope: 'all',
      tags: undefined,
      page: 0,
    })
  })

  it('the absolute empty state offers to create, for whoever may', () => {
    state.list = query({ data: { publications: [], total: 0 } })
    renderAt(<TeamAgendaPage />)
    expect(screen.getByRole('heading', { name: "Rien à l'agenda pour le moment" })).toBeTruthy()
    expect(screen.getAllByRole('link', { name: 'Créer une sortie' })).toHaveLength(2)
  })
})

describe('the ride templates are not asked for a plain member (DL23)', () => {
  it('asks once the reader organizes, never before nor for a member', () => {
    state.templatesAsked = []
    state.team = query({ data: { ...TEAM, role: 'MEMBER' } })
    const { unmount } = renderAt(<RideTemplateListPage />)
    expect(state.templatesAsked.every((asked) => !asked)).toBe(true)
    unmount()

    state.templatesAsked = []
    state.team = query({ data: TEAM })
    renderAt(<RideTemplateListPage />)
    expect(state.templatesAsked).toContain(true)
  })
})

describe('a list being replaced stays, dimmed (RL11)', () => {
  it('ads: the previous page under a busy veil', () => {
    state.list = query({
      data: { ads: [], total: 0 },
      isPlaceholderData: true,
    })
    state.filters = { search: 'vélo' }
    renderAt(<AdListPage />)
    const heading = screen.getByRole('heading', { name: 'Aucune annonce pour ces filtres' })
    expect(heading.closest('[aria-busy="true"]')).not.toBeNull()
  })
})

describe('the agenda reads in two sections, « À venir » then « Plus tôt » (RL15)', () => {
  it('each section under its heading with its count; no list count, no period « Passées »', async () => {
    const { ride } = await import('@/dev/cardGallery/fixtures')
    state.list = query({
      data: {
        publications: [
          ride({}, { id: 'a', name: 'Sortie à venir' }),
          ride({}, { id: 'b', name: 'Sortie finie' }),
        ],
        total: 30,
        upcomingTotal: 1,
        page: 0,
        size: 12,
      },
    })
    renderAt(<TeamAgendaPage />)
    const upcoming = screen.getByRole('region', { name: 'À venir' })
    expect(upcoming.textContent).toContain('1 sortie ou voyage')
    expect(upcoming.textContent).toContain('Sortie à venir')
    const earlier = screen.getByRole('region', { name: 'Plus tôt' })
    expect(earlier.textContent).toContain('29 sorties et voyages')
    expect(earlier.textContent).toContain('Sortie finie')
    expect(screen.queryByText(/sorties et voyages à venir/)).toBeNull()
    // The bar: « Toutes les dates / Je participe », the search in sight, no panel (RL6).
    expect(screen.getByRole('radio', { name: 'Toutes les dates' })).toBeTruthy()
    expect(screen.getByRole('radio', { name: 'Je participe' })).toBeTruthy()
    expect(screen.queryByRole('radio', { name: 'Passées' })).toBeNull()
    expect(screen.queryByRole('button', { name: /^Filtres/ })).toBeNull()
    expect(screen.getByRole('searchbox', { name: "Rechercher dans l'agenda" })).toBeTruthy()
  })

  it('a page that opens past « À venir » repeats the heading of « Plus tôt » alone', async () => {
    const { ride } = await import('@/dev/cardGallery/fixtures')
    state.list = query({
      data: {
        publications: [ride({}, { id: 'c' })],
        total: 40,
        upcomingTotal: 5,
        page: 2,
        size: 12,
      },
    })
    state.filters = { page: 2 }
    renderAt(<TeamAgendaPage />)
    expect(screen.queryByRole('region', { name: 'À venir' })).toBeNull()
    expect(screen.getByRole('region', { name: 'Plus tôt' }).textContent).toContain(
      '35 sorties et voyages'
    )
  })

  it('the absolute empty state no longer sends to « Voir les passées »', () => {
    state.list = query({ data: { publications: [], total: 0, upcomingTotal: 0 } })
    renderAt(<TeamAgendaPage />)
    expect(screen.queryByRole('button', { name: 'Voir les passées' })).toBeNull()
  })
})

describe('the teams offer « Ouvertes à l’adhésion » under « Toutes les équipes » (RL3)', () => {
  it('shown under « Toutes les équipes », hidden under « Membre »', () => {
    state.list = query({ data: { teams: [], total: 0 } })
    state.filters = { membership: 'all' }
    const { unmount } = renderAt(<TeamListPage />)
    fireEvent.click(screen.getByRole('checkbox', { name: "Ouvertes à l'adhésion" }))
    expect(state.setFilters).toHaveBeenCalledWith({ joinable: true })
    unmount()
    state.filters = { membership: 'member' }
    renderAt(<TeamListPage />)
    expect(screen.queryByRole('checkbox', { name: "Ouvertes à l'adhésion" })).toBeNull()
  })

  it('is a filter « Effacer les filtres » lifts', () => {
    state.list = query({ data: { teams: [], total: 0 } })
    state.filters = { membership: 'all', joinable: true }
    renderAt(<TeamListPage />)
    expect(screen.getByText("Rien ne correspond à : Ouvertes à l'adhésion.")).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Effacer les filtres' }))
    expect(state.setFilters).toHaveBeenCalledWith({
      search: undefined,
      membership: 'all',
      joinable: false,
      page: 0,
    })
  })
})

describe('a criterion has one form on the site, a segmented control (RL6)', () => {
  it('notifications: « Toutes / Non lues »', () => {
    state.list = query({ data: { items: [], total: 0, unreadCount: 0 } })
    renderAt(<NotificationListPage />)
    expect(screen.getByRole('radio', { name: 'Toutes' })).toBeTruthy()
    expect(screen.getByRole('radio', { name: 'Non lues' })).toBeTruthy()
    expect(screen.queryByRole('switch')).toBeNull()
  })

  it('ads: the kind', () => {
    state.list = query({ data: { ads: [], total: 0 } })
    renderAt(<AdListPage />)
    const kinds = screen.getByRole('radiogroup', { name: 'Filtrer par type' })
    expect(kinds.textContent).toContain('Vente')
  })
})
