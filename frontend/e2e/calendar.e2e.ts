import type { CalendarEventsResponse } from '../src/api/dto'
import { apiGet, type AuthResponse } from './support/api'
import {
  calendarEvent,
  globalCalendarPath,
  openCalendar,
  openCalendarAt,
  teamCalendarPath,
} from './support/calendar'
import { wallTime, parisDaysAhead, type WallClock } from './support/dates'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { calendarTokenOf, fetchFeed, parseIcs } from './support/flow-account'
import { joinGroup, newRide } from './support/rides'
import { hydrated } from './support/ui'

/**
 * The calendars of a signed-in member: the personal one (/calendrier, `CalendarPage`), which merges
 * the rides of every team they belong to and no other, and the team one's ICS feed
 * (`IcsFeedSettings` given a `teamSlug`), whose URL is the account's `teamFeedUrlTemplate` with the
 * team's slug put in and which serves that team alone.
 *
 * flow-account.e2e.ts already covers the personal feed (/calendrier's « URL du flux global »,
 * copy, regenerate); slug-change.e2e.ts a team feed under an old slug. Each test here builds its
 * own teams, owned by the platform admin (the only one who may add a member directly), and its own
 * member.
 */

/** A member of two teams, and a third, public team they are not in; each team has a ride on `day`. */
async function threeTeams(label: string, day: WallClock) {
  const admin = await roleSession('admin')
  const member = await newUser(unique(`Cycliste ${label}`))
  const mine = await newTeam(admin, unique(`Mon équipe ${label}`))
  const alsoMine = await newTeam(admin, unique(`Mon autre équipe ${label}`))
  // Public, and its ride public too: nothing but membership keeps it out of the member's calendar.
  const foreign = await newTeam(admin, unique(`Équipe voisine ${label}`), { visibility: 'PUBLIC' })
  await addMember(admin, mine.slug, member)
  await addMember(admin, alsoMine.slug, member)
  const at = (hour: number) => ({ dateTime: wallTime({ ...day, hour, minute: 0 }) })
  const joined = await newRide(admin, mine.slug, unique('Sortie inscrite'), at(9))
  const other = await newRide(admin, alsoMine.slug, unique('Sortie non inscrite'), at(14))
  const outside = await newRide(admin, foreign.slug, unique('Sortie voisine'), {
    ...at(10),
    visibility: 'PUBLIC',
  })
  // Registered in the first team's ride, in its only group, « Groupe A » (rideRequest).
  await joinGroup(member, mine.slug, joined, 'Groupe A')
  return { member, mine, alsoMine, foreign, joined, other, outside }
}

/** The personal calendar's events between two instants, as `who` reads them. */
const myEvents = async (who: AuthResponse, from: Date, to: Date) =>
  (
    await apiGet<CalendarEventsResponse>(who, '/api/calendar/events', {
      from: from.toISOString(),
      to: to.toISOString(),
    })
  ).events

test.describe('the personal calendar', () => {
  test('/calendrier shows the rides of my teams only, and an event opens its ride', async ({
    page,
  }) => {
    const day = parisDaysAhead(3, 8, 0)
    const { member, mine, alsoMine, joined, other, outside } = await threeTeams('global', day)

    // What the page is fed: both of my teams' rides, the registration on the one I joined.
    const from = new Date(Date.now() - 24 * 3600 * 1000)
    const to = new Date(Date.now() + 10 * 24 * 3600 * 1000)
    const events = await myEvents(member, from, to)
    const titles = events.map((e) => e.title)
    expect(titles).toEqual(expect.arrayContaining([joined.name, other.name]))
    expect(titles).not.toContain(outside.name)
    expect(events.find((e) => e.title === joined.name)).toMatchObject({
      teamSlug: mine.slug,
      registered: true,
      groupName: 'Groupe A',
    })
    expect(events.find((e) => e.title === other.name)).toMatchObject({
      teamSlug: alsoMine.slug,
      registered: false,
    })

    await signIn(page.context(), member)
    await openCalendarAt(page, globalCalendarPath, day)
    const registered = calendarEvent(page, joined.name)
    await expect(registered).toBeVisible()
    await expect(calendarEvent(page, other.name)).toBeVisible()
    // The two rides above, shown, say the day's events are in: the public team's is not among them.
    await expect(calendarEvent(page, outside.name)).toHaveCount(0)

    // An event opens its ride.
    await hydrated(registered)
    await registered.click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${mine.slug}/sorties/${joined.slug}$`))
    await expect(page.getByRole('heading', { level: 2, name: joined.name })).toBeVisible()
  })

  test("each event of /calendrier names its team, and « J'y vais · Groupe A » where I am registered", async ({
    page,
  }) => {
    // Regression (b790fafb): the phone agenda (MobileMonthView, which ignores `renderEventBody`)
    // gets its own event body — before, it showed the title and time only, the team and the
    // registration being left to a hover tooltip a touch screen never shows.
    const day = parisDaysAhead(3, 8, 0)
    const { member, mine, alsoMine, joined, other } = await threeTeams('détails', day)

    await signIn(page.context(), member)
    await openCalendarAt(page, globalCalendarPath, day)
    const registered = calendarEvent(page, joined.name)
    const notRegistered = calendarEvent(page, other.name)
    await expect(registered).toBeVisible()
    await expect(notRegistered).toBeVisible()

    await expect(registered).toContainText(mine.name)
    await expect(registered).toContainText("J'y vais · Groupe A")
    await expect(notRegistered).toContainText(alsoMine.name)
    await expect(notRegistered).not.toContainText("J'y vais")
  })
})

test.describe('the team calendar feed', () => {
  test("the team calendar hands out the team's own feed URL, which serves that team's rides and no other's", async ({
    page,
  }) => {
    const day = parisDaysAhead(4, 8, 0)
    const { member, mine, foreign, joined, other, outside } = await threeTeams('ics', day)
    const token = await calendarTokenOf(member)
    expect(token.teamFeedUrlTemplate, 'precondition: a template to fill').toContain('{teamSlug}')
    const expected = token.teamFeedUrlTemplate.replace('{teamSlug}', mine.slug)

    await signIn(page.context(), member)
    await openCalendar(page, mine.slug, day)
    const main = page.getByRole('main')
    await expect(calendarEvent(page, joined.name)).toBeVisible()
    await expect(
      main.getByText('Abonnez-vous au calendrier de cette équipe', { exact: false })
    ).toBeVisible()
    // The team's feed, not the global one: its own label, the slug in place of the placeholder.
    await expect(main.getByRole('textbox', { name: 'URL du flux global' })).toHaveCount(0)
    const field = main.getByRole('textbox', { name: "URL du flux d'équipe" })
    await expect(field).toHaveValue(expected)
    const url = await field.inputValue()
    expect(url).not.toContain('{')
    expect(new URL(url).pathname).toBe(`/api/teams/${mine.slug}/calendar/ics`)
    await expect(main.getByRole('link', { name: "S'abonner" })).toHaveAttribute(
      'href',
      url.replace(/^https?:\/\//, 'webcal://')
    )

    // A calendar application fetches it with nothing but the URL: this team's ride, and neither the
    // member's other team's nor the public team's.
    const feed = await fetchFeed(url)
    expect(feed.status).toBe(200)
    expect(feed.contentType).toMatch(/^text\/calendar\b/)
    const summaries = parseIcs(feed.body).events.map((e) => e.SUMMARY)
    expect(summaries).toContain(joined.name)
    expect(summaries).not.toContain(other.name)
    expect(summaries).not.toContain(outside.name)

    // The global feed of the same account does carry the other team's ride: the team feed's
    // filter is the team, not the account.
    const global = parseIcs((await fetchFeed(token.globalFeedUrl)).body).events.map(
      (e) => e.SUMMARY
    )
    expect(global).toEqual(expect.arrayContaining([joined.name, other.name]))
    expect(global).not.toContain(outside.name)

    // The same token on a team the member is not in: refused, public team or not.
    const refused = await fetchFeed(token.teamFeedUrlTemplate.replace('{teamSlug}', foreign.slug))
    expect(refused.status).toBe(403)
    expect(refused.body).not.toContain(outside.name)
  })

  test('a non-member is sent back from the team calendar, and gets no feed URL for it', async ({
    page,
  }) => {
    const day = parisDaysAhead(4, 8, 0)
    const { member, foreign } = await threeTeams('outsider', day)
    await signIn(page.context(), member)
    await page.goto(teamCalendarPath(foreign.slug))
    // To the agenda's lists, which a non-member may read (WEB-68).
    await expect(page).toHaveURL(new RegExp(`/equipes/${foreign.slug}/agenda$`))
    await expect(
      page.getByRole('main').getByRole('textbox', { name: "URL du flux d'équipe" })
    ).toHaveCount(0)
  })
})
