import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RideDto, RideWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import {
  okWeather,
  plain,
  routeLeg,
  routeWeather,
  weatherLeg,
  weatherRide,
} from '@/test/weatherFixtures'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

import { GroupWeatherSection } from './GroupWeatherSection'

/** A ride read in Paris time: passages from 08:30. */
const ride = (overrides: Partial<RideDto> = {}) =>
  weatherRide({ timezone: 'Europe/Paris', dateTime: '2026-10-18T06:30:00Z', ...overrides })

function renderSection(props: {
  ride?: RideDto
  weather?: RideWeatherDto
  leg?: WeatherLegDto
  canEdit?: boolean
  onRetry?: () => void
}) {
  const weather = 'weather' in props ? props.weather : routeWeather
  return render(
    <MantineProvider>
      <GroupWeatherSection
        ride={props.ride ?? ride()}
        weather={weather}
        leg={'leg' in props ? props.leg : weather?.legs.find((l) => l.groupId === 'g2')}
        isLoading={false}
        isFetching={false}
        onRetry={props.onRetry ?? (() => {})}
        canEdit={props.canEdit ?? false}
      />
    </MantineProvider>
  )
}

const text = () => plain(document.body.textContent)

/** The four verdict tiles, by their label. */
function verdict(label: string) {
  const tile = screen
    .getAllByRole('listitem')
    .find((li) => within(li).queryByText(label, { selector: 'p' }))
  if (!tile) throw new Error(`no verdict ${label}`)
  return plain(tile.textContent)
}

/** The detail panel of the selected point. */
const detail = () => plain(document.querySelector('[data-route-detail]')?.textContent)

/** The desktop table's columns, one button per point. */
const columns = () =>
  within(screen.getByRole('group', { name: 'Prévisions à chaque passage' })).getAllByRole('button')

describe('GroupWeatherSection', () => {
  afterEach(cleanup)

  it('answers the four questions first: temperatures, rain, wind, daylight', () => {
    renderSection({})
    expect(screen.getByRole('heading', { name: 'Météo du parcours' })).toBeTruthy()
    expect(text()).toContain('Open-Meteo.com')
    expect(verdict('Températures')).toContain('7 °C → 16 °C')
    expect(verdict('Températures')).toContain(
      '8 °C au départ, ressenti 5 °C. Le plus chaud vers 10:30.'
    )
    expect(verdict('Pluie')).toContain('Sec')
    expect(verdict('Pluie')).toContain('13 % au plus, de 09:30 à 10:30 (km 30 à km 60).')
    expect(verdict('Vent')).toContain('Face, puis dos')
    expect(verdict('Vent')).toContain('Vent dominant : N 14 km/h.')
    expect(verdict('Vent')).toContain(
      "De face par moments jusqu'au km 45 (rafales 32 km/h). Dans le dos après le km 60."
    )
    expect(verdict('Jour')).toContain('29 min de marge')
    expect(verdict('Jour')).toContain('Lever 08:28, coucher 11:59. Arrivée estimée 11:30.')
  })

  it('names the rain when the leg has an alert', () => {
    renderSection({
      leg: routeLeg({
        rainAlert: {
          probability: 60,
          time: '2026-10-18T08:00:00Z',
          distance: 45_000,
          condition: 'SHOWERS',
        },
      }),
    })
    expect(verdict('Pluie')).toContain('Averses')
    expect(verdict('Pluie')).toContain('Dès 10:00 (km 45), 60 %.')
    expect(verdict('Pluie')).not.toContain('Sec')
  })

  it('says 0 % when no point gives any chance of rain', () => {
    const leg = routeLeg()
    renderSection({
      leg: {
        ...leg,
        checkpoints: leg.checkpoints.map((c) => ({
          ...c,
          weather: c.weather && { ...c.weather, precipitationProbability: 0 },
        })),
      },
    })
    expect(verdict('Pluie')).toContain('0 % de risque de pluie tout le long.')
  })

  it('claims no dry weather when no point gives a chance of rain', () => {
    const leg = routeLeg()
    renderSection({
      leg: {
        ...leg,
        checkpoints: leg.checkpoints.map((c) => ({
          ...c,
          weather: c.weather && { ...c.weather, precipitationProbability: undefined },
        })),
      },
    })
    expect(verdict('Pluie')).toContain('—')
    expect(verdict('Pluie')).toContain('Cette prévision ne donne pas de probabilité de pluie.')
    expect(verdict('Pluie')).not.toContain('Sec')
    // Nor a measured 0 % to a screen reader.
    expect(columns()[0].getAttribute('aria-label')).not.toContain('pluie')
  })

  it('warns of an arrival after sunset, then after dark', () => {
    renderSection({ leg: routeLeg({ arrivalTime: '2026-10-18T10:39:00Z' }) })
    expect(verdict('Jour')).toContain('Arrivée 40 min après le coucher')
    cleanup()
    renderSection({
      leg: routeLeg({ startTime: '2026-10-18T05:00:00Z', arrivalTime: '2026-10-18T12:00:00Z' }),
    })
    expect(verdict('Jour')).toContain('Arrivée de nuit')
    expect(verdict('Jour')).toContain('Départ avant le lever du soleil.')
  })

  it('leaves the daylight tile out without a sunset', () => {
    renderSection({
      weather: {
        ...routeWeather,
        departure: { ...routeWeather.departure, sunrise: undefined, sunset: undefined },
      },
    })
    expect(screen.getAllByRole('listitem').map((li) => plain(li.textContent))).not.toContainEqual(
      expect.stringContaining('JOUR')
    )
    expect(text()).not.toContain('de marge')
  })

  it('draws the wind phase by phase, in words, with its totals', () => {
    renderSection({})
    const bar = screen.getByRole('group', { name: 'Le vent, tronçon par tronçon' })
    const phases = within(bar).getAllByRole('button')
    expect(phases.map((p) => p.getAttribute('aria-label'))).toEqual([
      'Vent de travers du km 0 au km 15, 08:30–09:00',
      'Vent de face du km 15 au km 45, 09:00–10:00',
      'Vent de travers du km 45 au km 60, 10:00–10:30',
      'Vent dans le dos du km 60 au km 90, 10:30–11:30',
    ])
    expect(plain(phases[1].textContent)).toContain('km 15–45 · 09:00–10:00')
    expect(text()).toContain('Face 30 km')
    expect(text()).toContain('Dos 30 km')
  })

  it('selects the first point, then the one clicked, and details it', () => {
    renderSection({})
    expect(text()).toContain('Passages estimés à 30 km/h · un point tous les 15 km')
    const cols = columns()
    expect(cols).toHaveLength(7)
    expect(cols[0].getAttribute('aria-pressed')).toBe('true')
    expect(detail()).toContain('Départ')
    expect(detail()).toContain('Travers du km 0 au km 15')

    fireEvent.click(cols[4])
    expect(columns()[4].getAttribute('aria-pressed')).toBe('true')
    expect(columns()[0].getAttribute('aria-pressed')).toBe('false')
    expect(detail()).toContain('km 60.0')
    expect(detail()).toContain('10:30')
    expect(detail()).toContain('16 °C')
    expect(detail()).toContain('ressenti 14 °C')
    expect(detail()).toContain('13 %')
    expect(detail()).toContain('Vent dans le dos')
    expect(detail()).toContain('rafales 24 km/h')
    expect(detail()).toContain('Dos du km 60 au km 90')

    fireEvent.click(columns()[6])
    expect(detail()).toContain('Arrivée · km 90.0')
  })

  it('selects the first point of a phase, from the bar and from the list', () => {
    renderSection({})
    const bar = screen.getByRole('group', { name: 'Le vent, tronçon par tronçon' })
    fireEvent.click(within(bar).getAllByRole('button')[1])
    expect(columns()[1].getAttribute('aria-pressed')).toBe('true')
    expect(detail()).toContain('km 15.0')

    const list = screen.getByRole('heading', { name: 'Par tronçon' }).parentElement!
    const items = within(list).getAllByRole('button')
    expect(plain(items[3].textContent)).toContain('Dos · km 60–90')
    expect(plain(items[3].textContent)).toContain(
      '10:30–11:30 · 16–18 km/h, raf. 24 · pluie ≤ 13 %'
    )
    expect(items[3].getAttribute('aria-expanded')).toBe('false')

    fireEvent.click(items[3])
    expect(items[3].getAttribute('aria-expanded')).toBe('true')
    expect(columns()[4].getAttribute('aria-pressed')).toBe('true')
    const rows = document.getElementById(items[3].getAttribute('aria-controls')!)!
    expect(
      within(rows)
        .getAllByRole('listitem', { hidden: true })
        .map((li) => plain(li.textContent))
    ).toEqual([
      '10:30km 6016 °C13 %Dos 16 (24)',
      '11:00km 7515 °C0 %Dos 17 (21)',
      '11:30km 9014 °C3 %Dos 18 (20)',
    ])

    // One phase open at a time.
    fireEvent.click(items[1])
    expect(items[1].getAttribute('aria-expanded')).toBe('true')
    expect(items[3].getAttribute('aria-expanded')).toBe('false')
  })

  it('keeps the phase clicked when it is shorter than the point spacing', () => {
    renderSection({
      leg: routeLeg({
        segments: [
          { fromDistance: 0, toDistance: 20_000, relativeWind: 'HEAD', headwind: 0 },
          { fromDistance: 20_000, toDistance: 22_000, relativeWind: 'CROSS', headwind: 0 },
          { fromDistance: 22_000, toDistance: 90_000, relativeWind: 'TAIL', headwind: 0 },
        ],
      }),
    })
    const bar = screen.getByRole('group', { name: 'Le vent, tronçon par tronçon' })
    fireEvent.click(within(bar).getAllByRole('button')[1])
    const blocks = within(bar).getAllByRole('button')
    expect(blocks.map((b) => b.getAttribute('aria-pressed'))).toEqual(['false', 'true', 'false'])
    expect(blocks[1].getAttribute('aria-label')).toBe('Vent de travers du km 20 au km 22, 09:00')
    expect(columns()[1].getAttribute('aria-pressed')).toBe('true')
    expect(detail()).toContain('Travers du km 20 au km 22')

    const list = screen.getByRole('heading', { name: 'Par tronçon' }).parentElement!
    const item = within(list).getAllByRole('button')[1]
    expect(plain(item.textContent)).toContain('Travers · km 20–22')
    expect(plain(item.textContent)).not.toContain('pluie')
    fireEvent.click(item)
    const panel = document.getElementById(item.getAttribute('aria-controls')!)!
    expect(within(panel).queryAllByRole('listitem', { hidden: true })).toHaveLength(0)
    expect(plain(panel.textContent)).toContain('Aucun point de prévision sur ce tronçon')
  })

  it('announces a point picked by pointer, not one the slider already speaks', () => {
    renderSection({})
    const live = () => plain(document.querySelector('[aria-live="polite"]')?.textContent)
    fireEvent.click(columns()[4])
    expect(live()).toBe('km 60.0, 10:30')
    fireEvent.change(screen.getByRole('slider'), { target: { value: '2' } })
    expect(live()).toBe('')
  })

  it('selects a point with the slider on a phone', () => {
    renderSection({})
    const slider = screen.getByRole('slider', { name: 'Glisser pour choisir un passage' })
    fireEvent.change(slider, { target: { value: '2' } })
    expect(columns()[2].getAttribute('aria-pressed')).toBe('true')
    expect(slider.getAttribute('aria-valuetext')).toContain('09:30, km 30.0')
  })

  it('keeps a point without forecast selectable, and says so', () => {
    const leg = routeLeg()
    renderSection({
      leg: {
        ...leg,
        checkpoints: leg.checkpoints.map((c, i) => (i === 3 ? { ...c, weather: undefined } : c)),
      },
    })
    expect(plain(columns()[3].textContent)).toContain('—')
    fireEvent.click(columns()[3])
    expect(detail()).toContain('Pas encore de prévision')
  })

  it('keeps the departure for a group without a route', () => {
    renderSection({ leg: weatherLeg('g2', { status: WeatherStatus.NO_LOCATION, checkpoints: [] }) })
    expect(text()).toMatch(/Au départ · 08:30/)
    expect(text()).toContain("Ce groupe n'a pas de parcours")
    expect(screen.queryByRole('group', { name: 'Prévisions à chaque passage' })).toBeNull()
  })

  it('flags an old forecast', () => {
    renderSection({ weather: { ...routeWeather, status: WeatherStatus.STALE } })
    expect(screen.getByText('Prévision ancienne')).toBeTruthy()
  })

  it('says when the forecast opens, and offers to retry an unreadable one', () => {
    renderSection({
      weather: {
        ...okWeather,
        status: WeatherStatus.NOT_YET_AVAILABLE,
        availableFrom: '2026-10-01T06:40:00Z',
        legs: [],
      },
    })
    expect(text()).toContain('La météo sera disponible à partir du')
    cleanup()
    const onRetry = vi.fn()
    renderSection({ weather: undefined, onRetry })
    fireEvent.click(screen.getByRole('button', { name: 'Réessayer' }))
    expect(onRetry).toHaveBeenCalled()
  })

  it('speaks of a missing place to organisers only', () => {
    const noLocation = { ...okWeather, status: WeatherStatus.NO_LOCATION, legs: [] }
    renderSection({ weather: noLocation, canEdit: false })
    expect(screen.queryByText(/Ajoutez un lieu/)).toBeNull()
    cleanup()
    renderSection({ weather: noLocation, canEdit: true })
    expect(screen.getByText(/Ajoutez un lieu/)).toBeTruthy()
  })

  it('draws nothing out of range, for a finished or cancelled ride', () => {
    const { container: outOfRange } = renderSection({
      weather: { ...okWeather, status: WeatherStatus.OUT_OF_RANGE, legs: [] },
    })
    expect(outOfRange.querySelector('section')).toBeNull()
    cleanup()
    const { container: finished } = renderSection({ ride: ride({ finished: true }) })
    expect(finished.querySelector('section')).toBeNull()
    cleanup()
    const { container: cancelled } = renderSection({ ride: ride({ status: Status.CANCELLED }) })
    expect(cancelled.querySelector('section')).toBeNull()
  })
})
