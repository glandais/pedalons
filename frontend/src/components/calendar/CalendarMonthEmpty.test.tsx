import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { CalendarEventDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { CalendarMonthEmpty, type CalendarMonthEmptyConfig } from './CalendarMonthEmpty'
import { monthBounds } from './calendarMonth'

/**
 * A month of the calendar that shows nothing (docs/LEDGER_*.md WEB-175, RL10), as the app says it:
 * filtered when the month has events, else the empty month and the way to the next one — found
 * without a read per month.
 */

afterEach(cleanup)

const ride = (id: string, start: string, type: 'RIDE' | 'TRIP_STAGE' = 'RIDE') =>
  ({ id, start, type }) as CalendarEventDto

const NOVEMBER = monthBounds('2026-11-12', 'UTC')

function renderIt(over: Partial<CalendarMonthEmptyConfig> = {}) {
  const onGoToMonth = vi.fn()
  const probe = vi.fn(async () => ({ events: [] as CalendarEventDto[] }))
  const props: CalendarMonthEmptyConfig = {
    allEvents: [],
    keep: () => true,
    activeFilters: [],
    onClearFilters: vi.fn(),
    scope: 'mine',
    loadedTo: '2027-06-01T00:00:00.000Z',
    probeKey: 'mine',
    probe,
    ...over,
  }
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <CalendarMonthEmpty
          {...props}
          month={NOVEMBER}
          tz="UTC"
          language="fr"
          onGoToMonth={onGoToMonth}
        />
      </QueryClientProvider>
    </MantineProvider>
  )
  return { onGoToMonth, probe: props.probe as typeof probe, onClear: props.onClearFilters }
}

describe('CalendarMonthEmpty', () => {
  it('an empty month says so, in lower case, and leads to the next month with a ride', () => {
    const { onGoToMonth, probe } = renderIt({
      allEvents: [ride('later', '2027-01-20T08:00:00Z')],
    })
    expect(screen.getByRole('heading', { name: 'Aucun événement ce mois-ci' })).toBeTruthy()
    expect(
      screen.getByText(
        "Vos équipes n'ont publié aucune sortie ni étape de voyage en novembre 2026."
      )
    ).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Aller au prochain mois avec une sortie' }))
    expect(onGoToMonth).toHaveBeenCalledWith('2027-01-01')
    // Found in the loaded window: no read.
    expect(probe).not.toHaveBeenCalled()
  })

  it('a team’s calendar names the team, and offers nothing when no month follows', () => {
    renderIt({ scope: 'team' })
    expect(
      screen.getByText("L'équipe n'a publié aucune sortie ni étape de voyage en novembre 2026.")
    ).toBeTruthy()
    expect(screen.queryByRole('button')).toBeNull()
  })

  it('a month whose events the filters hide is a filtered empty state', () => {
    const { onClear } = renderIt({
      allEvents: [ride('r', '2026-11-20T08:00:00Z')],
      keep: (event) => event.type === 'TRIP_STAGE',
      activeFilters: ['Voyages'],
    })
    expect(screen.getByRole('heading', { name: 'Aucun événement pour ces filtres' })).toBeTruthy()
    expect(screen.getByText('Rien ne correspond à : Voyages.')).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Effacer les filtres' }))
    expect(onClear).toHaveBeenCalled()
  })

  it('the next month is one the filters keep', () => {
    renderIt({
      allEvents: [
        ride('r', '2026-12-05T08:00:00Z'),
        ride('s', '2027-02-05T08:00:00Z', 'TRIP_STAGE'),
      ],
      keep: (event) => event.type === 'TRIP_STAGE',
      activeFilters: ['Voyages'],
    })
    expect(screen.getByRole('heading', { name: 'Aucun événement ce mois-ci' })).toBeTruthy()
    expect(
      screen.getByRole('button', { name: 'Aller au prochain mois avec une sortie' })
    ).toBeTruthy()
  })

  it('past the loaded window, one read covers the six months — never one per month', async () => {
    const probe = vi.fn(async () => ({ events: [ride('far', '2027-03-10T08:00:00Z')] }))
    const { onGoToMonth } = renderIt({ loadedTo: '2027-01-01T00:00:00.000Z', probe })
    fireEvent.click(
      await screen.findByRole('button', { name: 'Aller au prochain mois avec une sortie' })
    )
    expect(probe).toHaveBeenCalledTimes(1)
    expect(probe).toHaveBeenCalledWith('2027-01-01T00:00:00.000Z', '2027-06-01T00:00:00.000Z')
    expect(onGoToMonth).toHaveBeenCalledWith('2027-03-01')
  })
})
