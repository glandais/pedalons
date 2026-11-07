import { expect, type Locator, type Page } from '@playwright/test'

/**
 * Dates as a visitor reads them: wall-clock days and times in the browser's zone (Europe/Paris, see
 * playwright.config.ts), how the app writes them, and the Mantine DateTimePicker driven the way a
 * visitor does.
 */

export const TZ = 'Europe/Paris'

/** A calendar day and a time of day, as a visitor in Paris reads them. */
export interface WallClock {
  year: number
  /** 1–12 */
  month: number
  day: number
  hour: number
  minute: number
}

/** How `instant` reads on a wall clock in `zone`. */
export function wallClockIn(instant: Date | string, zone: string): WallClock {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', {
      timeZone: zone,
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      hourCycle: 'h23',
    })
      .formatToParts(new Date(instant))
      .map((part) => [part.type, part.value])
  )
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
  }
}

/** The instant (ISO) a wall clock in `zone` shows `w` at. */
export function instantIn(w: WallClock, zone: string): string {
  const asUtc = Date.UTC(w.year, w.month - 1, w.day, w.hour, w.minute)
  const seen = wallClockIn(new Date(asUtc), zone)
  const offset = Date.UTC(seen.year, seen.month - 1, seen.day, seen.hour, seen.minute) - asUtc
  return new Date(asUtc - offset).toISOString()
}

/** How `instant` reads on a Paris wall clock. */
export const parisWallClock = (instant: Date | string) => wallClockIn(instant, TZ)

/** The instant (ISO) a Paris wall clock shows `w` at. */
export const parisInstant = (w: WallClock) => instantIn(w, TZ)

/** Plain calendar arithmetic on a UTC date: no zone, no DST jump in the way. */
function shiftDays(from: WallClock, days: number, hour: number, minute: number): WallClock {
  const date = new Date(Date.UTC(from.year, from.month - 1, from.day + days))
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
    hour,
    minute,
  }
}

/** The day `days` after today in `zone`, at `hour`:`minute`. */
export function daysAheadIn(zone: string, days: number, hour: number, minute: number): WallClock {
  return shiftDays(wallClockIn(new Date(), zone), days, hour, minute)
}

/** The day `days` after today in Paris, at `hour`:`minute`. */
export const parisDaysAhead = (days: number, hour: number, minute: number) =>
  daysAheadIn(TZ, days, hour, minute)

/** Whether `a` and `b` fall in the same calendar month. */
export const sameMonth = (a: WallClock, b: WallClock) => a.year === b.year && a.month === b.month

/**
 * Two consecutive days of the current month, tomorrow and the day after when the month has room
 * for them, else the two days before today — so the team calendar, which opens on the current
 * month, shows both without paging.
 */
export function twoDaysThisMonth(): [WallClock, WallClock] {
  const today = parisWallClock(new Date())
  const lastDay = new Date(Date.UTC(today.year, today.month, 0)).getUTCDate()
  const first = today.day + 2 <= lastDay ? 1 : -2
  return [shiftDays(today, first, 9, 30), shiftDays(today, first + 1, 8, 15)]
}

const pad = (n: number) => String(n).padStart(2, '0')

/**
 * « 2026-10-10T20:30:00 » — a wall time without offset, as an editor sends a departure: the API
 * reads it in the zone it resolves for the entity (docs/LEDGER_*.md API-60).
 */
export const wallTime = (w: WallClock) =>
  `${w.year}-${pad(w.month)}-${pad(w.day)}T${pad(w.hour)}:${pad(w.minute)}:00`

/**
 * « 2026-10-10T20:30:15 » — `instant` as a wall time in `zone` (the team's, Paris by default), to
 * the second: what a request body carries since contract 11.0.0, whose `EventDateTime` refuses an
 * instant with `Z` or an offset (docs/LEDGER_*.md API-60). An instant read back from a DTO goes
 * through here with that entity's `timezone`.
 */
export function wallTimeOf(instant: Date | string | number, zone: string = TZ): string {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', {
      timeZone: zone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    })
      .formatToParts(new Date(instant))
      .map((part) => [part.type, part.value])
  )
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}`
}

/** « 20:30 ». */
export const clockText = (w: Pick<WallClock, 'hour' | 'minute'>) =>
  `${pad(w.hour)}:${pad(w.minute)}`

/** « 26/09/2026 08:00 » — how the picker's own button shows its value. */
export const pickerText = (w: WallClock) =>
  `${pad(w.day)}/${pad(w.month)}/${w.year} ${pad(w.hour)}:${pad(w.minute)}`

/**
 * « mer. 4 nov. · 09:30 », the year only outside the current one (« mer. 4 nov. 2027 · 09:30 ») —
 * the app's one date-and-time format (docs/BRANDING.md §8.3, docs/LEDGER_*.md WEB-138), never
 * relative: a scheduled publication, a rendezvous line.
 */
export function frenchDateTime(w: WallClock): string {
  const currentYear = parisWallClock(new Date()).year
  const date = new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'UTC',
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    year: w.year === currentYear ? undefined : 'numeric',
  }).format(new Date(Date.UTC(w.year, w.month - 1, w.day, 12)))
  return `${date} · ${pad(w.hour)}:${pad(w.minute)}`
}

/**
 * The same, « Aujourd'hui · 09:30 » and « Demain · 09:30 » for those two days — how a departure
 * line without a day box beside it reads (a trip page's stage cards).
 */
export function frenchDeparture(w: WallClock): string {
  const today = parisWallClock(new Date())
  const tomorrow = shiftDays(today, 1, 0, 0)
  const isDay = (d: WallClock) => d.year === w.year && d.month === w.month && d.day === w.day
  const time = `${pad(w.hour)}:${pad(w.minute)}`
  if (isDay(today)) return `Aujourd'hui · ${time}`
  if (isDay(tomorrow)) return `Demain · ${time}`
  return frenchDateTime(w)
}

/** The name of `month` (1–12) in `locale`: « septembre », « September ». */
export const monthName = (month: number, locale: string) =>
  new Intl.DateTimeFormat(locale, { month: 'long', timeZone: 'UTC' }).format(
    new Date(Date.UTC(2000, month - 1, 15))
  )

/**
 * The open picker dropdown: the one dialog holding a day grid. The day buttons' aria-labels are
 * « D MMMM YYYY », in English today — no DatesProvider, pinned in flow-trips.e2e.ts — so both
 * languages are accepted.
 */
const pickerDropdown = (page: Page) =>
  page.getByRole('dialog').filter({ has: page.getByRole('table') })

/** Opens a DateTimePicker (`field`: its button, found by label) and returns its dropdown, left open. */
export async function openPicker(page: Page, field: Locator): Promise<Locator> {
  await field.click()
  const dropdown = pickerDropdown(page)
  await expect(dropdown).toBeVisible()
  return dropdown
}

/**
 * Sets a Mantine DateTimePicker (`field`: its button) to `when`: opens the dropdown, pages to the
 * month from the one its current value shows, clicks the day, types the time and confirms with
 * Enter — which is what the picker's (unlabelled) check button does too.
 */
export async function pickDateTime(page: Page, field: Locator, when: WallClock) {
  const current = /^\d{2}\/(\d{2})\/(\d{4})/.exec((await field.textContent()) ?? '')
  if (!current) throw new Error(`the picker shows no date: ${await field.textContent()}`)
  const shownMonth = Number(current[2]) * 12 + Number(current[1])
  const months = when.year * 12 + when.month - shownMonth

  const dropdown = await openPicker(page, field)
  const direction = months >= 0 ? 'next' : 'previous'
  // The header's arrows have no accessible name; Mantine tags them with data-direction.
  for (let i = 0; i < Math.abs(months); i++)
    await dropdown.locator(`button[data-direction="${direction}"]`).click()

  const names = ['fr-FR', 'en-US'].map((locale) => monthName(when.month, locale)).join('|')
  await dropdown
    .getByRole('button', { name: new RegExp(`^${when.day} (${names}) ${when.year}$`, 'i') })
    .click()
  const spinbuttons = dropdown.getByRole('spinbutton')
  await expect(spinbuttons).toHaveCount(2)
  await spinbuttons.nth(0).fill(pad(when.hour))
  await spinbuttons.nth(1).fill(pad(when.minute))
  await spinbuttons.nth(1).press('Enter')
  await expect(dropdown).toBeHidden()
  await expect(field).toHaveText(pickerText(when))
}
