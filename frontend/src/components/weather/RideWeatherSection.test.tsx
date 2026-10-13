import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RideDto, RideWeatherDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { okWeather, plain, weatherLeg, weatherRide as ride } from '@/test/weatherFixtures'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

import { RideWeatherSection } from './RideWeatherSection'

function renderSection(props: {
  ride?: RideDto
  weather?: RideWeatherDto
  canEdit?: boolean
  onRetry?: () => void
}) {
  return render(
    <MantineProvider>
      <RideWeatherSection
        ride={props.ride ?? ride()}
        weather={props.weather}
        isLoading={false}
        isFetching={false}
        onRetry={props.onRetry ?? (() => {})}
        canEdit={props.canEdit ?? false}
      />
    </MantineProvider>
  )
}

describe('RideWeatherSection', () => {
  afterEach(cleanup)

  it('keeps to the departure: no group, no route, no selector (WEB-77)', () => {
    renderSection({ weather: okWeather })
    const text = plain(document.body.textContent)
    expect(screen.getByRole('heading', { name: 'Météo au départ' })).toBeTruthy()
    expect(text).toContain('ressenti')
    expect(text).toContain('Open-Meteo.com')
    // Nothing of a group's leg: its schedule, its points, its wind, a group to pick.
    expect(text).not.toContain('Heures de passage')
    expect(text).not.toContain('Exposition au vent')
    expect(screen.queryByRole('region', { name: 'Prévisions le long du parcours' })).toBeNull()
    expect(screen.queryByText('Rapide')).toBeNull()
    expect(screen.queryByRole('radiogroup')).toBeNull()
  })

  it("keeps the route of a ride without groups, which has no group's page", () => {
    renderSection({
      ride: ride({ groups: [], registeredGroupId: undefined }),
      weather: { ...okWeather, legs: [weatherLeg(undefined)] },
    })
    const text = plain(document.body.textContent)
    expect(text).toContain('vitesse par défaut')
    expect(screen.getByRole('region', { name: 'Prévisions le long du parcours' })).toBeTruthy()
  })

  it("unrolls the group's leg of a ride with one group, which has no group's page (WEB-79)", () => {
    renderSection({
      ride: ride({ groups: [{ id: 'g1', name: 'Rapide' }] as RideDto['groups'] }),
      weather: { ...okWeather, legs: [weatherLeg('g1')] },
    })
    const text = plain(document.body.textContent)
    expect(screen.getByRole('heading', { name: 'Météo au départ' })).toBeTruthy()
    expect(text).toContain('Exposition au vent')
    expect(screen.getByRole('region', { name: 'Prévisions le long du parcours' })).toBeTruthy()
  })

  it('keeps a ride with two groups at the departure (WEB-79)', () => {
    renderSection({ weather: { ...okWeather, legs: [weatherLeg('g1'), weatherLeg('g2')] } })
    expect(plain(document.body.textContent)).not.toContain('Exposition au vent')
  })

  it("titles the departure with the ride's own time, not the forecast's round hour", () => {
    renderSection({ weather: okWeather })
    expect(plain(document.body.textContent)).toMatch(/Au départ · \d{1,2}:40/)
  })

  it('says the day of an update that was not today, and flags an old forecast', () => {
    renderSection({ weather: { ...okWeather, fetchedAt: new Date().toISOString() } })
    expect(plain(document.body.textContent)).toMatch(/Mise à jour à \d{1,2}:\d{2}/)
    cleanup()
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString()
    renderSection({ weather: { ...okWeather, status: WeatherStatus.STALE, fetchedAt: twoDaysAgo } })
    expect(plain(document.body.textContent)).toMatch(
      /Mise à jour le \d{1,2} \S+ \d{4} à \d{1,2}:\d{2}/
    )
    expect(screen.getByText('Prévision ancienne')).toBeTruthy()
  })

  it('says when the forecast opens', () => {
    renderSection({
      weather: {
        ...okWeather,
        status: WeatherStatus.NOT_YET_AVAILABLE,
        availableFrom: '2026-10-01T06:40:00Z',
        legs: [],
      },
    })
    expect(plain(document.body.textContent)).toContain('La météo sera disponible à partir du')
  })

  it('offers to retry when there is no forecast to show — a failed read included', () => {
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

  it('draws nothing for a finished or cancelled ride, or an unknown status', () => {
    const { container: finished } = renderSection({
      ride: ride({ finished: true }),
      weather: okWeather,
    })
    expect(finished.querySelector('section')).toBeNull()
    cleanup()
    const { container: cancelled } = renderSection({
      ride: ride({ status: Status.CANCELLED }),
      weather: okWeather,
    })
    expect(cancelled.querySelector('section')).toBeNull()
    cleanup()
    const { container: unknown } = renderSection({
      weather: { ...okWeather, status: 'SOMETHING_NEW' as WeatherStatus },
    })
    expect(unknown.querySelector('section')).toBeNull()
  })
})
