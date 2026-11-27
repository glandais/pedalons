import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { AdminPlatformStatsDto } from '@/api/dto'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, o?: Record<string, string>) =>
      key.startsWith('dateFormats.')
        ? key.includes('Year')
          ? 'd MMM yyyy'
          : key.toLowerCase().includes('time')
            ? 'HH:mm'
            : 'd MMM'
        : o
          ? `${key} ${Object.values(o)[0]}`
          : key,
    i18n: { language: 'fr' },
  }),
}))
vi.mock('@/components/admin/AdminLayout', () => ({
  AdminLayout: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
}))

const stats: AdminPlatformStatsDto = {
  generatedAt: '2026-11-27T10:00:00Z',
  users: {
    total: 200,
    deleted: 3,
    emailVerified: 150,
    termsAccepted: 180,
    platformAdmins: 2,
    withAvatar: 40,
    neverLoggedIn: 20,
    activeLast7Days: 50,
    activeLast30Days: 100,
    activeLast90Days: 150,
  },
  authMethods: { passwordOnly: 100, passkeyOnly: 10, passwordAndPasskey: 30, neither: 60 },
  passkeys: { total: 44, usedLast30Days: 12 },
  signupsByMonth: [{ month: '2026-11', count: 7 }],
  teams: {
    active: 9,
    deleted: 1,
    byTier: [{ key: 'FREE', count: 8 }],
    membershipsByRole: [{ key: 'ADMIN', count: 9 }],
    usersByTeamCount: [{ key: '3+', count: 5 }],
  },
  gpsServices: [
    {
      service: 'GARMIN',
      connections: 12,
      users: 11,
      autoSync: 4,
      reconnectRequired: 1,
      usedLast30Days: 6,
      routeSyncs: 30,
      routeSyncsSucceeded: 28,
      routeSyncsFailed: 2,
    },
  ],
  usersWithGpsService: 11,
  pushDevices: [{ platform: 'IOS', devices: 77, users: 70, seenLast7Days: 33 }],
  clientsLast30Days: [{ key: 'MOBILE_APP', count: 88 }],
  calendarFeeds: { tokens: 15, usedEver: 9, usedLast7Days: 4 },
}

const mocks = vi.hoisted(() => ({ result: {} as Record<string, unknown> }))
vi.mock('@/api/endpoints/admin-domains/admin-domains', () => ({
  useGetPlatformStats: () => mocks.result,
  useListDomains: () => ({ data: { domains: [] } }),
}))

import { AdminStatsPage } from './AdminStatsPage'

const renderPage = () =>
  render(
    <MantineProvider>
      <AdminStatsPage />
    </MantineProvider>
  )

afterEach(cleanup)

describe('AdminStatsPage', () => {
  it('renders the numbers of the response, percentages included', () => {
    mocks.result = { data: stats, isLoading: false, isError: false }
    renderPage()

    expect(screen.getByText('200')).toBeVisible()
    expect(screen.getByText('88')).toBeVisible()
    expect(screen.getByText('77')).toBeVisible()
    expect(screen.getByText('Garmin')).toBeVisible()
    expect(screen.getByText('admin.statsPage.clients.MOBILE_APP')).toBeVisible()
    expect(screen.getByText('3+')).toBeVisible()
    expect(screen.getByText(/25.%/)).toBeVisible()
  })

  it('shows an alert on error and skeletons while loading', () => {
    mocks.result = { data: undefined, isLoading: false, isError: true }
    renderPage()
    expect(screen.getByText('admin.statsPage.error')).toBeVisible()
    cleanup()
    mocks.result = { data: undefined, isLoading: true, isError: false }
    renderPage()
    expect(screen.getByTestId('stats-skeleton')).toBeInTheDocument()
  })
})
