import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { RideGroupDto, WeatherLegDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { plain, weatherLeg } from '@/test/weatherFixtures'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('./RideGroupRouteActions', () => ({
  RideGroupRouteActions: () => <div data-testid="route-actions" />,
}))

import { RideGroupCard } from './RideGroupCard'

const group = {
  id: 'g1',
  name: 'Rapide',
  startAt: '2026-10-08T06:40:00Z',
  countParticipants: 3,
  maxParticipants: 12,
  participants: [],
  registered: false,
  full: false,
} as unknown as RideGroupDto

function renderCard(weather?: WeatherLegDto, trackColor?: string) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <RideGroupCard
            group={group}
            rideTimezone="UTC"
            rideDateTime="2026-10-08T06:40:00Z"
            teamSlug="np"
            rideSlug="sortie"
            rideRouteSlug="boucle"
            routesBySlug={new Map()}
            weatherLeg={weather}
            trackColor={trackColor}
            canJoin
          />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('RideGroupCard (WEB-77)', () => {
  afterEach(cleanup)

  it("links its name — and only its name — to the group's page, and keeps « Rejoindre »", () => {
    renderCard()
    const target = paths.rideGroup('np', 'sortie', 'g1')
    expect(screen.getByRole('link', { name: 'Rapide' }).getAttribute('href')).toBe(target)
    expect(screen.queryByRole('link', { name: 'Voir le groupe' })).toBeNull()
    expect(screen.getByRole('button', { name: 'Rejoindre' })).toBeTruthy()
  })

  it("carries the group's weather line — not a link — when its leg has a forecast", () => {
    renderCard(
      weatherLeg('g1', {
        rainAlert: { probability: 40, time: '2026-10-08T10:30:00Z', condition: 'RAIN' },
        windExposure: { head: 20_000, cross: 0, tail: 30_000 },
      })
    )
    const line = screen.getByTestId('group-weather-line')
    expect(plain(line.textContent)).toContain('Pluie 40 % vers 10:30')
    expect(plain(line.textContent)).toContain('Face 20.0 km')
    expect(plain(line.textContent)).toContain('Dos 30.0 km')
    expect(line.closest('a')).toBeNull()
    expect(line.querySelector('a')).toBeNull()
  })

  it('carries no weather line without a forecast', () => {
    renderCard(undefined)
    expect(screen.queryByTestId('group-weather-line')).toBeNull()
  })

  it('recalls the colour of its trace on the map in front of its name', () => {
    renderCard(undefined, '#1d32a8')
    expect(screen.getByTestId('group-track-color')).toHaveStyle({ backgroundColor: '#1d32a8' })
  })

  it('shows no colour bar for a group with no trace on the map', () => {
    renderCard(undefined)
    expect(screen.queryByTestId('group-track-color')).toBeNull()
  })
})
