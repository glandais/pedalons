import type { Page } from '@playwright/test'
import type { RideRequest } from '../src/api/dto'
import { apiPost, apiPut } from './support/api'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { inviteByApi } from './support/invitations'
import { queueCard, report, teamQueuePath } from './support/moderation'
import {
  about,
  expectNoNotification,
  isMuted,
  listNotifications,
  unreadCount,
  waitForNotification,
} from './support/notifications'
import { commentOnPost, newPost } from './support/posts'
import { joinGroup, newRide, readRide, rideRequest, ridePath } from './support/rides'
import { hydrated, toasts } from './support/ui'
import { wallTimeOf } from './support/dates'

/**
 * Notifications, end to end: a publication or a reply queues an event, the backend's dispatcher
 * fans it out (every 15 s), and the member finds it in the header bell (desktop) or through the
 * drawer (mobile, which has no bell), then on /notifications; muting a team in the profile silences
 * its announcements, never what is addressed to the member personally.
 *
 * Every test has an inbox of its own — a fresh member — since the dispatcher writes to whoever is
 * in the team, and counts are asserted exactly.
 */

// Each test waits on the dispatcher at least once, up to two cycles each time.
test.describe.configure({ timeout: 120_000 })

/** A team owned by a fresh author, with a fresh member in it: the one whose inbox is watched. */
async function teamWithMember(label: string) {
  const author = await newUser(unique('Autrice'))
  const member = await newUser(unique('Membre'))
  const team = await newTeam(author, unique(label))
  await addMember(await roleSession('admin'), team.slug, member)
  return { author, member, team }
}

/** Opens /notifications the way the layout offers it: the drawer on mobile, the URL otherwise. */
async function openInbox(page: Page, isMobile: boolean) {
  if (isMobile) {
    await page.goto('/')
    const burger = page.getByRole('banner').getByRole('button', { name: 'Ouvrir le menu' })
    await hydrated(burger)
    await burger.click()
    await page.getByRole('navigation').getByRole('link', { name: 'Notifications' }).click()
    await expect(page).toHaveURL(/\/notifications$/)
  } else {
    await page.goto('/notifications')
  }
  await expect(
    page.getByRole('main').getByRole('heading', { level: 2, name: 'Notifications' })
  ).toBeVisible()
}

test('a published post reaches a member in the team’s name, and opening it reads it', async ({
  page,
  context,
  isMobile,
}) => {
  const { author, member, team } = await teamWithMember('Annonces')
  const post = await newPost(author, team.slug, unique('Article annoncé'))

  const notification = await test.step('the dispatcher puts it in the member’s inbox', async () => {
    const found = await waitForNotification(
      member,
      about('POST_PUBLISHED', post.slug),
      'the POST_PUBLISHED notification'
    )
    // Regression of 0ab444d6: a publication speaks for the team, the API never names its author.
    expect(found.actorName, 'a publication is announced without its author').toBeUndefined()
    expect(found).toMatchObject({
      read: false,
      teamSlug: team.slug,
      teamName: team.name,
      subjectType: 'POST',
      subjectName: post.name,
    })
    expect(await unreadCount(member)).toBe(1)
    return found
  })

  await signIn(context, member)
  const main = page.getByRole('main')
  const entryText = `${team.name} a publié un article`

  if (isMobile) {
    await test.step('mobile: the drawer leads to the inbox, where the entry is unread', async () => {
      await openInbox(page, true)
      const entry = main.getByRole('link').filter({ hasText: post.name })
      await expect(entry).toContainText(entryText)
      await expect(entry).not.toContainText(author.user.displayName)
      await expect(entry.getByLabel('Non lue', { exact: true })).toBeVisible()
      await hydrated(entry)
      await entry.click()
    })
  } else {
    await test.step('desktop: the bell counts it, and its dropdown words it for the team', async () => {
      await page.goto('/')
      const bell = page
        .getByRole('banner')
        .getByRole('button', { name: 'Notifications, 1 non lue', exact: true })
      await expect(bell).toBeVisible()
      await hydrated(bell)
      await bell.click()
      const entry = page.getByRole('menu').getByRole('link').filter({ hasText: post.name })
      await expect(entry).toContainText(entryText)
      await expect(entry).not.toContainText(author.user.displayName)
      await expect(entry.getByLabel('Non lue', { exact: true })).toBeVisible()
      await entry.click()
    })
  }

  await test.step('the entry opens the post, and reading it clears the count', async () => {
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/articles/${post.slug}$`))
    await expect(main.getByRole('heading', { level: 2, name: post.name })).toBeVisible()
    await expect.poll(() => unreadCount(member)).toBe(0)
    if (!isMobile)
      await expect(
        page.getByRole('banner').getByRole('button', { name: 'Notifications', exact: true })
      ).toBeVisible()
    const [stored] = (await listNotifications(member)).items.filter((n) => n.id === notification.id)
    expect(stored.read).toBe(true)
  })

  await test.step('back in the inbox, the entry has lost its unread dot', async () => {
    await openInbox(page, isMobile)
    const entry = main.getByRole('link').filter({ hasText: post.name })
    await expect(entry).toContainText(entryText)
    await expect(entry.getByLabel('Non lue', { exact: true })).toHaveCount(0)
    await expect(main.getByRole('button', { name: 'Tout marquer lu' })).toHaveCount(0)
  })
})

test('the inbox filters unread entries from its URL, and "mark all read" empties the filter', async ({
  page,
  context,
  isMobile,
}) => {
  const { author, member, team } = await teamWithMember('Boîte de réception')
  await signIn(context, member)
  const main = page.getByRole('main')
  const unreadOnly = main.getByRole('switch', { name: 'Non lues uniquement' })
  const markAllRead = main.getByRole('button', { name: 'Tout marquer lu' })
  const entries = main.getByRole('link').filter({ hasText: `${team.name} a publié un article` })

  await test.step('an empty inbox says so, without the filtered wording', async () => {
    await openInbox(page, isMobile)
    await expect(main.getByText('Aucune notification', { exact: true })).toBeVisible()
    await expect(
      main.getByText('Les sorties, voyages et publications de vos équipes apparaîtront ici.')
    ).toBeVisible()
    await expect(markAllRead).toHaveCount(0)
  })

  const first = await newPost(author, team.slug, unique('Premier article'))
  const second = await newPost(author, team.slug, unique('Second article'))
  await test.step('two announcements arrive; the first is read elsewhere', async () => {
    const read = await waitForNotification(member, about('POST_PUBLISHED', first.slug))
    await waitForNotification(member, about('POST_PUBLISHED', second.slug))
    await apiPost(member, `/api/notifications/${read.id}/read`)
    expect(await unreadCount(member)).toBe(1)
  })

  await test.step('unfiltered, both entries are listed', async () => {
    await page.reload()
    await expect(main.getByText('2 notifications', { exact: true })).toBeVisible()
    await expect(entries).toHaveCount(2)
    await expect(unreadOnly).not.toBeChecked()
  })

  await test.step('"unread only" lands in the URL and survives a reload', async () => {
    await hydrated(unreadOnly)
    // A click, not check(): the switch is controlled by the URL, which the router updates after
    // the click returns — check() would read the state back too early.
    await unreadOnly.click()
    await expect(unreadOnly).toBeChecked()
    await expect(page).toHaveURL(/[?&]unread=true(&|$)/)
    await expect(entries).toHaveCount(1)
    await expect(entries.filter({ hasText: second.name })).toHaveCount(1)
    await expect(main.getByText('1 notification', { exact: true })).toBeVisible()

    await page.reload()
    await expect(unreadOnly).toBeChecked()
    await expect(entries).toHaveCount(1)
    await expect(entries.filter({ hasText: second.name })).toHaveCount(1)
  })

  await test.step('"mark all read" empties the filtered list, which says why', async () => {
    await hydrated(markAllRead)
    await markAllRead.click()
    await expect(main.getByText('Aucune notification non lue', { exact: true })).toBeVisible()
    await expect(entries).toHaveCount(0)
    await expect(markAllRead).toHaveCount(0)
    expect(await unreadCount(member)).toBe(0)
  })

  await test.step('the empty state lifts the filter, and everything is back, read', async () => {
    await main.getByRole('button', { name: 'Voir toutes les notifications' }).click()
    await expect(page).not.toHaveURL(/unread=/)
    await expect(unreadOnly).not.toBeChecked()
    await expect(entries).toHaveCount(2)
    await expect(main.getByLabel('Non lue', { exact: true })).toHaveCount(0)
  })
})

test('muting a team in the profile silences its announcements, but not a reply', async ({
  page,
  context,
}) => {
  // One author per team: a user may own only one team (USER_TEAM_LIMIT_REACHED).
  const author = await newUser(unique('Autrice'))
  const otherAuthor = await newUser(unique('Auteur'))
  const member = await newUser(unique('Membre'))
  const muted = await newTeam(author, unique('Équipe en sourdine'))
  const heard = await newTeam(otherAuthor, unique('Équipe écoutée'))
  const admin = await roleSession('admin')
  await addMember(admin, muted.slug, member)
  await addMember(admin, heard.slug, member)

  // The thread the reply will land in, in the team about to be muted — announced before the mute,
  // and waited for, so that the mute cannot race its dispatch.
  const thread = await newPost(author, muted.slug, unique('Article commenté'))
  await waitForNotification(member, about('POST_PUBLISHED', thread.slug))
  const comment = await commentOnPost(member, muted.slug, thread.slug, 'Je serai là dimanche.')

  await test.step('the member mutes the team from the profile', async () => {
    await signIn(context, member)
    await page.goto('/profil/notifications')
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: 'Annonces des équipes' })).toBeVisible()
    const mutedSwitch = main.getByRole('switch', { name: `Recevoir les annonces de ${muted.name}` })
    const heardSwitch = main.getByRole('switch', { name: `Recevoir les annonces de ${heard.name}` })
    await expect(mutedSwitch).toBeChecked()
    await expect(heardSwitch).toBeChecked()
    await hydrated(mutedSwitch)
    // A click, not uncheck(): the switch shows the saved preference, which only flips once the
    // PUT has answered and the preferences are read again.
    await mutedSwitch.click()
    await expect(mutedSwitch).not.toBeChecked()
    await expect.poll(() => isMuted(member, muted.slug)).toBe(true)
    expect(await isMuted(member, heard.slug)).toBe(false)

    await page.reload()
    await expect(mutedSwitch).not.toBeChecked()
    await expect(heardSwitch).toBeChecked()
  })

  // Queued in this order, and the dispatcher takes events oldest first: once the last one is in,
  // the muted announcement has been processed — its absence is then a decision, not a delay.
  const silenced = await newPost(author, muted.slug, unique('Article tu'))
  const reply = await commentOnPost(
    author,
    muted.slug,
    thread.slug,
    'Parfait, à dimanche !',
    comment.id
  )
  const announced = await newPost(otherAuthor, heard.slug, unique('Article entendu'))

  await test.step('the other team’s announcement and the reply arrive; the muted one does not', async () => {
    const replied = await waitForNotification(
      member,
      about('COMMENT_REPLY', thread.slug),
      'the COMMENT_REPLY notification'
    )
    await waitForNotification(member, about('POST_PUBLISHED', announced.slug))
    // A reply is personal: it names who replied, and quotes them.
    expect(replied).toMatchObject({
      actorName: author.user.displayName,
      teamSlug: muted.slug,
      excerpt: reply.content,
    })
    const inbox = (await listNotifications(member)).items
    expect(inbox.filter(about('POST_PUBLISHED', silenced.slug)), 'muted announcement').toEqual([])
  })

  await test.step('the inbox shows the reply and the heard team’s post only', async () => {
    await page.goto('/notifications')
    const main = page.getByRole('main')
    await expect(
      main
        .getByRole('link')
        .filter({ hasText: `${author.user.displayName} a répondu à votre commentaire` })
    ).toContainText(thread.name)
    await expect(main.getByRole('link').filter({ hasText: announced.name })).toContainText(
      `${heard.name} a publié un article`
    )
    await expect(main.getByRole('link').filter({ hasText: silenced.name })).toHaveCount(0)
  })
})

/**
 * Personal notifications: addressed to someone in particular, and worded by the client from the
 * type and the structured fields (NotificationItem.tsx:33-60), with a destination picked from the
 * subject's type (notificationDisplay.ts:78-97) — never from a text or a link the API would send.
 */
test.describe('personal notifications', () => {
  /** The inbox entry about `subjectName` — every test's subjects have unique names. */
  const inboxEntry = (page: Page, subjectName: string) =>
    page.getByRole('main').getByRole('link').filter({ hasText: subjectName })

  test('a cancelled ride reaches its registered riders only, and leads to the ride marked « Annulé »', async ({
    page,
    context,
    isMobile,
  }) => {
    const owner = await newUser(unique('Organisatrice'))
    const registered = await newUser(unique('Inscrite'))
    const bystander = await newUser(unique('Non inscrit'))
    const team = await newTeam(owner, unique('Sorties annulées'), { addMemberAllowed: true })
    await addMember(owner, team.slug, registered)
    await addMember(owner, team.slug, bystander)
    const group = unique('Groupe du matin')
    const ride = await newRide(owner, team.slug, unique('Sortie annulée'), {
      groups: [{ name: group }],
    })
    await joinGroup(registered, team.slug, ride, group)

    // What the ride editor sends when « Annuler la sortie » is confirmed: the ride, cancelled.
    await apiPut(owner, `/api/teams/${team.slug}/rides/${ride.slug}`, {
      ...rideRequest(ride.name, {
        dateTime: wallTimeOf(ride.dateTime, ride.timezone),
        status: 'CANCELLED',
      }),
      groups: ride.groups.map((g) => ({ id: g.id, name: g.name, leaderId: g.leader?.id })),
    } satisfies RideRequest)
    expect((await readRide(owner, team.slug, ride.slug)).status).toBe('CANCELLED')

    await test.step('the registered rider is told; the other member is not', async () => {
      const found = await waitForNotification(
        registered,
        about('RIDE_CANCELLED', ride.slug),
        'the RIDE_CANCELLED notification'
      )
      expect(found).toMatchObject({
        read: false,
        teamSlug: team.slug,
        subjectType: 'RIDE',
        subjectName: ride.name,
      })
      // Same event, same tick: the bystander's copy would be there by now.
      await expectNoNotification(
        bystander,
        about('RIDE_CANCELLED', ride.slug),
        'a member not registered hears nothing of the cancellation'
      )
    })

    await test.step('the entry says a ride is cancelled, and opens it marked « Annulé »', async () => {
      await signIn(context, registered)
      await openInbox(page, isMobile)
      const entry = inboxEntry(page, ride.name)
      await expect(entry).toContainText('Une sortie est annulée')
      await expect(entry.getByLabel('Non lue', { exact: true })).toBeVisible()
      await hydrated(entry)
      await entry.click()
      await expect(page).toHaveURL(new RegExp(`${ridePath(team.slug, ride.slug)}$`))
      const main = page.getByRole('main')
      await expect(main.getByRole('heading', { level: 2, name: ride.name })).toBeVisible()
      await expect(main.getByText('Annulé', { exact: true })).toBeVisible()
    })
  })

  test('a rider joining a ride is announced to its creator and to the group’s leader, with the group’s name', async ({
    page,
    context,
    isMobile,
  }) => {
    const owner = await newUser(unique('Organisatrice'))
    const leader = await newUser(unique('Meneur'))
    const rider = await newUser(unique('Cycliste'))
    const team = await newTeam(owner, unique('Inscriptions'), { addMemberAllowed: true })
    await addMember(owner, team.slug, leader)
    await addMember(owner, team.slug, rider)
    const group = unique('Groupe rapide')
    const ride = await newRide(owner, team.slug, unique('Sortie rejointe'), {
      groups: [{ name: group, leaderId: leader.user.id }],
    })
    await joinGroup(rider, team.slug, ride, group)

    await test.step('the creator and the leader are told who joined which group', async () => {
      for (const organiser of [owner, leader]) {
        const found = await waitForNotification(
          organiser,
          about('RIDE_JOINED', ride.slug),
          'the RIDE_JOINED notification'
        )
        // A personal notification names who did it; the group travels as the excerpt.
        expect(found).toMatchObject({
          actorName: rider.user.displayName,
          subjectType: 'RIDE',
          subjectName: ride.name,
          excerpt: group,
        })
      }
      await expectNoNotification(
        rider,
        about('RIDE_JOINED', ride.slug),
        'nobody is told of what they did themselves'
      )
    })

    await test.step('the creator’s entry names the rider and the group, and opens the ride', async () => {
      await signIn(context, owner)
      await openInbox(page, isMobile)
      const entry = inboxEntry(page, ride.name)
      await expect(entry).toContainText(`${rider.user.displayName} a rejoint votre sortie`)
      await expect(entry).toContainText(`Groupe : ${group}`)
      await hydrated(entry)
      await entry.click()
      await expect(page).toHaveURL(new RegExp(`${ridePath(team.slug, ride.slug)}$`))
      await expect(
        page.getByRole('main').getByRole('heading', { level: 2, name: ride.name })
      ).toBeVisible()
    })
  })

  test('an invitation reaches the invited account, and leads to the team list whose banner accepts it', async ({
    page,
    context,
    isMobile,
  }) => {
    const owner = await newUser(unique('Capitaine'))
    const invitee = await newUser(unique('Invitée'))
    const team = await newTeam(owner, unique('Équipe invitante'), { addMemberAllowed: true })
    await inviteByApi(owner, team.slug, invitee.user.email)

    await test.step('the invitee is told who invites them, and where', async () => {
      const found = await waitForNotification(
        invitee,
        about('TEAM_INVITATION', team.slug),
        'the TEAM_INVITATION notification'
      )
      expect(found).toMatchObject({
        actorName: owner.user.displayName,
        teamSlug: team.slug,
        teamName: team.name,
        subjectType: 'TEAM',
        subjectName: team.name,
      })
    })

    await test.step('the entry opens the team list, not the team the invitee cannot see yet', async () => {
      await signIn(context, invitee)
      await openInbox(page, isMobile)
      const entry = inboxEntry(page, `vous invite à rejoindre ${team.name}`)
      await expect(entry).toContainText(
        `${owner.user.displayName} vous invite à rejoindre ${team.name}`
      )
      await hydrated(entry)
      await entry.click()
      await expect(page).toHaveURL(/\/equipes$/)
    })

    await test.step('the banner there accepts the invitation', async () => {
      const banner = page
        .getByRole('alert')
        .filter({ hasText: 'Vous avez une invitation en attente' })
      await expect(
        banner.getByText(`${owner.user.displayName} vous invite à rejoindre ${team.name}.`, {
          exact: true,
        })
      ).toBeVisible()
      const accept = banner.getByRole('button', { name: 'Accepter' })
      await hydrated(accept)
      await accept.click()
      await expect(
        toasts(page).filter({ hasText: `Vous avez rejoint ${team.name}.` })
      ).toBeVisible()
      await expect(banner).toBeHidden()
    })
  })

  test('a report reaches the team’s moderator without naming the reporter, and leads to its queue', async ({
    page,
    context,
    isMobile,
  }) => {
    const moderator = await newUser(unique('Modératrice'))
    const author = await newUser(unique('Autrice signalée'))
    const reporter = await newUser(unique('Signaleuse'))
    const team = await newTeam(moderator, unique('Équipe modérée'), { addMemberAllowed: true })
    await addMember(moderator, team.slug, author, 'ORGANIZER')
    await addMember(moderator, team.slug, reporter)
    const reported = await newPost(author, team.slug, unique('Article signalé'))
    await report(reporter, team.slug, 'POST', reported.id, 'SPAM', 'Publicité déguisée.')

    await test.step('the moderator is told, anonymously; neither the reporter nor the author is', async () => {
      const found = await waitForNotification(
        moderator,
        about('CONTENT_REPORTED', team.slug),
        'the CONTENT_REPORTED notification'
      )
      expect(found).toMatchObject({ subjectType: 'REPORT', teamSlug: team.slug })
      // No actor (the reporter is anonymous to the team) and no excerpt (a push reaches the lock
      // screen): NotificationRecipientResolver#resolveReport.
      expect(found.actorName, 'the reporter is not named').toBeUndefined()
      expect(found.excerpt, 'the reported content is not quoted').toBeUndefined()
      await expectNoNotification(reporter, about('CONTENT_REPORTED', team.slug), 'the reporter')
      await expectNoNotification(
        author,
        about('CONTENT_REPORTED', team.slug),
        'the reported author, though an organiser of the team'
      )
    })

    await test.step('the entry names the team only, and opens its moderation queue', async () => {
      await signIn(context, moderator)
      await openInbox(page, isMobile)
      const entry = inboxEntry(page, `Nouveau signalement dans ${team.name}`)
      await expect(entry).toBeVisible()
      await expect(entry).not.toContainText(reporter.user.displayName)
      await hydrated(entry)
      await entry.click()
      await expect(page).toHaveURL(new RegExp(`${teamQueuePath(team.slug)}$`))
      await expect(queueCard(page, reported.name)).toBeVisible()
    })
  })
})

test('mobile: the burger wears a dot while something is unread, and the drawer’s link counts it', async ({
  page,
  context,
  isMobile,
}) => {
  test.skip(!isMobile, 'on desktop the bell carries the count (first test of this file)')
  // Regression (9ba0a402): below `sm` the bell is hidden, and nothing said a notification waited.
  const { author, member, team } = await teamWithMember('Pastille')
  const first = await newPost(author, team.slug, unique('Premier article'))
  const second = await newPost(author, team.slug, unique('Second article'))
  const read = await waitForNotification(member, about('POST_PUBLISHED', first.slug))
  await waitForNotification(member, about('POST_PUBLISHED', second.slug))

  const banner = page.getByRole('banner')
  // Layout.tsx wraps the burger in a Mantine Indicator: its dot is decoration, with no name.
  const dot = banner
    .locator('.mantine-Indicator-root')
    .filter({ has: page.locator('.mantine-Burger-root') })
    .locator('.mantine-Indicator-indicator')
  const drawer = page.getByRole('navigation')
  const openDrawer = async () => {
    const burger = banner.getByRole('button', { name: 'Ouvrir le menu' })
    await hydrated(burger)
    await burger.click()
    await expect(drawer.getByRole('link', { name: /^Notifications/ })).toBeVisible()
  }
  await signIn(context, member)

  await test.step('two unread: a dot on the burger, « 2 » on the drawer’s link', async () => {
    await page.goto('/')
    await expect(dot).toBeVisible()
    await openDrawer()
    await expect(drawer.getByLabel('Notifications, 2 non lues', { exact: true })).toHaveText('2')
    // The drawer shows the count itself: the dot steps aside while it is open.
    await expect(dot).toHaveCount(0)
  })

  await test.step('one read elsewhere: the link says « 1 non lue »', async () => {
    await apiPost(member, `/api/notifications/${read.id}/read`)
    await page.reload()
    await expect(dot).toBeVisible()
    await openDrawer()
    await expect(drawer.getByLabel('Notifications, 1 non lue', { exact: true })).toHaveText('1')
  })

  await test.step('everything read: no dot, no count', async () => {
    await drawer.getByRole('link', { name: /^Notifications/ }).click()
    await expect(page).toHaveURL(/\/notifications$/)
    const markAllRead = page.getByRole('main').getByRole('button', { name: 'Tout marquer lu' })
    await hydrated(markAllRead)
    await markAllRead.click()
    await expect(markAllRead).toHaveCount(0)
    await expect(dot).toHaveCount(0)
    await openDrawer()
    await expect(drawer.getByLabel(/^Notifications, \d+ non lues?$/)).toHaveCount(0)
  })
})
