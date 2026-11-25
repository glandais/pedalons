import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import type { UserDto } from '@/api/dto'
import { useAuthStore } from '@/store/authStore'

// Keys, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))
vi.mock('../common/NavButtons', () => ({ NavButtons: () => null }))

import { AdminLayout } from './AdminLayout'

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

function renderLayout(subtitle?: string) {
  render(
    <MantineProvider>
      <MemoryRouter initialEntries={['/admin']}>
        <Routes>
          <Route
            path="/admin"
            element={
              <AdminLayout currentTab="dashboard" subtitle={subtitle}>
                <p>contenu</p>
              </AdminLayout>
            }
          />
          <Route path="*" element={<p>redirigé</p>} />
        </Routes>
      </MemoryRouter>
    </MantineProvider>
  )
}

afterEach(() => {
  cleanup()
  useAuthStore.setState({ isAuthenticated: false, user: null, accessToken: null })
})

describe('AdminLayout (docs/LEDGER_*.md WEB-208)', () => {
  it('a platform admin gets the h1, the subtitle and no back link', () => {
    signIn(true)
    renderLayout('sous-titre')
    expect(screen.getByRole('heading', { level: 1, name: 'admin.title' })).toBeTruthy()
    expect(screen.getByText('sous-titre')).toBeInTheDocument()
    expect(screen.queryAllByRole('link')).toHaveLength(0)
  })

  it('without a subtitle only the h1 and the children render', () => {
    signIn(true)
    renderLayout()
    expect(screen.getByRole('heading', { level: 1 })).toBeTruthy()
    expect(screen.getByText('contenu')).toBeInTheDocument()
  })

  it('a non-admin is redirected', () => {
    signIn(false)
    renderLayout()
    expect(screen.getByText('redirigé')).toBeInTheDocument()
  })
})
