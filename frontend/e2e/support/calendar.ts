import { expect, test, type Page } from '@playwright/test'
import type { CalendarEventDto, CalendarEventsResponse } from '../../src/api/dto'
import { apiGet, type AuthResponse } from './api'
import { monthName, parisWallClock, type WallClock } from './dates'
import { hydrated } from './ui'

/**
 * The team calendar (/equipes/{slug}/calendrier) and the personal one (/calendrier), on both
 * layouts: the desktop month grid lists
 * every event of the month; the phone layout (`layout="responsive"`) lists only the selected day's,
 * under a grid whose other months are reached through the year view.
 *
 * Its events are loaded once, for a window running from last month to six months ahead
 * (useCalendarDateRange), and that load is prefetched by the SSR server: paging months sends no
 * request from the browser at all. So nothing on the network says « the events are in » — a test
 * that checks an event is *absent* shows another event of the same view first (an anchor).
 */

export const teamCalendarPath = (teamSlug: string) => `/equipes/${teamSlug}/calendrier`

/**
 * Opens the team calendar on `day`: the month holding it (months ahead are reached with « Suivant »
 * on a desktop, through the year view on a phone) and, on a phone, that day selected.
 */
export async function openCalendar(page: Page, teamSlug: string, day: WallClock) {
  await openCalendarAt(page, teamCalendarPath(teamSlug), day)
}

/** The personal calendar, every team of the signed-in user's in one grid. */
export const globalCalendarPath = '/calendrier'

/**
 * The heading each calendar page renders: the team calendar is the agenda's calendar view
 * (WEB-68), titled « Agenda » like its lists; the personal one is « Calendrier ». The personal page titles it as its h1; the team titles
 * « Agenda » as an h2 under the team's name (h1), hence the level in `openCalendarAt`.
 */
const calendarHeading = (path: string) => (path === globalCalendarPath ? 'Calendrier' : 'Agenda')

/**
 * Opens a calendar page — the team's (`teamCalendarPath`) or the personal one
 * (`globalCalendarPath`), which share `CalendarView` — on `day`, as `openCalendar` does.
 */
export async function openCalendarAt(page: Page, path: string, day: WallClock) {
  await page.goto(path)
  const main = page.getByRole('main')
  await expect(
    main.getByRole('heading', {
      name: calendarHeading(path),
      level: path === globalCalendarPath ? 1 : 2,
    })
  ).toBeVisible()
  const today = parisWallClock(new Date())
  const monthsAhead = day.year * 12 + day.month - (today.year * 12 + today.month)
  expect(monthsAhead, 'the calendar only pages forward here').toBeGreaterThanOrEqual(0)
  const visibleButton = (name: string) =>
    main.getByRole('button', { name, exact: true }).filter({ visible: true })

  if (test.info().project.use.isMobile) {
    if (monthsAhead > 0) {
      await hydrated(visibleButton(String(day.year)))
      await visibleButton(String(day.year)).click()
      await visibleButton(monthName(day.month, 'fr-FR')).click()
    }
    // Day buttons are labelled « septembre 27, 2026 ».
    const dayButton = visibleButton(`${monthName(day.month, 'fr-FR')} ${day.day}, ${day.year}`)
    await hydrated(dayButton)
    await dayButton.click()
  } else {
    // Even on the current month: the caller clicks an event next, and the grid is heavy enough
    // that a click right after it shows lands before hydration and is lost (WEB-35).
    await hydrated(visibleButton('Suivant'))
    for (let i = 0; i < monthsAhead; i++) {
      await visibleButton('Suivant').click()
      await hydrated(visibleButton('Suivant'))
    }
  }
}

/** An event of the calendar, by its title — the visible one of the desktop and phone layouts. */
export const calendarEvent = (page: Page, title: string) =>
  page.getByRole('main').getByRole('button').filter({ hasText: title }).filter({ visible: true })

/** The team calendar's events between two instants, as `who` reads them. */
export async function teamEvents(
  who: AuthResponse,
  teamSlug: string,
  from: Date,
  to: Date
): Promise<CalendarEventDto[]> {
  const response = await apiGet<CalendarEventsResponse>(
    who,
    `/api/teams/${teamSlug}/calendar/events`,
    { from: from.toISOString(), to: to.toISOString() }
  )
  return response.events
}
