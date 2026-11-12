import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { routeWeather } from '@/test/weatherFixtures'
import { TrackSurface, TrackSurfaceState, type GpxPreviewDto, type TrackDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({ isAuthenticated: false }))
const weatherState = vi.hoisted(() => ({ data: undefined as unknown }))
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
  getGetTeamQueryKey: (slug: string) => [`/api/teams/${slug}`],
}))
vi.mock('@/api/endpoints/gpx-previews/gpx-previews', () => ({
  createRouteFromPreview: vi.fn(),
  useDeletePreview: () => ({ mutateAsync: vi.fn(), isPending: false }),
  useGetPreviewWeather: () => ({
    data: weatherState.data,
    isLoading: false,
    isFetching: false,
    refetch: vi.fn(),
  }),
}))
vi.mock('@/components/route/RouteMapView', () => ({
  RouteMapView: () => <div data-testid="route-map" />,
}))

import { GpxPreviewView } from './GpxPreviewView'
import { createRouteFromPreview } from '@/api/endpoints/gpx-previews/gpx-previews'
import { ApiClientError } from '@/lib/apiError'

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
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <MemoryRouter>
          <GpxPreviewView preview={shown} />
        </MemoryRouter>
      </MantineProvider>
    </QueryClientProvider>
  )
}

describe('GpxPreviewView', () => {
  beforeEach(() => {
    state.isAuthenticated = false
    teamsState.teams = []
    weatherState.data = undefined
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

  it('explains a promotion refused at the team quota in the dialog, not in a toast', async () => {
    // jsdom has no scrollIntoView, which the combobox calls on the picked option
    Element.prototype.scrollIntoView = vi.fn()
    state.isAuthenticated = true
    teamsState.teams = [
      { slug: 'open', name: 'Les Copains', enableRoutes: true, enableRoutePlanner: true },
    ]
    vi.mocked(createRouteFromPreview).mockRejectedValue(
      new ApiClientError(403, {
        code: 'PLANNER_QUOTA_REACHED',
        errorDetails: {
          type: 'PLANNER_QUOTA_REACHED',
          scope: 'TEAM',
          limit: 20,
          current: 20,
          resetsOn: '2026-12-01',
          teamName: 'Les Copains',
        },
      })
    )
    renderView({ ...preview, drawn: true, owned: true })
    fireEvent.click(screen.getByText('Enregistrer comme parcours'))
    fireEvent.click(await screen.findByRole('combobox'))
    fireEvent.click(screen.getByRole('option', { name: 'Les Copains', hidden: true }))
    fireEvent.click(screen.getByRole('button', { name: 'Enregistrer' }))
    expect(await screen.findByTestId('planner-quota-modal')).toBeTruthy()
    expect(screen.getByText(/Les Copains utilise l'offre gratuite/)).toBeTruthy()
    expect(screen.getByText(/repart le 1er décembre/)).toBeTruthy()
  })

  describe('departure', () => {
    // The year shows only outside the current one: the clock is held in 2026.
    beforeEach(() => {
      vi.useFakeTimers({ toFake: ['Date'] })
      vi.setSystemTime(new Date('2026-09-01T10:00:00Z'))
    })
    afterEach(() => vi.useRealTimers())

    const dated: GpxPreviewDto = {
      ...preview,
      departureTime: '2026-10-18T06:30:00Z',
      departureTimezone: 'Europe/Paris',
    }

    it('says when the track leaves, in the zone of its start, with the speed if there is one', () => {
      renderView({ ...dated, averageSpeed: 27 })
      // The one format, in 700 on its departure line (ledger BRAND-8)
      const line = screen.getByTestId('departure-line')
      expect(line.textContent).toMatch(/^dim\. 18 oct\. · 08:30/)
      expect(screen.getByText(/^dim\. 18 oct\. · 08:30$/).getAttribute('style') ?? '').toContain(
        'font-weight: 700'
      )
      expect(screen.getByText(/Vitesse moyenne : 27/)).toBeTruthy()
    })

    it('shows no speed that was not given', () => {
      renderView(dated)
      expect(screen.getByTestId('departure-line')).toBeTruthy()
      expect(screen.queryByText(/Vitesse moyenne/)).toBeNull()
    })

    it('offers the owner, and only them, to add a date', () => {
      renderView({ ...preview, owned: true })
      expect(screen.getByText('Ajouter une date de départ pour voir la météo')).toBeTruthy()
      cleanup()
      renderView()
      expect(screen.queryByText('Ajouter une date de départ pour voir la météo')).toBeNull()
      expect(screen.queryByTestId('departure-line')).toBeNull()
    })

    it('shows the weather of the track, and offers the wind colouring with a forecast', () => {
      weatherState.data = { ...routeWeather, legs: routeWeather.legs.slice(0, 1) }
      renderView(dated)
      expect(screen.getByRole('heading', { name: 'Météo du parcours' })).toBeTruthy()
      expect(screen.getByRole('radio', { name: /Météo/ })).toBeTruthy()
    })

    it('has no weather block and no wind mode without a date', () => {
      renderView()
      expect(screen.queryByRole('heading', { name: 'Météo du parcours' })).toBeNull()
      expect(screen.queryByRole('radio', { name: /Météo/ })).toBeNull()
    })
  })
})
