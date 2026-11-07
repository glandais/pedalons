import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { GpxPreviewDto, RideWeatherDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { okWeather, plain, routeWeather } from '@/test/weatherFixtures'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

import { GpxPreviewWeatherSection } from './GpxPreviewWeatherSection'

const preview = {
  id: 'p1',
  departureTime: '2026-10-18T06:30:00Z',
  departureTimezone: 'Europe/Paris',
} as GpxPreviewDto

function renderSection(
  props: {
    preview?: GpxPreviewDto
    weather?: RideWeatherDto
    isLoading?: boolean
    polling?: boolean
    onRetry?: () => void
  } = {}
) {
  return render(
    <MantineProvider>
      <GpxPreviewWeatherSection
        preview={props.preview ?? preview}
        weather={'weather' in props ? props.weather : routeWeather}
        isLoading={props.isLoading ?? false}
        isFetching={false}
        polling={props.polling ?? false}
        onRetry={props.onRetry ?? (() => {})}
      />
    </MantineProvider>
  )
}

const withStatus = (status: WeatherStatus, more: Partial<RideWeatherDto> = {}): RideWeatherDto => ({
  ...routeWeather,
  status,
  legs: [],
  ...more,
})

afterEach(cleanup)

/** Mantine injects style tags: the text of the page is not a measure, its elements are. */
const nothingShown = () => !document.querySelector('section, p, button')

describe('GpxPreviewWeatherSection', () => {
  it('draws nothing without a date, nor while loading', () => {
    renderSection({ preview: { id: 'p1' } as GpxPreviewDto })
    expect(nothingShown()).toBe(true)
    cleanup()
    renderSection({ isLoading: true })
    expect(nothingShown()).toBe(true)
  })

  it('says a departure in the past is past, rather than leaving a hole', () => {
    renderSection({ weather: withStatus(WeatherStatus.OUT_OF_RANGE) })
    expect(screen.getByText('Ce départ est passé : plus de prévisions à afficher.')).toBeTruthy()
  })

  it('draws nothing for a track without location, or a status it does not know', () => {
    renderSection({ weather: withStatus(WeatherStatus.NO_LOCATION) })
    expect(nothingShown()).toBe(true)
    cleanup()
    renderSection({ weather: withStatus('SOMETHING_NEW' as WeatherStatus) })
    expect(nothingShown()).toBe(true)
  })

  it('says when the forecast opens, for a departure beyond seven days', () => {
    renderSection({
      weather: withStatus(WeatherStatus.NOT_YET_AVAILABLE, {
        availableFrom: '2026-10-11T06:30:00Z',
      }),
    })
    expect(screen.getByText(/La météo sera disponible à partir du/)).toBeTruthy()
  })

  it('says the forecast is on its way while the cache is filled', () => {
    renderSection({ weather: withStatus(WeatherStatus.UNAVAILABLE), polling: true })
    expect(screen.getByText(/Récupération des prévisions en cours/)).toBeTruthy()
    expect(screen.queryByRole('button', { name: /Réessayer/ })).toBeNull()
  })

  it('offers a retry once it stopped waiting, and for a read that failed', () => {
    const onRetry = vi.fn()
    renderSection({ weather: withStatus(WeatherStatus.UNAVAILABLE), onRetry })
    fireEvent.click(screen.getByRole('button', { name: /Réessayer/ }))
    expect(onRetry).toHaveBeenCalledTimes(1)
    cleanup()
    renderSection({ weather: undefined, onRetry })
    expect(screen.getByRole('button', { name: /Réessayer/ })).toBeTruthy()
  })

  it('shows the forecast along the track with its passage times', () => {
    renderSection({ weather: { ...routeWeather, legs: routeWeather.legs.slice(0, 1) } })
    expect(screen.getByRole('heading', { name: 'Météo du parcours' })).toBeTruthy()
    // Passages are read in the zone of the track's start (Paris, UTC+2)
    expect(plain(document.body.textContent)).toContain('Départ, 09:00')
  })

  it("names the default speed as the track's, not the group's", () => {
    const leg = { ...routeWeather.legs[0], speedIsDefault: true, averageSpeed: 25 }
    renderSection({ weather: { ...routeWeather, legs: [leg] } })
    const text = plain(document.body.textContent)
    expect(text).toContain('vitesse par défaut')
    expect(text).not.toContain('le groupe')
  })

  it('keeps the departure and a word when the leg has no forecast', () => {
    renderSection({ weather: { ...okWeather, legs: [] } })
    expect(
      screen.getByText(/Les prévisions le long du parcours ne sont pas encore disponibles/)
    ).toBeTruthy()
  })
})
