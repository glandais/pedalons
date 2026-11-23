import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup, within } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { AdminActivationWeekDto } from '@/api/dto'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

import { ActivationTable } from './ActivationTable'

/**
 * « Activation des nouveaux comptes » (docs/LEDGER_*.md API-213): the rates are computed here from
 * the server's counts, over the accounts created that week; a week still running says so.
 */
const week = (overrides: Partial<AdminActivationWeekDto>): AdminActivationWeekDto => ({
  domainId: 'd1',
  domainName: 'Pédalons',
  weekStart: '2026-11-16',
  complete: true,
  signedUp: 8,
  verified: 6,
  joinedTeam: 2,
  joinedRide: 1,
  ...overrides,
})

function renderTable(weeks: AdminActivationWeekDto[]) {
  return render(
    <MantineProvider>
      <ActivationTable weeks={weeks} isLoading={false} isError={false} />
    </MantineProvider>
  )
}

afterEach(cleanup)

describe('ActivationTable', () => {
  it('one row per week and domain, the rates over the accounts created', () => {
    renderTable([week({})])

    const row = screen.getAllByRole('row')[1]
    const cells = within(row)
      .getAllByRole('cell')
      .map((c) => c.textContent)
    expect(cells).toEqual(['2026-11-16', 'Pédalons', '8', '75 %', '25 %', '13 %'])
  })

  it('a week whose accounts have not all had their 7 days is marked in progress', () => {
    renderTable([week({ complete: false, weekStart: '2026-11-23' })])

    expect(screen.getByText('admin.activation.inProgress')).toBeVisible()
  })

  it('no account in a week: a dash, never a division by zero', () => {
    renderTable([week({ signedUp: 0, verified: 0, joinedTeam: 0, joinedRide: 0 })])

    expect(screen.getAllByText('—')).toHaveLength(3)
  })

  it('nothing at all: says so', () => {
    renderTable([])

    expect(screen.getByText('admin.activation.empty')).toBeVisible()
  })
})
