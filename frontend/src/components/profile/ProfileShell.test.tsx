import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => ({ logout: vi.fn() }) }))

import { ProfileShell } from './ProfileShell'

function renderShell(section: Parameters<typeof ProfileShell>[0]['section']) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <ProfileShell section={section} title="Titre">
            <p data-testid="content" />
          </ProfileShell>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('ProfileShell', () => {
  afterEach(cleanup)

  it('marks the current subject in the grouped sidebar, and only it', () => {
    renderShell('notifications')

    const nav = screen.getByRole('navigation', { name: 'nav.profile' })
    const current = within(nav)
      .getAllByRole('link')
      .filter((link) => link.getAttribute('aria-current') === 'page')
    expect(current.map((link) => link.textContent)).toEqual(['profile.nav.notifications'])
    for (const group of ['profile.nav.group.settings', 'profile.nav.group.security'])
      expect(within(nav).getByText(group)).toBeTruthy()
    expect(within(nav).queryByText('profile.nav.group.account')).toBeNull()
  })

  it('puts « Mon compte » first of the settings and « Aide » last, in no group', () => {
    renderShell('overview')

    const nav = screen.getByRole('navigation', { name: 'nav.profile' })
    const labels = within(nav)
      .getAllByRole('link')
      .map((link) => link.textContent)
    expect(labels.slice(0, 3)).toEqual([
      'profile.nav.overview',
      'profile.nav.account',
      'profile.nav.preferences',
    ])
    expect(labels.at(-1)).toBe('profile.nav.help')
  })

  it('offers « Se déconnecter » once, at the foot of the sidebar', () => {
    renderShell('overview')

    const nav = screen.getByRole('navigation', { name: 'nav.profile' })
    expect(within(nav).getAllByRole('button', { name: 'nav.signOut' })).toHaveLength(1)
    expect(screen.getByRole('heading', { name: 'Titre' })).toBeTruthy()
  })
})
