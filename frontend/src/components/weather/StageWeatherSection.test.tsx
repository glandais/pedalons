import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { TripWeatherDto, WeatherLegDto } from '@/api/dto'
import { WeatherStatus } from '@/api/dto'
import fr from '@/locales/fr/common.json'

vi.mock('react-i18next', () => {
  const messages = fr as Record<string, string>
  const t = (key: string, options?: Record<string, unknown>) =>
    (messages[key] ?? key).replace(/\{\{(\w+)\}\}/g, (_, name: string) =>
      String(options?.[name] ?? '')
    )
  return { useTranslation: () => ({ t, i18n: { language: 'fr' } }) }
})

import { StageWeatherSection } from './StageWeatherSection'

const conditions = {
  time: '2026-10-08T07:00:00Z',
  weatherCode: 0,
  condition: 'CLEAR' as const,
  daylight: true,
  temperature: 12,
  apparentTemperature: 10,
  precipitationProbability: 10,
  precipitation: 0,
  wind: { speed: 15, direction: 225, compass: 'SW' as const },
}

const leg = (overrides: Partial<WeatherLegDto> = {}): WeatherLegDto => ({
  status: WeatherStatus.OK,
  startTime: '2026-10-08T07:00:00Z',
  averageSpeed: 25,
  speedIsDefault: true,
  distance: 50_000,
  arrivalTime: '2026-10-08T09:00:00Z',
  checkpoints: [
    { index: 0, kind: 'START', distance: 0, time: '2026-10-08T07:00:00Z', weather: conditions },
    {
      index: 1,
      kind: 'FINISH',
      distance: 50_000,
      time: '2026-10-08T09:00:00Z',
      weather: conditions,
    },
  ],
  segments: [],
  windExposure: { head: 0, cross: 0, tail: 0 },
  ...overrides,
})

const tripWeather = (...legs: [string, WeatherLegDto][]): TripWeatherDto => ({
  status: WeatherStatus.OK,
  stages: legs.map(([stageId, l]) => ({ stageId, leg: l })),
  attribution: { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' },
})

function renderSection(weather: TripWeatherDto | undefined, stageId = 's2', canEdit = false) {
  return render(
    <MantineProvider>
      <StageWeatherSection
        weather={weather}
        stageId={stageId}
        isLoading={false}
        isFetching={false}
        onRetry={() => {}}
        canEdit={canEdit}
      />
    </MantineProvider>
  )
}

describe('StageWeatherSection', () => {
  afterEach(cleanup)

  it("shows the stage's own leg, worded for a stage", () => {
    renderSection(
      tripWeather(
        ['s1', leg({ status: WeatherStatus.OUT_OF_RANGE, checkpoints: [] })],
        ['s2', leg()]
      )
    )

    expect(screen.getByText(fr['rides.weather.title'])).toBeTruthy()
    expect(screen.getByText(/l'étape n'en indique pas/)).toBeTruthy()
    expect(screen.getByText('Open-Meteo.com')).toBeTruthy()
  })

  it('draws nothing for a stage already gone', () => {
    const { container } = renderSection(
      tripWeather(['s2', leg({ status: WeatherStatus.OUT_OF_RANGE, checkpoints: [] })])
    )

    expect(container.querySelector('section')).toBeNull()
  })

  it('says when the forecast of a far stage opens', () => {
    renderSection(
      tripWeather([
        's2',
        leg({ status: WeatherStatus.NOT_YET_AVAILABLE, availableFrom: '2026-10-10T07:00:00Z' }),
      ])
    )

    expect(screen.getByText(/La météo sera disponible à partir du/)).toBeTruthy()
  })

  it('tells only the organisers about a stage without a route', () => {
    const noRoute = tripWeather(['s2', leg({ status: WeatherStatus.NO_LOCATION, checkpoints: [] })])

    const { container } = renderSection(noRoute)
    expect(container.querySelector('section')).toBeNull()
    cleanup()

    renderSection(noRoute, 's2', true)
    expect(screen.getByText(fr['trips.weather.noLocation'])).toBeTruthy()
  })

  it('offers a retry when nothing could be read', () => {
    renderSection(undefined)

    expect(screen.getByText(fr['rides.weather.retry'])).toBeTruthy()
  })
})
