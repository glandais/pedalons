import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { GpxPreviewSummaryDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({ previews: [] as unknown[] }))

vi.mock('./gpxPreviewListData', () => ({
  useGpxPreviewListData: () => ({
    filters: { page: 0 },
    setFilters: () => {},
    previews: { data: { previews: state.previews }, isLoading: false },
    totalPages: 1,
  }),
}))
vi.mock('@/api/endpoints/gpx-previews/gpx-previews', () => ({
  getListMyPreviewsQueryKey: () => ['previews'],
  useDeletePreview: () => ({ mutateAsync: async () => {}, isPending: false }),
}))

import { MyGpxPreviewsPage } from './MyGpxPreviewsPage'

const preview = (overrides: Partial<GpxPreviewSummaryDto> = {}): GpxPreviewSummaryDto => ({
  id: 'p1',
  name: 'Boucle du dimanche',
  distance: 42000,
  elevationGain: 600,
  elevationLoss: 590,
  hilliness: 14,
  createdAt: '2026-08-31T10:00:00Z',
  ...overrides,
})

function renderPage() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <MyGpxPreviewsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('MyGpxPreviewsPage — the departure (BRAND-8)', () => {
  // The year shows only outside the current one: the clock is held in 2026.
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date('2026-09-01T10:00:00Z'))
  })
  afterEach(() => {
    cleanup()
    vi.useRealTimers()
  })

  it('puts the departure under the name, in its one format and in 700, out of the stats', () => {
    state.previews = [
      preview({ departureTime: '2026-10-18T06:30:00Z', departureTimezone: 'Europe/Paris' }),
    ]
    renderPage()
    const line = screen.getByTestId('departure-line')
    expect(line.textContent).toBe('dim. 18 oct. · 08:30')
    expect(within(line).getByText('dim. 18 oct. · 08:30').getAttribute('style') ?? '').toContain(
      'font-weight: 700'
    )
    expect(screen.queryByText(/Départ : /)).toBeNull()
  })

  it('shows no departure line for a track without a date', () => {
    state.previews = [preview()]
    renderPage()
    expect(screen.getByText('Boucle du dimanche')).toBeTruthy()
    expect(screen.queryByTestId('departure-line')).toBeNull()
  })
})
