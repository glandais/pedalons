import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { TrackSurface, TrackSurfaceState, type RouteDetailDto, type TrackDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

// The map is lazy and pulls map vendors: a stand-in that exposes the colour mode it was given.
vi.mock('@/components/route/RouteMapView', () => ({
  RouteMapView: ({ colorBy }: { colorBy?: string }) => <div data-testid="map">{colorBy}</div>,
}))
vi.mock('@/components/ride/RideGroupRouteActions', () => ({
  RideGroupRouteActions: () => null,
}))

import { GroupRouteMap } from './GroupRouteMap'

function route(track: Partial<TrackDto>): RouteDetailDto {
  return {
    tracks: [{ line: { type: 'LineString', coordinates: [] }, climbs: [], ...track }],
  } as unknown as RouteDetailDto
}

function show(r: RouteDetailDto | undefined) {
  render(
    <MantineProvider>
      <GroupRouteMap teamSlug="t" routeSlug="r" route={r} withActions={false} />
    </MantineProvider>
  )
}

describe('GroupRouteMap', () => {
  afterEach(cleanup)

  it('offers the grade / surface switch when the track has a surface', async () => {
    show(
      route({
        surfaceState: TrackSurfaceState.READY,
        surfaces: [{ from: 0, to: 1000, surface: TrackSurface.PAVED }],
      })
    )
    expect(await screen.findByTestId('route-surface-summary')).toBeTruthy()
    expect((await screen.findByTestId('map')).textContent).toBe('grade')
  })

  it('shows no switch without surfaces', async () => {
    show(route({}))
    await screen.findByTestId('map')
    expect(screen.queryByTestId('route-surface-summary')).toBeNull()
  })
})
