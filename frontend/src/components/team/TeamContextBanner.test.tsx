import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TeamPublicationDto } from '@/api/dto'
import { paths } from '@/config/paths'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

import { TeamContextBanner } from './TeamContextBanner'

const team = (overrides: Partial<TeamPublicationDto> = {}): TeamPublicationDto => ({
  id: 't1',
  slug: 'np',
  name: 'N Peloton',
  visibility: 'TEAM',
  accessible: true,
  ...overrides,
})

function renderBanner(summary: TeamPublicationDto) {
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <TeamContextBanner team={summary} />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

/** Built from the entity's embedded summary, never from `GET team` (docs/LEDGER_*.md WEB-166). */
describe('TeamContextBanner', () => {
  afterEach(cleanup)

  it('leads to a team the reader may open', () => {
    renderBanner(team())
    expect(screen.getByRole('link').getAttribute('href')).toBe(paths.team('np'))
  })

  it('names a closed team without a link to it', () => {
    renderBanner(team({ accessible: false }))
    expect(screen.getByTestId('team-context-banner').textContent).toContain('N Peloton')
    expect(screen.queryByRole('link')).toBeNull()
  })

  it('shows a closed team’s logo only when the summary carries one', () => {
    renderBanner(team({ accessible: false }))
    expect(screen.queryByRole('img')).toBeNull()
    expect(screen.getByTestId('team-context-banner').textContent).not.toContain('NP')
    cleanup()
    renderBanner(team({ accessible: false, logoUrl: '/api/assets/logo/{size}' }))
    const logo = screen.getByTestId('team-context-banner').querySelector('img')
    expect(logo?.getAttribute('src')).toBe('/api/assets/logo/128')
    // Decorative, the name being written beside it: not read twice.
    expect(logo?.getAttribute('alt')).toBe('')
    expect(screen.queryByRole('img')).toBeNull()
  })
})
