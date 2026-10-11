import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type {
  AdDto,
  PostDto,
  RideDto,
  RideGroupSummaryDto,
  RideTemplateListResponse,
  TeamDashboardDto,
  TeamDetailDto,
  TeamRole,
  TripDto,
} from '@/api/dto'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => false }))
vi.mock('@/hooks/useGpsConnections', () => ({
  useGpsConnections: () => ({ connectedServices: [], uploadRoute: vi.fn(), isUploading: false }),
}))

// Keys and their count, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: { count?: number }) =>
      options?.count !== undefined ? `${key}:${options.count}` : key,
    i18n: { language: 'fr' },
  }),
}))

import { TeamDashboard } from './TeamDashboard'
import { paths } from '@/config/paths'

const TEAM_REF = {
  id: 't1',
  name: 'VC Craponne',
  slug: 'vc-craponne',
  visibility: 'PUBLIC',
} as const
const MEDIA = { markdown: '', assets: { images: [], attachments: [] } }

function team(overrides: Partial<TeamDetailDto> = {}): TeamDetailDto {
  return {
    ...TEAM_REF,
    about: MEDIA,
    enableTrips: true,
    enableAds: true,
    enablePosts: true,
    enableRides: true,
    enableRoutes: true,
    enableMemberDirectory: false,
    postsAsTeamByDefault: false,
    visibilityEditable: true,
    joinable: true,
    addMemberAllowed: true,
    enableRoutePlanner: false,
    memberCount: 12,
    upcomingRideCount: 1,
    routeCount: 0,
    upcomingTripCount: 0,
    recentPostCount: 0,
    createdAt: '2026-01-01T00:00:00Z',
    ...overrides,
  } as TeamDetailDto
}

function group(overrides: Partial<RideGroupSummaryDto>): RideGroupSummaryDto {
  return {
    id: 'g1',
    name: 'Groupe A',
    averageSpeed: 30,
    countParticipants: 14,
    maxParticipants: 14,
    full: true,
    sortOrder: 0,
    startAt: '2026-10-10T06:30:00Z',
    ...overrides,
  }
}

function ride(overrides: Partial<RideDto> = {}): RideDto {
  return {
    type: 'RIDE',
    team: TEAM_REF,
    id: 'r1',
    slug: 'sortie-du-samedi',
    name: 'Sortie du samedi',
    media: MEDIA,
    dateTime: '2026-10-10T06:30:00Z',
    timezone: 'Europe/Paris',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    participantCount: 20,
    groupCount: 2,
    groups: [],
    groupSummaries: [
      group({ id: 'g1', name: 'Groupe A', routeSlug: 'monts-d-or' }),
      group({
        id: 'g2',
        name: 'Groupe B',
        countParticipants: 6,
        maxParticipants: 16,
        full: false,
        sortOrder: 1,
      }),
    ],
    distance: 72000,
    elevationGain: 980,
    surfaceType: 'ROAD',
    topParticipants: [],
    deleted: false,
    registered: false,
    full: false,
    commentCount: 2,
    tags: [],
    ...overrides,
  } as RideDto
}

function post(): PostDto {
  return {
    type: 'POST',
    team: TEAM_REF,
    id: 'p1',
    slug: 'bilan',
    name: 'Bilan de la saison',
    media: MEDIA,
    excerpt: 'Assemblée générale le 6 novembre.',
    dateTime: '2026-10-02T10:00:00Z',
    timezone: 'Europe/Paris',
    status: 'PUBLISHED',
    visibility: 'TEAM',
    deleted: false,
    signedAsTeam: false,
    createdBy: { id: 'u1', displayName: 'Martine L.' },
    commentCount: 4,
    tags: [],
  } as PostDto
}

function trip(): TripDto {
  return {
    type: 'TRIP',
    team: TEAM_REF,
    id: 'tr1',
    slug: 'jura',
    name: 'Traversée du Jura',
    media: MEDIA,
    dateTime: '2026-10-23T06:00:00Z',
    timezone: 'Europe/Paris',
    endDate: '2026-10-25T16:00:00Z',
    endDateTime: '2026-10-25T19:00:00Z',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    participantCount: 8,
    stageCount: 3,
    stages: [],
    participants: [],
    deleted: false,
    registered: true,
    tags: [],
  } as TripDto
}

function ad(price?: number): AdDto {
  return {
    team: TEAM_REF,
    id: price === undefined ? 'a2' : 'a1',
    slug: price === undefined ? 'porte-velos' : 'roues',
    name: price === undefined ? 'Porte-vélos' : 'Roues carbone',
    media: MEDIA,
    images: [],
    status: 'PUBLISHED',
    visibility: 'TEAM',
    adType: price === undefined ? 'WANTED' : 'SALE',
    price,
    locationDescription: 'Caluire-et-Cuire',
    createdAt: '2026-10-01T10:00:00Z',
    updatedAt: '2026-10-01T10:00:00Z',
    createdById: 'u2',
    createdByDisplayName: 'Karim B.',
    deleted: false,
    tags: [],
  } as AdDto
}

const page = <T,>(publications: T[]) => ({
  publications,
  total: publications.length,
  page: 0,
  size: 3,
})

/** A dashboard as the API builds it for `role`: the organizer and admin blocks only above MEMBER. */
function dashboard(role: TeamRole, overrides: Partial<TeamDashboardDto> = {}): TeamDashboardDto {
  const isOrganizer = role !== 'MEMBER'
  return {
    team: team({
      role,
      memberCountByRole: role === 'ADMIN' ? { admins: 2, organizers: 3, members: 7 } : undefined,
    }),
    role,
    myUpcoming: page([ride({ id: 'r0', registered: true }), trip()]),
    upcomingRides: page([ride()]),
    latestPosts: page([post()]),
    newRoutes: { routes: [], total: 0, page: 0, size: 3 },
    latestAds: { ads: [ad(650), ad(undefined)], total: 2, page: 0, size: 3 },
    organizer: isOrganizer
      ? {
          drafts: page([ride({ id: 'd1', name: 'Brouillon de sortie', status: 'DRAFT' })]),
          ridesWithoutRoute: page([]),
          ridesWithFullGroup: page([ride()]),
          reports: {
            openCount: 1,
            latestReason: 'SPAM',
            latestTargetType: 'COMMENT',
            latestExcerpt: 'Achetez',
          },
          rideTemplates: {
            templates: [{ id: 'tp1', slug: 'samedi', name: 'Modèle du samedi', groupCount: 3 }],
            total: 1,
            page: 0,
            size: 5,
          } as unknown as RideTemplateListResponse,
        }
      : undefined,
    admin:
      role === 'ADMIN'
        ? {
            newestMembers: {
              members: [
                {
                  team: TEAM_REF,
                  id: 'm1',
                  user: { id: 'u3', displayName: 'Léa Martin' },
                  role: 'MEMBER',
                  joinedAt: '2026-10-04T10:00:00Z',
                },
              ],
              total: 12,
              page: 0,
              size: 3,
            },
            webhook: { configured: true, kind: 'DISCORD', enabled: true, lastStatus: 'SENT' },
          }
        : undefined,
    ...overrides,
  } as TeamDashboardDto
}

function renderDashboard(dto: TeamDashboardDto) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <TeamDashboard dashboard={dto} />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const heading = (key: string) => screen.queryByRole('heading', { name: key })

describe('team dashboard, by role', () => {
  afterEach(cleanup)

  it('a member gets the shared sections and nothing to manage', () => {
    renderDashboard(dashboard('MEMBER'))

    expect(heading('teams.dashboard.myUpcoming.title')).toBeInTheDocument()
    expect(heading('teams.dashboard.upcomingRides.title')).toBeInTheDocument()
    expect(heading('teams.dashboard.posts.title')).toBeInTheDocument()
    expect(heading('teams.dashboard.ads.title')).toBeInTheDocument()

    expect(heading('teams.dashboard.todo.title')).not.toBeInTheDocument()
    expect(heading('teams.dashboard.templates.title')).not.toBeInTheDocument()
    expect(heading('teams.dashboard.admin.title')).not.toBeInTheDocument()
    expect(screen.queryByText('teams.dashboard.ride.edit')).not.toBeInTheDocument()
    // Not registered: the card leads to the ride page to register.
    expect(screen.getByText('teams.dashboard.ride.register')).toBeInTheDocument()
  })

  it('an organizer also gets « À traiter », the templates and « Modifier », not the administration', () => {
    renderDashboard(dashboard('ORGANIZER'))

    const todo = screen.getByRole('region', { name: 'teams.dashboard.todo.title' })
    expect(within(todo).getByText('teams.dashboard.todo.drafts:1')).toBeInTheDocument()
    expect(within(todo).getByText('Brouillon de sortie')).toBeInTheDocument()
    // The reports tile is for organizers too (same audience as the moderation queue).
    expect(within(todo).getByText('teams.dashboard.todo.reports:1')).toBeInTheDocument()
    expect(within(todo).getByText('teams.dashboard.todo.withoutRouteNone')).toBeInTheDocument()

    expect(heading('teams.dashboard.templates.title')).toBeInTheDocument()
    expect(screen.getByText('Modèle du samedi')).toBeInTheDocument()
    expect(screen.getAllByText('teams.dashboard.ride.edit').length).toBeGreaterThan(0)
    expect(heading('teams.dashboard.admin.title')).not.toBeInTheDocument()
  })

  it('an administrator gets the administration panel, members split by role', () => {
    renderDashboard(dashboard('ADMIN'))

    const admin = screen.getByRole('region', { name: 'teams.dashboard.admin.title' })
    expect(within(admin).getByText('teams.dashboard.admin.admins:2')).toBeInTheDocument()
    expect(within(admin).getByText('teams.dashboard.admin.organizers:3')).toBeInTheDocument()
    expect(within(admin).getByText('teams.dashboard.admin.members:7')).toBeInTheDocument()
    expect(within(admin).getByText('Léa Martin')).toBeInTheDocument()
    expect(within(admin).getByText('teams.dashboard.admin.webhookActive')).toBeInTheDocument()
    expect(within(admin).getByText('teams.dashboard.admin.invite')).toBeInTheDocument()
    expect(heading('teams.dashboard.todo.title')).toBeInTheDocument()
  })

  it('never shows a block above the role, even when the payload carries it', () => {
    const stale = dashboard('ADMIN')
    renderDashboard({ ...stale, role: 'MEMBER' })

    expect(heading('teams.dashboard.todo.title')).not.toBeInTheDocument()
    expect(heading('teams.dashboard.admin.title')).not.toBeInTheDocument()
  })

  it('a disabled module has no section: a null block is hidden, an empty one says so', () => {
    renderDashboard(
      dashboard('MEMBER', { latestAds: undefined, latestPosts: undefined, newRoutes: undefined })
    )

    expect(heading('teams.dashboard.ads.title')).not.toBeInTheDocument()
    expect(heading('teams.dashboard.posts.title')).not.toBeInTheDocument()
    expect(heading('teams.dashboard.routes.title')).not.toBeInTheDocument()
  })

  it('an ad without a price reads « Prix à négocier », its place as a sector', () => {
    renderDashboard(dashboard('MEMBER'))

    const ads = screen.getByRole('region', { name: 'teams.dashboard.ads.title' })
    expect(within(ads).getByText('ads.detail.priceNegotiable')).toBeInTheDocument()
    expect(within(ads).getAllByText('teams.dashboard.ads.sector')).toHaveLength(2)
  })

  it('shows each group of an upcoming ride with its fill', () => {
    renderDashboard(dashboard('MEMBER'))

    const rides = screen.getByRole('region', { name: 'teams.dashboard.upcomingRides.title' })
    expect(within(rides).getByText('Groupe A')).toBeInTheDocument()
    expect(within(rides).getByText('rides.detail.groups.full')).toBeInTheDocument()
    expect(within(rides).getByText('teams.dashboard.ride.fill')).toBeInTheDocument()
  })
})

describe('team dashboard, for a visitor (API-86)', () => {
  afterEach(cleanup)

  /** What the API builds for a reader with no role: the public sections, nothing else. */
  function visitorDashboard(): TeamDashboardDto {
    return {
      ...dashboard('MEMBER'),
      role: undefined,
      myUpcoming: undefined,
      latestAds: undefined,
      organizer: undefined,
      admin: undefined,
    } as unknown as TeamDashboardDto
  }

  it('shows the public sections only', () => {
    renderDashboard(visitorDashboard())

    expect(heading('teams.dashboard.upcomingRides.title')).toBeInTheDocument()
    expect(heading('teams.dashboard.posts.title')).toBeInTheDocument()
    expect(heading('teams.dashboard.myUpcoming.title')).not.toBeInTheDocument()
    expect(heading('teams.dashboard.ads.title')).not.toBeInTheDocument()
    expect(heading('teams.dashboard.todo.title')).not.toBeInTheDocument()
    expect(heading('teams.dashboard.admin.title')).not.toBeInTheDocument()
  })

  it('leads each « Voir tout » to the list behind it (WEB-68)', () => {
    renderDashboard(dashboard('MEMBER'))

    const seeAll = (section: string) =>
      within(screen.getByRole('region', { name: section }))
        .getByRole('link', { name: 'teams.dashboard.seeAll' })
        .getAttribute('href')
    expect(seeAll('teams.dashboard.myUpcoming.title')).toBe(
      `${paths.teamAgenda('vc-craponne')}?w=me`
    )
    expect(seeAll('teams.dashboard.upcomingRides.title')).toBe(paths.teamAgenda('vc-craponne'))
    expect(seeAll('teams.dashboard.posts.title')).toBe(paths.teamPosts('vc-craponne'))
  })
})
