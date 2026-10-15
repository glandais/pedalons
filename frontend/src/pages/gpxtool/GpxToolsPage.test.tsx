import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { paths } from '@/config/paths'
import { notifications } from '@mantine/notifications'
import { mergePreviews } from '@/api/endpoints/gpx-previews/gpx-previews'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/api/endpoints/gpx-previews/gpx-previews', () => ({
  createPreview: vi.fn(),
  mergePreviews: vi.fn(),
  getListMyPreviewsQueryKey: () => ['gpx-previews'],
}))
vi.mock('@mantine/notifications', () => ({ notifications: { show: vi.fn() } }))
vi.mock('@/config/appConfig', () => ({ isGpxPlannerEnabled: () => false }))

import { GpxToolsPage } from './GpxToolsPage'

afterEach(() => {
  cleanup()
  vi.clearAllMocks()
})

function renderHub() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[paths.gpxTools()]}>
          <Routes>
            <Route path={paths.gpxTools()} element={<GpxToolsPage />} />
            <Route path={paths.gpxToolsBlankMap()} element={<div data-testid="blank-map" />} />
            <Route
              path={paths.gpxToolsView(':previewId')}
              element={<div data-testid="preview" />}
            />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

function gpxFiles(count: number): File[] {
  return Array.from(
    { length: count },
    (_, i) => new File(['<gpx/>'], `part-${i}.gpx`, { type: 'application/gpx+xml' })
  )
}

function pickForMerge(files: File[]) {
  fireEvent.change(screen.getByTestId('gpx-merge-input'), { target: { files } })
}

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

  it('merges the picked files and opens the merged preview', async () => {
    vi.mocked(mergePreviews).mockResolvedValue({ id: 'abc123' } as Awaited<
      ReturnType<typeof mergePreviews>
    >)
    renderHub()

    expect(screen.getByText('Fusionner des fichiers')).toBeTruthy()
    const files = gpxFiles(3)
    pickForMerge(files)

    expect(await screen.findByTestId('preview')).toBeTruthy()
    expect(mergePreviews).toHaveBeenCalledWith({ gpxFiles: files })
  })

  it.each([1, 11])('refuses %i file(s) before uploading', (count) => {
    renderHub()

    pickForMerge(gpxFiles(count))

    expect(mergePreviews).not.toHaveBeenCalled()
    expect(notifications.show).toHaveBeenCalledWith(
      expect.objectContaining({
        color: 'yellow',
        message: expect.stringContaining('entre 2 et 10'),
      })
    )
  })
})
