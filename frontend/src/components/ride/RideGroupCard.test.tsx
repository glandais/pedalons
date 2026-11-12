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
vi.mock('@/components/route/GpsMenuButton', () => ({
  GpsMenuButton: ({ routeSlug }: { routeSlug: string }) => (
    <button type="button" data-testid="gps-button" data-route={routeSlug}>
      GPS
    </button>
  ),
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
            action="join"
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

  it("carries the group's weather line — not a link — read on its leg's summary (R2)", () => {
    renderCard(
      weatherLeg('g1', {
        windExposure: { head: 20_000, cross: 0, tail: 30_000 },
        summary: {
          status: 'OK',
          condition: 'RAIN',
          temperatureMin: 9,
          temperatureMax: 13,
          maxPrecipitationProbability: 40,
          wind: { speed: 18, direction: 270, compass: 'W' },
          rainAlert: { probability: 40, time: '2026-10-08T10:30:00Z', condition: 'RAIN' },
        },
      })
    )
    const line = screen.getByTestId('ride-weather-summary')
    expect(plain(line.textContent)).toContain('9–13 °C')
    expect(plain(line.textContent)).toContain('Pluie 40 % vers 10:30')
    // The Face / Dos badges stay on the group's page, not on its card (KIT §9).
    expect(plain(line.textContent)).not.toContain('Face')
    expect(plain(line.textContent)).not.toContain('Dos')
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
    expect(screen.queryByTestId('ride-weather-summary')).toBeNull()
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
      at({}, { action: 'registeredElsewhere', canSwitch: true, onSwitch })
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
      at({}, { action: 'registeredElsewhere', canSwitch: false })
      expect(screen.queryByRole('button', { name: /Changer pour/ })).toBeNull()
    })

    // R6 (docs/LEDGER_*.md WEB-167): « Quitter » leaves the corner for a red link at the foot.
    it('puts « Quitter le groupe » at the foot of my group, never in its corner', () => {
      const onLeave = vi.fn()
      at({ registered: true }, { action: 'leave', onLeave })
      expect(screen.queryByRole('button', { name: 'Quitter' })).toBeNull()
      const link = screen.getByRole('button', { name: 'Quitter le groupe' })
      expect(link.closest('[data-testid="leave-group"]') ?? link).toBeTruthy()
      // After the people and the « GPS » button: the card's last control.
      const gps = screen.getByTestId('gps-button')
      expect(gps.compareDocumentPosition(link) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
      expect(screen.getByText("J'y vais")).toBeTruthy()
      fireEvent.click(link)
      expect(onLeave).toHaveBeenCalledTimes(1)
    })

    it('keeps « J\u2019y vais » but offers no leaving on a cancelled or finished ride', () => {
      at({ registered: true }, { action: 'none', onLeave: vi.fn() })
      expect(screen.queryByRole('button', { name: 'Quitter le groupe' })).toBeNull()
      expect(screen.getByText("J'y vais")).toBeTruthy()
    })

    it('says « Complet » with a disabled button in place of « Rejoindre »', () => {
      at({ full: true, countParticipants: 12 }, { action: 'full' })
      const full = screen.getByRole('button', { name: 'Complet' })
      expect(full).toBeDisabled()
      expect(screen.queryByRole('button', { name: 'Rejoindre' })).toBeNull()
    })

    it('shows the failure inside the card concerned', () => {
      at({}, { action: 'join', error: 'Ce groupe est complet. Choisissez un autre groupe.' })
      const alert = screen.getByRole('alert')
      expect(alert.textContent).toContain('Ce groupe est complet. Choisissez un autre groupe.')
      expect(alert.closest('.mantine-Paper-root')).toBeTruthy()
    })

    // R7: one « GPS » button, on the reader's own group only.
    it('offers « GPS » on my group only, for its route', () => {
      at({ registered: true, routeSlug: 'boucle-b' }, { action: 'leave', onLeave: vi.fn() })
      expect(screen.getByTestId('gps-button').getAttribute('data-route')).toBe('boucle-b')
      expect(screen.queryByText('GPX')).toBeNull()
      expect(screen.queryByText('FIT')).toBeNull()
      cleanup()
      at({}, { action: 'join' })
      expect(screen.queryByTestId('gps-button')).toBeNull()
      cleanup()
      at({}, { action: 'registeredElsewhere', canSwitch: true })
      expect(screen.queryByTestId('gps-button')).toBeNull()
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

  // R5 (docs/LEDGER_*.md WEB-167): one form of the count, the cluster kept, the bar under it.
  describe('people', () => {
    const faces = ['Léa Martin', 'Karim Benali', 'Noé Perrin', 'Inès Roche', 'Sacha Morel'].map(
      (displayName, i) => ({ id: `u${i}`, displayName })
    )

    it('counts « 8/12 personnes », and « 8 personnes » without a maximum', () => {
      renderCard(undefined, undefined, true, { countParticipants: 8 })
      expect(plain(screen.getByTestId('group-count').textContent)).toBe('8/12 personnes')
      cleanup()
      renderCard(undefined, undefined, true, { countParticipants: 8, maxParticipants: undefined })
      expect(plain(screen.getByTestId('group-count').textContent)).toBe('8 personnes')
      expect(screen.queryByTestId('group-places-bar')).toBeNull()
    })

    it('leaves the leader out of the cluster, and offers « Voir tout » once it ends on « +N »', () => {
      renderCard(undefined, undefined, true, {
        participants: faces,
        countParticipants: 8,
        leader: faces[0],
      })
      const cluster = screen.getByTestId('avatar-cluster')
      expect(cluster.querySelector('img[alt="Léa Martin"], [title="Léa Martin"]')).toBeNull()
      expect(cluster.textContent).not.toContain('LM')
      expect(cluster.textContent).toContain('KB')
      // Four faces of the seven people besides the leader: « +3 ».
      expect(cluster.textContent).toContain('+3')
      expect(screen.getByRole('button', { name: 'Voir tout' })).toBeTruthy()
    })

    it('offers no « Voir tout » when the cluster shows everyone', () => {
      renderCard(undefined, undefined, true, {
        participants: faces.slice(1, 4),
        countParticipants: 3,
      })
      expect(screen.queryByRole('button', { name: 'Voir tout' })).toBeNull()
    })

    it('keeps the cluster on a full group, over a red bar; a primary one otherwise', () => {
      const { container } = renderCard(undefined, undefined, true, {
        participants: faces,
        countParticipants: 12,
        full: true,
      })
      expect(screen.getByTestId('avatar-cluster')).toBeTruthy()
      expect(plain(screen.getByTestId('group-count').textContent)).toBe('12/12 personnes')
      const sectionColor = (root: HTMLElement) =>
        root
          .querySelector('[data-testid="group-places-bar"] [role="progressbar"]')!
          .getAttribute('style')
      expect(sectionColor(container)).toContain('var(--mantine-color-red-filled)')
      cleanup()
      // The test's theme has no `primary` palette: Mantine passes the name through.
      const open = renderCard(undefined, undefined, true, { participants: faces })
      expect(sectionColor(open.container)).toMatch(/--progress-section-color: primary/)
    })

    it('shows a non-member the count and the bar, never a face (API-144)', () => {
      renderCard(undefined, undefined, false, { participants: faces, countParticipants: 8 })
      expect(screen.queryByTestId('avatar-cluster')).toBeNull()
      expect(screen.queryByText('KB')).toBeNull()
      expect(plain(screen.getByTestId('group-count').textContent)).toBe('8/12 personnes')
      expect(screen.getByTestId('group-places-bar')).toBeTruthy()
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
