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

function renderCard(
  weather?: WeatherLegDto,
  trackColor?: string,
  canSeeParticipants = true,
  overrides: Partial<RideGroupDto> = {}
) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <RideGroupCard
            group={{ ...group, ...overrides }}
            rideTimezone="UTC"
            rideDateTime="2026-10-08T06:40:00Z"
            teamSlug="np"
            rideSlug="sortie"
            rideRouteSlug="boucle"
            routesBySlug={new Map()}
            weatherLeg={weather}
            trackColor={trackColor}
            canJoin
            canSeeParticipants={canSeeParticipants}
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

  it('offers the participants list to those who may see names (API-144)', () => {
    renderCard()
    expect(screen.getByRole('button', { name: 'Voir toutes les personnes inscrites' })).toBeTruthy()
  })

  it('shows the count only, with no participants button, to a non-member (API-144)', () => {
    renderCard(undefined, undefined, false)
    expect(screen.queryByRole('button', { name: 'Voir toutes les personnes inscrites' })).toBeNull()
    expect(screen.getByText(/3/)).toBeTruthy()
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

  describe("the group's own departure (BRAND-8)", () => {
    afterEach(() => vi.useRealTimers())
    const fixClock = () => {
      vi.useFakeTimers({ toFake: ['Date'] })
      vi.setSystemTime(new Date('2026-09-01T10:00:00Z'))
    }

    it('shows no departure line for a group leaving with the ride', () => {
      fixClock()
      renderCard()
      expect(screen.queryByTestId('departure-line')).toBeNull()
    })

    it('gives its own time in 700, out of the stats row, and « après la sortie »', () => {
      fixClock()
      renderCard(undefined, undefined, true, { startAt: '2026-10-08T07:10:00Z' })
      const line = screen.getByTestId('departure-line')
      expect(plain(line.textContent)).toBe('Départ 07:10 · après la sortie')
      const time = screen.getByText('Départ 07:10')
      expect(time.getAttribute('style') ?? '').toContain('font-weight: 700')
    })

    it('says « avant la sortie » for a group leaving first', () => {
      fixClock()
      renderCard(undefined, undefined, true, { startAt: '2026-10-08T06:00:00Z' })
      expect(plain(screen.getByTestId('departure-line').textContent)).toBe(
        'Départ 06:00 · avant la sortie'
      )
    })

    it('names the day when the group leaves on another day than the ride', () => {
      fixClock()
      renderCard(undefined, undefined, true, { startAt: '2026-10-09T05:30:00Z' })
      expect(plain(screen.getByTestId('departure-line').textContent)).toBe(
        'ven. 9 oct. · 05:30 · après la sortie'
      )
    })
  })
})
