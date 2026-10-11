import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, renderHook, screen, cleanup, fireEvent } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type { CalendarEventDto, TeamDetailDto } from '@/api/dto'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys and their count, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: { count?: number }) =>
      options?.count !== undefined ? `${key}:${options.count}` : key,
    i18n: { language: 'fr' },
  }),
}))

const app = vi.hoisted(() => ({ singleTeam: false }))
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => app.singleTeam }))

import { useTeamActivity, useWeekSummary, eventPath } from './memberHomeHelpers'
import { QuickActions } from './QuickActions'
import { MyTeamsCard } from './MyTeamsCard'

function team(overrides: Partial<TeamDetailDto>): TeamDetailDto {
  return {
    id: 't1',
    name: 'VC Craponne',
    slug: 'vc-craponne',
    about: { markdown: '', assets: {} },
    visibility: 'PUBLIC',
    enableTrips: true,
    enableAds: true,
    enablePosts: true,
    enableRides: true,
    enableRoutes: true,
    enableMemberDirectory: true,
    postsAsTeamByDefault: false,
    visibilityEditable: true,
    joinable: true,
    addMemberAllowed: true,
    enableRoutePlanner: false,
    memberCount: 12,
    upcomingRideCount: 0,
    routeCount: 0,
    upcomingTripCount: 0,
    recentPostCount: 0,
    role: 'MEMBER',
    createdAt: '2026-01-01T00:00:00Z',
    ...overrides,
  } as TeamDetailDto
}

function event(overrides: Partial<CalendarEventDto>): CalendarEventDto {
  return {
    id: 'e1',
    title: 'Sortie du mardi',
    start: '2026-10-06T16:30:00Z',
    allDay: false,
    type: 'RIDE',
    teamSlug: 'vc-craponne',
    teamName: 'VC Craponne',
    entitySlug: 'sortie-du-mardi',
    registered: false,
    status: 'PUBLISHED',
    finished: false,
    timezone: 'Europe/Paris',
    ...overrides,
  }
}

function renderIn(ui: React.ReactNode) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>{ui}</MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('member home helpers', () => {
  afterEach(cleanup)

  it('the activity line leaves the zeros out', () => {
    const { result } = renderHook(() => useTeamActivity())
    expect(result.current(team({ upcomingRideCount: 2, recentPostCount: 1 }))).toBe(
      'home.teams.activity.rides:2 · home.teams.activity.posts:1'
    )
    expect(result.current(team({ upcomingTripCount: 1 }))).toBe('home.teams.activity.trips:1')
  })

  it('a team with nothing going on shows its member count', () => {
    const { result } = renderHook(() => useTeamActivity())
    expect(result.current(team({}))).toBe('memberCount:12')
  })

  it('the week summary counts published rides, then the ones the member joined', () => {
    const { result, rerender } = renderHook(({ events }) => useWeekSummary(events), {
      initialProps: { events: undefined as CalendarEventDto[] | undefined },
    })
    expect(result.current).toBeNull()

    rerender({ events: [] })
    expect(result.current).toBe('home.member.summary.none')

    rerender({
      events: [
        event({ id: 'a', registered: true }),
        event({ id: 'b' }),
        event({ id: 'c' }),
        event({ id: 'd', status: 'DRAFT' }),
        event({ id: 'e', type: 'TRIP_STAGE', registered: true }),
      ],
    })
    expect(result.current).toBe('home.member.summary.rides:3 home.member.summary.registered:1')

    rerender({ events: [event({ registered: true })] })
    expect(result.current).toBe('home.member.summary.rides:1 home.member.summary.registeredAll:1')
  })

  it('a stage links under its trip, a ride under its team', () => {
    expect(eventPath(event({}))).toMatch(/\/vc-craponne\/.+\/sortie-du-mardi$/)
    expect(
      eventPath(event({ type: 'TRIP_STAGE', tripSlug: 'ardeche', entitySlug: 'etape-1' }))
    ).toMatch(/\/vc-craponne\/.+\/ardeche\/.+\/etape-1$/)
  })
})

describe('QuickActions', () => {
  afterEach(cleanup)

  it('nothing for a plain member', () => {
    renderIn(<QuickActions teams={[team({ role: 'MEMBER' })]} />)
    expect(screen.queryByRole('group', { name: 'home.actions.label' })).toBeNull()
  })

  it('an organizer of one team gets direct links to its forms', () => {
    renderIn(
      <QuickActions teams={[team({ role: 'ORGANIZER' }), team({ id: 't2', role: 'MEMBER' })]} />
    )
    expect(
      screen.getByRole('link', { name: 'home.actions.createRide' }).getAttribute('href')
    ).toMatch(/\/vc-craponne\//)
    expect(screen.getByRole('link', { name: 'home.actions.addRoute' })).toBeTruthy()
    expect(screen.getByRole('link', { name: 'home.actions.writePost' })).toBeTruthy()
  })

  it('a module turned off drops its action; a ride needs the routes module too', () => {
    renderIn(
      <QuickActions teams={[team({ role: 'ADMIN', enableRoutes: false, enablePosts: false })]} />
    )
    expect(screen.queryByRole('group', { name: 'home.actions.label' })).toBeNull()
  })

  it('with several teams, the action asks which one', async () => {
    renderIn(
      <QuickActions
        teams={[
          team({ role: 'ADMIN' }),
          team({ id: 't2', name: 'Rouleurs du Pilat', slug: 'pilat', role: 'ORGANIZER' }),
        ]}
      />
    )
    fireEvent.click(screen.getByRole('button', { name: 'home.actions.createRide' }))
    // The dropdown lives in a portal jsdom does not lay out: query it with `hidden`.
    const menu = await screen.findByRole('menu', { hidden: true })
    expect(menu.textContent).toContain('home.actions.pickTeam')
    expect(menu.textContent).toContain('Rouleurs du Pilat')
  })
})

describe('MyTeamsCard', () => {
  afterEach(() => {
    cleanup()
    app.singleTeam = false
  })

  it('lists each team with its role and activity', () => {
    renderIn(
      <MyTeamsCard
        teams={[team({ role: 'ADMIN', upcomingRideCount: 2 })]}
        total={1}
        isLoading={false}
      />
    )
    expect(screen.getByText('VC Craponne')).toBeTruthy()
    expect(screen.getByText('roles.ADMIN')).toBeTruthy()
    expect(screen.getByText('home.teams.activity.rides:2')).toBeTruthy()
  })

  it('no team: offers to find one', () => {
    renderIn(<MyTeamsCard teams={[]} total={0} isLoading={false} />)
    expect(screen.getByText('home.teams.empty')).toBeTruthy()
    expect(screen.getByRole('link', { name: 'home.teams.find' })).toBeTruthy()
  })

  it('a single-team site has no team to find', () => {
    app.singleTeam = true
    renderIn(<MyTeamsCard teams={[]} total={0} isLoading={false} />)
    expect(screen.queryByRole('link', { name: 'home.teams.find' })).toBeNull()
  })
})
