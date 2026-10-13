import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RideDto, RideWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import {
  conditions,
  okWeather,
  plain,
  weatherLeg,
  weatherRide as ride,
} from '@/test/weatherFixtures'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

import { GroupWeatherSection } from './GroupWeatherSection'

function renderSection(props: {
  ride?: RideDto
  weather?: RideWeatherDto
  leg?: WeatherLegDto
  canEdit?: boolean
  onRetry?: () => void
}) {
  const weather = 'weather' in props ? props.weather : okWeather
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

describe('GroupWeatherSection', () => {
  afterEach(cleanup)

  it("shows the departure, then the group's whole route, then the provider", () => {
    renderSection({})
    const text = plain(document.body.textContent)
    expect(screen.getByRole('heading', { name: 'Météo du parcours' })).toBeTruthy()
    expect(text).toMatch(/Au départ · \d{1,2}:40/)
    expect(text).toContain('ressenti')
    expect(text).toContain('vitesse par défaut')
    expect(text).toContain('Exposition au vent')
    expect(text).toContain('Pas de pluie attendue sur le parcours')
    expect(text).toContain('Open-Meteo.com')
    expect(screen.getByRole('region', { name: 'Prévisions le long du parcours' })).toBeTruthy()
    expect(screen.getByRole('img', { name: 'Vent de face, 15 km/h' }).style.transform).toBe(
      'rotate(180deg)'
    )
  })

  it("writes the wind speed and gusts on each point, and the leg's prevailing wind", () => {
    const gusty = {
      ...conditions,
      wind: { speed: 18, gusts: 35, direction: 225, compass: 'SW' as const },
    }
    const base = weatherLeg('g2')
    renderSection({
      leg: weatherLeg('g2', {
        checkpoints: base.checkpoints.map((c) => ({ ...c, weather: gusty })),
        prevailingWind: { speed: 16, gusts: 40, direction: 225, compass: 'SW' },
      }),
    })
    const points = screen.getAllByRole('listitem').map((li) => plain(li.textContent))
    expect(points).toHaveLength(2)
    for (const point of points) expect(point).toContain('rafales 35 km/h')
    expect(plain(document.body.textContent)).toContain(
      'Vent dominant : SO 16 km/h, rafales 40 km/h'
    )
  })

  it('raises the rain alert of the leg', () => {
    renderSection({
      leg: weatherLeg('g2', {
        rainAlert: { probability: 60, time: '2026-10-08T08:30:00Z', condition: 'RAIN' },
      }),
    })
    expect(plain(document.body.textContent)).toMatch(/Pluie probable \(60 %\) vers \d{1,2}:30/)
  })

  it('says a group without a route only has the departure', () => {
    renderSection({ leg: weatherLeg('g2', { status: WeatherStatus.NO_LOCATION, checkpoints: [] }) })
    expect(plain(document.body.textContent)).toContain("Ce groupe n'a pas de parcours")
  })

  it('flags an old forecast', () => {
    renderSection({ weather: { ...okWeather, status: WeatherStatus.STALE } })
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
    expect(plain(document.body.textContent)).toContain('La météo sera disponible à partir du')
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
