import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import type { GpxPreviewDto } from '@/api/dto'
import { routeWeather } from '@/test/weatherFixtures'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

const state = vi.hoisted(() => ({
  preview: undefined as unknown,
  view: {} as Record<string, unknown>,
}))

vi.mock('@/pages/gpxtool/gpxPreviewData', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/pages/gpxtool/gpxPreviewData')>()),
  useGpxPreviewData: () => ({ data: state.preview, isLoading: false }),
  useGpxPreviewWeather: () => ({ weather: { data: routeWeather } }),
}))
vi.mock('@/hooks/useAppName', () => ({ useAppName: () => 'Pédalons' }))
vi.mock('@/hooks/useCanonicalPath', () => ({ useCanonicalPath: () => {} }))
vi.mock('@/components/route/MapColorFullscreenView', () => ({
  MapColorFullscreenView: (props: Record<string, unknown>) => {
    state.view = props
    return <div />
  },
}))

import { GpxPreviewFullscreenMapPage } from './GpxPreviewFullscreenMapPage'

afterEach(cleanup)

describe('GpxPreviewFullscreenMapPage', () => {
  it('hands the leg, the credit and the zone of the forecast to the map, for the track', () => {
    state.preview = {
      id: 'p1',
      name: 'Boucle',
      departureTime: '2026-10-18T06:30:00Z',
      departureTimezone: 'Europe/Paris',
    } as GpxPreviewDto
    render(
      <MemoryRouter initialEntries={['/p1']}>
        <Routes>
          <Route path="/:previewId" element={<GpxPreviewFullscreenMapPage />} />
        </Routes>
      </MemoryRouter>
    )
    expect(state.view.windLeg).toBe(routeWeather.legs[0])
    expect(state.view.windAttribution).toBe(routeWeather.attribution)
    expect(state.view.windSubject).toBe('track')
    expect(state.view.timezone).toBe('Europe/Paris')
  })
})
