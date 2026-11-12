import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RideDto } from '@/api/dto'

// Keys and their arguments, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}))

import { PublicationCardProgress } from './PublicationCardProgress'

/** A list row: no `groups`, the capacity is the server's (docs/LEDGER_*.md API-5). */
function listRow(overrides: Partial<RideDto>): RideDto {
  return { groups: [], participantCount: 12, full: false, ...overrides } as RideDto
}

function renderProgress(ride: RideDto) {
  return render(
    <MantineProvider>
      <PublicationCardProgress ride={ride} />
    </MantineProvider>
  )
}

describe('PublicationCardProgress', () => {
  afterEach(cleanup)

  it('draws the ride against its capacity, though the row carries no groups', () => {
    renderProgress(listRow({ maxParticipants: 40 }))
    const bar = screen.getByRole('progressbar')
    expect(bar.getAttribute('aria-label')).toBe('rides.detail.groups.participants')
    expect(bar.getAttribute('aria-valuenow')).toBe('30')
  })

  // R5 (docs/LEDGER_*.md WEB-167): primary, red once full — no green, no yellow.
  it('is primary while there is room, red once the server says full', () => {
    renderProgress(listRow({ maxParticipants: 14 }))
    expect(screen.getByRole('progressbar').getAttribute('style')).toContain(
      '--progress-section-color: primary'
    )
    cleanup()
    renderProgress(listRow({ maxParticipants: 12, full: true }))
    expect(screen.getByRole('progressbar').getAttribute('style')).toContain(
      'var(--mantine-color-red-filled)'
    )
  })

  it('draws nothing for a ride without an overall limit', () => {
    renderProgress(listRow({ maxParticipants: undefined }))
    expect(screen.queryByRole('progressbar')).toBeNull()
  })
})
