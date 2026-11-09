import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { DayBox } from './DayBox'

vi.mock('react-i18next', async (importOriginal) => ({
  ...(await importOriginal<typeof import('react-i18next')>()),
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

function renderBox(date: string) {
  render(
    <MantineProvider>
      <DayBox date={date} zone="Europe/Paris" />
    </MantineProvider>
  )
  return screen.getByTestId('day-box').textContent
}

// docs/BRANDING.md §7.8 (ledger BRAND-9): on a card the box is the only date.
describe('DayBox: the year outside the current one', () => {
  afterEach(() => {
    cleanup()
    vi.useRealTimers()
  })

  it('keeps three lines in the current year', () => {
    vi.useFakeTimers({ now: new Date('2026-11-09T12:00:00Z'), toFake: ['Date'] })
    expect(renderBox('2026-12-12T08:00:00Z')).toBe('sam.12déc.')
  })

  it('adds the year as a fourth line in another year', () => {
    vi.useFakeTimers({ now: new Date('2026-11-09T12:00:00Z'), toFake: ['Date'] })
    expect(renderBox('2027-04-10T07:00:00Z')).toBe('sam.10avr.2027')
  })
})
