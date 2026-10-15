import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { paths } from '@/config/paths'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/api/endpoints/gpx-previews/gpx-previews', () => ({
  createPreview: vi.fn(),
  getListMyPreviewsQueryKey: () => ['gpx-previews'],
}))
vi.mock('@/config/appConfig', () => ({ isGpxPlannerEnabled: () => false }))

import { GpxToolsPage } from './GpxToolsPage'

afterEach(() => {
  cleanup()
  vi.clearAllMocks()
})

describe('GpxToolsPage', () => {
  it('opens the map with no track from its card', () => {
    render(
      <MantineProvider>
        <QueryClientProvider client={new QueryClient()}>
          <MemoryRouter initialEntries={[paths.gpxTools()]}>
            <Routes>
              <Route path={paths.gpxTools()} element={<GpxToolsPage />} />
              <Route path={paths.gpxToolsBlankMap()} element={<div data-testid="blank-map" />} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      </MantineProvider>
    )

    expect(screen.getByText('Ouvrir une carte')).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Ouvrir la carte' }))
    expect(screen.getByTestId('blank-map')).toBeTruthy()
  })
})
