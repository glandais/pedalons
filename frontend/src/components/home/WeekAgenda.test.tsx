import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { CalendarEventDto } from '@/api/dto'
import { paths } from '@/config/paths'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { WeekAgenda } from './WeekAgenda'

const NOW = '2026-04-10T10:00:00Z'

function event(index: number): CalendarEventDto {
  return {
    id: `e${index}`,
    title: `Sortie ${index}`,
    // One a day from tomorrow, all inside the seven days.
    start: `2026-04-${String(11 + (index % 5)).padStart(2, '0')}T07:00:00Z`,
    allDay: false,
    type: 'RIDE',
    teamSlug: 'np',
    teamName: 'Nantes Pédale',
    entitySlug: `sortie-${index}`,
    status: 'PUBLISHED',
    finished: false,
    registered: false,
    timezone: 'Europe/Paris',
  } as CalendarEventDto
}

function renderAgenda(count: number, edit: (e: CalendarEventDto) => CalendarEventDto = (e) => e) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <WeekAgenda
            nowIso={NOW}
            events={Array.from({ length: count }, (_, i) => edit(event(i)))}
            isLoading={false}
          />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

// docs/LEDGER_*.md WEB-167, as the app: rows past the limit are named, never dropped silently.
describe('WeekAgenda', () => {
  afterEach(cleanup)

  it('names the events past the fifth row, with a link to the calendar', () => {
    renderAgenda(7)
    const more = screen.getByTestId('week-more')
    expect(more.textContent).toBe('2\u00a0autres événements au calendrier')
    expect(more.getAttribute('href')).toBe(paths.calendar())
    cleanup()
    renderAgenda(6)
    expect(screen.getByTestId('week-more').textContent).toBe('1\u00a0autre événement au calendrier')
  })

  it('says nothing more when every event has its row', () => {
    renderAgenda(5)
    expect(screen.queryByTestId('week-more')).toBeNull()
  })

  // docs/LEDGER_*.md WEB-167, R1: one state, then « J'y vais »; never « Publié ».
  it('says the state before « J’y vais », and nothing of a published event', () => {
    renderAgenda(1, (e) => ({ ...e, status: 'CANCELLED', registered: true }))
    const row = screen.getByText('Sortie 0').parentElement!
    expect(row.textContent).toBe("Sortie 0AnnuléJ'y vais")
    cleanup()
    renderAgenda(1)
    expect(screen.getByText('Sortie 0').parentElement!.textContent).toBe('Sortie 0')
  })
})
