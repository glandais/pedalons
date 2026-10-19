import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { TrackSurface, TrackSurfaceState, type TrackDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { RouteSurfaceSummary } from './RouteSurfaceSummary'

function track(extra: Partial<TrackDto>): TrackDto {
  return { line: { type: 'LineString', coordinates: [] }, climbs: [], ...extra }
}

// 10 000 m: 6 000 asphalt (60 %), 3 997 path (40 % rounded), 3 m gravel (below 1 %)
const READY = track({
  surfaceState: TrackSurfaceState.READY,
  surfaces: [
    { from: 0, to: 6000, surface: TrackSurface.PAVED },
    { from: 6000, to: 6003, surface: TrackSurface.GRAVEL },
    { from: 6003, to: 10000, surface: TrackSurface.PATH },
  ],
})

function summary(tracks: TrackDto[], onColorByChange = vi.fn()) {
  render(
    <MantineProvider>
      <RouteSurfaceSummary tracks={tracks} colorBy="grade" onColorByChange={onColorByChange} />
    </MantineProvider>
  )
  return onColorByChange
}

describe('RouteSurfaceSummary', () => {
  afterEach(cleanup)

  it('shows the switch, the bar, the legend with the shares and the OSM credit', () => {
    summary([READY])
    expect(screen.getByTestId('route-surface-summary')).toBeTruthy()
    expect(screen.getByTestId('route-surface-bar')).toBeTruthy()
    const legend = screen.getByTestId('route-surface-legend')
    expect(legend.textContent).toContain('Asphalte 60 %')
    expect(legend.textContent).toContain('Sentier 40 %')
    expect(legend.textContent).toContain('Compacté, gravier < 1 %')
    expect(legend.textContent).not.toContain('Inconnu')
    const link = screen.getByRole('link', { name: '© contributeurs OpenStreetMap' })
    expect(link.getAttribute('href')).toBe('https://www.openstreetmap.org/copyright')
    expect(link.getAttribute('rel')).toContain('noopener')
    expect(screen.getByRole('radiogroup', { name: /Colorer le profil/ })).toBeTruthy()
  })

  it('reports the mode chosen', () => {
    const onColorByChange = summary([READY])
    fireEvent.click(screen.getByLabelText('Revêtement'))
    expect(onColorByChange).toHaveBeenCalledWith('surface')
  })

  it('says the surface is being computed, with no bar and no switch', () => {
    summary([track({ surfaceState: TrackSurfaceState.PENDING })])
    expect(screen.getByTestId('route-surface-pending').textContent).toBe(
      'Revêtement en cours de calcul'
    )
    expect(screen.queryByTestId('route-surface-bar')).toBeNull()
    expect(screen.queryByRole('radiogroup')).toBeNull()
  })

  it('shows nothing when the provider could not match the track or there is no surface', () => {
    summary([track({ surfaceState: TrackSurfaceState.UNAVAILABLE })])
    expect(screen.queryByTestId('route-surface-summary')).toBeNull()
    expect(screen.queryByTestId('route-surface-pending')).toBeNull()
    cleanup()
    summary([track({})])
    expect(screen.queryByTestId('route-surface-summary')).toBeNull()
    expect(screen.queryByTestId('route-surface-pending')).toBeNull()
  })
})
