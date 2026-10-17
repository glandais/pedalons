import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, fireEvent, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Visibility } from '@/api/dto'

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
}))

vi.mock('@/api/endpoints/teams/teams', () => ({
  useCreateTeam: () => ({ mutate: state.mutate, isPending: false }),
  useUpdateTeam: () => ({ mutate: state.mutate, isPending: false }),
  getListTeamsQueryKey: () => ['teams'],
  getGetTeamQueryKey: (slug: string) => ['team', slug],
  usePreviewTeamTimezoneChange: () => ({ ...state.preview, refetch: state.refetch }),
}))
vi.mock('@/api/endpoints/admin-teams/admin-teams', () => ({
  useAdminUpdateTeamAttributes: () => ({ mutate: vi.fn(), isPending: false }),
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

function renderForm() {
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
})

afterEach(cleanup)

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
