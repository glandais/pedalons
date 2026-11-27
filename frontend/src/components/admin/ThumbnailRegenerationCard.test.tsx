import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, fireEvent } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { ThumbnailCatchUpStatus } from '@/api/dto'

// The key and its values, so a test can tell which line was built and with what
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: Record<string, unknown>) =>
      options ? `${key} ${JSON.stringify(options)}` : key,
    i18n: { language: 'en' },
  }),
}))

const catchUp = vi.hoisted(() => ({
  data: undefined as ThumbnailCatchUpStatus | undefined,
  refetch: vi.fn(),
}))

vi.mock('@/api/endpoints/admin-thumbnails/admin-thumbnails', () => ({
  useAdminGetThumbnailCatchUp: () => catchUp,
  useAdminRegenerateThumbnails: () => ({ mutate: vi.fn(), isPending: false }),
}))

import { ThumbnailRegenerationCard } from './ThumbnailRegenerationCard'

/**
 * The catch-up line and the two criteria of the « Miniatures de carte » card (docs/LEDGER_*.md
 * API-223): what the automatic catch-up has left to do, and the admin's way to redraw it by hand.
 */
const status = (overrides: Partial<ThumbnailCatchUpStatus>): ThumbnailCatchUpStatus => ({
  version: 2,
  enabled: true,
  perHour: 300,
  behind: 0,
  waiting: 0,
  givenUp: 0,
  ...overrides,
})

function renderCard() {
  return render(
    <MantineProvider>
      <ThumbnailRegenerationCard domainId={null} />
    </MantineProvider>
  )
}

beforeEach(() => {
  catchUp.data = undefined
})
afterEach(cleanup)

describe('ThumbnailRegenerationCard', () => {
  it('nothing behind, nothing given up: says everything is up to date', () => {
    catchUp.data = status({})
    renderCard()

    expect(screen.getByText('admin.maintenance.thumbnails.catchUp.upToDate')).toBeVisible()
  })

  it('behind: the counts, with those waiting for a new attempt, formatted', () => {
    catchUp.data = status({ behind: 6120, waiting: 12, givenUp: 3 })
    renderCard()

    const line = screen.getByText(/admin\.maintenance\.thumbnails\.catchUp\.status/)
    expect(line.textContent).toContain('"behind":"6,120"')
    expect(line.textContent).toContain('"givenUp":"3"')
    expect(line.textContent).toContain('catchUp.waiting {\\"waiting\\":\\"12\\"}')
  })

  it('only given up: still a count, not the up to date line', () => {
    catchUp.data = status({ givenUp: 2 })
    renderCard()

    expect(screen.queryByText('admin.maintenance.thumbnails.catchUp.upToDate')).toBeNull()
    expect(screen.getByText(/catchUp\.status/).textContent).toContain('"givenUp":"2"')
  })

  it('switched off: the line says it is stopped', () => {
    catchUp.data = status({ enabled: false, behind: 5 })
    renderCard()

    expect(screen.getByText(/catchUp\.stopped/)).toBeVisible()
  })

  it('ticking « outdated » enables the preview, « given up » too', () => {
    renderCard()
    const preview = screen.getByRole('button', { name: 'admin.maintenance.preview' })
    expect(preview).toBeDisabled()

    fireEvent.click(screen.getByLabelText('admin.maintenance.thumbnails.outdated'))
    expect(preview).toBeEnabled()
    fireEvent.click(screen.getByLabelText('admin.maintenance.thumbnails.outdated'))
    expect(preview).toBeDisabled()

    fireEvent.click(screen.getByLabelText('admin.maintenance.thumbnails.givenUp'))
    expect(preview).toBeEnabled()
  })
})
