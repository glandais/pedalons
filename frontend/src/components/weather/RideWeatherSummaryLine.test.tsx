import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RideWeatherSummaryDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { usePreferencesStore } from '@/store/preferencesStore'
import fr from '@/locales/fr/common.json'

// The real French wording, interpolated: the line is read as a rider reads it.
vi.mock('react-i18next', () => {
  const messages = fr as Record<string, string>
  const t = (key: string, options?: Record<string, unknown>) =>
    (messages[key] ?? key).replace(/\{\{(\w+)\}\}/g, (_, name: string) =>
      String(options?.[name] ?? '')
    )
  return { useTranslation: () => ({ t, i18n: { language: 'fr' } }) }
})

import { RideWeatherSummaryLine } from './RideWeatherSummaryLine'

// Intl and the locale files separate value and unit with a no-break space; compare on plain spaces.
const plain = (s: string | null | undefined) => (s ?? '').replace(/[  ]/g, ' ')

function renderLine(summary: RideWeatherSummaryDto | undefined, timezone?: string) {
  return render(
    <MantineProvider>
      <RideWeatherSummaryLine summary={summary} timezone={timezone} />
    </MantineProvider>
  )
}

const okSummary: RideWeatherSummaryDto = {
  status: WeatherStatus.OK,
  weatherCode: 80,
  condition: 'SHOWERS',
  daylight: true,
  temperature: 9.4,
  temperatureMin: 8.2,
  temperatureMax: 14.4,
  maxPrecipitationProbability: 70,
  wind: { speed: 18.3, gusts: 35, direction: 225, compass: 'SW' },
  rainAlert: { probability: 70, time: '2026-10-08T10:00:00Z', condition: 'SHOWERS' },
}

describe('RideWeatherSummaryLine', () => {
  beforeEach(() => usePreferencesStore.setState({ unitSystem: 'METRIC' }))
  afterEach(cleanup)

  it('reads the range 8–14 °C, the arrow and the speed, and the alert in its tint', () => {
    renderLine(okSummary)
    const line = screen.getByTestId('ride-weather-summary')
    const text = plain(line.textContent)
    // An en dash, no arrow (R2, the app's `formatTemperatureRange`).
    expect(text).toContain('8–14 °C')
    expect(text).not.toContain('→')
    // The arrow carries the direction; the compass point stays for screen readers only.
    expect(screen.getByTestId('wind-from-arrow')).toBeTruthy()
    expect(text).toContain('18 km/h')
    // The alert, written in full: no badge, no « dès », no tooltip.
    expect(plain(screen.getByTestId('ride-weather-rain-alert').textContent)).toMatch(
      /^Pluie 70 % vers \d{1,2}:\d{2}$/
    )
    expect(text).not.toContain('dès')
    expect(screen.getByRole('img', { name: 'Averses' })).toBeTruthy()
  })

  it("reads the alert in the summary's own zone over the card's (a trip's next stage)", () => {
    // 10:00Z: 12:00 in Paris (the trip's first stage), 19:00 in Tokyo (its next one) —
    // docs/LEDGER_*.md API-60.
    renderLine({ ...okSummary, timezone: 'Asia/Tokyo' }, 'Europe/Paris')
    const text = plain(screen.getByTestId('ride-weather-summary').textContent)
    expect(text).toContain('Pluie 70 % vers 19:00')
    cleanup()
    renderLine(okSummary, 'Europe/Paris')
    expect(plain(screen.getByTestId('ride-weather-summary').textContent)).toContain(
      'Pluie 70 % vers 12:00'
    )
  })

  it('always writes the chance of rain, without an alert', () => {
    renderLine({ ...okSummary, rainAlert: undefined, maxPrecipitationProbability: 20 })
    const text = plain(screen.getByTestId('ride-weather-summary').textContent)
    expect(text).toContain('Pluie 20 %')
    expect(screen.queryByTestId('ride-weather-rain-alert')).toBeNull()
    cleanup()
    // No probability from the model: nothing to write.
    renderLine({ ...okSummary, rainAlert: undefined, maxPrecipitationProbability: undefined })
    expect(plain(screen.getByTestId('ride-weather-summary').textContent)).not.toContain('Pluie')
  })

  it('converts to °F and mph for an imperial reader', () => {
    usePreferencesStore.setState({ unitSystem: 'IMPERIAL' })
    renderLine(okSummary)
    const text = plain(screen.getByTestId('ride-weather-summary').textContent)
    expect(text).toContain('47–58 °F')
    expect(text).toContain('11 mph')
  })

  it('shows a single temperature when the range rounds to one degree', () => {
    renderLine({ ...okSummary, temperatureMin: 12.2, temperatureMax: 12.4, rainAlert: undefined })
    const text = plain(screen.getByTestId('ride-weather-summary').textContent)
    expect(text).toContain('12 °C')
    expect(text).not.toContain('–')
  })

  it('says when the forecast opens, the year only outside the current one', () => {
    const year = new Date().getFullYear()
    renderLine({
      status: WeatherStatus.NOT_YET_AVAILABLE,
      availableFrom: `${year}-10-10T12:00:00Z`,
    })
    expect(plain(screen.getByTestId('ride-weather-summary').textContent)).toBe(
      'Météo dès le 10 octobre'
    )
    cleanup()
    renderLine({
      status: WeatherStatus.NOT_YET_AVAILABLE,
      availableFrom: `${year + 1}-01-15T12:00:00Z`,
    })
    expect(plain(screen.getByTestId('ride-weather-summary').textContent)).toBe(
      `Météo dès le 15 janvier ${year + 1}`
    )
  })

  it('flags an old forecast', () => {
    renderLine({ ...okSummary, status: WeatherStatus.STALE })
    expect(screen.getByRole('img', { name: 'Prévision ancienne' })).toBeTruthy()
  })

  it('draws a plain cloud for a condition this build does not know', () => {
    renderLine({ ...okSummary, condition: 'VOLCANIC_ASH' as RideWeatherSummaryDto['condition'] })
    expect(screen.getByRole('img', { name: 'Météo' })).toBeTruthy()
  })

  it('draws nothing without a summary, or for a status it does not know', () => {
    renderLine(undefined)
    expect(screen.queryByTestId('ride-weather-summary')).toBeNull()
    cleanup()
    renderLine({ ...okSummary, status: 'SOMETHING_NEW' as WeatherStatus })
    expect(screen.queryByTestId('ride-weather-summary')).toBeNull()
  })
})
