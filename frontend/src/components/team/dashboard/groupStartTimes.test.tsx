import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import type { RideDto, RideGroupDto, RideGroupSummaryDto } from '@/api/dto'
import { plain } from '@/test/weatherFixtures'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => false }))
vi.mock('@/hooks/useGpsConnections', () => ({
  useGpsConnections: () => ({ connectedServices: [], uploadRoute: vi.fn(), isUploading: false }),
}))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { MyUpcomingList } from './MyUpcomingList'
import { UpcomingRideCard } from './UpcomingRideCard'
import { NextRideCard } from '@/components/home/NextRideCard'

// docs/LEDGER_*.md WEB-136: the departure that concerns a registered person is their group's.
const TEAM_REF = { id: 't1', name: 'VC Craponne', slug: 'vc-craponne', visibility: 'PUBLIC' }
const MEDIA = { markdown: '', assets: { images: [], attachments: [] } }
const RIDE_START = '2026-10-10T06:30:00Z'
const LATER = '2026-10-10T07:15:00Z'

function summary(overrides: Partial<RideGroupSummaryDto>): RideGroupSummaryDto {
  return {
    id: 'g1',
    name: 'Groupe A',
    countParticipants: 4,
    full: false,
    sortOrder: 0,
    startAt: RIDE_START,
    ...overrides,
  }
}

function joined(startAt: string): RideGroupDto {
  return { id: 'g2', name: 'Groupe B', countParticipants: 6, startAt } as RideGroupDto
}

function ride(overrides: Partial<RideDto> = {}): RideDto {
  return {
    type: 'RIDE',
    team: TEAM_REF,
    id: 'r1',
    slug: 'sortie-du-samedi',
    name: 'Sortie du samedi',
    media: MEDIA,
    dateTime: RIDE_START,
    timezone: 'UTC',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    participantCount: 10,
    groupCount: 2,
    groups: [],
    groupSummaries: [],
    topParticipants: [],
    deleted: false,
    registered: true,
    full: false,
    permissions: { canEdit: false, canDelete: false, indexable: false },
    tags: [],
    ...overrides,
  } as RideDto
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

const text = () => plain(document.body.textContent)

describe('UpcomingRideCard: a group leaving at its own time says when', () => {
  afterEach(cleanup)

  it('gives every group its time as soon as they do not all leave together', () => {
    renderIn(
      <UpcomingRideCard
        ride={ride({
          registered: false,
          groupSummaries: [
            summary({ id: 'g1', name: 'Groupe A' }),
            summary({ id: 'g2', name: 'Groupe B', sortOrder: 1, startAt: LATER }),
          ],
        })}
      />
    )
    expect(screen.getByText(/Groupe B/).textContent).toContain('départ 07:15')
    expect(screen.getByText(/Groupe A/).textContent).toContain('départ 06:30')
  })

  it('gives no time when every group leaves with the ride', () => {
    renderIn(
      <UpcomingRideCard
        ride={ride({
          registered: false,
          groupSummaries: [
            summary({ id: 'g1', name: 'Groupe A' }),
            summary({ id: 'g2', name: 'Groupe B', sortOrder: 1 }),
          ],
        })}
      />
    )
    expect(screen.getByText(/Groupe A/).textContent).not.toContain('départ')
    expect(screen.getByText(/Groupe B/).textContent).not.toContain('départ')
  })

  it('leads with the reader’s group, marks it, and times every group', () => {
    renderIn(
      <UpcomingRideCard
        ride={ride({
          registeredGroupId: 'g2',
          registeredGroup: joined(LATER),
          groupSummaries: [
            summary({ id: 'g1', name: 'Groupe A' }),
            summary({ id: 'g2', name: 'Groupe B', sortOrder: 1, startAt: LATER }),
          ],
        })}
      />
    )
    expect(screen.getByText(/sam\.? 10 oct\.?/i).textContent).toContain('07:15')
    expect(screen.getByText(/Groupe A/).textContent).toContain('départ 06:30')
    expect(screen.getByText(/Groupe B/).textContent).toContain('départ 07:15')
    expect(screen.getAllByRole('img', { name: "J'y vais" })).toHaveLength(1)
  })
})

describe('MyUpcomingList: the registered group’s departure', () => {
  afterEach(cleanup)

  it('shows the group’s time when it leaves at its own', () => {
    renderIn(<MyUpcomingList publications={[ride({ registeredGroup: joined(LATER) })]} />)
    expect(text()).toContain('07:15')
    expect(text()).not.toContain('06:30')
  })

  it('shows the ride’s time without a group', () => {
    renderIn(<MyUpcomingList publications={[ride()]} />)
    expect(text()).toContain('06:30')
  })
})

describe('NextRideCard: the departure that concerns the reader', () => {
  afterEach(cleanup)

  it('leads with the group’s time, and names the group alone', () => {
    renderIn(
      <NextRideCard ride={ride({ registeredGroupId: 'g2', registeredGroup: joined(LATER) })} />
    )
    expect(text()).toContain('Départ 07:15')
    expect(text()).toContain('Groupe B · ')
    expect(text()).not.toContain('après la sortie')
    // The day of the group's departure, posed on the picture (docs/LEDGER_*.md WEB-138).
    const box = screen.getByTestId('day-box')
    expect(box.textContent).toBe('sam.10oct.')
    expect(box.getAttribute('data-variant')).toBe('posed')
  })

  it('names the group alone when it leaves with the ride', () => {
    renderIn(
      <NextRideCard ride={ride({ registeredGroupId: 'g2', registeredGroup: joined(RIDE_START) })} />
    )
    expect(text()).toContain('06:30')
    expect(text()).not.toContain('après la sortie')
    expect(text()).toContain('Groupe B · ')
  })
})
