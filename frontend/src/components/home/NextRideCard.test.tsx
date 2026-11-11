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
})
