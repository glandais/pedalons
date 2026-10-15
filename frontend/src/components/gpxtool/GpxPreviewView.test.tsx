import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import type { GpxPreviewDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({ isAuthenticated: false }))

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
  useListTeams: () => ({ data: undefined }),
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
  owned: false,
  createdAt: '2026-10-15T08:00:00Z',
  gpxUrl: '/api/gpx-previews/0abcdefghijkl/gpx',
  fitUrl: '/api/gpx-previews/0abcdefghijkl/fit',
  tracks: [],
  waypoints: [],
}

function renderView() {
  render(
    <MantineProvider>
      <MemoryRouter>
        <GpxPreviewView preview={preview} />
      </MemoryRouter>
    </MantineProvider>
  )
}

describe('GpxPreviewView', () => {
  beforeEach(() => {
    state.isAuthenticated = false
  })
  afterEach(cleanup)

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
})
