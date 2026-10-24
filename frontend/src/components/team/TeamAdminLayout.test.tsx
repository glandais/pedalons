import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import type { TeamDetailDto, TeamRole, UserDto } from '@/api/dto'
import { useAuthStore } from '@/store/authStore'

// Keys, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

// The tab row itself is NavButtons' business: only which tabs it is given matters here.
vi.mock('../common/NavButtons', () => ({
  NavButtons: ({ items }: { items: { id: string }[] }) => (
    <ul>
      {items.map((item) => (
        <li key={item.id}>{item.id}</li>
      ))}
    </ul>
  ),
}))

import { TeamAdminLayout } from './TeamAdminLayout'

function team(role?: TeamRole) {
  return { id: 't1', slug: 'vc-craponne', name: 'VC Craponne', role } as unknown as TeamDetailDto
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
      <MemoryRouter initialEntries={['/admin']}>
        <Routes>
          <Route
            path="/admin"
            element={
              <TeamAdminLayout team={displayed} currentTab="members">
                <p>contenu</p>
              </TeamAdminLayout>
            }
          />
          <Route path="*" element={<p>redirigé</p>} />
        </Routes>
      </MemoryRouter>
    </MantineProvider>
  )
}

const tabs = () => screen.queryAllByRole('listitem').map((item) => item.textContent)

afterEach(() => {
  cleanup()
  useAuthStore.setState({ isAuthenticated: false, user: null, accessToken: null })
})

describe('TeamAdminLayout (docs/LEDGER_*.md API-137)', () => {
  it('a platform admin who is not a member gets every tab', () => {
    signIn(true)
    renderLayout(team(undefined))
    expect(screen.getByText('contenu')).toBeInTheDocument()
    expect(tabs()).toEqual([
      'ride-templates',
      'places',
      'tags',
      'pages',
      'members',
      'reports',
      'settings',
    ])
  })

  it('an organizer gets the organizer tabs only', () => {
    signIn(false)
    renderLayout(team('ORGANIZER'))
    expect(tabs()).toEqual(['ride-templates', 'places', 'reports'])
  })

  it('a plain member is sent back to the team', () => {
    signIn(false)
    renderLayout(team('MEMBER'))
    expect(screen.getByText('redirigé')).toBeInTheDocument()
    expect(screen.queryByText('contenu')).toBeNull()
  })
})
