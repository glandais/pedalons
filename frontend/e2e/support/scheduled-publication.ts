import type { Locator, Page } from '@playwright/test'
import type { Status } from '../../src/api/dto'
import {
  wallTimeOf,
  monthName,
  openPicker,
  parisWallClock,
  pickerText,
  type WallClock,
} from './dates'
import { expect } from './fixtures'

/**
 * Scheduled publication (« Publication programmée ») of posts and trips — flow-posts.e2e.ts and
 * flow-trips.e2e.ts; flow-rides.e2e.ts has its own copy of the picker driver for rides.
 *
 * The stack's clock cannot be moved, so a test schedules a date in the editor, then saves the
 * publication again through the API with a `publishAt` already past: the backend keeps it as it is,
 * and `PublicationPublishScheduler` (every minute) publishes it on its next run — exactly what
 * happens when the date is reached.
 */

/** A scheduler run (one a minute) and a slow tick — as flow-rides.e2e.ts waits for a ride. */
export const AUTO_PUBLISH_TIMEOUT_MS = 100_000

/**
 * Sets an empty DateTimePicker (`field`: its button) to `when` — dates.ts pickDateTime pages from
 * the value the field shows, and an unset « Publication programmée » shows none: its dropdown opens
 * on today's month.
 */
export async function pickIntoEmptyPicker(page: Page, field: Locator, when: WallClock) {
  await expect(field, 'the picker starts empty').toHaveText('')
  const today = parisWallClock(new Date())
  const months = when.year * 12 + when.month - (today.year * 12 + today.month)
  const dropdown = await openPicker(page, field)
  for (let i = 0; i < months; i++) await dropdown.locator('button[data-direction="next"]').click()
  const names = ['fr-FR', 'en-US'].map((locale) => monthName(when.month, locale)).join('|')
  await dropdown
    .getByRole('button', { name: new RegExp(`^${when.day} (${names}) ${when.year}$`, 'i') })
    .click()
  const spinbuttons = dropdown.getByRole('spinbutton')
  await expect(spinbuttons).toHaveCount(2)
  await spinbuttons.nth(0).fill(String(when.hour).padStart(2, '0'))
  await spinbuttons.nth(1).fill(String(when.minute).padStart(2, '0'))
  await spinbuttons.nth(1).press('Enter')
  await expect(dropdown).toBeHidden()
  await expect(field).toHaveText(pickerText(when))
}

/**
 * The instant a minute ago, to the second: a `publishAt` the scheduler's next run takes. In the hour
 * the clocks go back, its Paris wall time names two instants and the API takes the earlier one
 * (`ZonedDateTime`'s rule) — still past, so that is the one returned.
 */
export const pastPublishInstant = () => {
  const due = Math.floor((Date.now() - 60_000) / 1000) * 1000
  const anHourEarlier = due - 3_600_000
  return new Date(wallTimeOf(anHourEarlier) === wallTimeOf(due) ? anHourEarlier : due).toISOString()
}

/** `pastPublishInstant` as the request carries it: a Paris wall time (contract 11.0.0). */
export const pastPublishAt = () => wallTimeOf(pastPublishInstant())

/** Waits until `read` says the publication was published by the scheduler. */
export async function waitForAutoPublish(read: () => Promise<{ status: Status } | null>) {
  await expect
    .poll(async () => (await read())?.status, {
      message: 'the scheduler publishes it',
      timeout: AUTO_PUBLISH_TIMEOUT_MS,
      intervals: [2_000],
    })
    .toBe('PUBLISHED')
}
