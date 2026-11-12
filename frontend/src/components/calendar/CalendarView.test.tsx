import { describe, it, expect, vi, beforeAll, afterAll } from 'vitest'
import { renderToString } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', () => ({
  // The key, but « Group B » for the group's title, so the compact line can be read (KIT §9).
  useTranslation: () => ({
    t: (key: string, params?: { name?: string }) =>
      key === 'rides.group.title' ? `Group ${params?.name}` : key,
    i18n: { language: 'en' },
  }),
}))

import { CalendarView } from './CalendarView'
import type { CalendarEventDto } from '@/api/dto'

/**
 * Between midnight and the visitor's offset, the date in their zone is not the date in UTC — the
 * zone the SSR container runs in, and the one `useEffectiveTimezone` answers during the server and
 * hydration renders. Anything the server render derives from a bare `dayjs()` then reads the
 * *process* zone instead, and the browser renders another day: a text mismatch, React error #418.
 *
 * Here the process plays the browser (Europe/Paris, already on the 28th) while `renderToString`
 * takes the server snapshot (UTC, still the 27th): whatever the markup shows must be the 27th.
 */
describe('CalendarView server render', () => {
  const previousTz = process.env.TZ

  beforeAll(() => {
    process.env.TZ = 'Europe/Paris'
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date('2026-09-27T22:30:00Z'))
  })

  afterAll(() => {
    vi.useRealTimers()
    process.env.TZ = previousTz
  })

  function render(events: CalendarEventDto[] = []): string {
    return renderToString(
      <MantineProvider>
        <MemoryRouter>
          <CalendarView events={events} isLoading={false} onDateRangeChange={() => {}} />
        </MemoryRouter>
      </MantineProvider>
    )
  }

  it('titles the mobile agenda with the day in the render timezone, not the process one', () => {
    const heading = /mobileMonthViewEventsHeader[^>]*>([^<]*)</.exec(render())?.[1]
    expect(heading).toBe('Sunday, September 27')
  })

  it('leaves "today" unmarked until mounted, since React never patches the attribute', () => {
    expect(render()).not.toContain('data-today')
  })

  it("lists the day's events on the phone with their team and the registration", () => {
    const html = render([
      {
        id: '1',
        title: 'Sortie du dimanche',
        start: '2026-09-27T07:00:00Z',
        end: '2026-09-27T10:00:00Z',
        allDay: false,
        type: 'RIDE',
        teamSlug: 'n-peloton',
        teamName: 'N Peloton',
        entitySlug: 'sortie-du-dimanche',
        registered: true,
        groupName: 'Groupe A',
        status: 'PUBLISHED',
        finished: false,
        timezone: 'Europe/Paris',
      },
    ])
    // The phone's agenda, below its day header: MobileMonthView ignores renderEventBody.
    const agenda = html.slice(html.indexOf('mobileMonthViewEventsHeader'))
    expect(agenda).toContain('N Peloton')
    expect(agenda).toContain('calendar.event.registered')
    expect(agenda).not.toContain('All day')
  })

  // docs/LEDGER_*.md WEB-167, R11 and R3: « 09:00 · team · group », the place on its own line, then
  // the server's distance and climb — on the phone too.
  it('orders the summary time · team · group, and shows the place and the distance apart', () => {
    const html = render([
      {
        id: '1',
        title: 'Sortie du dimanche',
        start: '2026-09-27T07:00:00Z',
        end: '2026-09-27T10:00:00Z',
        allDay: false,
        type: 'RIDE',
        teamSlug: 'n-peloton',
        teamName: 'N Peloton',
        entitySlug: 'sortie-du-dimanche',
        startPlaceName: 'Place de la Mairie',
        distance: 92_400,
        elevationGain: 1_240,
        displayDistance: 78_000,
        displayElevationGain: 980,
        registered: true,
        groupName: 'B',
        status: 'PUBLISHED',
        finished: false,
        timezone: 'Europe/Paris',
      },
    ])
    const agenda = html
      .slice(html.indexOf('mobileMonthViewEventsHeader'))
      .replace(/&nbsp;|\u00a0|\u202f/g, ' ')
    // « Group B »: a one-letter name takes the word « Group » (KIT §9), compact lines included.
    expect(agenda).toMatch(/>9:00 AM · N Peloton · Group B</)
    expect(agenda).toContain('>Place de la Mairie<')
    expect(agenda).toContain('78.0 km · 980 m')
    expect(agenda).not.toContain('92.4')
  })
})
