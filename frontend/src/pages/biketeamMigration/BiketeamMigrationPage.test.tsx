import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup, waitFor, act } from '@testing-library/react'
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type { UserDto } from '@/api/dto'
import type { BiketeamMigrationPreviewDto } from './biketeamMigrationApi'
import { ApiClientError } from '@/lib/apiError'
import { useAuthStore } from '@/store/authStore'

const previewBiketeamMigration = vi.fn()
const confirmBiketeamMigration = vi.fn()
vi.mock('./biketeamMigrationApi', () => ({
  previewBiketeamMigration: (...args: unknown[]) => previewBiketeamMigration(...args),
  confirmBiketeamMigration: (...args: unknown[]) => confirmBiketeamMigration(...args),
}))

const leaveForBiketeam = vi.fn()
vi.mock('./biketeamMigrationRequest', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./biketeamMigrationRequest')>()),
  leaveForBiketeam: (url: string) => leaveForBiketeam(url),
}))

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys, not wording: the assertions read which message is shown, not how it is phrased.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

// The real formatter reads its pattern from the global i18next instance, which tests don't load.
vi.mock('@/utils/dateFormat', () => ({
  useFormattedDate: () => ({ formatDateTime: (date: string) => date }),
}))

import { BiketeamMigrationPage } from './BiketeamMigrationPage'
import { REQUEST_STORAGE_KEY } from './biketeamMigrationRequest'

const TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature'

function previewDto(overrides: Partial<BiketeamMigrationPreviewDto> = {}) {
  return {
    requestId: '6f1c2a3e-0000-4000-8000-000000000001',
    teamId: 'n-peloton',
    teamName: "N'Peloton",
    requestedBy: 'Jane D.',
    expiresAt: '2026-09-22T11:15:00Z',
    summary: {
      places: 1,
      routes: 2,
      rides: 3,
      rideTemplates: 0,
      trips: 1,
      tripStages: 2,
      publications: 4,
      faqPage: true,
      logo: false,
    },
    targetDomainName: 'Pédalons',
    targetTeamSlug: 'n-peloton',
    targetState: 'NEW',
    existingTeamName: null,
    trashedTeamSetAside: null,
    confirmable: false,
    blockReason: 'LOGIN_REQUIRED',
    cancelUrl:
      'https://biketeam.example/n-peloton/admin/pedalons/callback?request=6f1c2a3e-0000-4000-8000-000000000001&outcome=cancelled',
    ...overrides,
  } as BiketeamMigrationPreviewDto
}

const user = { id: 'u1', displayName: 'Jane', email: 'jane@example.com' } as UserDto

function signIn() {
  useAuthStore.setState({ isInitialized: true, isAuthenticated: true, user, accessToken: 'at' })
}

function signOut() {
  useAuthStore.setState({
    isInitialized: true,
    isAuthenticated: false,
    user: null,
    accessToken: null,
  })
}

/** Renders where the login button leads, so the test can read the state it carries. */
function LoginProbe() {
  const location = useLocation()
  const from = (location.state as { from?: { pathname: string; search: string } } | null)?.from
  return <div data-testid="login">{from ? `${from.pathname}${from.search}` : ''}</div>
}

function renderAt(path: string) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[path]}>
          <Routes>
            <Route path="/migration-biketeam" element={<BiketeamMigrationPage />} />
            <Route path="*" element={<LoginProbe />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('BiketeamMigrationPage', () => {
  beforeEach(() => {
    previewBiketeamMigration.mockReset()
    confirmBiketeamMigration.mockReset()
    leaveForBiketeam.mockReset()
    sessionStorage.clear()
    signOut()
  })
  afterEach(() => {
    cleanup()
  })

  it('keeps the request for the login detour and sends a signed-out visitor to sign in', async () => {
    previewBiketeamMigration.mockResolvedValue(previewDto())
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    expect(await screen.findByText('biketeamMigration.title')).toBeInTheDocument()
    expect(previewBiketeamMigration).toHaveBeenCalledWith({ requestToken: TOKEN })
    expect(sessionStorage.getItem(REQUEST_STORAGE_KEY)).toBe(TOKEN)
    expect(screen.getByText('biketeamMigration.notImported.members')).toBeInTheDocument()
    expect(screen.getByText('biketeamMigration.notImported.comments')).toBeInTheDocument()
    expect(screen.getByText('biketeamMigration.copy.title')).toBeInTheDocument()
    expect(screen.getByText('biketeamMigration.copy.body')).toBeInTheDocument()
    expect(screen.queryByText('biketeamMigration.confirm')).not.toBeInTheDocument()

    fireEvent.click(screen.getByText('biketeamMigration.signIn'))
    expect(await screen.findByTestId('login')).toHaveTextContent(
      `/migration-biketeam?request=${TOKEN}`
    )
  })

  it('picks the request back up from sessionStorage when the URL lost it', async () => {
    sessionStorage.setItem(REQUEST_STORAGE_KEY, TOKEN)
    signIn()
    previewBiketeamMigration.mockResolvedValue(previewDto({ confirmable: true, blockReason: null }))
    renderAt('/migration-biketeam')

    expect(await screen.findByText('biketeamMigration.confirm')).toBeInTheDocument()
    expect(previewBiketeamMigration).toHaveBeenCalledWith({ requestToken: TOKEN })
  })

  it('says the link is incomplete when there is no request at all', async () => {
    renderAt('/migration-biketeam')

    expect(await screen.findByText('biketeamMigration.unavailable.missing')).toBeInTheDocument()
    expect(previewBiketeamMigration).not.toHaveBeenCalled()
  })

  it('waits for the session before asking, then asks again when it changes', async () => {
    useAuthStore.setState({ isInitialized: false, isAuthenticated: false, user: null })
    previewBiketeamMigration.mockResolvedValue(previewDto())
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(previewBiketeamMigration).not.toHaveBeenCalled()

    act(() => signOut())
    await waitFor(() => expect(previewBiketeamMigration).toHaveBeenCalledTimes(1))

    previewBiketeamMigration.mockResolvedValue(previewDto({ confirmable: true, blockReason: null }))
    act(() => signIn())
    await waitFor(() => expect(previewBiketeamMigration).toHaveBeenCalledTimes(2))
    expect(await screen.findByText('biketeamMigration.confirm')).toBeInTheDocument()
  })

  it('confirms, forgets the request and goes back to biketeam with the grant', async () => {
    signIn()
    previewBiketeamMigration.mockResolvedValue(previewDto({ confirmable: true, blockReason: null }))
    const redirectUrl =
      'https://biketeam.example/n-peloton/admin/pedalons/callback?request=6f1c2a3e-0000-4000-8000-000000000001&grant=bmg_x'
    confirmBiketeamMigration.mockResolvedValue({ redirectUrl, expiresAt: '2026-09-22T10:25:00Z' })
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    fireEvent.click(await screen.findByText('biketeamMigration.confirm'))

    await waitFor(() => expect(leaveForBiketeam).toHaveBeenCalledWith(redirectUrl))
    expect(confirmBiketeamMigration).toHaveBeenCalledWith({ requestToken: TOKEN })
    expect(sessionStorage.getItem(REQUEST_STORAGE_KEY)).toBeNull()
  })

  it('cancels back to biketeam', async () => {
    signIn()
    const preview = previewDto({ confirmable: true, blockReason: null })
    previewBiketeamMigration.mockResolvedValue(preview)
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    fireEvent.click(await screen.findByText('biketeamMigration.cancel'))
    expect(leaveForBiketeam).toHaveBeenCalledWith(preview.cancelUrl)
    expect(sessionStorage.getItem(REQUEST_STORAGE_KEY)).toBeNull()
  })

  it('shows why the request cannot be confirmed', async () => {
    signIn()
    previewBiketeamMigration.mockResolvedValue(
      previewDto({
        targetState: 'SLUG_CONFLICT',
        existingTeamName: 'Nantes Peloton',
        blockReason: 'SLUG_CONFLICT',
      })
    )
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    expect(await screen.findByText('biketeamMigration.block.SLUG_CONFLICT')).toBeInTheDocument()
    expect(screen.queryByText('biketeamMigration.confirm')).not.toBeInTheDocument()
    expect(screen.getByText('biketeamMigration.backToBiketeam')).toBeInTheDocument()
  })

  it('says that a team from a previous migration is updated', async () => {
    signIn()
    previewBiketeamMigration.mockResolvedValue(
      previewDto({
        targetState: 'EXISTING_MIGRATED',
        existingTeamName: "N'Peloton",
        confirmable: true,
        blockReason: null,
      })
    )
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    expect(await screen.findByText('biketeamMigration.existing.update')).toBeInTheDocument()
    expect(screen.queryByText('biketeamMigration.trashed.setAside')).not.toBeInTheDocument()
    expect(screen.getByText('biketeamMigration.confirm')).toBeInTheDocument()
  })

  it('says that a deleted team from a previous migration is set aside, not updated', async () => {
    signIn()
    previewBiketeamMigration.mockResolvedValue(
      previewDto({
        targetState: 'NEW',
        trashedTeamSetAside: "N'Peloton",
        confirmable: true,
        blockReason: null,
      })
    )
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    expect(await screen.findByText('biketeamMigration.trashed.setAside')).toBeInTheDocument()
    expect(screen.queryByText('biketeamMigration.existing.update')).not.toBeInTheDocument()
  })

  it('mentions no deleted team when there is none', async () => {
    signIn()
    previewBiketeamMigration.mockResolvedValue(previewDto({ confirmable: true, blockReason: null }))
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    expect(await screen.findByText('biketeamMigration.confirm')).toBeInTheDocument()
    expect(screen.queryByText('biketeamMigration.trashed.setAside')).not.toBeInTheDocument()
  })

  it('drops an expired request and says so', async () => {
    sessionStorage.setItem(REQUEST_STORAGE_KEY, 'stale')
    previewBiketeamMigration.mockRejectedValue(
      new ApiClientError(400, { code: 'BIKETEAM_REQUEST_EXPIRED' })
    )
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    expect(await screen.findByText('errors.api.BIKETEAM_REQUEST_EXPIRED')).toBeInTheDocument()
    expect(sessionStorage.getItem(REQUEST_STORAGE_KEY)).toBeNull()
  })

  it('keeps the page and refreshes the preview when confirming hits a conflict', async () => {
    signIn()
    previewBiketeamMigration.mockResolvedValueOnce(
      previewDto({ confirmable: true, blockReason: null })
    )
    previewBiketeamMigration.mockResolvedValueOnce(previewDto({ blockReason: 'MIGRATION_RUNNING' }))
    confirmBiketeamMigration.mockRejectedValue(
      new ApiClientError(409, { code: 'BIKETEAM_MIGRATION_RUNNING' })
    )
    renderAt(`/migration-biketeam?request=${TOKEN}`)

    fireEvent.click(await screen.findByText('biketeamMigration.confirm'))

    expect(await screen.findByText('errors.api.BIKETEAM_MIGRATION_RUNNING')).toBeInTheDocument()
    expect(await screen.findByText('biketeamMigration.block.MIGRATION_RUNNING')).toBeInTheDocument()
    expect(previewBiketeamMigration).toHaveBeenCalledTimes(2)
    expect(leaveForBiketeam).not.toHaveBeenCalled()
    expect(sessionStorage.getItem(REQUEST_STORAGE_KEY)).toBe(TOKEN)
  })
})
