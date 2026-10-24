import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { TripDto, TripStageDto, TripWeatherDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import type { MapItemWind } from '@/lib/tripWeatherOnMap'
import { plain, weatherLeg } from '@/test/weatherFixtures'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({ map: {} as Record<string, unknown> }))
vi.mock('@/components/route/RoutesMapView', () => ({
  RoutesMapView: (props: Record<string, unknown>) => {
    state.map = props
    return <div data-testid="routes-map" />
  },
}))

import { TripOverviewMap } from './TripOverviewMap'

const stage = (id: string, timezone: string): TripStageDto =>
  ({ id, slug: id, name: id, timezone, route: { slug: `route-${id}` } }) as unknown as TripStageDto

const trip = (overrides: Partial<TripDto> = {}): TripDto =>
  ({
    id: 't1',
    slug: 'voyage',
    status: Status.PUBLISHED,
    finished: false,
    timezone: 'Europe/Paris',
    stages: [
      stage('s1', 'Europe/Paris'),
      stage('s2', 'Europe/Lisbon'),
      stage('s3', 'Europe/Lisbon'),
    ],
    ...overrides,
  }) as TripDto

const weather: TripWeatherDto = {
  status: WeatherStatus.OK,
  stages: [
    {
      stageId: 's1',
      leg: weatherLeg(undefined, { windExposure: { head: 30_000, cross: 0, tail: 0 } }),
    },
    {
      stageId: 's2',
      leg: weatherLeg(undefined, { windExposure: { head: 0, cross: 4_000, tail: 16_000 } }),
    },
    { stageId: 's3', leg: weatherLeg(undefined, { status: WeatherStatus.OUT_OF_RANGE }) },
  ],
  attribution: { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' },
}

const items = (t: TripDto) =>
  t.stages.map((s) => ({ id: s.id, name: s.name, routeSlug: s.route?.slug }))

function show(t: TripDto = trip(), w: TripWeatherDto | null = weather) {
  return render(
    <MantineProvider>
      <TripOverviewMap
        trip={t}
        items={items(t)}
        teamSlug="np"
        weather={w ?? undefined}
        highlightedItemId={null}
        onItemHover={() => {}}
      />
    </MantineProvider>
  )
}

const winds = () => state.map.winds as ReadonlyMap<string, MapItemWind> | undefined

describe('TripOverviewMap (WEB-118)', () => {
  beforeEach(() => {
    state.map = {}
  })
  afterEach(cleanup)

  it('offers « Étapes | Météo », one colour per stage by default', async () => {
    show()
    await screen.findByTestId('routes-map')
    expect(plain(screen.getByTestId('trip-map-mode').textContent)).toBe('ÉtapesMétéo')
    expect(winds()).toBeUndefined()
    expect(state.map.windAttribution).toBeUndefined()
    expect(screen.queryByTestId('wind-map-legend')).toBeNull()
  })

  it('colours every stage with a forecast by its own wind, its badges in its own zone', async () => {
    show()
    await screen.findByTestId('routes-map')
    fireEvent.click(screen.getByLabelText('Météo'))
    expect([...winds()!.keys()]).toEqual(['s1', 's2'])
    expect(winds()!.get('s1')).toEqual({ leg: weather.stages[0].leg, timezone: 'Europe/Paris' })
    expect(winds()!.get('s2')).toEqual({ leg: weather.stages[1].leg, timezone: 'Europe/Lisbon' })
    expect(state.map.windAttribution).toEqual(weather.attribution)
  })

  it("adds the stages' shares up in one legend, with the forecast's credit", async () => {
    show()
    await screen.findByTestId('routes-map')
    fireEvent.click(screen.getByLabelText('Météo'))
    const legend = plain(screen.getByTestId('wind-map-legend').textContent)
    expect(legend).toContain('Dos 16.0 km')
    expect(legend).toContain('Travers 4.0 km')
    expect(legend).toContain('Face 30.0 km')
    expect(legend).toContain('Open-Meteo.com')
    // Both stages ride at the default speed: said for the stages
    expect(legend).toContain('pour les étapes sans vitesse indiquée')
  })

  it('offers no Météo mode on a trip over or cancelled, nor without a forecast', async () => {
    for (const t of [trip({ finished: true }), trip({ status: Status.CANCELLED })]) {
      show(t)
      await screen.findByTestId('routes-map')
      expect(screen.queryByLabelText('Météo')).toBeNull()
      expect(winds()).toBeUndefined()
      cleanup()
    }
    show(trip(), null)
    await screen.findByTestId('routes-map')
    expect(screen.queryByLabelText('Météo')).toBeNull()
  })

  it('falls back on the stages when a refetch loses the forecast', async () => {
    const { rerender } = show()
    await screen.findByTestId('routes-map')
    fireEvent.click(screen.getByLabelText('Météo'))
    expect(winds()).toBeDefined()
    const t = trip()
    rerender(
      <MantineProvider>
        <TripOverviewMap
          trip={t}
          items={items(t)}
          teamSlug="np"
          weather={{ ...weather, stages: [] }}
          highlightedItemId={null}
          onItemHover={() => {}}
        />
      </MantineProvider>
    )
    expect(winds()).toBeUndefined()
    expect(screen.queryByTestId('wind-map-legend')).toBeNull()
  })
})
