import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup, fireEvent } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type { TFunction } from 'i18next'
import type { TeamDetailDto, TeamRole } from '@/api/dto'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

const auth = { isAuthenticated: true }
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => auth }))

let singleTeam = false
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => singleTeam }))

// What the « my teams » listing returns, and whether the switcher asked for it.
const listing = vi.hoisted(() => ({
  teams: undefined as TeamDetailDto[] | undefined,
  enabled: [] as (boolean | undefined)[],
}))
vi.mock('@/api/endpoints/teams/teams', () => ({
  useListTeams: (_params: unknown, options?: { query?: { enabled?: boolean } }) => {
    listing.enabled.push(options?.query?.enabled)
    const enabled = options?.query?.enabled !== false
    return { data: enabled && listing.teams ? { teams: listing.teams } : undefined }
  },
}))

import { TeamSwitcher } from './TeamSwitcher'
import { teamSwitchPath } from '@/hooks/useNavItems'
import { paths } from '@/config/paths'

function team(id: string, name: string, role?: TeamRole, overrides: Partial<TeamDetailDto> = {}) {
  return {
    id,
    name,
    slug: id,
    visibility: 'PUBLIC',
    enableRides: true,
    enableRoutes: true,
    enablePosts: true,
    about: { markdown: '', assets: {} },
    pages: [],
    role,
    ...overrides,
  } as unknown as TeamDetailDto
}

const current = team('c-team', 'Craponne', 'MEMBER')

// `null`: a custom page, for which TeamLayout passes no section (an `undefined` would take the default).
function renderSwitcher(displayed: TeamDetailDto = current, section: string | null = 'agenda') {
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <TeamSwitcher team={displayed} section={section ?? undefined} />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const heading = () => screen.getByRole('heading', { level: 1 })
const menuButton = () => screen.queryByRole('button', { name: /Craponne/ })

afterEach(() => {
  cleanup()
  auth.isAuthenticated = true
  singleTeam = false
  listing.teams = undefined
  listing.enabled = []
})

describe('TeamSwitcher (WEB-111)', () => {
  it('stays a plain title when logged out', () => {
    auth.isAuthenticated = false
    listing.teams = [team('a-team', 'Annonay', 'MEMBER'), current]
    renderSwitcher()
    expect(heading()).toHaveTextContent('Craponne')
    expect(menuButton()).toBeNull()
    expect(listing.enabled).not.toContain(true)
  })

  it('stays a plain title for a member of this team only', () => {
    listing.teams = [current]
    renderSwitcher()
    expect(heading()).toHaveTextContent('Craponne')
    expect(menuButton()).toBeNull()
  })

  // docs/LEDGER_*.md API-137: « Mes équipes » is the real memberships, a platform admin's too. One
  // who belongs to no team gets an empty listing, so a team they only administer has no menu.
  it('stays a plain title for a platform admin who belongs to no team', () => {
    listing.teams = []
    renderSwitcher(team('c-team', 'Craponne'))
    expect(heading()).toHaveTextContent('Craponne')
    expect(menuButton()).toBeNull()
  })

  it('stays a plain title on a single-team site, without asking for the listing', () => {
    singleTeam = true
    listing.teams = [team('a-team', 'Annonay', 'MEMBER'), current]
    renderSwitcher()
    expect(menuButton()).toBeNull()
    expect(listing.enabled).not.toContain(true)
  })

  it('lists my teams in the given order, this one checked, then all teams', async () => {
    const annonay = team('a-team', 'Annonay', 'MEMBER')
    const brioude = team('b-team', 'Brioude', 'MEMBER', { enableRides: false })
    listing.teams = [annonay, brioude, current]
    renderSwitcher()

    // The heading keeps the team's name, the button inside it too.
    expect(heading()).toHaveAccessibleName('Craponne')
    fireEvent.click(menuButton()!)

    const items = await screen.findAllByRole('menuitem')
    expect(items.map((item) => item.textContent)).toEqual([
      'AAnnonay',
      'BBrioude',
      'CCraponne',
      'teams.switcher.allTeams',
    ])
    expect(screen.getByText('teams.switcher.title')).toBeInTheDocument()

    const t = ((key: string) => key) as unknown as TFunction
    expect(items[0]).toHaveAttribute('href', paths.teamAgenda('a-team'))
    // Brioude has no agenda: its dashboard.
    expect(items[1]).toHaveAttribute('href', teamSwitchPath(brioude, 'agenda', t))
    expect(items[1]).toHaveAttribute('href', paths.team('b-team'))
    expect(items[2]).toHaveAttribute('aria-current', 'true')
    expect(items[2]).not.toHaveAttribute('href')
    expect(items[0]).not.toHaveAttribute('aria-current')
    expect(items[3]).toHaveAttribute('href', paths.teams())
  })

  it('lists a visitor their own teams, none checked', async () => {
    listing.teams = [team('a-team', 'Annonay', 'MEMBER')]
    renderSwitcher(team('c-team', 'Craponne', undefined))
    fireEvent.click(menuButton()!)

    const items = await screen.findAllByRole('menuitem')
    expect(items).toHaveLength(2)
    expect(items.filter((item) => item.hasAttribute('aria-current'))).toHaveLength(0)
  })

  it('leads to the dashboards from a custom page, even one slugged like a section', async () => {
    listing.teams = [team('a-team', 'Annonay', 'MEMBER'), current]
    // TeamPageDetailPage on a page « Agenda » (slug `agenda`): TeamLayout passes no section.
    renderSwitcher(current, null)
    fireEvent.click(menuButton()!)

    const items = await screen.findAllByRole('menuitem')
    expect(items[0]).toHaveAttribute('href', paths.team('a-team'))
  })

  it('stays a plain title for a visitor with no team', () => {
    listing.teams = []
    renderSwitcher(team('c-team', 'Craponne', undefined))
    expect(menuButton()).toBeNull()
  })
})
