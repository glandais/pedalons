import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { DepartureBlock } from './DepartureBlock'

function renderBlock(props: Partial<React.ComponentProps<typeof DepartureBlock>> = {}) {
  return render(
    <MantineProvider>
      <DepartureBlock date="2026-04-11T07:00:00Z" zone="Europe/Paris" {...props} />
    </MantineProvider>
  )
}

const block = () => screen.getByRole('region', { name: 'Date et heure de départ' })

// docs/BRANDING.md §7.8, docs/LEDGER_*.md WEB-137. The reader is in Paris (Vitest's zone), « now »
// Friday 10 April 2026 at noon.
describe('DepartureBlock', () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date('2026-04-10T10:00:00Z'))
  })
  afterEach(() => {
    cleanup()
    vi.useRealTimers()
  })

  it('is a named section: the day box, the time, the long day', () => {
    renderBlock()
    const section = block()
    expect(within(section).getByTestId('day-box').textContent).toBe('sam.11avr.')
    expect(within(section).getByText('Départ 09:00')).toBeTruthy()
    expect(within(section).getByText('samedi 11 avril')).toBeTruthy()
  })

  it('carries the « Demain » pill tomorrow, « Aujourd’hui » today, none on another day', () => {
    renderBlock()
    expect(within(block()).getByText('Demain')).toBeTruthy()
    cleanup()
    renderBlock({ date: '2026-04-10T16:00:00Z' })
    expect(within(block()).getByText("Aujourd'hui")).toBeTruthy()
    cleanup()
    renderBlock({ date: '2026-04-18T07:00:00Z' })
    expect(within(block()).queryByText('Demain')).toBeNull()
    expect(within(block()).queryByText("Aujourd'hui")).toBeNull()
  })

  it('takes a span in place of the long day', () => {
    renderBlock({ tone: 'teal', dayLine: 'sam. 11 → lun. 13 avr.' })
    expect(within(block()).getByText('sam. 11 → lun. 13 avr.')).toBeTruthy()
  })

  it('adds the zone mention when the reader is elsewhere', () => {
    // 09:00 in Tokyo is 02:00 in Paris.
    renderBlock({ date: '2026-04-18T00:00:00Z', zone: 'Asia/Tokyo' })
    expect(within(block()).getByText('Départ 09:00')).toBeTruthy()
    expect(block().textContent).toContain('heure de Tokyo (02:00 chez vous)')
  })

  it('names the start place', () => {
    renderBlock({ place: { name: 'Parking de la gare', address: '1 rue du Port' } })
    expect(within(block()).getByText('Parking de la gare')).toBeTruthy()
    expect(within(block()).getByText('(1 rue du Port)')).toBeTruthy()
    expect(within(block()).getByRole('img', { name: 'Lieu de départ' })).toBeTruthy()
  })

  it('shows the reader’s group and its time only when given one', () => {
    renderBlock()
    expect(screen.queryByTestId('departure-group')).toBeNull()
    cleanup()
    renderBlock({ group: { name: 'Groupe B', startAt: '2026-04-11T07:30:00Z' } })
    const group = screen.getByTestId('departure-group')
    expect(group.textContent).toBe('Votre groupeGroupe B · 09:30')
    // The block still gives the ride's own time.
    expect(within(block()).getByText('Départ 09:00')).toBeTruthy()
  })
})
