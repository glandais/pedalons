import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RideWeatherSummaryDto, WeatherLegDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import { usePreferencesStore } from '@/store/preferencesStore'
import { plain, weatherLeg } from '@/test/weatherFixtures'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

import { GroupWeatherLine } from './GroupWeatherLine'

function renderLine(leg: WeatherLegDto | undefined) {
  return render(
    <MantineProvider>
      <GroupWeatherLine leg={leg} timezone="UTC" />
    </MantineProvider>
  )
}

/** The leg's own summary (`WeatherLegDto.summary`): what the card's line reads. */
const summary: RideWeatherSummaryDto = {
  status: WeatherStatus.OK,
  condition: 'PARTLY_CLOUDY',
  daylight: true,
  temperature: 9,
  temperatureMin: 9,
  temperatureMax: 13,
  maxPrecipitationProbability: 20,
  wind: { speed: 18, direction: 270, compass: 'W' },
}

describe('GroupWeatherLine (docs/LEDGER_*.md WEB-167, R2)', () => {
  beforeEach(() => usePreferencesStore.setState({ unitSystem: 'METRIC' }))
  afterEach(cleanup)

  it("reads the card's line on the group's summary: range, wind, rain — no sky, no Face / Dos", () => {
    renderLine(weatherLeg('g1', { summary }))
    const line = plain(screen.getByTestId('ride-weather-summary').textContent)
    expect(line).toContain('9–13 °C')
    expect(line).toContain('18 km/h')
    expect(line).toContain('Pluie 20 %')
    // The sky in words and the wind badges are the group page's (KIT §9).
    expect(line).not.toContain('Partiellement nuageux')
    expect(line).not.toContain('Face')
    expect(line).not.toContain('Dos')
    // Never a link: the group's page is reached by the card's own links.
    expect(screen.queryByRole('link')).toBeNull()
  })

  it('writes the alert of the group: its probability and its time', () => {
    renderLine(
      weatherLeg('g1', {
        summary: {
          ...summary,
          rainAlert: { probability: 60, time: '2026-10-08T11:00:00Z', condition: 'RAIN' },
        },
      })
    )
    expect(plain(screen.getByTestId('ride-weather-rain-alert').textContent)).toBe(
      'Pluie 60 % vers 11:00'
    )
  })

  it('draws nothing without a summary for the group', () => {
    const { container: none } = renderLine(undefined)
    expect(none.querySelector('[data-testid="ride-weather-summary"]')).toBeNull()
    cleanup()
    // A leg with checkpoints but no summary (an older server): nothing either.
    const { container: noSummary } = renderLine(weatherLeg('g1'))
    expect(noSummary.querySelector('[data-testid="ride-weather-summary"]')).toBeNull()
  })
})
