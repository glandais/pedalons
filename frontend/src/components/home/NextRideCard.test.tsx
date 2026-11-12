import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { RideDto, RideGroupDto } from '@/api/dto'

const leave = vi.hoisted(() => ({ mutate: vi.fn() }))

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/hooks/useGpsConnections', () => ({
  useGpsConnections: () => ({ connectedServices: [], uploadRoute: vi.fn(), isUploading: false }),
}))
vi.mock('@/api/endpoints/rides/rides', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/endpoints/rides/rides')>()),
  useLeaveGroup: () => ({ mutate: leave.mutate, isPending: false }),
}))
vi.mock('@/components/route/GpsMenuButton', () => ({
  GpsMenuButton: ({ routeSlug }: { routeSlug: string }) => (
    <button type="button" data-testid="gps-button" data-route={routeSlug}>
      GPS
    </button>
  ),
}))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { NextRideCard } from './NextRideCard'

const TEAM_REF = { id: 't1', name: 'VC Craponne', slug: 'vc-craponne', visibility: 'PUBLIC' }
const MEDIA = { markdown: '', assets: { images: [], attachments: [] } }
// Saturday 11 April 2026, 09:00 in Paris; « now » is Friday 10 April at noon.
const START = '2026-04-11T07:00:00Z'

function ride(overrides: Partial<RideDto> = {}): RideDto {
  return {
    type: 'RIDE',
    team: TEAM_REF,
    id: 'r1',
    slug: 'sortie-du-samedi',
    name: 'Sortie du samedi',
    media: MEDIA,
    dateTime: START,
    endDateTime: '2026-04-11T11:00:00Z',
    timezone: 'Europe/Paris',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    participantCount: 10,
    groupCount: 1,
    groups: [],
    groupSummaries: [],
    topParticipants: [],
    deleted: false,
    registered: true,
    registeredGroupId: 'g1',
    registeredGroup: {
      id: 'g1',
      name: 'Groupe A',
      countParticipants: 6,
      startAt: START,
    } as RideGroupDto,
    full: false,
    permissions: { canEdit: false, canDelete: false, indexable: false },
    tags: [],
    ...overrides,
  } as RideDto
}

function renderCard(dto: RideDto) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <NextRideCard ride={dto} />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('NextRideCard', () => {
  beforeEach(() => {
    leave.mutate.mockReset()
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date('2026-04-10T10:00:00Z'))
  })
  afterEach(() => {
    cleanup()
    vi.useRealTimers()
  })

  // KIT §9 (docs/LEDGER_*.md WEB-167): leaving is undone by joining again, so it asks nothing.
  it('leaves at once, without a confirmation', () => {
    renderCard(ride())
    fireEvent.click(screen.getByRole('button', { name: 'Se désinscrire' }))
    expect(screen.queryByRole('dialog')).toBeNull()
    expect(leave.mutate).toHaveBeenCalledTimes(1)
    expect(leave.mutate.mock.calls[0][0]).toEqual({
      teamSlug: 'vc-craponne',
      rideSlug: 'sortie-du-samedi',
      groupId: 'g1',
    })
  })

  it('carries « Demain » on a ride of tomorrow, but not once it has started (MOB-115)', () => {
    renderCard(ride())
    expect(screen.getByTestId('day-pill').textContent).toBe('Demain')
    cleanup()
    renderCard(ride({ finished: true }))
    expect(screen.getByTestId('day-box')).toBeTruthy()
    expect(screen.queryByTestId('day-pill')).toBeNull()
  })

  // R6 (docs/LEDGER_*.md WEB-167): « Se désinscrire » is the red link of « Quitter le groupe ».
  it('offers « Se désinscrire » as the red leave link, until the ride is over', () => {
    renderCard(ride())
    expect(screen.getByRole('button', { name: 'Se désinscrire' }).dataset.testid).toBe(
      'leave-group'
    )
    cleanup()
    // Started an hour ago, not over: still offered.
    vi.setSystemTime(new Date('2026-04-11T08:00:00Z'))
    renderCard(ride({ finished: true }))
    expect(screen.getByRole('button', { name: 'Se désinscrire' })).toBeTruthy()
    cleanup()
    vi.setSystemTime(new Date('2026-04-11T12:00:00Z'))
    renderCard(ride({ finished: true }))
    expect(screen.queryByRole('button', { name: 'Se désinscrire' })).toBeNull()
  })

  it('offers no leaving on a cancelled ride', () => {
    renderCard(ride({ status: 'CANCELLED' }))
    expect(screen.queryByRole('button', { name: 'Se désinscrire' })).toBeNull()
  })

  // KIT §9 (2026-11-12): the route's map, as the banner, is shown whole, as on the feed's card.
  it('shows the route’s map whole in its banner', () => {
    renderCard(ride({ thumbnailLightUrl: 'https://x/map-light.png' }))
    expect(screen.getByTestId('card-image-map')).toBeTruthy()
  })

  // KIT §9 (2026-11-12): no control at all on a cancelled ride's card, « GPS » included.
  it('offers no « GPS » on a cancelled ride', () => {
    renderCard(ride({ routeSlug: 'boucle', status: 'CANCELLED' }))
    expect(screen.queryByTestId('gps-button')).toBeNull()
    expect(screen.queryByText('Quitter le groupe')).toBeNull()
  })

  // R7: one « GPS » button for the group's route, until the ride is over.
  it('offers « GPS » for the group’s route, not after the end', () => {
    renderCard(
      ride({
        routeSlug: 'boucle',
        registeredGroup: { ...ride().registeredGroup!, routeSlug: 'boucle-a' },
      })
    )
    expect(screen.getByTestId('gps-button').getAttribute('data-route')).toBe('boucle-a')
    expect(screen.queryByText('Envoyer vers l’appareil')).toBeNull()
    cleanup()
    vi.setSystemTime(new Date('2026-04-11T12:00:00Z'))
    renderCard(ride({ routeSlug: 'boucle' }))
    expect(screen.queryByTestId('gps-button')).toBeNull()
  })

  // R5: the group card's row — cluster, « Groupe A · 6/12 personnes », the places bar.
  it('shows the group’s cluster, its count and its places bar', () => {
    renderCard(
      ride({
        permissions: {
          canEdit: false,
          canDelete: false,
          indexable: false,
          canSeeParticipants: true,
        },
        registeredGroup: {
          ...ride().registeredGroup!,
          maxParticipants: 12,
          full: false,
          participants: [
            { id: 'u1', displayName: 'Léa Martin' },
            { id: 'u2', displayName: 'Karim Benali' },
          ],
        } as RideGroupDto,
      })
    )
    expect(screen.getByTestId('avatar-cluster').textContent).toContain('KB')
    // The group is named under the departure (R11), not in the count.
    expect(screen.getByTestId('group-count').textContent?.replace(/\u00a0/g, ' ')).toBe(
      '6/12 personnes'
    )
    expect(screen.getByTestId('group-places-bar')).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'Voir tout' })).toBeNull()
  })

  // docs/LEDGER_*.md WEB-167, R11: « Groupe A · Place de la Mairie » under « Départ 09:00 ».
  it('says the group and the place on one line under the departure, the place by its name', () => {
    renderCard(
      ride({
        startPlace: {
          id: 'p1',
          name: 'Place de la Mairie',
          address: '1 place de la Mairie, Huelgoat',
          startPlace: true,
          endPlace: false,
        },
      })
    )
    const line = screen.getByTestId('group-place-line')
    // « Groupe A » is the group's own name: not « Groupe Groupe A ».
    expect(line.textContent).toBe('Groupe A · Place de la Mairie')
    expect(screen.queryByText(/Huelgoat/)).toBeNull()
    const departure = screen.getByTestId('departure-line')
    expect(departure.compareDocumentPosition(line) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
  })

  // docs/LEDGER_*.md API-178, R3: the server's distance for the reader, shown as is.
  it('shows the server’s distance and climb, and nothing without them', () => {
    renderCard(
      ride({
        distance: 92_400,
        elevationGain: 1_240,
        displayDistance: 78_000,
        displayElevationGain: 980,
        registeredGroup: { ...ride().registeredGroup!, distance: 61_000 } as RideGroupDto,
      })
    )
    const text = document.body.textContent?.replace(/[\u00a0\u202f]/g, ' ') ?? ''
    expect(text).toContain('78,0 km')
    expect(text).toContain('980 m')
    expect(text).not.toContain('92,4 km')
    expect(text).not.toContain('61,0 km')
    cleanup()
    renderCard(
      ride({
        distance: 92_400,
        registeredGroup: { ...ride().registeredGroup!, distance: 61_000 } as RideGroupDto,
      })
    )
    expect(screen.queryByText('Distance')).toBeNull()
  })
})
