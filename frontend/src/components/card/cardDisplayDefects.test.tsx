/**
 * The card defects the gallery captures showed on the site (docs/LEDGER_*.md WEB-167; identifiers of
 * `docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/constat-captures.md`). Each test
 * renders the production component.
 */
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import type { MemberDto, RideDto, RideGroupSummaryDto, TripDto } from '@/api/dto'
import fr from '@/locales/fr/common.json'
import en from '@/locales/en/common.json'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => false }))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { UpcomingRideCard } from '@/components/team/dashboard/UpcomingRideCard'
import { MyUpcomingList } from '@/components/team/dashboard/MyUpcomingList'
import { TeamMemberList } from '@/components/team/TeamMemberList'
import { TemplateGroupBadge } from '@/components/ridetemplate/TemplateGroupBadge'
import { StatusBadge } from './common'

const NBSP = '\u00a0'
const TEAM_REF = {
  id: 't1',
  name: 'Vélo Club des Monts',
  slug: 'vcm',
  visibility: 'TEAM' as const,
  accessible: true,
}
const MEDIA = { markdown: '', assets: { images: [], attachments: [] } }
const START = '2026-11-16T08:00:00Z'

function summary(overrides: Partial<RideGroupSummaryDto>): RideGroupSummaryDto {
  return {
    id: 'g-a',
    name: 'A',
    countParticipants: 8,
    maxParticipants: 12,
    full: false,
    sortOrder: 0,
    startAt: START,
    ...overrides,
  }
}

function ride(overrides: Partial<RideDto> = {}): RideDto {
  return {
    type: 'RIDE',
    team: TEAM_REF,
    id: 'r1',
    slug: 'boucle',
    name: 'Boucle des Monts d’Arrée',
    media: MEDIA,
    dateTime: START,
    timezone: 'Europe/Paris',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    participantCount: 31,
    groupCount: 3,
    groups: [],
    groupSummaries: [
      summary({}),
      summary({ id: 'g-b', name: 'B', sortOrder: 1, countParticipants: 11 }),
      summary({ id: 'g-c', name: 'C', sortOrder: 2, countParticipants: 12, full: true }),
    ],
    topParticipants: [],
    distance: 92_400,
    elevationGain: 1_240,
    deleted: false,
    registered: false,
    full: false,
    commentCount: 4,
    permissions: { canEdit: false, canDelete: false, indexable: false },
    tags: [],
    ...overrides,
  } as RideDto
}

function trip(): TripDto {
  return {
    type: 'TRIP',
    team: TEAM_REF,
    id: 'tr1',
    slug: 'morvan',
    name: 'Traversée du Morvan',
    media: MEDIA,
    dateTime: '2026-11-22T07:30:00Z',
    endDateTime: '2026-11-24T15:00:00Z',
    endDate: '2026-11-24T08:00:00Z',
    timezone: 'Europe/Paris',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    participantCount: 12,
    stageCount: 3,
    totalDistance: 201_000,
    stages: [],
    participants: [],
    deleted: false,
    registered: true,
    commentCount: 0,
    permissions: { canEdit: false, canDelete: false, indexable: false },
    tags: [],
  } as TripDto
}

function renderIn(node: ReactNode) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>{node}</MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

afterEach(cleanup)

describe('D13: thousands are grouped on a card, and the gap shows', () => {
  it('renders « 1 240 m » (no-break space, U+00A0) on a dashboard card, never « 1240 »', () => {
    const { container } = renderIn(
      <UpcomingRideCard ride={ride({ displayDistance: 92_400, displayElevationGain: 1_240 })} />
    )
    const text = container.textContent ?? ''
    expect(text).toContain(`1${NBSP}240${NBSP}m`)
    expect(text).toContain(`92,4${NBSP}km`)
    expect(text).not.toMatch(/1240/)
  })

  // docs/LEDGER_*.md API-178, R3: the server's distance for the reader, never the ride's own.
  it('shows the server’s distance on « Sorties à venir », and none when it sends none', () => {
    const { container } = renderIn(
      <UpcomingRideCard ride={ride({ distance: 92_400, elevationGain: 1_240 })} />
    )
    expect(container.textContent).not.toContain('92,4')
    cleanup()
    const again = renderIn(
      <UpcomingRideCard ride={ride({ distance: 92_400, displayDistance: 78_000 })} />
    )
    expect(again.container.textContent).toContain(`78,0${NBSP}km`)
  })
})

describe('N4: every group full', () => {
  // KIT §9 (2026-11-12): a cancelled ride's card offers nothing to do, only « Voir la sortie ».
  it('offers neither « S’inscrire » nor « Complet » on a cancelled ride', () => {
    const groupSummaries = ride().groupSummaries.map((g) => ({ ...g, full: true }))
    renderIn(<UpcomingRideCard ride={ride({ status: 'CANCELLED', groupSummaries })} />)
    expect(screen.queryByText("S'inscrire")).toBeNull()
    expect(screen.queryByRole('button', { name: 'Complet' })).toBeNull()
    expect(screen.getByText('Voir la sortie')).toBeTruthy()
  })

  it('offers a disabled « Complet » instead of « S’inscrire »', () => {
    const groupSummaries = ride().groupSummaries.map((g) => ({
      ...g,
      countParticipants: 12,
      full: true,
    }))
    renderIn(<UpcomingRideCard ride={ride({ groupSummaries, full: true })} />)
    expect(screen.queryByText("S'inscrire")).toBeNull()
    expect(screen.getByRole('button', { name: 'Complet' })).toBeDisabled()
  })

  it('keeps « S’inscrire » while a group has room', () => {
    renderIn(<UpcomingRideCard ride={ride()} />)
    expect(screen.getByText("S'inscrire")).toBeInTheDocument()
  })
})

describe('N23: a group line on a 260 px card', () => {
  it('keeps the fill badge and the departure time whole', () => {
    const groupSummaries = ride().groupSummaries.map((g, i) => ({
      ...g,
      startAt: ['2026-11-16T08:00:00Z', '2026-11-16T09:00:00Z', '2026-11-16T10:00:00Z'][i],
    }))
    const { container } = renderIn(<UpcomingRideCard ride={ride({ groupSummaries })} />)
    const badge = screen.getByText('Complet').closest('.mantine-Badge-root') as HTMLElement
    expect(badge.style.flexShrink).toBe('0')
    const time = [...container.querySelectorAll('span')].find(
      (s) => s.textContent === 'départ 11:00'
    )
    expect(time?.style.whiteSpace).toBe('nowrap')
  })
})

describe('N21, N28: a trip in « Vos prochaines sorties »', () => {
  it('keeps its date span on one line', () => {
    renderIn(<MyUpcomingList publications={[trip()]} />)
    const span = screen.getByTestId('trip-span')
    expect(span.textContent).toContain('→')
    expect(span.style.whiteSpace).toBe('nowrap')
  })

  it('gives the stages and the distance two different icons', () => {
    renderIn(<MyUpcomingList publications={[trip()]} />)
    const iconOf = (text: RegExp) =>
      screen.getByText(text).closest('div')?.querySelector('svg')?.getAttribute('class')
    expect(iconOf(/3.étapes/)).toContain('tabler-icon-stack-2')
    expect(iconOf(/201,0.km/)).toContain('tabler-icon-route')
  })
})

// R7 (docs/LEDGER_*.md WEB-167): « GPS » replaces « Envoyer vers l'appareil », until the end.
describe('R7: a ride in « Vos prochaines sorties »', () => {
  const mine = (overrides: Partial<RideDto> = {}) =>
    ride({
      registered: true,
      routeSlug: 'boucle',
      dateTime: '2099-11-16T08:00:00Z',
      endDateTime: '2099-11-16T12:00:00Z',
      ...overrides,
    })

  it('offers the one « GPS » button for its route', () => {
    renderIn(<MyUpcomingList publications={[mine()]} />)
    expect(screen.getByTestId('gps-button').textContent).toBe('GPS')
    expect(screen.queryByText('Envoyer vers l’appareil')).toBeNull()
    expect(screen.queryByText("Envoyer vers l'appareil")).toBeNull()
  })

  it('offers none once the ride is over, nor on a cancelled one', () => {
    renderIn(<MyUpcomingList publications={[mine({ endDateTime: '2020-01-01T12:00:00Z' })]} />)
    expect(screen.queryByTestId('gps-button')).toBeNull()
    cleanup()
    renderIn(<MyUpcomingList publications={[mine({ status: 'CANCELLED' })]} />)
    expect(screen.queryByTestId('gps-button')).toBeNull()
  })
})

describe('N22: a status beside a title', () => {
  it('never shrinks', () => {
    renderIn(<StatusBadge status="DRAFT">Brouillon</StatusBadge>)
    expect(screen.getByTestId('status-badge').style.flexShrink).toBe('0')
  })
})

describe('N24: a member’s role at 390 px', () => {
  it('sits in a group that never shrinks, and the name may wrap', () => {
    const member: MemberDto = {
      team: TEAM_REF,
      id: 'm1',
      user: { id: 'u-lea', displayName: 'Léa Martin' },
      role: 'ADMIN',
      joinedAt: '2021-03-01T10:00:00Z',
    }
    renderIn(<TeamMemberList members={[member]} currentUserRole={null} currentUserId="u-x" />)
    const badge = screen.getByTestId('member-role-badge')
    expect((badge.parentElement as HTMLElement).style.flexShrink).toBe('0')
    expect(screen.getByText('Léa Martin').className).not.toMatch(/truncate/)
  })
})

describe('N27: a template group’s pace', () => {
  it('keeps the unit in its case inside the uppercase badge', () => {
    renderIn(<TemplateGroupBadge group={{ name: 'A', averageSpeed: 28 }} color="primary" />)
    const speed = screen.getByTestId('template-group-speed')
    expect(speed.textContent).toBe(`28${NBSP}km/h`)
    expect(speed.getAttribute('style') ?? '').toMatch(/text-transform:\s*none/)
  })
})

describe('N14: a count never leaves its noun at a line end', () => {
  const COUNTERS = [
    'comments.count',
    'groups.groupCount',
    'trips.card.stageCount',
    'participantCount',
    'memberCount',
    'home.teams.activity.rides',
    'rides.detail.groups.participantsNoMax',
  ]
  it.each([
    ['fr', fr],
    ['en', en],
  ])('binds « {{count}} » to the next word in %s', (_lang, catalogue) => {
    const values = catalogue as Record<string, string>
    for (const key of COUNTERS) {
      const forms = Object.keys(values).filter((k) => k.startsWith(`${key}_`))
      expect(forms.length, key).toBeGreaterThan(0)
      for (const form of forms) expect(values[form], form).toMatch(/^\{\{count\}\}\u00a0/)
    }
  })
})
