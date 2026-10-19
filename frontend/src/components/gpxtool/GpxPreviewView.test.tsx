import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { TrackSurface, TrackSurfaceState, type GpxPreviewDto, type TrackDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({ isAuthenticated: false }))
const teamsState = vi.hoisted(() => ({
  teams: [] as { slug: string; name: string; enableRoutes: boolean; enableRoutePlanner: boolean }[],
}))

vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({ isAuthenticated: state.isAuthenticated }),
}))
vi.mock('@/hooks/useGpsConnections', () => ({
  useGpsConnections: () => ({
    connectedServices: [],
    uploadPreview: () => {},
    isUploadingPreview: false,
  }),
}))
vi.mock('@/api/endpoints/teams/teams', () => ({
  useListTeams: () => ({ data: { teams: teamsState.teams } }),
}))
vi.mock('@/api/endpoints/gpx-previews/gpx-previews', () => ({
  createRouteFromPreview: vi.fn(),
  useDeletePreview: () => ({ mutateAsync: vi.fn(), isPending: false }),
}))
vi.mock('@/components/route/RouteMapView', () => ({
  RouteMapView: () => <div data-testid="route-map" />,
}))

import { GpxPreviewView } from './GpxPreviewView'

const preview: GpxPreviewDto = {
  id: '0abcdefghijkl',
  name: 'Boucle des étangs',
  distance: 42_000,
  elevationGain: 350,
  elevationLoss: 350,
  hilliness: 8,
  elevationState: 'HD',
  owned: false,
  drawn: false,
  createdAt: '2026-10-15T08:00:00Z',
  gpxUrl: '/api/gpx-previews/0abcdefghijkl/gpx',
  fitUrl: '/api/gpx-previews/0abcdefghijkl/fit',
  tracks: [],
  waypoints: [],
}

function renderView(shown: GpxPreviewDto = preview) {
  render(
    <MantineProvider>
      <MemoryRouter>
        <GpxPreviewView preview={shown} />
      </MemoryRouter>
    </MantineProvider>
  )
}

describe('GpxPreviewView', () => {
  beforeEach(() => {
    state.isAuthenticated = false
    teamsState.teams = []
  })
  afterEach(cleanup)

  it('says the precise elevation is still being computed, only while the preview is PENDING', () => {
    renderView({ ...preview, elevationState: 'PENDING' })
    expect(screen.getByText(/Profil d'altitude provisoire/)).toBeTruthy()
    cleanup()
    renderView()
    expect(screen.queryByText(/Profil d'altitude provisoire/)).toBeNull()
    cleanup()
    renderView({ ...preview, elevationState: 'FAST' })
    expect(screen.queryByText(/Profil d'altitude provisoire/)).toBeNull()
  })

  it('shows the surface breakdown once the preview has it, and says when it is coming', () => {
    const withSurface = (extra: Partial<TrackDto>): GpxPreviewDto => ({
      ...preview,
      tracks: [{ line: { type: 'LineString', coordinates: [] }, climbs: [], ...extra }],
    })
    renderView(
      withSurface({
        surfaceState: TrackSurfaceState.READY,
        surfaces: [
          { from: 0, to: 3000, surface: TrackSurface.PAVED },
          { from: 3000, to: 4000, surface: TrackSurface.DIRT },
        ],
      })
    )
    expect(screen.getByTestId('route-surface-legend').textContent).toContain('Asphalte 75 %')
    expect(screen.getByTestId('route-surface-attribution')).toBeTruthy()
    cleanup()
    renderView(withSurface({ surfaceState: TrackSurfaceState.PENDING }))
    expect(screen.getByText('Revêtement en cours de calcul')).toBeTruthy()
    expect(screen.queryByTestId('route-surface-bar')).toBeNull()
    cleanup()
    renderView()
    expect(screen.queryByTestId('route-surface-summary')).toBeNull()
    expect(screen.queryByTestId('route-surface-pending')).toBeNull()
  })

  it('offers to share the preview to an anonymous visitor holding the link', () => {
    renderView()
    expect(screen.getByRole('heading', { name: 'Boucle des étangs' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Partager' })).toBeTruthy()
    // The account-only actions stay hidden.
    expect(screen.queryByText('Enregistrer comme parcours')).toBeNull()
  })

  it('keeps the share button for a signed-in member', () => {
    state.isAuthenticated = true
    renderView()
    expect(screen.getByRole('button', { name: 'Partager' })).toBeTruthy()
  })

  it('greys out the teams without route planner for a drawn preview, and says why', async () => {
    state.isAuthenticated = true
    teamsState.teams = [
      { slug: 'open', name: 'Équipe ouverte', enableRoutes: true, enableRoutePlanner: true },
      { slug: 'closed', name: 'Équipe fermée', enableRoutes: true, enableRoutePlanner: false },
    ]
    renderView({ ...preview, drawn: true, owned: true })
    fireEvent.click(screen.getByText('Enregistrer comme parcours'))
    fireEvent.click(await screen.findByRole('combobox'))
    expect(screen.getByText(/dont le tracé d'itinéraire est activé/)).toBeTruthy()
    expect(
      screen
        .getByRole('option', { name: 'Équipe ouverte', hidden: true })
        .hasAttribute('data-combobox-disabled')
    ).toBe(false)
    expect(
      screen
        .getByRole('option', { name: 'Équipe fermée', hidden: true })
        .hasAttribute('data-combobox-disabled')
    ).toBe(true)
  })
})
