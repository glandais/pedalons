import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
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

import type { ComponentProps } from 'react'
import { RideGroupCard } from './RideGroupCard'
import { groupLeavesAtOwnTime } from '@/utils/groupStart'

const RIDE_START = '2026-10-08T06:40:00Z'

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
  overrides: Partial<RideGroupDto> = {},
  showStartTime = groupLeavesAtOwnTime(overrides.startAt ?? group.startAt, RIDE_START),
  cardProps: Partial<ComponentProps<typeof RideGroupCard>> = {}
) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <RideGroupCard
            group={{ ...group, ...overrides }}
            rideTimezone="UTC"
            rideDateTime={RIDE_START}
            showStartTime={showStartTime}
            teamSlug="np"
            rideSlug="sortie"
            rideRouteSlug="boucle"
            routesBySlug={new Map()}
            weatherLeg={weather}
            trackColor={trackColor}
            canJoin
            canSeeParticipants={canSeeParticipants}
            {...cardProps}
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
    expect(plain(line.textContent)).toContain('Face 20,0 km')
    expect(plain(line.textContent)).toContain('Dos 30,0 km')
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

  // KIT §8 and §9, ledger WEB-165 (docs/LEDGER_*.md WEB-167).
  describe('registration controls', () => {
    const at = (
      overrides: Partial<RideGroupDto>,
      props: Partial<ComponentProps<typeof RideGroupCard>>
    ) => renderCard(undefined, undefined, true, overrides, false, props)

    it('offers « Changer pour {groupe} » at the foot, full width, to a reader registered elsewhere', () => {
      const onSwitch = vi.fn()
      at({}, { canJoin: false, canSwitch: true, onSwitch })
      const button = screen.getByRole('button', { name: 'Changer pour Rapide' })
      expect(button.getAttribute('data-block')).toBe('true')
      expect(screen.queryByRole('button', { name: 'Rejoindre' })).toBeNull()
      // At the foot, after the group's facts — not in the corner beside its name.
      const facts = screen.getByText(/personnes/)
      expect(facts.compareDocumentPosition(button) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
      fireEvent.click(button)
      expect(onSwitch).toHaveBeenCalledTimes(1)
    })

    it('offers no switch when the page does not allow it (full, cancelled, closed)', () => {
      at({}, { canJoin: false, canSwitch: false })
      expect(screen.queryByRole('button', { name: /Changer pour/ })).toBeNull()
    })

    it('keeps « J\u2019y vais » but drops « Quitter » on a cancelled ride', () => {
      at({ registered: true }, { canLeave: false })
      expect(screen.queryByRole('button', { name: 'Quitter' })).toBeNull()
      expect(screen.getByText("J'y vais")).toBeTruthy()
      cleanup()
      at({ registered: true }, {})
      expect(screen.getByRole('button', { name: 'Quitter' })).toBeTruthy()
    })

    it('gives its figures in the order distance · climb · speed', () => {
      at({ distance: 92_400, elevationGain: 1240, averageSpeed: 27 }, {})
      const row = screen.getByText(/92/).closest('div')!.parentElement!
      const texts = Array.from(row.querySelectorAll('p')).map((p) => p.textContent ?? '')
      const index = (pattern: RegExp) => texts.findIndex((text) => pattern.test(text))
      expect(index(/km$/)).toBeGreaterThanOrEqual(0)
      expect(index(/km$/)).toBeLessThan(index(/^1.?240/))
      expect(index(/^1.?240/)).toBeLessThan(index(/km\/h/))
    })
  })

  describe("the group's own departure (BRAND-8)", () => {
    afterEach(() => vi.useRealTimers())
    const fixClock = () => {
      vi.useFakeTimers({ toFake: ['Date'] })
      vi.setSystemTime(new Date('2026-09-01T10:00:00Z'))
    }

    it('shows no departure line when every group leaves with the ride', () => {
      fixClock()
      renderCard()
      expect(screen.queryByTestId('departure-line')).toBeNull()
    })

    it('gives the ride’s time too when another group leaves at a different one', () => {
      fixClock()
      renderCard(undefined, undefined, true, {}, true)
      expect(plain(screen.getByTestId('departure-line').textContent)).toBe('Départ 06:40')
    })

    it('gives its own time in 700 on an indigo band, out of the stats row', () => {
      fixClock()
      renderCard(undefined, undefined, true, { startAt: '2026-10-08T07:10:00Z' })
      const line = screen.getByTestId('departure-line')
      expect(plain(line.textContent)).toBe('Départ 07:10')
      const time = screen.getByText('Départ 07:10')
      expect(time.getAttribute('style') ?? '').toContain('font-weight: 700')
      expect(screen.getByTestId('group-own-time').contains(line)).toBe(true)
    })

    it('names the day when the group leaves on another day than the ride', () => {
      fixClock()
      renderCard(undefined, undefined, true, { startAt: '2026-10-09T05:30:00Z' })
      expect(plain(screen.getByTestId('departure-line').textContent)).toBe('ven. 9 oct. · 05:30')
    })
  })
})
