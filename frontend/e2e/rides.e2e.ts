import type { Page } from '@playwright/test'
import { ApiError } from './support/api'
import { calendarEvent } from './support/calendar'
import {
  monthName,
  parisDaysAhead,
  parisWallClock,
  type WallClock,
  wallTime,
  wallTimeOf,
} from './support/dates'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import {
  groupCard,
  groupId,
  joinGroup,
  newRide,
  openRide,
  postComments,
  readRide,
  ridePath,
} from './support/rides'
import { entityCard, homeFeed, hydrated, mainNavLink, toasts } from './support/ui'

/**
 * The ride detail page (`RideDetailPage` + `RideGroupCard` + `CommentSection`), against the real
 * backend: the first page of comments, the group leader invariant, registration to a group, a
 * past ride, and moving from one group to another.
 *
 * Each test builds its own team (owned by the platform admin: only a platform admin may add a member
 * directly, an owner gets TEAM_ADD_MEMBER_NOT_ALLOWED), its own members and its own ride.
 */

/** A team with an organizer (who creates the rides) and a plain member (who looks). */
async function ridingTeam(label: string) {
  const owner = await roleSession('admin')
  const team = await newTeam(owner, unique(`Rides ${label}`))
  const organizer = await newUser(unique('Créatrice'))
  const member = await newUser(unique('Membre'))
  await addMember(owner, team.slug, organizer, 'ORGANIZER')
  await addMember(owner, team.slug, member)
  return { owner, team, organizer, member }
}

test.describe('comments', () => {
  test('a ride with more than 20 comments loads only 20 at first render', async ({ page }) => {
    const { team, organizer, member } = await ridingTeam('comments')
    const ride = await newRide(organizer, team.slug, unique('Sortie bavarde'), {
      groups: [{ name: unique('Groupe unique') }],
    })
    const contents = Array.from(
      { length: 25 },
      (_, i) => `Commentaire e2e n°${String(i + 1).padStart(2, '0')}`
    )
    await postComments(organizer, team.slug, ride.slug, contents)

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)

    // The heading counts every comment; only the first page of them is in the DOM.
    await expect(page.getByRole('heading', { name: 'Commentaires (25)' })).toBeVisible()
    const rendered = page.getByText(/^Commentaire e2e n°\d{2}$/)
    await expect(rendered).toHaveCount(20)
    // Newest first: the five oldest are the ones left out.
    await expect(page.getByText('Commentaire e2e n°25', { exact: true })).toBeVisible()
    await expect(page.getByText('Commentaire e2e n°06', { exact: true })).toBeVisible()
    await expect(page.getByText('Commentaire e2e n°05', { exact: true })).toHaveCount(0)

    // The rest is one click away, and then the button goes.
    const loadMore = page.getByRole('button', { name: 'Charger plus de commentaires' })
    await hydrated(loadMore)
    await loadMore.click()
    await expect(rendered).toHaveCount(25)
    await expect(page.getByText('Commentaire e2e n°01', { exact: true })).toBeVisible()
    await expect(loadMore).toHaveCount(0)
  })
})

test.describe('group leader', () => {
  test('no designated leader: no badge, and never the ride creator in its place', async ({
    page,
  }) => {
    const { team, organizer, member } = await ridingTeam('no-leader')
    const first = unique('Groupe A')
    const second = unique('Groupe B')
    const ride = await newRide(organizer, team.slug, unique('Sortie sans meneur'), {
      groups: [{ name: first }, { name: second }],
    })
    expect(ride.groups.map((g) => g.leader)).toEqual([undefined, undefined])

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)

    for (const name of [first, second]) {
      const card = groupCard(page, name)
      await expect(card).toBeVisible()
      await expect(card.getByText('Meneur', { exact: true })).toHaveCount(0)
      await expect(card.getByText(organizer.user.displayName)).toHaveCount(0)
    }
    await expect(page.getByText('Meneur', { exact: true })).toHaveCount(0)
  })

  test('a designated leader is shown on their group only', async ({ page }) => {
    const { owner, team, organizer, member } = await ridingTeam('leader')
    const leader = await newUser(unique('Meneuse'))
    await addMember(owner, team.slug, leader)
    const led = unique('Groupe mené')
    const free = unique('Groupe libre')
    const ride = await newRide(organizer, team.slug, unique('Sortie menée'), {
      groups: [{ name: led, leaderId: leader.user.id }, { name: free }],
    })

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)

    const ledCard = groupCard(page, led)
    await expect(ledCard.getByText('Meneur', { exact: true })).toBeVisible()
    await expect(ledCard.getByText(leader.user.displayName, { exact: true })).toBeVisible()
    await expect(ledCard.getByText(organizer.user.displayName)).toHaveCount(0)

    const freeCard = groupCard(page, free)
    await expect(freeCard).toBeVisible()
    await expect(freeCard.getByText('Meneur', { exact: true })).toHaveCount(0)
    await expect(freeCard.getByText(leader.user.displayName)).toHaveCount(0)
    await expect(freeCard.getByText(organizer.user.displayName)).toHaveCount(0)
  })
})

test.describe('registration', () => {
  test('register to a group, see it, unregister', async ({ page }) => {
    const { team, organizer, member } = await ridingTeam('register')
    const name = unique('Groupe loisir')
    const ride = await newRide(organizer, team.slug, unique('Sortie à rejoindre'), {
      groups: [{ name, maxParticipants: 5 }],
    })

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)

    const card = groupCard(page, name)
    await expect(card.getByText('0/5 participants')).toBeVisible()
    await expect(card.getByText('Inscrit', { exact: true })).toHaveCount(0)
    await hydrated(card.getByRole('button', { name: 'Rejoindre' }))
    await card.getByRole('button', { name: 'Rejoindre' }).click()

    await expect(card.getByText('Inscrit', { exact: true })).toBeVisible()
    await expect(card.getByRole('button', { name: 'Quitter' })).toBeEnabled()
    await expect(card.getByText('1/5 participants')).toBeVisible()

    // It is the server's state, not only the optimistic cache.
    await page.reload()
    await openRide(page, team.slug, ride)
    await expect(card.getByText('Inscrit', { exact: true })).toBeVisible()
    await hydrated(card.getByRole('button', { name: 'Quitter' }))
    await card.getByRole('button', { name: 'Quitter' }).click()

    await expect(card.getByRole('button', { name: 'Rejoindre' })).toBeEnabled()
    await expect(card.getByText('Inscrit', { exact: true })).toHaveCount(0)
    await expect(card.getByText('0/5 participants')).toBeVisible()

    await page.reload()
    await openRide(page, team.slug, ride)
    await expect(card.getByRole('button', { name: 'Rejoindre' })).toBeVisible()
    await expect(card.getByText('Inscrit', { exact: true })).toHaveCount(0)
  })

  test('a full group shows « Complet » and offers no way to join', async ({ page }) => {
    const { owner, team, organizer, member } = await ridingTeam('full')
    const other = await newUser(unique('Premier inscrit'))
    await addMember(owner, team.slug, other)
    const full = unique('Groupe plein')
    const open = unique('Groupe ouvert')
    const ride = await newRide(organizer, team.slug, unique('Sortie presque pleine'), {
      groups: [
        { name: full, maxParticipants: 1 },
        { name: open, maxParticipants: 10 },
      ],
    })
    await joinGroup(other, team.slug, ride, full)

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)

    const fullCard = groupCard(page, full)
    await expect(fullCard.getByText('Complet', { exact: true })).toBeVisible()
    await expect(fullCard.getByText('1/1 participants')).toBeVisible()
    await expect(fullCard.getByRole('button', { name: 'Rejoindre' })).toHaveCount(0)
    // The other group is still open — which also proves the page offers joining at all.
    await expect(groupCard(page, open).getByRole('button', { name: 'Rejoindre' })).toBeEnabled()
  })

  test('a ride whose only group is full still says « Complet »', async ({ page }) => {
    // RideGroupCard used to render « Complet » only inside `(canJoin || isJoined)`, and canJoin is
    // false once the whole ride is full — the capacity state vanished exactly then (fixed
    // 2026-09-25).
    const { owner, team, organizer, member } = await ridingTeam('all-full')
    const other = await newUser(unique('Premier inscrit'))
    await addMember(owner, team.slug, other)
    const full = unique('Groupe plein')
    const ride = await newRide(organizer, team.slug, unique('Sortie pleine'), {
      groups: [{ name: full, maxParticipants: 1 }],
    })
    await joinGroup(other, team.slug, ride, full)

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)

    // Preconditions: the group is on the page, and full.
    const card = groupCard(page, full)
    await expect(card, 'precondition: the group card is rendered').toBeVisible()
    await expect(
      card.getByText('1/1 participants'),
      'precondition: the only seat is taken'
    ).toBeVisible()
    await expect(
      card.getByRole('button', { name: 'Rejoindre' }),
      'precondition: a full group offers no join'
    ).toHaveCount(0)
    await expect(card.getByText('Complet', { exact: true })).toBeVisible()
  })

  test('a GROUP_FULL answer rolls back and is reported on that group', async ({ page }) => {
    const { owner, team, organizer, member } = await ridingTeam('race')
    const other = await newUser(unique('Plus rapide'))
    await addMember(owner, team.slug, other)
    const contested = unique('Groupe disputé')
    const spare = unique('Groupe de réserve')
    const ride = await newRide(organizer, team.slug, unique('Sortie disputée'), {
      groups: [
        { name: contested, maxParticipants: 1 },
        { name: spare, maxParticipants: 10 },
      ],
    })

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)
    const card = groupCard(page, contested)
    const join = card.getByRole('button', { name: 'Rejoindre' })
    await expect(join).toBeEnabled()
    await hydrated(join)

    // Someone else takes the last seat while the page is open: the join now answers GROUP_FULL.
    await joinGroup(other, team.slug, ride, contested)
    const answer = page.waitForResponse(
      (r) => r.url().includes(`/rides/${ride.slug}/groups/`) && r.request().method() === 'POST'
    )
    await join.click()
    const response = await answer
    expect(response.status()).toBe(409)
    expect(((await response.json()) as { code?: string }).code).toBe('GROUP_FULL')

    // The failure is written in the card of the group that refused, not in the other one...
    await expect(card.getByRole('alert').filter({ hasText: 'Ce groupe est complet' })).toBeVisible()
    await expect(groupCard(page, spare).getByText('Ce groupe est complet')).toHaveCount(0)
    // ...the optimistic registration is undone, and the refetched group says it is full.
    await expect(card.getByText('Inscrit', { exact: true })).toHaveCount(0)
    await expect(card.getByText('Complet', { exact: true })).toBeVisible()
    await expect(card.getByText('1/1 participants')).toBeVisible()
  })
})

test.describe('a past ride', () => {
  test('a ride of yesterday says « Terminée » and offers no « Rejoindre » in any group', async ({
    page,
  }) => {
    const { team, organizer, member } = await ridingTeam('past')
    const first = unique('Groupe A')
    const second = unique('Groupe B')
    const ride = await newRide(organizer, team.slug, unique('Sortie passée'), {
      dateTime: wallTimeOf(Date.now() - 24 * 3600 * 1000),
      groups: [
        { name: first, maxParticipants: 10 },
        { name: second, maxParticipants: 10 },
      ],
    })
    expect(ride.status, 'precondition: published, so only its date stops the join').toBe(
      'PUBLISHED'
    )

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)

    const header = page.getByRole('main').getByRole('heading', { level: 2, name: ride.name })
    await expect(header).toBeVisible()
    await expect(page.getByRole('main').getByText('Terminée', { exact: true })).toBeVisible()
    await expect(page.getByRole('main').getByText('Publié', { exact: true })).toBeVisible()
    for (const name of [first, second]) {
      const card = groupCard(page, name)
      await expect(card.getByText('0/10 participants')).toBeVisible()
      await expect(card.getByRole('button', { name: 'Rejoindre' })).toHaveCount(0)
      await expect(card.getByText('Complet', { exact: true })).toHaveCount(0)
    }
  })

  test('the API refuses a registration to a ride of yesterday', async () => {
    // Regression (80670273): RideService.joinGroup refuses a ride whose dateTime is past (409
    // RIDE_PAST) — before, only the clients withheld « Rejoindre », and the API registered.
    const { team, organizer, member } = await ridingTeam('past-api')
    const name = unique('Groupe A')
    const ride = await newRide(organizer, team.slug, unique('Sortie passée'), {
      dateTime: wallTimeOf(Date.now() - 24 * 3600 * 1000),
      groups: [{ name }],
    })
    const answer = await joinGroup(member, team.slug, ride, name).then(
      () => undefined,
      (error: unknown) => error
    )
    expect(answer, 'the join is refused').toBeInstanceOf(ApiError)
    expect((answer as ApiError).status).toBe(409)
    expect((answer as ApiError).code).toBe('RIDE_PAST')
    expect((await readRide(member, team.slug, ride.slug)).registered).toBe(false)
  })

  test('an upcoming ride is not « Terminée »', async ({ page }) => {
    // The counterpart of the test above: the badge follows the date, not the status.
    const { team, organizer, member } = await ridingTeam('upcoming')
    const name = unique('Groupe A')
    const ride = await newRide(organizer, team.slug, unique('Sortie à venir'), {
      groups: [{ name }],
    })
    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)
    await expect(groupCard(page, name).getByRole('button', { name: 'Rejoindre' })).toBeVisible()
    await expect(page.getByRole('main').getByText('Terminée', { exact: true })).toHaveCount(0)
  })
})

test.describe('changing group', () => {
  test('registered in one group: no « Rejoindre » on the others, the API refuses a second group, and leaving frees the member to join another', async ({
    page,
  }) => {
    const { team, organizer, member } = await ridingTeam('switch')
    const first = unique('Groupe A')
    const second = unique('Groupe B')
    const ride = await newRide(organizer, team.slug, unique('Sortie à deux groupes'), {
      groups: [
        { name: first, maxParticipants: 10 },
        { name: second, maxParticipants: 10 },
      ],
    })
    await joinGroup(member, team.slug, ride, first)

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)
    const firstCard = groupCard(page, first)
    const secondCard = groupCard(page, second)
    await expect(firstCard.getByText('Inscrit', { exact: true })).toBeVisible()
    await expect(firstCard.getByRole('button', { name: 'Quitter' })).toBeEnabled()
    await expect(firstCard.getByText('1/10 participants')).toBeVisible()
    await expect(secondCard.getByText('0/10 participants')).toBeVisible()
    await expect(secondCard.getByRole('button', { name: 'Rejoindre' })).toHaveCount(0)
    await expect(secondCard.getByText('Inscrit', { exact: true })).toHaveCount(0)

    // The page is not the only guard: the API refuses a second registration on the same ride.
    const refused = await joinGroup(member, team.slug, ride, second).then(
      () => undefined,
      (error: unknown) => error
    )
    expect(refused).toBeInstanceOf(ApiError)
    expect((refused as ApiError).status).toBe(409)
    expect((refused as ApiError).code).toBe('ALREADY_REGISTERED')

    // Leave A: B becomes joinable, and joining it moves the member there.
    const leave = firstCard.getByRole('button', { name: 'Quitter' })
    await hydrated(leave)
    await leave.click()
    await expect(firstCard.getByText('Inscrit', { exact: true })).toHaveCount(0)
    await expect(firstCard.getByText('0/10 participants')).toBeVisible()
    const join = secondCard.getByRole('button', { name: 'Rejoindre' })
    await expect(join).toBeEnabled()
    // The card says « Inscrit » optimistically, before the server has answered: the API read below
    // waits for that answer, or it can go out while the join is still in flight.
    const joined = page.waitForResponse(
      (r) =>
        r.request().method() === 'POST' && r.url().endsWith(`/groups/${groupId(ride, second)}/join`)
    )
    await join.click()
    expect((await joined).ok(), 'the server accepted the join').toBe(true)
    await expect(secondCard.getByText('Inscrit', { exact: true })).toBeVisible()
    await expect(secondCard.getByText('1/10 participants')).toBeVisible()
    await expect(firstCard.getByRole('button', { name: 'Rejoindre' })).toHaveCount(0)

    const after = await readRide(member, team.slug, ride.slug)
    expect(after.registered).toBe(true)
    expect(after.registeredGroupId).toBe(groupId(ride, second))
    expect(after.groups.map((g) => [g.name, g.countParticipants])).toEqual([
      [first, 0],
      [second, 1],
    ])

    // The server's state, not only the optimistic cache.
    await page.reload()
    await openRide(page, team.slug, ride)
    await expect(secondCard.getByText('Inscrit', { exact: true })).toBeVisible()
    await expect(firstCard.getByRole('button', { name: 'Rejoindre' })).toHaveCount(0)
  })
})

/**
 * Leaving a ride refreshes everything that shows the registration, wherever the member left from:
 * the home page's « Ma prochaine sortie », the « Inscrit » badge of the feed cards, the « Je
 * participe » scope and the calendars (lib/rideRegistration.ts invalidateRideRegistration).
 * Regression (11602d48): « Se désinscrire » on the home card only refreshed « Ma prochaine
 * sortie », « Quitter » on the ride page only the ride — the rest stayed as it was until a reload,
 * the cache holding them fresh for three to five minutes (lib/queryClient.ts:11,
 * CalendarPage.tsx:20).
 *
 * Every step after the first `goto` is an in-app navigation (links, history), so what the page
 * shows comes from the client's cache, not from a new server render.
 */
test.describe('leaving a ride, seen from the home page and the calendar', () => {
  const homePath = (rideName: string) => `/?q=${encodeURIComponent(rideName)}`
  const nextRideHeading = (page: Page) =>
    page.getByRole('main').getByRole('heading', { name: 'Ma prochaine sortie' })
  /** « Ma prochaine sortie »: the heading's box, which holds the card (not a link). */
  const nextRideCard = (page: Page) => nextRideHeading(page).locator('xpath=..')
  /** The section keeps its heading once nothing is booked: its empty state says so. */
  const nextRideEmpty = (page: Page) =>
    page.getByRole('main').getByRole('heading', { name: 'Aucune sortie à venir' })
  /**
   * The ride's card in the home feed: NextRideCard is no link, and the « Cette semaine » rows,
   * which are, sit outside the feed's region.
   */
  const feedCard = (page: Page, rideName: string) => entityCard(homeFeed(page), rideName)

  async function scope(page: Page, label: 'Tout' | 'Je participe') {
    const control = page.getByRole('radiogroup', { name: 'Portée du fil' })
    await hydrated(control.getByRole('radio', { name: label }))
    await control.getByText(label, { exact: true }).click()
  }

  /**
   * Shows `day` on the personal calendar the page is already on — calendar.ts openCalendarAt
   * without its `goto`, which would be a fresh server render.
   */
  async function showCalendarDay(page: Page, day: WallClock) {
    const main = page.getByRole('main')
    await expect(page).toHaveURL(/\/calendrier$/)
    await expect(main.getByRole('heading', { name: 'Calendrier', level: 2 })).toBeVisible()
    const today = parisWallClock(new Date())
    const monthsAhead = day.year * 12 + day.month - (today.year * 12 + today.month)
    const visibleButton = (name: string) =>
      main.getByRole('button', { name, exact: true }).filter({ visible: true })
    if (test.info().project.use.isMobile) {
      if (monthsAhead > 0) {
        await hydrated(visibleButton(String(day.year)))
        await visibleButton(String(day.year)).click()
        await visibleButton(monthName(day.month, 'fr-FR')).click()
      }
      const dayButton = visibleButton(`${monthName(day.month, 'fr-FR')} ${day.day}, ${day.year}`)
      await hydrated(dayButton)
      await dayButton.click()
    } else {
      for (let i = 0; i < monthsAhead; i++) {
        await hydrated(visibleButton('Suivant'))
        await visibleButton('Suivant').click()
      }
    }
  }

  /**
   * From a home page, the « Calendrier » link of the main navigation — the header's on desktop, the
   * burger's drawer on mobile — then `day`.
   */
  async function toCalendar(page: Page, day: WallClock) {
    const link = await mainNavLink(page, 'Calendrier')
    await link.click()
    await showCalendarDay(page, day)
  }

  /** A member registered in the only group of a ride two days ahead. */
  async function registered(label: string) {
    const { team, organizer, member } = await ridingTeam(label)
    const day = parisDaysAhead(2, 10, 0)
    const group = unique('Groupe A')
    const ride = await newRide(organizer, team.slug, unique('Sortie prochaine'), {
      dateTime: wallTime(day),
      groups: [{ name: group, maxParticipants: 10 }],
    })
    await joinGroup(member, team.slug, ride, group)
    return { team, member, ride, group, day }
  }

  test('« Se désinscrire » on « Ma prochaine sortie »: the card goes, and the feed badge, « Je participe » and the calendar follow without a reload', async ({
    page,
  }) => {
    const { team, member, ride, group, day } = await registered('next-ride')
    await signIn(page.context(), member)
    await page.goto(homePath(ride.name))
    await expect(nextRideCard(page)).toContainText(ride.name)
    await expect(feedCard(page, ride.name)).toContainText('Inscrit')

    // The calendar and the « Je participe » feed are read once, so the leave has a cache to
    // refresh.
    await toCalendar(page, day)
    await expect(calendarEvent(page, ride.name)).toContainText(`Inscrit · ${group}`)
    await page.goBack()
    await expect(nextRideCard(page)).toContainText(ride.name)
    await scope(page, 'Je participe')
    await expect(feedCard(page, ride.name)).toContainText('Inscrit')

    // --- Leave from the home card.
    const leave = nextRideCard(page).getByRole('button', { name: 'Se désinscrire' })
    await hydrated(leave)
    await leave.click()
    const confirm = page.getByRole('dialog', { name: 'Se désinscrire de la sortie ?' })
    await expect(confirm).toContainText(ride.name)
    await confirm.getByRole('button', { name: 'Se désinscrire' }).click()
    await expect(
      toasts(page).filter({ hasText: 'Désinscription de la sortie confirmée' })
    ).toBeVisible()
    await expect(nextRideEmpty(page)).toBeVisible()
    expect((await readRide(member, team.slug, ride.slug)).registered).toBe(false)

    // « Je participe » no longer lists it...
    await expect(feedCard(page, ride.name)).toHaveCount(0)
    await expect(
      page.getByRole('main').getByRole('heading', { name: 'Aucune publication trouvée' })
    ).toBeVisible()
    // ...« Tout » still does, without the badge...
    await scope(page, 'Tout')
    await expect(feedCard(page, ride.name)).toBeVisible()
    await expect(feedCard(page, ride.name)).not.toContainText('Inscrit')
    // ...and the calendar's event is no longer marked.
    await toCalendar(page, day)
    await expect(calendarEvent(page, ride.name)).toBeVisible()
    await expect(calendarEvent(page, ride.name)).not.toContainText('Inscrit')
  })

  test('« Quitter » on the ride page: the calendar, « Ma prochaine sortie », the feed badge and « Je participe » follow without a reload', async ({
    page,
  }) => {
    const { team, member, ride, group, day } = await registered('ride-page')
    await signIn(page.context(), member)
    await page.goto(homePath(ride.name))
    await expect(nextRideCard(page)).toContainText(ride.name)
    await expect(feedCard(page, ride.name)).toContainText('Inscrit')
    await toCalendar(page, day)
    const event = calendarEvent(page, ride.name)
    await expect(event).toContainText(`Inscrit · ${group}`)

    // --- From the calendar to the ride, and leave there.
    await hydrated(event)
    await event.click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/sorties/${ride.slug}$`))
    const card = groupCard(page, group)
    const quit = card.getByRole('button', { name: 'Quitter' })
    await hydrated(quit)
    await quit.click()
    await expect(card.getByRole('button', { name: 'Rejoindre' })).toBeEnabled()
    await expect(card.getByText('0/10 participants')).toBeVisible()
    expect((await readRide(member, team.slug, ride.slug)).registered).toBe(false)

    // --- Back to the calendar: the event is no longer marked.
    await page.goBack()
    await showCalendarDay(page, day)
    await expect(calendarEvent(page, ride.name)).toBeVisible()
    await expect(calendarEvent(page, ride.name)).not.toContainText('Inscrit')

    // --- Back home: no « Ma prochaine sortie », no badge, nothing under « Je participe ».
    await page.goBack()
    await expect(page).toHaveURL(/\/\?q=/)
    await expect(feedCard(page, ride.name)).toBeVisible()
    await expect(feedCard(page, ride.name)).not.toContainText('Inscrit')
    await expect(nextRideEmpty(page)).toBeVisible()
    await scope(page, 'Je participe')
    await expect(
      page.getByRole('main').getByRole('heading', { name: 'Aucune publication trouvée' })
    ).toBeVisible()
    await expect(feedCard(page, ride.name)).toHaveCount(0)
  })
})

test.describe('participants', () => {
  /**
   * docs/LEDGER_*.md API-12: the ride detail embeds only the first participants of a group; the
   * modal reads the whole list page by page from the server, searched there, with its « N sur M ».
   */
  test('the participant list is read and searched on the server', async ({ page }) => {
    const { owner, team, organizer, member } = await ridingTeam('participants')
    const name = unique('Groupe nombreux')
    // Two groups: a solo ride lists its participants inline instead (WEB-79).
    const ride = await newRide(organizer, team.slug, unique('Sortie fréquentée'), {
      groups: [{ name }, { name: unique('Groupe calme') }],
    })
    // Ten riders: more than the 8 the detail embeds, so the card and the modal must both go by
    // the server's count, not by the length of the preview.
    const riders = await Promise.all(
      Array.from({ length: 10 }, (_, i) => newUser(unique(`Cycliste ${i}`)))
    )
    for (const rider of riders) {
      await addMember(owner, team.slug, rider)
      await joinGroup(rider, team.slug, ride, name)
    }

    await signIn(page.context(), member)
    await openRide(page, team.slug, ride)

    const card = groupCard(page, name)
    await expect(card.getByText('10 participants')).toBeVisible()
    await hydrated(card.getByRole('button', { name: 'Voir tous les participants' }))
    await card.getByRole('button', { name: 'Voir tous les participants' }).click()

    const modal = page.getByRole('dialog', { name })
    await expect(modal.getByRole('listitem')).toHaveCount(10)
    await expect(modal.getByTestId('participants-shown-of')).toHaveText('1–10 sur 10')

    const wanted = riders[7].user.displayName
    await modal.getByPlaceholder('Rechercher un participant…').fill(wanted)
    await expect(modal.getByRole('listitem')).toHaveCount(1)
    await expect(modal.getByRole('listitem')).toContainText(wanted)
    await expect(modal.getByTestId('participants-shown-of')).toHaveText('1–1 sur 1')
  })
})

test.describe('a ride with one group (WEB-79)', () => {
  test("its group's URL leads to the ride, and « back » does not return to it", async ({
    page,
  }) => {
    const { team, organizer, member } = await ridingTeam('solo')
    const ride = await newRide(organizer, team.slug, unique('Sortie à un groupe'))
    expect(ride.groups, 'precondition: one group').toHaveLength(1)

    await signIn(page.context(), member)
    await page.goto(ridePath(team.slug, ride.slug))
    await page.getByRole('heading', { level: 2, name: ride.name }).waitFor()
    const groupUrl = `${ridePath(team.slug, ride.slug)}/groupes/${ride.groups[0].id}?q=x`
    await page.goto(groupUrl)
    await expect(page).toHaveURL(new RegExp(`${ridePath(team.slug, ride.slug)}\\?q=x$`))
    await expect(page.getByRole('heading', { level: 2, name: ride.name })).toBeVisible()
    await expect(page.getByTestId('group-stats')).toBeVisible()
    await expect(page.getByRole('link', { name: /Voir le groupe/ })).toHaveCount(0)

    // A redirect, not a stacked entry: back is the ride page opened before.
    await page.goBack()
    await expect(page).toHaveURL(new RegExp(`${ridePath(team.slug, ride.slug)}$`))
  })
})
