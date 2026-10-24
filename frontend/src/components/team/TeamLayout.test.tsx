import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type { TeamDetailDto, TeamRole, UserDto } from '@/api/dto'
import { useAuthStore } from '@/store/authStore'

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
vi.mock('../common/ShareButton', () => ({ ShareButton: () => null }))
vi.mock('../common/NavButtons', () => ({ NavButtons: () => null }))

import { TeamLayout } from './TeamLayout'

function team(role?: TeamRole) {
  return {
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

function renderLayout(displayed: TeamDetailDto) {
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <TeamLayout team={displayed} currentTab="dashboard">
            <p>contenu</p>
          </TeamLayout>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

afterEach(() => {
  cleanup()
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
})
