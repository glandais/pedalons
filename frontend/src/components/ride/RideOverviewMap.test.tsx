import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
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

import { RideOverviewMap } from './RideOverviewMap'

const items = [
  { id: 'route-court', name: 'Chill', routeSlug: 'court' },
  { id: 'route-long', name: 'Rapide', routeSlug: 'long' },
]
const attribution = { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' }
const myWind: MapItemWind = { leg: weatherLeg('g2'), timezone: 'Europe/Paris' }

function show(
  winds: ReadonlyMap<string, MapItemWind> = new Map([['route-long', myWind]]),
  shown = items
) {
  const onItemSelect = vi.fn()
  const view = render(
    <MantineProvider>
      <RideOverviewMap
        items={shown}
        teamSlug="np"
        winds={winds}
        attribution={attribution}
        highlightedItemId={null}
        onItemHover={() => {}}
        selectedItemId={null}
        onItemSelect={onItemSelect}
      />
    </MantineProvider>
  )
  return { ...view, onItemSelect }
}

describe('RideOverviewMap (WEB-178)', () => {
  beforeEach(() => {
    state.map = {}
  })
  afterEach(cleanup)

  it("offers « Parcours | Météo » for the reader's group, one colour per route by default", async () => {
    show()
    await screen.findByTestId('routes-map')
    expect(plain(screen.getByTestId('ride-map-mode').textContent)).toBe('ParcoursMétéo')
    expect(state.map.winds).toBeUndefined()
    expect(state.map.windAttribution).toBeUndefined()
    expect(screen.queryByTestId('wind-map-legend')).toBeNull()
  })

  it("lays the group's wind on its route, selects it, and says it in a legend", async () => {
    const { onItemSelect } = show()
    await screen.findByTestId('routes-map')
    fireEvent.click(screen.getByLabelText('Météo'))
    const winds = state.map.winds as ReadonlyMap<string, MapItemWind>
    expect([...winds.keys()]).toEqual(['route-long'])
    expect(state.map.windAttribution).toEqual(attribution)
    expect(onItemSelect).toHaveBeenCalledWith('route-long')
    const legend = plain(screen.getByTestId('wind-map-legend').textContent)
    expect(legend).toContain('Face 50,0 km')
    expect(legend).toContain('Open-Meteo.com')
  })

  it('has no switch for a reader without a group', async () => {
    show(new Map())
    await screen.findByTestId('routes-map')
    expect(screen.queryByTestId('ride-map-mode')).toBeNull()
  })

  it('falls back on the routes when the forecast goes', async () => {
    const { rerender } = show()
    await screen.findByTestId('routes-map')
    fireEvent.click(screen.getByLabelText('Météo'))
    rerender(
      <MantineProvider>
        <RideOverviewMap
          items={items}
          teamSlug="np"
          winds={new Map()}
          highlightedItemId={null}
          onItemHover={() => {}}
          selectedItemId={null}
          onItemSelect={() => {}}
        />
      </MantineProvider>
    )
    expect(state.map.winds).toBeUndefined()
    expect(screen.queryByTestId('wind-map-legend')).toBeNull()
  })

  it('asks for the km markers on a single trace only, never in the Météo mode', async () => {
    show(new Map([['route-court', myWind]]), items.slice(0, 1))
    await screen.findByTestId('routes-map')
    expect(state.map.kmMarkers).toBe(true)
    fireEvent.click(screen.getByLabelText('Météo'))
    expect(state.map.kmMarkers).toBe(false)
    cleanup()
    show()
    await screen.findByTestId('routes-map')
    expect(state.map.kmMarkers).toBe(false)
  })
})
