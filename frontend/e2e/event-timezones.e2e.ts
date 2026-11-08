import type { Page } from '@playwright/test'
import {
  clockText,
  daysAheadIn,
  frenchLongDay,
  instantIn,
  pickDateTime,
  pickerText,
  wallClockIn,
  wallTime,
  type WallClock,
} from './support/dates'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { departureBlock, groupCard, newRide, openRide, readRide, ridePath } from './support/rides'
import { rawDocument, sessionCookie, ssrOutlet } from './support/ssr'
import { hydrated, watchHydration } from './support/ui'

/**
 * A ride reads in its own zone wherever its reader is (docs/LEDGER_*.md API-60, plan §11): the
 * organiser's « 20:30 » stays 20:30 from Tokyo, followed by « heure de Paris (dim. 03:30 chez vous) »
 * — the reader's day only when it is not the ride's. The mention is about the reader's clock, which
 * the server does not know: absent from the server render and from the hydration render, it comes
 * with the render after. An editor types wall times in the ride's zone, and gets them back as typed.
 *
 * The suite runs in Europe/Paris (playwright.config.ts); the Tokyo reader overrides it per block.
 */

const PARIS = 'Europe/Paris'
const TOKYO = 'Asia/Tokyo'

const main = (page: Page) => page.getByRole('main')

/** An instant in one spelling: the API drops the milliseconds `toISOString` writes. */
const iso = (instant: string | undefined) => instant && new Date(instant).toISOString()

/** « heure de Paris (dim. 03:30 chez vous) », as `rendezvousMention` words it in French. */
function mention(instant: string, zone: string, city: string, readerZone: string): string {
  const entity = wallClockIn(instant, zone)
  const reader = wallClockIn(instant, readerZone)
  const sameDay =
    entity.year === reader.year && entity.month === reader.month && entity.day === reader.day
  const day = sameDay
    ? ''
    : `${new Intl.DateTimeFormat('fr-FR', { weekday: 'short', timeZone: readerZone }).format(new Date(instant))} `
  return `heure de ${city} (${day}${clockText(reader)} chez vous)`
}

/**
 * A team in `zone` with an organizer and a member, and a ride without a place — its zone is the
 * team's — at `departure` on the team's clock. « Groupe A » leaves with the ride, the second group
 * at `groupTime` of its own.
 */
async function rideAbroad(label: string, zone: string, departure: WallClock, groupTime: string) {
  const owner = await roleSession('admin')
  const team = await newTeam(owner, unique(`Fuseaux ${label}`), { timezone: zone })
  const organizer = await newUser(unique('Organisatrice'))
  const member = await newUser(unique('Membre'))
  await addMember(owner, team.slug, organizer, 'ORGANIZER')
  await addMember(owner, team.slug, member)
  const withRide = unique('Groupe avec la sortie')
  const ownTime = unique('Groupe à son heure')
  const ride = await newRide(organizer, team.slug, unique(`Sortie ${label}`), {
    dateTime: wallTime(departure),
    groups: [{ name: withRide }, { name: ownTime, time: groupTime }],
  })
  return { team, organizer, member, ride, withRide, ownTime }
}

test.describe('a Paris team read from Tokyo', () => {
  test.use({ timezoneId: TOKYO })

  // 20:30 in Paris is the next morning in Tokyo: the mention names the reader's day.
  const departure = daysAheadIn(PARIS, 3, 20, 30)

  test('the ride keeps its Paris time, and the mention comes after hydration', async ({ page }) => {
    const { team, member, ride, withRide, ownTime } = await rideAbroad(
      'Paris',
      PARIS,
      departure,
      '21:15'
    )
    expect(ride.timezone).toBe(PARIS)
    expect(iso(ride.dateTime)).toBe(instantIn(departure, PARIS))
    const groupStart = instantIn({ ...departure, hour: 21, minute: 15 }, PARIS)
    expect(iso(ride.groups.find((group) => group.name === ownTime)?.startAt)).toBe(groupStart)

    const rideMention = mention(ride.dateTime, PARIS, 'Paris', TOKYO)
    expect(rideMention, 'the departure is another day in Tokyo').toMatch(/\(\S+\. \d{2}:\d{2} /)

    // The server knows nothing of the reader's clock: the Paris time, and no mention.
    const document = await rawDocument(ridePath(team.slug, ride.slug), {
      cookie: sessionCookie(member),
    })
    expect(document.status).toBe(200)
    const markup = ssrOutlet(document.html)
    expect(markup).toContain(`Départ ${clockText(departure)}`)
    expect(markup).toContain(frenchLongDay(departure))
    expect(markup).not.toContain('chez vous')

    // The browser says it, once hydrated, without a mismatch on the way.
    const watch = await watchHydration(page)
    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)
    const block = departureBlock(page)
    await expect(block.getByText(`Départ ${clockText(departure)}`, { exact: true })).toBeVisible()
    await expect(block).toContainText(`${frenchLongDay(departure)}`)
    await expect(block).toContainText(` · ${rideMention}`)
    expect(watch.hydrationErrors).toEqual([])
    expect(watch.pageErrors).toEqual([])

    // A group shows a time only when it leaves at its own, in the ride's zone, with its mention.
    const own = groupCard(page, ownTime)
    await expect(own.getByText('Départ 21:15', { exact: true })).toBeVisible()
    await expect(
      own.getByRole('img', { name: mention(groupStart, PARIS, 'Paris', TOKYO), exact: true })
    ).toBeVisible()
    const withTheRide = groupCard(page, withRide)
    await expect(withTheRide).toBeVisible()
    await expect(withTheRide.getByTestId('group-own-time')).toHaveCount(0)
    await expect(withTheRide.getByRole('img', { name: /chez vous/ })).toHaveCount(0)
  })

  test('the editor types Paris wall times and gets them back as typed', async ({ page }) => {
    const { team, organizer, ride, ownTime } = await rideAbroad(
      'éditeur',
      PARIS,
      departure,
      '21:15'
    )

    await signIn(page.context(), organizer)
    await page.goto(`${ridePath(team.slug, ride.slug)}/modifier`)
    await expect(
      main(page).getByRole('heading', { name: 'Modifier la sortie', level: 1 })
    ).toBeVisible()
    const field = main(page).getByRole('button', { name: 'Départ' })
    // The Paris clock, not Tokyo's, labelled with its zone.
    await expect(field).toHaveText(pickerText(departure))
    await expect(field).toHaveAccessibleDescription('heure de Paris')

    const moved = { ...departure, hour: 19, minute: 45 }
    await hydrated(field)
    await pickDateTime(page, field, moved)
    await main(page).getByRole('button', { name: 'Enregistrer' }).click()
    await expect(page).toHaveURL(new RegExp(`/sorties/${ride.slug}$`))
    const block = departureBlock(page)
    await expect(block.getByText(`Départ ${clockText(moved)}`, { exact: true })).toBeVisible()
    await expect(block).toContainText(`${frenchLongDay(moved)}`)
    await expect(block).toContainText(' · heure de Paris (')

    const saved = await readRide(organizer, team.slug, ride.slug)
    expect(iso(saved.dateTime)).toBe(instantIn(moved, PARIS))
    // The group's own time is a Paris wall time too: saving from Tokyo did not shift it.
    expect(iso(saved.groups.find((group) => group.name === ownTime)?.startAt)).toBe(
      instantIn({ ...moved, hour: 21, minute: 15 }, PARIS)
    )
  })
})

test.describe('a Tokyo team read from Paris', () => {
  // No browser setting: the suite already runs in Europe/Paris.
  const departure = daysAheadIn(TOKYO, 3, 8, 0)

  test('the ride keeps its Tokyo time, with the Paris equivalent', async ({ page }) => {
    const { team, member, ride, ownTime } = await rideAbroad('Tokyo', TOKYO, departure, '09:30')
    expect(ride.timezone).toBe(TOKYO)
    expect(iso(ride.dateTime)).toBe(instantIn(departure, TOKYO))

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)
    const block = departureBlock(page)
    await expect(block.getByText(`Départ ${clockText(departure)}`, { exact: true })).toBeVisible()
    await expect(block).toContainText(`${frenchLongDay(departure)}`)
    await expect(block).toContainText(` · ${mention(ride.dateTime, TOKYO, 'Tokyo', PARIS)}`)

    const groupStart = instantIn({ ...departure, hour: 9, minute: 30 }, TOKYO)
    const own = groupCard(page, ownTime)
    await expect(own.getByText('Départ 09:30', { exact: true })).toBeVisible()
    await expect(
      own.getByRole('img', { name: mention(groupStart, TOKYO, 'Tokyo', PARIS), exact: true })
    ).toBeVisible()
  })
})
