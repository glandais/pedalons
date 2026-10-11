import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { TeamTimezoneChangePreviewDto } from '@/api/dto'

// Keys and their values, not wording: an example is rendered inline as `key{json}`. The date
// pattern is the French catalog's.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: Record<string, unknown>) => {
      if (key === 'teams.settings.timezoneChange.datePattern') return 'EEEE d MMMM'
      return options === undefined ? key : `${key}${JSON.stringify(options)}`
    },
    i18n: { language: 'fr' },
  }),
}))

import { TimezoneChangePreview } from './TimezoneChangePreview'

function preview(overrides: Partial<TeamTimezoneChangePreviewDto> = {}) {
  return {
    from: 'Europe/Paris',
    to: 'America/Montreal',
    upcomingCount: 0,
    pastCount: 0,
    upcoming: [],
    ...overrides,
  } as TeamTimezoneChangePreviewDto
}

function renderPreview(value: TeamTimezoneChangePreviewDto) {
  return render(
    <MantineProvider>
      <TimezoneChangePreview preview={value} />
    </MantineProvider>
  )
}

// docs/LEDGER_*.md API-60, plan §9.
describe('TimezoneChangePreview', () => {
  afterEach(cleanup)

  it('gives the count and the first upcoming rendezvous at its wall time in the old zone', () => {
    renderPreview(
      preview({
        upcomingCount: 3,
        upcoming: [
          {
            type: 'RIDE',
            id: 'r1',
            slug: 'boucle',
            title: 'Boucle',
            // 09:30 in Paris on Sunday 11 October 2026 (UTC+2).
            dateTime: '2026-10-11T07:30:00Z',
          },
        ],
      })
    )

    const text = screen.getByTestId('timezone-change-upcoming').textContent ?? ''
    expect(text.startsWith('teams.settings.timezoneChange.upcoming{"count":3')).toBe(true)
    expect(text).toContain('teams.settings.timezoneChange.example.RIDE')
    expect(text).toContain('\\"title\\":\\"Boucle\\"')
    expect(text).toContain('\\"date\\":\\"dimanche 11 octobre\\"')
    expect(text).toContain('\\"time\\":\\"09:30\\"')
    expect(text).toContain('\\"ofCity\\":\\"de Montréal\\"')
  })

  it('names the trip of a stage', () => {
    renderPreview(
      preview({
        upcomingCount: 1,
        upcoming: [
          {
            type: 'TRIP_STAGE',
            id: 's1',
            slug: 'j1',
            title: 'J1',
            tripTitle: 'Tour du lac',
            dateTime: '2026-10-11T06:00:00Z',
          },
        ],
      })
    )

    const text = screen.getByTestId('timezone-change-upcoming').textContent ?? ''
    expect(text).toContain('teams.settings.timezoneChange.example.TRIP_STAGE')
    expect(text).toContain('\\"trip\\":\\"Tour du lac\\"')
    expect(text).toContain('\\"time\\":\\"08:00\\"')
  })

  it('says nothing changes when no upcoming rendezvous lacks a place', () => {
    renderPreview(preview())

    expect(screen.getByTestId('timezone-change-upcoming').textContent).toBe(
      'teams.settings.timezoneChange.none'
    )
    expect(screen.queryByText(/timezoneChange\.past/)).toBeNull()
  })

  it('counts the past ones, relabelled in the new zone', () => {
    renderPreview(preview({ pastCount: 2 }))

    expect(
      screen.getByText('teams.settings.timezoneChange.past{"count":2,"ofCity":"de Montréal"}')
    ).toBeTruthy()
  })

  it('names both zones by their city, with the French « of » phrase', () => {
    renderPreview(preview({ from: 'Europe/Athens', to: 'Africa/Cairo' }))

    expect(
      screen.getByText(
        'teams.settings.timezoneChange.question{"ofFrom":"d\'Athènes","ofTo":"du Caire"}'
      )
    ).toBeTruthy()
  })
})
