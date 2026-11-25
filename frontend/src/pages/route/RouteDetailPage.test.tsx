import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({
  route: undefined as unknown,
  isAuthenticated: true,
}))

vi.mock('./routeDetailData', () => ({
  useRouteDetailData: () => ({
    route: { data: state.route, isLoading: false, error: null, refetch: () => {} },
    team: { data: undefined },
  }),
}))
vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({ isAuthenticated: state.isAuthenticated }),
}))
vi.mock('@/api/endpoints/routes/routes', () => ({
  useDeleteRoute: () => ({ mutateAsync: vi.fn(), isPending: false }),
  useUndeleteRoute: () => ({ mutateAsync: vi.fn(), isPending: false }),
  useDuplicateRoute: () => ({ mutate: vi.fn(), isPending: false }),
  useCreatePreviewFromRoute: () => ({ mutate: vi.fn(), isPending: false }),
}))
vi.mock('@/api/endpoints/gpx-previews/gpx-previews', () => ({
  getListMyPreviewsQueryKey: () => ['/api/gpx-previews'],
}))
vi.mock('../../components/routeRetouch/useRouteRetouchOffer', () => ({
  useRouteRetouchOffer: () => ({ data: undefined }),
}))
vi.mock('../../components/routeRetouch/RouteRetouchButton', () => ({
  RouteRetouchButton: () => <button type="button">Retoucher</button>,
}))
vi.mock('../../components/routeRetouch/RouteRetouchModal', () => ({
  RouteRetouchModal: () => null,
}))
vi.mock('@/components/route/GpsMenuButton', () => ({
  GpsMenuButton: () => <button type="button">GPS</button>,
}))
vi.mock('@/components/moderation/ContentActionsMenu', () => ({
  ContentActionsMenu: () => null,
}))
vi.mock('../../components/moderation/ContentActionsMenu', () => ({
  ContentActionsMenu: () => null,
}))
vi.mock('../../components/route/RouteDetailView', () => ({ RouteDetailView: () => null }))
vi.mock('../../components/route/RouteUsages', () => ({ RouteUsages: () => null }))
vi.mock('../../components/comment', () => ({ CommentSection: () => null }))
vi.mock('../../components/team/TeamContextBanner', () => ({ TeamContextBanner: () => null }))
vi.mock('../../components/common/MediaDisplay', () => ({ MediaDisplay: () => null }))
vi.mock('../../components/common/EntityLogo', () => ({ EntityLogo: () => null }))

import { RouteDetailPage } from './RouteDetailPage'

const makeRoute = (overrides: Record<string, unknown> = {}) => ({
  id: 'r1',
  slug: 'boucle',
  name: 'Boucle des étangs',
  deleted: false,
  team: { slug: 'copains', name: 'Les Copains', accessible: true },
  permissions: { canEdit: true, canDelete: true, canComment: false },
  media: { assets: { gpx: { url: '/x.gpx' } } },
  gpsSyncStatuses: [],
  tracks: [],
  ...overrides,
})

function renderPage() {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <MemoryRouter initialEntries={['/teams/copains/routes/boucle']}>
          <Routes>
            <Route path="/teams/:teamSlug/routes/:routeSlug" element={<RouteDetailPage />} />
          </Routes>
        </MemoryRouter>
      </MantineProvider>
    </QueryClientProvider>
  )
}

describe('RouteDetailPage header (WEB-206)', () => {
  beforeEach(() => {
    state.isAuthenticated = true
    state.route = makeRoute()
  })
  afterEach(cleanup)

  it('gives an editor « Modifier » as a link and the other actions in the menu', async () => {
    renderPage()
    expect(screen.getByRole('link', { name: 'Modifier' })).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'Dupliquer' })).toBeNull()
    expect(screen.queryByRole('button', { name: 'Supprimer' })).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: 'Options de gestion' }))
    expect(await screen.findByRole('menuitem', { name: 'Dupliquer', hidden: true })).toBeTruthy()
    expect(screen.getByRole('menuitem', { name: 'Supprimer', hidden: true })).toBeTruthy()
    expect(screen.queryByRole('menuitem', { name: 'Restaurer', hidden: true })).toBeNull()
  })

  it('offers a deleted route only « Restaurer »', async () => {
    state.route = makeRoute({ deleted: true })
    renderPage()
    fireEvent.click(screen.getByRole('button', { name: 'Options de gestion' }))
    expect(await screen.findByRole('menuitem', { name: 'Restaurer', hidden: true })).toBeTruthy()
    expect(screen.queryByRole('menuitem', { name: 'Dupliquer', hidden: true })).toBeNull()
    expect(screen.queryByRole('menuitem', { name: 'Supprimer', hidden: true })).toBeNull()
    expect(screen.queryByRole('button', { name: 'Retoucher' })).toBeNull()
  })

  it('offers a signed-in reader who cannot edit a copy, not « Modifier »', () => {
    state.route = makeRoute({
      permissions: { canEdit: false, canDelete: false, canComment: false },
    })
    renderPage()
    expect(screen.getByRole('button', { name: 'Modifier une copie' })).toBeTruthy()
    expect(screen.queryByRole('link', { name: 'Modifier' })).toBeNull()
    expect(screen.queryByRole('button', { name: 'Options de gestion' })).toBeNull()
    expect(screen.getByRole('button', { name: 'Retoucher' })).toBeTruthy()
  })
})
