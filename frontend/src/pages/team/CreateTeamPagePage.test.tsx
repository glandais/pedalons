import type { ReactNode } from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TeamDetailDto, Visibility } from '@/api/dto'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

const state = vi.hoisted(() => ({ team: undefined as unknown }))

vi.mock('./teamPageFormData', () => ({
  useCreateTeamPageFormData: () => ({ team: { data: state.team, isLoading: false } }),
}))
vi.mock('../../hooks/useCanonicalPath', () => ({ useCanonicalPath: () => {} }))
vi.mock('../../components/team/TeamAdminLayout', () => ({
  TeamAdminLayout: ({ children }: { children: ReactNode }) => <>{children}</>,
}))
vi.mock('@/components/common/MediaEditor', () => ({ MediaEditor: () => null }))
vi.mock('@/components/common/SlugEditor', () => ({ SlugEditor: () => null }))
vi.mock('@/api/endpoints/team-pages/team-pages', () => ({
  useCreatePage: () => ({ mutate: vi.fn(), isPending: false }),
  useUpdatePage: () => ({ mutate: vi.fn(), isPending: false }),
  useChangePageSlug: () => ({ mutateAsync: vi.fn(), isPending: false }),
  getListPagesQueryKey: (slug: string) => ['pages', slug],
  getGetPageQueryKey: (slug: string, page: string) => ['page', slug, page],
}))

import { CreateTeamPagePage } from './CreateTeamPagePage'

function renderPage(teamPage: Visibility[], visibility: Visibility = 'PUBLIC') {
  state.team = {
    slug: 'np',
    name: 'N Peloton',
    visibility,
    role: 'ADMIN',
    allowedContentVisibilities: {
      ride: ['TEAM'],
      route: ['TEAM'],
      rideTemplate: ['TEAM'],
      post: ['TEAM'],
      trip: ['TEAM'],
      teamPage,
      ad: ['TEAM'],
    },
  } as unknown as TeamDetailDto
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <MemoryRouter initialEntries={['/np']}>
          <Routes>
            <Route path="/:teamSlug" element={<CreateTeamPagePage />} />
          </Routes>
        </MemoryRouter>
      </MantineProvider>
    </QueryClientProvider>
  )
}

/** A team page takes « Non répertorié » too, as soon as the backend allows it (plan A2, WEB-166). */
describe('CreateTeamPagePage visibility', () => {
  afterEach(cleanup)

  it("offers every value of the team's allowedContentVisibilities.teamPage, unlisted included", () => {
    renderPage(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
    expect(screen.getAllByRole('radio').map((r) => (r as HTMLInputElement).value)).toEqual([
      'TEAM',
      'PUBLIC_UNLISTED',
      'PUBLIC',
    ])
    expect(screen.getByRole('radio', { name: 'Non répertorié' })).not.toBeDisabled()
    expect(screen.getByRole('radio', { name: 'Équipe uniquement' })).toBeChecked()
  })

  it('shows no field when the team only allows « Équipe uniquement »', () => {
    renderPage(['TEAM'], 'TEAM')
    expect(screen.queryByRole('radio')).toBeNull()
  })
})
