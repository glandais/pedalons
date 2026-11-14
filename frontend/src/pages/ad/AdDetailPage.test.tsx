import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { AdDto, TeamDetailDto } from '@/api/dto'
import { AdType, Status } from '@/api/dto'
import { pathVariants, paths } from '@/config/paths'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

/** The ad the page reads, and every request it sends. */
const state = vi.hoisted(() => ({
  ad: undefined as unknown,
  requests: [] as Array<{ url: string; method: string; data?: unknown }>,
}))

vi.mock('@/lib/axiosInstance', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/lib/axiosInstance')>()),
  axiosMutator: (config: { url: string; method: string; data?: unknown }) => {
    state.requests.push({ url: config.url, method: config.method, data: config.data })
    return Promise.resolve({})
  },
}))
vi.mock('./adDetailData', () => ({
  useAdDetailData: () => ({
    team: {
      data: { slug: 'np', name: 'N Peloton', enableAds: true, role: 'MEMBER' } as TeamDetailDto,
      isLoading: false,
    },
    ad: { data: state.ad, isLoading: false, error: null, refetch: () => {} },
  }),
}))
vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({ isAuthenticated: true, user: { id: 'author' } }),
}))
vi.mock('@/components/team/TeamContextBanner', () => ({ TeamContextBanner: () => null }))
vi.mock('@/components/moderation/ContentActionsMenu', () => ({ ContentActionsMenu: () => null }))
vi.mock('@/components/ad/AdLocationMap', () => ({ AdLocationMap: () => <div /> }))
vi.mock('@/components/ad/AdGallery', () => ({ AdGallery: () => null }))
vi.mock('@/components/ad/AdContactModal', () => ({ AdContactModal: () => null }))
vi.mock('@/components/common/MediaDisplay', () => ({ MediaDisplay: () => null }))

import { AdDetailPage } from './AdDetailPage'

/** The author's own ad, as `GET …/classifieds/{slug}` serves it: the point is the blurred one. */
const ad = (status: Status): AdDto =>
  ({
    id: 'a1',
    slug: 'velo',
    name: 'Vélo de route',
    status,
    visibility: 'TEAM',
    adType: AdType.SALE,
    price: 450,
    locationDescription: 'Rennes centre',
    locationGeometry: { type: 'Point', coordinates: [-1.675, 48.115] },
    media: { markdown: '', assets: { attachments: [] } },
    images: [],
    tags: [],
    team: { slug: 'np', name: 'N Peloton', visibility: 'PUBLIC', accessible: true },
    permissions: { canEdit: true, canDelete: true },
    createdAt: '2026-11-10T08:00:00Z',
    updatedAt: '2026-11-10T08:00:00Z',
    createdById: 'author',
    createdByDisplayName: 'Léa',
    deleted: false,
  }) as unknown as AdDto

function renderPage() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[paths.ad('np', 'velo')]}>
          <Routes>
            {Object.values(pathVariants.ad(':teamSlug', ':adSlug')).map((path) => (
              <Route key={path} path={path} element={<AdDetailPage />} />
            ))}
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

async function openMenu() {
  fireEvent.click(screen.getByRole('button', { name: 'Options de gestion' }))
  // The dropdown lives in a portal jsdom does not lay out: query it with `hidden`.
  await screen.findByRole('menu', { hidden: true })
}

const STATUS_URL = '/api/teams/np/classifieds/velo/status'
const writes = () => state.requests.filter((request) => request.method !== 'GET')

// `AdDto.locationGeometry` is blurred for the author too, and the full update applies what an
// author sends: a PUT of the ad would replace the exact place with the centre of its cell
// (docs/LEDGER_*.md WEB-181).
describe('AdDetailPage — publishing changes the status alone, never the ad (WEB-181)', () => {
  beforeEach(() => {
    state.requests.length = 0
  })
  afterEach(cleanup)

  it('publishes a draft through PATCH …/status, without sending the blurred point back', async () => {
    state.ad = ad(Status.DRAFT)
    renderPage()
    await openMenu()
    fireEvent.click(screen.getByRole('menuitem', { name: 'Publier', hidden: true }))

    await waitFor(() => expect(writes()).toHaveLength(1))
    expect(writes()[0]).toEqual({
      url: STATUS_URL,
      method: 'PATCH',
      data: { status: Status.PUBLISHED },
    })
  })

  it('unpublishes, once confirmed, through PATCH …/status too', async () => {
    state.ad = ad(Status.PUBLISHED)
    renderPage()
    await openMenu()
    fireEvent.click(screen.getByRole('menuitem', { name: 'Dépublier', hidden: true }))
    const dialog = await screen.findByRole('dialog', { hidden: true })
    const confirm = Array.from(dialog.querySelectorAll('button')).find(
      (button) => button.textContent === 'Dépublier'
    )
    fireEvent.click(confirm!)

    await waitFor(() => expect(writes()).toHaveLength(1))
    expect(writes()[0]).toEqual({
      url: STATUS_URL,
      method: 'PATCH',
      data: { status: Status.DRAFT },
    })
  })
})
