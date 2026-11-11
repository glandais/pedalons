import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, fireEvent, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Visibility, TeamTier } from '@/api/dto'
import type { TeamDetailDto, UserDto } from '@/api/dto'
import { useAuthStore } from '@/store/authStore'

vi.mock('react-i18next', async (importOriginal) => ({
  ...(await importOriginal<typeof import('react-i18next')>()),
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

// What the preview query returns, and the refetches asked of it (docs/LEDGER_*.md API-60, plan §9).
const state = vi.hoisted(() => ({
  preview: {
    data: undefined as unknown,
    isError: false,
    isFetching: false,
  },
  refetch: vi.fn(),
  mutate: vi.fn(),
  adminMutate: vi.fn(),
  adminTeam: undefined as { tierNote?: string } | undefined,
}))

vi.mock('@/api/endpoints/teams/teams', () => ({
  useCreateTeam: () => ({ mutate: state.mutate, isPending: false }),
  useUpdateTeam: () => ({ mutate: state.mutate, isPending: false }),
  getListTeamsQueryKey: () => ['teams'],
  getGetTeamQueryKey: (slug: string) => ['team', slug],
  usePreviewTeamTimezoneChange: () => ({ ...state.preview, refetch: state.refetch }),
}))
vi.mock('@/api/endpoints/admin-teams/admin-teams', () => ({
  useAdminUpdateTeamAttributes: () => ({ mutate: state.adminMutate, isPending: false }),
  useAdminGetTeam: () => ({ data: state.adminTeam }),
  getAdminGetTeamQueryKey: (teamId: string) => ['admin-team', teamId],
  getAdminListTeamsQueryKey: () => ['admin-teams'],
}))
vi.mock('@/lib/teamDashboardCache', () => ({
  invalidateTeamDashboard: vi.fn(),
  invalidateTeamEventTimes: vi.fn(),
}))
vi.mock('../common/SlugEditor', () => ({ SlugEditor: () => null }))
vi.mock('../common/MediaEditor', () => ({ MediaEditor: () => null }))
// Two buttons stand in for a picked place whose position starts, then stops, resolving.
vi.mock('../common/GeocoderAutocomplete', () => ({
  GeocoderAutocomplete: ({
    onResolvingChange,
  }: {
    onResolvingChange?: (resolving: boolean) => void
  }) => (
    <>
      <button type="button" onClick={() => onResolvingChange?.(true)}>
        geocode-start
      </button>
      <button type="button" onClick={() => onResolvingChange?.(false)}>
        geocode-end
      </button>
    </>
  ),
}))
// A button per zone stands in for the searchable list.
vi.mock('../common/TimezoneSelect', () => ({
  TimezoneSelect: ({ onChange }: { onChange: (zone: string) => void }) => (
    <button type="button" onClick={() => onChange('Asia/Tokyo')}>
      pick-tokyo
    </button>
  ),
}))

import { TeamForm } from './TeamForm'

function renderForm(tier?: TeamTier) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <TeamForm
            teamSlug="velo-club"
            teamId="t1"
            create={false}
            onSuccess={vi.fn()}
            initialValues={{
              name: 'Vélo Club',
              media: { markdown: '', assets: { images: [], attachments: [] } },
              visibility: Visibility.TEAM,
              enableTrips: true,
              enableAds: true,
              enablePosts: true,
              enableRides: true,
              enableRoutes: true,
              enableMemberDirectory: false,
              postsAsTeamByDefault: true,
              timezone: 'Europe/Paris',
              tier,
            }}
          />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

beforeEach(() => {
  state.preview = { data: undefined, isError: true, isFetching: false }
  state.refetch.mockReset()
  state.mutate.mockReset()
  state.adminMutate.mockReset()
  state.adminTeam = undefined
})

afterEach(() => {
  cleanup()
  useAuthStore.setState({ isAuthenticated: false, user: null, accessToken: null })
})

function signInPlatformAdmin() {
  useAuthStore.setState({
    isInitialized: true,
    isAuthenticated: true,
    accessToken: 'at',
    user: {
      id: 'u1',
      displayName: 'Root',
      email: 'root@example.com',
      platformRole: 'PLATFORM_ADMIN',
    } as UserDto,
  })
}

// Saves the team, then runs the team update's success so the platform attributes go out.
function saveAndSendAttributes() {
  state.mutate.mockImplementation((_vars, opts?: { onSuccess?: (team: TeamDetailDto) => void }) =>
    opts?.onSuccess?.({ slug: 'velo-club' } as TeamDetailDto)
  )
  fireEvent.click(screen.getByText('actions.save'))
}

describe('TeamForm — change of zone', () => {
  it('asks the preview again when it failed, instead of reopening on the cached error', async () => {
    renderForm()
    fireEvent.click(screen.getByText('pick-tokyo'))
    fireEvent.click(screen.getByText('actions.save'))

    await waitFor(() => expect(state.refetch).toHaveBeenCalledTimes(1))
    expect(await screen.findByText('teams.settings.timezoneChange.error')).toBeTruthy()
    expect(state.mutate).not.toHaveBeenCalled()
  })

  it('offers a retry from the failed preview, and keeps Confirm disabled', async () => {
    renderForm()
    fireEvent.click(screen.getByText('pick-tokyo'))
    fireEvent.click(screen.getByText('actions.save'))
    state.refetch.mockReset()

    fireEvent.click(await screen.findByText('generic.retry'))
    expect(state.refetch).toHaveBeenCalledTimes(1)

    const confirm = screen.getByText('teams.settings.timezoneChange.confirm').closest('button')
    expect(confirm?.disabled).toBe(true)
  })
})

describe('TeamForm — place being resolved (docs/LEDGER_*.md API-129)', () => {
  it('keeps Save disabled while a picked place has no position yet', () => {
    renderForm()
    const save = () => screen.getByText('actions.save').closest('button')

    fireEvent.click(screen.getByText('geocode-start'))
    expect(save()?.disabled).toBe(true)

    fireEvent.click(screen.getByText('geocode-end'))
    expect(save()?.disabled).toBe(false)
  })
})

describe('TeamForm — plan (docs/LEDGER_*.md BILL-10)', () => {
  it('sends the tier, and leaves the note out when it was not touched', () => {
    signInPlatformAdmin()
    state.adminTeam = { tierNote: 'club pilote' }
    renderForm(TeamTier.UNLOCKED)

    const note = screen.getByTestId('team-tier-note') as HTMLTextAreaElement
    expect(note.value).toBe('club pilote')
    saveAndSendAttributes()

    expect(state.adminMutate).toHaveBeenCalledTimes(1)
    const data = state.adminMutate.mock.calls[0][0].data
    expect(data.tier).toBe(TeamTier.UNLOCKED)
    expect('tierNote' in data).toBe(false)
  })

  it('sends the note once edited, blank included so the backend clears it', () => {
    signInPlatformAdmin()
    state.adminTeam = { tierNote: 'club pilote' }
    renderForm(TeamTier.FREE)

    fireEvent.change(screen.getByTestId('team-tier-note'), { target: { value: '' } })
    saveAndSendAttributes()

    const data = state.adminMutate.mock.calls[0][0].data
    expect(data.tier).toBe(TeamTier.FREE)
    expect(data.tierNote).toBe('')
  })

  it('shows no note to a team admin, and sends no attributes', () => {
    renderForm(TeamTier.FREE)

    expect(screen.queryByTestId('team-tier-note')).toBeNull()
    saveAndSendAttributes()
    expect(state.adminMutate).not.toHaveBeenCalled()
  })
})
