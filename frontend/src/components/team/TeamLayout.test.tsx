import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type { TeamDetailDto, TeamRole, UserDto } from '@/api/dto'
import { useAuthStore } from '@/store/authStore'

const responsive = vi.hoisted(() => ({ isMobile: false }))
vi.mock('@/hooks/useResponsive', () => ({
  useResponsive: () => ({
    isMobile: responsive.isMobile,
    isTablet: false,
    isDesktop: !responsive.isMobile,
    size: 'md',
    sizeCompact: 'sm',
  }),
  useMediaMatch: () => false,
}))

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

vi.mock('../../hooks/useAuth', () => ({ useAuth: () => ({ isAuthenticated: true }) }))
vi.mock('../../hooks/useFavicon', () => ({ useFavicon: () => undefined }))
vi.mock('@/api/endpoints/team-members/team-members', () => ({
  useJoinTeam: () => ({ mutate: vi.fn(), isPending: false }),
  useLeaveTeam: () => ({ mutate: vi.fn(), isPending: false }),
  getGetMembersQueryKey: (slug: string) => ['members', slug],
}))
// The header's other pieces are not what is under test.
vi.mock('./TeamSwitcher', () => ({ TeamSwitcher: () => null }))
vi.mock('./TeamAvatar', () => ({ TeamAvatar: () => null }))
vi.mock('../common/ShareButton', () => ({
  ShareButton: () => <button type="button">share</button>,
}))
vi.mock('../common/NavButtons', () => ({ NavButtons: () => null }))

import { TeamLayout } from './TeamLayout'

function team(role?: TeamRole, members?: { memberCount: number; memberLimit?: number }) {
  return {
    memberCount: 3,
    ...members,
    id: 't1',
    slug: 'vc-craponne',
    name: 'VC Craponne',
    visibility: 'PUBLIC',
    joinable: true,
    about: { markdown: '', assets: {} },
    pages: [],
    role,
  } as unknown as TeamDetailDto
}

function signIn(platformAdmin: boolean) {
  useAuthStore.setState({
    isInitialized: true,
    isAuthenticated: true,
    accessToken: 'at',
    user: {
      id: 'u1',
      displayName: 'Root',
      email: 'root@example.com',
      platformRole: platformAdmin ? 'PLATFORM_ADMIN' : undefined,
    } as UserDto,
  })
}

function renderLayout(displayed: TeamDetailDto, actions?: React.ReactNode) {
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <TeamLayout team={displayed} currentTab="dashboard" actions={actions}>
            <p>contenu</p>
          </TeamLayout>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

afterEach(() => {
  cleanup()
  responsive.isMobile = false
  useAuthStore.setState({ isAuthenticated: false, user: null, accessToken: null })
})

describe('TeamLayout (docs/LEDGER_*.md API-137)', () => {
  it('a platform admin who is not a member may join, and still administers', () => {
    signIn(true)
    renderLayout(team(undefined))
    expect(screen.getByRole('button', { name: 'teams.detail.actions.join' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'teams.detail.actions.leave' })).toBeNull()
    expect(screen.getByRole('link', { name: 'teams.detail.actions.admin' })).toBeInTheDocument()
  })

  it('a platform admin who is a plain member may leave', () => {
    signIn(true)
    renderLayout(team('MEMBER'))
    expect(screen.queryByRole('button', { name: 'teams.detail.actions.join' })).toBeNull()
    expect(screen.getByRole('button', { name: 'teams.detail.actions.leave' })).toBeInTheDocument()
  })

  it('a plain member has no administration entry', () => {
    signIn(false)
    renderLayout(team('MEMBER'))
    expect(screen.queryByRole('link', { name: 'teams.detail.actions.admin' })).toBeNull()
  })

  it('a full free team replaces the join button by the reason (BILL-10)', () => {
    signIn(false)
    renderLayout(team(undefined, { memberCount: 25, memberLimit: 25 }))
    expect(screen.queryByRole('button', { name: 'teams.detail.actions.join' })).toBeNull()
    expect(screen.getByText('teams.memberLimit.fullAskAdmin')).toBeInTheDocument()
  })

  it('a free team with a place left still offers to join', () => {
    signIn(false)
    renderLayout(team(undefined, { memberCount: 24, memberLimit: 25 }))
    expect(screen.getByRole('button', { name: 'teams.detail.actions.join' })).toBeInTheDocument()
    expect(screen.queryByText('teams.memberLimit.fullAskAdmin')).toBeNull()
  })

  it('a platform admin, exempt from the cap, may still join a full team', () => {
    signIn(true)
    renderLayout(team(undefined, { memberCount: 25, memberLimit: 25 }))
    expect(screen.getByRole('button', { name: 'teams.detail.actions.join' })).toBeInTheDocument()
  })

  it('a member of a full team sees no notice', () => {
    signIn(false)
    renderLayout(team('MEMBER', { memberCount: 25, memberLimit: 25 }))
    expect(screen.queryByText('teams.memberLimit.fullAskAdmin')).toBeNull()
  })
})

describe('TeamLayout banner (docs/LEDGER_*.md WEB-208)', () => {
  it('joining or leaving, then create, then manage, then share', () => {
    signIn(false)
    renderLayout(team('ORGANIZER'), <button type="button">create</button>)
    const order = Array.from(document.querySelectorAll('a, button')).map(
      (el) => el.getAttribute('aria-label') ?? el.textContent
    )
    expect(order).toEqual([
      'teams.detail.actions.leave',
      'create',
      'teams.detail.actions.admin',
      'share',
    ])
  })

  it('on a phone « Gérer » is an icon named for assistive tech, and create keeps its own row', () => {
    responsive.isMobile = true
    signIn(false)
    renderLayout(team('ORGANIZER'), <button type="button">create</button>)
    const manage = screen.getByRole('link', { name: 'teams.detail.actions.admin' })
    expect(manage.textContent).toBe('')
    expect(screen.getAllByRole('button', { name: 'create' })).toHaveLength(1)
    const share = screen.getByRole('button', { name: 'share' })
    const create = screen.getByRole('button', { name: 'create' })
    expect(share.compareDocumentPosition(create) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
  })
})
