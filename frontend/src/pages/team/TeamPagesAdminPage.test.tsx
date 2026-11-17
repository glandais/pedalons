import type { ReactNode } from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TeamDetailDto, TeamPageSummaryDto } from '@/api/dto'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

const state = vi.hoisted(() => ({ pages: [] as unknown[] }))

vi.mock('./teamPagesAdminData', () => ({
  useTeamPagesAdminData: () => ({
    team: {
      data: { slug: 'np', name: 'N Peloton', role: 'ADMIN' } as unknown as TeamDetailDto,
      isLoading: false,
    },
    pages: { data: state.pages, isLoading: false },
  }),
}))
vi.mock('../../hooks/useCanonicalPath', () => ({ useCanonicalPath: () => {} }))
vi.mock('../../components/team/TeamAdminLayout', () => ({
  TeamAdminLayout: ({ children }: { children: ReactNode }) => <>{children}</>,
}))
vi.mock('@/api/endpoints/team-pages/team-pages', () => ({
  useDeletePage: () => ({ mutate: vi.fn(), isPending: false }),
  useUndeletePage: () => ({ mutate: vi.fn(), isPending: false }),
  useReorderPages: () => ({ mutate: vi.fn(), isPending: false }),
  getListPagesQueryKey: (slug: string) => ['pages', slug],
}))

import { TeamPagesAdminPage } from './TeamPagesAdminPage'

function page(n: number, deleted = false): TeamPageSummaryDto {
  return {
    id: `p${n}`,
    title: `Page ${n}`,
    slug: `page-${n}`,
    visibility: 'PUBLIC',
    order: n,
    deleted,
    status: 'PUBLISHED',
    moderationHidden: false,
  }
}

function renderPage(pages: TeamPageSummaryDto[]) {
  state.pages = pages
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <MemoryRouter initialEntries={['/np']}>
          <Routes>
            <Route path="/:teamSlug" element={<TeamPagesAdminPage />} />
          </Routes>
        </MemoryRouter>
      </MantineProvider>
    </QueryClientProvider>
  )
}

/** The cap counts the pages the server counts: not the ones in the bin (WEB-185, API-204). */
describe('TeamPagesAdminPage cap', () => {
  afterEach(cleanup)

  it('still offers « Ajouter une page » with two active pages and one in the bin', () => {
    renderPage([page(1), page(2), page(3, true)])
    expect(screen.getByText('2 pages sur 3 maximum')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Ajouter une page' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Restaurer' })).not.toBeDisabled()
  })

  it('disables « Restaurer » and says why once three pages are active', () => {
    renderPage([page(1), page(2), page(3), page(4, true)])
    expect(screen.queryByRole('link', { name: 'Ajouter une page' })).toBeNull()
    expect(screen.getByRole('button', { name: 'Restaurer' })).toBeDisabled()
    expect(
      screen.getByText("L'équipe a déjà ses 3 pages : supprimez-en une pour restaurer celle-ci.")
    ).toBeInTheDocument()
  })
})
