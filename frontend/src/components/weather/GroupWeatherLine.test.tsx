import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { WeatherLegDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
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

describe('GroupWeatherLine', () => {
  afterEach(cleanup)

  it("says the sky and temperature at the group's start, and its head and tail wind", () => {
    renderLine(weatherLeg('g1', { windExposure: { head: 30_000, cross: 5_000, tail: 15_000 } }))
    const line = plain(screen.getByTestId('group-weather-line').textContent)
    expect(line).toContain('12 °C · Ciel dégagé')
    expect(line).toContain('Face 30.0 km')
    expect(line).toContain('Dos 15.0 km')
    // The crosswind is the detail page's business; and no rain, no rain badge.
    expect(line).not.toContain('Travers')
    expect(line).not.toContain('Pluie')
    // Never a link: the group's page is reached by the card's own links.
    expect(screen.queryByRole('link')).toBeNull()
  })

  it('names the rain, its probability and its time', () => {
    renderLine(
      weatherLeg('g1', {
        rainAlert: { probability: 40, time: '2026-10-08T10:30:00Z', condition: 'RAIN' },
      })
    )
    expect(plain(screen.getByTestId('group-weather-line').textContent)).toContain(
      'Pluie 40 % vers 10:30'
    )
  })

  it('leaves out a wind the group never meets', () => {
    renderLine(weatherLeg('g1', { windExposure: { head: 0, cross: 0, tail: 20_000 } }))
    const line = plain(screen.getByTestId('group-weather-line').textContent)
    expect(line).not.toContain('Face')
    expect(line).toContain('Dos 20.0 km')
  })

  it('draws nothing without a forecast for the group', () => {
    const { container: none } = renderLine(undefined)
    expect(none.querySelector('[data-testid="group-weather-line"]')).toBeNull()
    cleanup()
    const { container: notYet } = renderLine(
      weatherLeg('g1', { status: WeatherStatus.NOT_YET_AVAILABLE })
    )
    expect(notYet.querySelector('[data-testid="group-weather-line"]')).toBeNull()
    cleanup()
    const { container: noWeather } = renderLine(
      weatherLeg('g1', {
        checkpoints: weatherLeg('g1').checkpoints.map((c) => ({ ...c, weather: undefined })),
      })
    )
    expect(noWeather.querySelector('[data-testid="group-weather-line"]')).toBeNull()
  })
})
