import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ProfileSummaryDto, PublicationDto, UserDto } from '@/api/dto'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys and their parameters, not wording: the assertions read which line shows where.
vi.mock('react-i18next', async (importOriginal) => ({
  ...(await importOriginal<typeof import('react-i18next')>()),
  useTranslation: () => ({
    t: (key: string, options?: Record<string, unknown>) =>
      options
        ? `${key}(${Object.entries(options)
            .map(([name, value]) => `${name}=${String(value)}`)
            .join(',')})`
        : key,
    i18n: { language: 'fr' },
  }),
}))

const state = vi.hoisted(() => ({
  user: undefined as UserDto | undefined,
  summary: undefined as ProfileSummaryDto | undefined,
}))

vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({ user: state.user, isLoading: false, logout: vi.fn() }),
}))
vi.mock('@/api/endpoints/users/users', () => ({
  useGetMyProfileSummary: () => ({ data: state.summary }),
}))
vi.mock('@/components/common/FormattedDate', () => ({
  FormattedDateTime: ({ date }: { date: string }) => <span>{date}</span>,
}))

import { paths } from '@/config/paths'
import { ProfileOverviewPage } from './ProfileOverviewPage'

const USER: UserDto = {
  id: 'u1',
  email: 'camille@example.org',
  displayName: 'Camille Dupont',
  contactableByMembers: false,
  emailVerified: true,
}

const NEXT = {
  id: 'p1',
  type: 'RIDE',
  slug: 'sortie-du-dimanche',
  name: 'Sortie du dimanche',
  dateTime: '2026-10-11T07:00:00Z',
  team: { slug: 'velo-club', name: 'Vélo Club' },
} as unknown as PublicationDto

const SUMMARY: ProfileSummaryDto = {
  participations: { upcomingCount: 2, pastCount: 7, next: [NEXT] },
  teams: [{ slug: 'velo-club', name: 'Vélo Club', role: 'ADMIN' }],
  passkeyCount: 1,
  pairedDevices: [],
  blockedUserCount: 0,
  notifications: { channels: ['EMAIL'], enabledChannels: ['EMAIL'], emailDigest: false },
}

function renderOverview() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <ProfileOverviewPage />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

/** The link of a shortcut carrying both its label and its state line. */
function shortcuts(label: string, status: string) {
  return screen
    .getAllByRole('link')
    .filter((link) => link.textContent?.includes(label) && link.textContent.includes(status))
}

describe('ProfileOverviewPage', () => {
  beforeEach(() => {
    state.user = USER
    state.summary = SUMMARY
  })
  afterEach(cleanup)

  it('shows who is signed in, with the way to « Mon compte »', () => {
    renderOverview()

    expect(screen.getByRole('heading', { name: 'profile.title' })).toBeTruthy()
    expect(screen.getByText('Camille Dupont')).toBeTruthy()
    expect(screen.getByText('camille@example.org')).toBeTruthy()
    const accountLinks = screen
      .getAllByRole('link')
      .filter((link) => link.getAttribute('href') === paths.profileAccount())
    // The identity card's, the sidebar's, the desktop card's and the phone list's.
    expect(accountLinks).toHaveLength(4)
  })

  it('lists the teams with their role, and no longer the rides', () => {
    renderOverview()

    // « Mes sorties » left the profile: the home page and the agenda already list them.
    expect(screen.queryByRole('link', { name: 'Sortie du dimanche' })).toBeNull()
    expect(screen.queryByText('profile.nav.rides')).toBeNull()
    const team = screen.getByRole('link', { name: /Vélo Club/ })
    expect(team).toHaveAttribute('href', paths.team('velo-club'))
    expect(within(team).getByText('roles.ADMIN')).toBeTruthy()
  })

  it('gives each subject its state line, on the desktop cards and on the phone list', () => {
    renderOverview()

    // On both layouts (one of the two is hidden by CSS only).
    for (const [label, status] of [
      ['profile.nav.account', 'profile.status.account'],
      ['profile.nav.security', 'profile.status.passkeys(count=1)'],
      ['profile.nav.privacy', 'profile.status.notContactable'],
      ['profile.nav.notifications', 'profile.status.notifications.email'],
      ['profile.nav.devices', 'profile.status.noDevice'],
      ['profile.nav.help', 'profile.status.help'],
    ])
      expect(shortcuts(label, status), `${label}: ${status}`).toHaveLength(2)
  })

  it('switches between the sidebar and the phone list by CSS only, « Se déconnecter » in each', () => {
    const { container } = renderOverview()

    // Both layouts are in the markup: the server cannot know the viewport.
    const signOuts = screen.getAllByRole('button', { name: 'nav.signOut' })
    expect(signOuts).toHaveLength(2)
    const sidebar = screen.getByRole('navigation', { name: 'nav.profile' })
    expect(sidebar.closest('.mantine-visible-from-md')).not.toBeNull()
    expect(within(sidebar).getAllByRole('button', { name: 'nav.signOut' })).toHaveLength(1)
    const phoneOnly = container.querySelectorAll('.mantine-hidden-from-md')
    expect(
      [...phoneOnly].some((element) =>
        within(element as HTMLElement).queryByRole('button', { name: 'nav.signOut' })
      )
    ).toBe(true)
    // The sidebar marks the overview as the current page.
    expect(within(sidebar).getByRole('link', { name: 'profile.nav.overview' })).toHaveAttribute(
      'aria-current',
      'page'
    )
  })

  it('shows no line for what the summary carries until it lands', () => {
    state.summary = undefined
    renderOverview()

    expect(screen.queryByText(/profile\.status\.passkeys/)).toBeNull()
    expect(shortcuts('profile.nav.privacy', 'profile.status.notContactable')).toHaveLength(2)
  })
})
