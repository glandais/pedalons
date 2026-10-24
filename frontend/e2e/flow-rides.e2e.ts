import type { Locator, Page } from '@playwright/test'
import type {
  CountResponse,
  PlaceDetailDto,
  PlaceRequest,
  RideDto,
  RideRequest,
  RideTemplateDto,
  RideTemplateGroupRequest,
  RideTemplateRequest,
  RouteDto,
} from '../src/api/dto'
import { apiDelete, apiGet, apiPost, apiPut } from './support/api'
import { calendarEvent, openCalendar } from './support/calendar'
import {
  frenchDateTime,
  monthName,
  openPicker,
  parisDaysAhead,
  parisInstant,
  parisWallClock,
  pickDateTime,
  pickerText,
  type WallClock,
  wallTime,
  wallTimeOf,
} from './support/dates'
import { addMember, markdownMedia, newTeam, newUser, roleSession, signIn } from './support/data'
import { richText } from './support/editor'
import { expect, test, unique } from './support/fixtures'
import {
  findRide,
  groupCard,
  newRide,
  readComments,
  readRide,
  readTemplates,
  ridePath,
} from './support/rides'
import { expectNoNotification, waitForNotification } from './support/notifications'
import { getRoute, gpxOf, newRoute, windingTrack } from './support/routes'
import {
  actionsMenu,
  entityCard,
  hydrated,
  openActionsMenu,
  pageAs,
  toasts,
  watchToasts,
} from './support/ui'

/**
 * The ride journey through the UI only, as a team's organizer and one of its members: the ride
 * editor (create, publish, edit), the team's feed and calendar, registration and a comment from the
 * ride page, then cancellation, restoration and deletion — a group's leader picked in the editor, a
 * route created from it (and a private one refused for a public ride) — and ride templates, created,
 * edited and deleted in their own editor and loaded into a new ride.
 *
 * What rides.e2e.ts already pins on the ride page (comment paging, the leader badge, a full group,
 * GROUP_FULL) is not repeated here. Every test builds its own team, owned by the platform admin (only
 * a platform admin may add members directly), with its own organizer and member.
 */

async function ridingTeam(label: string) {
  const owner = await roleSession('admin')
  const team = await newTeam(owner, unique(`Flow sorties ${label}`))
  const organizer = await newUser(unique('Organisatrice'))
  const member = await newUser(unique('Membre'))
  await addMember(owner, team.slug, organizer, 'ORGANIZER')
  await addMember(owner, team.slug, member)
  return { team, organizer, member }
}

const main = (page: Page) => page.getByRole('main')

/**
 * The team agenda (WEB-68), loaded: its heading and its count are there before any presence or
 * absence check.
 */
async function openFeed(page: Page, teamSlug: string) {
  await page.goto(`/equipes/${teamSlug}/agenda`)
  await expect(main(page).getByRole('heading', { name: 'Agenda', level: 2 })).toBeVisible()
  await expect(main(page).getByText(/^\d+ sorties? (et|ou) voyages? à venir$/)).toBeVisible()
}

const feedCard = (page: Page, name: string) => entityCard(main(page), name)

/**
 * Sets an empty DateTimePicker (`field`: its button) to `when` — dates.ts pickDateTime pages from
 * the value the field shows, and an unset « Publication programmée » shows none: its dropdown opens
 * on today's month.
 */
async function pickIntoEmptyPicker(page: Page, field: Locator, when: WallClock) {
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

/** The request that saves `ride` back as it is, but for `changes` — what the ride editor sends. */
const rideAsRequest = (ride: RideDto, changes: Partial<RideRequest>): RideRequest => ({
  name: ride.name,
  media: ride.media,
  dateTime: wallTimeOf(ride.dateTime, ride.timezone),
  status: ride.status,
  visibility: ride.visibility,
  routeSlug: ride.routeSlug,
  publishAt: ride.publishAt && wallTimeOf(ride.publishAt, ride.timezone),
  groups: ride.groups.map((g) => ({
    id: g.id,
    name: g.name,
    maxParticipants: g.maxParticipants,
    leaderId: g.leader?.id,
  })),
  ...changes,
})

test.describe('ride journey', () => {
  test('an organizer creates, publishes and edits a ride; a member joins and comments; the organizer deletes it', async ({
    page,
    browser,
  }) => {
    test.slow()
    const { team, organizer, member } = await ridingTeam('parcours')
    const routeName = unique('Boucle de la Beauce')
    const route = await newRoute(organizer, team.slug, routeName, windingTrack(200))
    const rideName = unique('Sortie du jeudi')
    const description = 'Café à mi-parcours, retour avant midi.'
    const fast = unique('Groupe rapide')
    const easy = unique('Groupe tranquille')
    const day = parisDaysAhead(3, 18, 30)

    // --- Create, from the team feed's « Créer une sortie ».
    await signIn(page.context(), organizer)
    await openFeed(page, team.slug)
    const create = main(page).getByRole('link', { name: 'Créer une sortie' })
    await hydrated(create)
    await create.click()
    await expect(
      main(page).getByRole('heading', { name: 'Créer une sortie', level: 1 })
    ).toBeVisible()

    const title = main(page).getByRole('textbox', { name: 'Titre de la sortie' })
    await hydrated(title)
    await title.fill(rideName)
    await richText(main(page)).fill(description)
    await pickDateTime(page, main(page).getByRole('button', { name: 'Départ' }), day)

    // The ride's route, among the team's routes (the first « Sélectionner un parcours » is the
    // ride's; the others belong to the groups).
    await main(page).getByRole('button', { name: 'Sélectionner un parcours' }).first().click()
    const picker = page.getByRole('dialog', { name: 'Sélectionner un parcours pour la sortie' })
    await picker.getByRole('button').filter({ hasText: routeName }).click()
    await expect(picker).toBeHidden()
    await expect(main(page).getByText('Aucun parcours sélectionné')).toHaveCount(1) // the group's

    // Two groups, each with a capacity.
    const groupNames = main(page).getByRole('textbox', { name: 'Nom du groupe' })
    const capacities = main(page).getByRole('textbox', { name: 'Taille max' })
    await groupNames.first().fill(fast)
    await capacities.first().fill('8')
    await main(page).getByRole('button', { name: 'Ajouter un groupe' }).click()
    await expect(groupNames).toHaveCount(2)
    await groupNames.nth(1).fill(easy)
    await capacities.nth(1).fill('12')

    // Created as a draft (the editor's default), published from the ride page afterwards.
    await expect(main(page).getByRole('radio', { name: 'Brouillon' })).toBeChecked()
    await main(page).getByRole('button', { name: 'Créer la sortie' }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/sorties/(?!nouvelle)[^/]+$`))
    const rideSlug = new URL(page.url()).pathname.split('/').pop()!
    await expect(main(page).getByRole('heading', { name: rideName, level: 2 })).toBeVisible()
    await expect(main(page).getByText('Brouillon', { exact: true })).toBeVisible()

    let saved = await readRide(organizer, team.slug, rideSlug)
    expect(saved.name).toBe(rideName)
    expect(saved.media.markdown.trim()).toBe(description)
    expect(parisWallClock(saved.dateTime)).toEqual(day)
    expect(saved.routeSlug).toBe(route.slug)
    expect(saved.status).toBe('DRAFT')
    expect(saved.groups.map((g) => [g.name, g.maxParticipants])).toEqual([
      [fast, 8],
      [easy, 12],
    ])

    // A draft is not in the member's feed yet.
    const { context: memberContext, page: memberPage } = await pageAs(browser, member)
    try {
      await openFeed(memberPage, team.slug)
      await expect(
        main(memberPage).getByText('0 sortie ou voyage à venir', { exact: true })
      ).toBeVisible()
      await expect(feedCard(memberPage, rideName)).toHaveCount(0)
      expect(await findRide(member, team.slug, rideSlug), 'a draft is 404 to a member').toBeNull()

      // --- Publish.
      const menu = await openActionsMenu(page)
      await menu.getByRole('menuitem', { name: 'Publier' }).click()
      await expect(main(page).getByText('Publié', { exact: true })).toBeVisible()
      expect((await readRide(organizer, team.slug, rideSlug)).status).toBe('PUBLISHED')

      // --- In the team's feed and its calendar, for the member.
      await openFeed(memberPage, team.slug)
      await expect(feedCard(memberPage, rideName)).toBeVisible()
      await openCalendar(memberPage, team.slug, day)
      await expect(calendarEvent(memberPage, rideName)).toBeVisible()

      // --- Edit: the easy group becomes smaller and changes its name.
      const easier = unique('Groupe découverte')
      const edit = main(page).getByRole('link', { name: 'Modifier' })
      await hydrated(edit)
      await edit.click()
      await expect(
        main(page).getByRole('heading', { name: 'Modifier la sortie', level: 1 })
      ).toBeVisible()
      const editNames = main(page).getByRole('textbox', { name: 'Nom du groupe' })
      await expect(editNames.nth(1)).toHaveValue(easy)
      await hydrated(editNames.nth(1))
      await editNames.nth(1).fill(easier)
      await main(page).getByRole('textbox', { name: 'Taille max' }).nth(1).fill('4')
      await main(page).getByRole('button', { name: 'Enregistrer' }).click()
      await expect(page).toHaveURL(new RegExp(`/sorties/${rideSlug}$`))
      await expect(groupCard(page, easier)).toBeVisible()
      await expect(groupCard(page, easier).getByText('0/4 personnes')).toBeVisible()
      await expect(main(page).getByText(easy, { exact: true })).toHaveCount(0)

      saved = await readRide(organizer, team.slug, rideSlug)
      expect(saved.groups.map((g) => [g.name, g.maxParticipants])).toEqual([
        [fast, 8],
        [easier, 4],
      ])
      // Editing kept what it did not touch.
      expect(saved.status).toBe('PUBLISHED')
      expect(saved.routeSlug).toBe(route.slug)
      expect(parisWallClock(saved.dateTime)).toEqual(day)

      // --- The member opens it from the calendar, joins a group and comments.
      await calendarEvent(memberPage, rideName).click()
      await expect(memberPage).toHaveURL(new RegExp(`/sorties/${rideSlug}$`))
      await expect(
        main(memberPage).getByRole('heading', { name: rideName, level: 2 })
      ).toBeVisible()
      const card = groupCard(memberPage, easier)
      await expect(card.getByText('0/4 personnes')).toBeVisible()
      const join = card.getByRole('button', { name: 'Rejoindre' })
      await hydrated(join)
      await join.click()
      await expect(card.getByText("J'y vais", { exact: true })).toBeVisible()
      await expect(card.getByText('1/4 personnes')).toBeVisible()

      const comment = `On se retrouve au parking ${unique('msg')}`
      const commentBox = main(memberPage).getByRole('textbox', { name: /Écrivez un commentaire/ })
      await commentBox.fill(comment)
      await main(memberPage).getByRole('button', { name: 'Envoyer le commentaire' }).click()
      await expect(main(memberPage).getByText(comment, { exact: true })).toBeVisible()
      await expect(
        main(memberPage).getByRole('heading', { name: 'Commentaires (1)' })
      ).toBeVisible()

      const asMember = await readRide(member, team.slug, rideSlug)
      expect(asMember.registered).toBe(true)
      expect(asMember.registeredGroupId).toBe(saved.groups[1].id)
      const comments = await readComments(organizer, team.slug, rideSlug)
      expect(comments.items.map((c) => c.content)).toEqual([comment])

      // The organizer sees both on their page.
      await page.reload()
      await expect(groupCard(page, easier).getByText('1/4 personnes')).toBeVisible()
      await expect(main(page).getByText(comment, { exact: true })).toBeVisible()

      // --- Delete: back on the feed, and gone from every list.
      const actions = await openActionsMenu(page)
      await actions.getByRole('menuitem', { name: 'Supprimer' }).click()
      const confirm = page.getByRole('dialog', { name: 'Supprimer' })
      await expect(confirm.getByText('Voulez-vous vraiment supprimer cette sortie ?')).toBeVisible()
      await confirm.getByRole('button', { name: 'Supprimer' }).click()
      await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/agenda$`))
      await expect(main(page).getByRole('heading', { name: 'Agenda', level: 2 })).toBeVisible()
      // An organizer is not a team admin: deleted rides are not listed back to them.
      await expect(
        main(page).getByText('0 sortie ou voyage à venir', { exact: true })
      ).toBeVisible()
      await expect(feedCard(page, rideName)).toHaveCount(0)

      expect(await findRide(member, team.slug, rideSlug), 'the API answers 404').toBeNull()
      await openFeed(memberPage, team.slug)
      await expect(
        main(memberPage).getByText('0 sortie ou voyage à venir', { exact: true })
      ).toBeVisible()
      await expect(feedCard(memberPage, rideName)).toHaveCount(0)
      // The calendar's events come with the page, prefetched by the server: another ride of the
      // same day, shown, is what says they are in (see support/calendar.ts).
      const anchor = await newRide(organizer, team.slug, unique('Sortie repère'), {
        dateTime: wallTime({ ...day, hour: 10, minute: 0 }),
      })
      await openCalendar(memberPage, team.slug, day)
      await expect(calendarEvent(memberPage, anchor.name)).toBeVisible()
      await expect(calendarEvent(memberPage, rideName)).toHaveCount(0)
      // Its own page says it is gone — see 'a deleted ride's page says so at once' for how long
      // that takes.
      await memberPage.goto(`/equipes/${team.slug}/sorties/${rideSlug}`)
      await expect(main(memberPage).getByText('Sortie non trouvée')).toBeVisible({
        timeout: 15_000,
      })
    } finally {
      await memberContext.close()
    }
  })

  test('an organizer cancels a published ride: it says « Annulé » and takes no more registrations', async ({
    page,
    browser,
  }) => {
    const { team, organizer, member } = await ridingTeam('annulation')
    const rideName = unique('Sortie annulée')
    const group = unique('Groupe du matin')

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/sorties/nouvelle`)
    await expect(
      main(page).getByRole('heading', { name: 'Créer une sortie', level: 1 })
    ).toBeVisible()
    const title = main(page).getByRole('textbox', { name: 'Titre de la sortie' })
    await hydrated(title)
    await title.fill(rideName)
    await main(page).getByRole('textbox', { name: 'Nom du groupe' }).fill(group)
    // Published straight from the editor this time.
    await main(page).getByRole('radio', { name: 'Publié' }).check()
    await main(page).getByRole('button', { name: 'Créer la sortie' }).click()
    await expect(main(page).getByRole('heading', { name: rideName, level: 2 })).toBeVisible()
    await expect(main(page).getByText('Publié', { exact: true })).toBeVisible()
    const rideSlug = new URL(page.url()).pathname.split('/').pop()!

    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Annuler la sortie' }).click()
    const confirm = page.getByRole('dialog', { name: 'Annuler la sortie' })
    await expect(confirm.getByText('Voulez-vous vraiment annuler cette sortie ?')).toBeVisible()
    await confirm.getByRole('button', { name: 'Annuler la sortie' }).click()
    await expect(confirm).toBeHidden()
    await expect(main(page).getByText('Annulé', { exact: true })).toBeVisible()
    expect((await readRide(organizer, team.slug, rideSlug)).status).toBe('CANCELLED')

    // The member still finds it, marked cancelled, and cannot register any more.
    const { context, page: memberPage } = await pageAs(browser, member)
    try {
      await openFeed(memberPage, team.slug)
      const card = feedCard(memberPage, rideName)
      await expect(card).toBeVisible()
      await expect(card.getByText('Annulé', { exact: true })).toBeVisible()
      await card.click()
      await expect(
        main(memberPage).getByRole('heading', { name: rideName, level: 2 })
      ).toBeVisible()
      await expect(groupCard(memberPage, group)).toBeVisible()
      await expect(main(memberPage).getByText('Annulé', { exact: true })).toBeVisible()
      await expect(
        groupCard(memberPage, group).getByRole('button', { name: 'Rejoindre' })
      ).toHaveCount(0)
    } finally {
      await context.close()
    }
  })
})

test.describe('publication states', () => {
  test('a ride with a scheduled publication: a draft that says when, hidden from members until the scheduler publishes it', async ({
    page,
    browser,
  }) => {
    // The scheduler (PublicationPublishScheduler) runs once a minute: the last step waits for it.
    test.setTimeout(180_000)
    const { team, organizer, member } = await ridingTeam('programmée')
    const rideName = unique('Sortie programmée')
    const day = parisDaysAhead(4, 9, 0)
    const publishOn = parisDaysAhead(1, 7, 15)

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/sorties/nouvelle`)
    await expect(
      main(page).getByRole('heading', { name: 'Créer une sortie', level: 1 })
    ).toBeVisible()
    const title = main(page).getByRole('textbox', { name: 'Titre de la sortie' })
    await hydrated(title)
    await title.fill(rideName)
    await pickDateTime(page, main(page).getByRole('button', { name: 'Départ' }), day)
    await main(page).getByRole('textbox', { name: 'Nom du groupe' }).fill(unique('Groupe'))
    // A draft (the editor's default) is what offers a scheduled publication.
    await expect(main(page).getByRole('radio', { name: 'Brouillon' })).toBeChecked()
    await pickIntoEmptyPicker(
      page,
      main(page).getByRole('button', { name: 'Publication programmée' }),
      publishOn
    )
    await main(page).getByRole('button', { name: 'Créer la sortie' }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/sorties/(?!nouvelle)[^/]+$`))
    const rideSlug = new URL(page.url()).pathname.split('/').pop()!

    // --- Before the date: the page says it is a draft, and when it will be published.
    await expect(main(page).getByRole('heading', { name: rideName, level: 2 })).toBeVisible()
    await expect(main(page).getByText('Brouillon', { exact: true })).toBeVisible()
    await expect(
      main(page).getByText(`Publication programmée pour le ${frenchDateTime(publishOn)}`, {
        exact: true,
      })
    ).toBeVisible()
    const saved = await readRide(organizer, team.slug, rideSlug)
    expect(saved.status).toBe('DRAFT')
    expect(new Date(saved.publishAt!).toISOString()).toBe(parisInstant(publishOn))
    expect(parisWallClock(saved.dateTime)).toEqual(day)

    const { context: memberContext, page: memberPage } = await pageAs(browser, member)
    try {
      // Members see nothing of it yet.
      expect(await findRide(member, team.slug, rideSlug), 'a draft is 404 to a member').toBeNull()
      await openFeed(memberPage, team.slug)
      await expect(
        main(memberPage).getByText('0 sortie ou voyage à venir', { exact: true })
      ).toBeVisible()
      await expect(feedCard(memberPage, rideName)).toHaveCount(0)

      // --- The date comes. The stack's clock cannot be moved, but the backend takes a scheduled
      // date already past as it is, and its scheduler then publishes the ride on its next run —
      // exactly what happens when the date is reached.
      await apiPut(
        organizer,
        `/api/teams/${team.slug}/rides/${rideSlug}`,
        rideAsRequest(saved, { publishAt: wallTimeOf(Date.now() - 60_000) })
      )
      await expect
        .poll(async () => (await readRide(organizer, team.slug, rideSlug)).status, {
          message: 'the scheduler publishes the ride',
          timeout: 100_000,
          intervals: [2_000],
        })
        .toBe('PUBLISHED')
      const published = await readRide(organizer, team.slug, rideSlug)
      expect(published.publishAt, 'the schedule is spent').toBeUndefined()
      expect(parisWallClock(published.dateTime), 'a ride keeps its own date').toEqual(day)

      await page.reload()
      await expect(main(page).getByRole('heading', { name: rideName, level: 2 })).toBeVisible()
      await expect(main(page).getByText('Publié', { exact: true })).toBeVisible()
      await expect(main(page).getByText(/^Publication programmée/)).toHaveCount(0)

      await openFeed(memberPage, team.slug)
      await expect(feedCard(memberPage, rideName)).toBeVisible()
      expect((await readRide(member, team.slug, rideSlug)).status).toBe('PUBLISHED')
    } finally {
      await memberContext.close()
    }
  })
})

test.describe('regressions', () => {
  test("the actions menus' chevrons have a name", async ({ page }) => {
    // The chevron opening a detail page's other actions was an icon-only Button with no
    // aria-label — on the ride, trip, post and ad pages — and so was the feed's create menu
    // (fixed 2026-09-25: « Options de gestion », « Créer autre chose » — the first was briefly
    // « Plus d'actions », the moderation menu's name, so a screen reader heard two identical
    // buttons). The ride page stands for the
    // others here; support/ui.ts actionsMenu finds the chevron by that name, so flow-trips,
    // flow-posts and flow-ads check it on theirs.
    const { team, organizer } = await ridingTeam('menu')
    const ride = await newRide(organizer, team.slug, unique('Sortie au menu'))
    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/sorties/${ride.slug}`)
    await expect(main(page).getByRole('heading', { name: ride.name, level: 2 })).toBeVisible()
    await expect(actionsMenu(page)).toHaveAccessibleName('Options de gestion')
    const menu = await openActionsMenu(page)
    await expect(menu.getByRole('menuitem', { name: 'Annuler la sortie' })).toBeVisible()
    await page.keyboard.press('Escape')

    // The agenda's create button, whose chevron offers the other kind it lists, the trip.
    await openFeed(page, team.slug)
    await expect(main(page).getByRole('link', { name: 'Créer une sortie' })).toBeVisible()
    const createOther = main(page).getByRole('button', { name: 'Créer autre chose', exact: true })
    await hydrated(createOther)
    await createOther.click()
    await expect(
      page.getByRole('menu').getByRole('menuitem', { name: 'Créer un voyage' })
    ).toBeVisible()
  })

  test("publishing a draft ride from its page keeps its groups' leaders and its start place", async ({
    page,
  }) => {
    // RideDetailPage published by sending the RideDto back as the request ({ ...ride, status }): a
    // group's `leader` is not the request's `leaderId`, nor `startPlace` its `startPlaceId`, so
    // the update cleared them (fixed 2026-09-25).
    const { team, organizer } = await ridingTeam('meneur')
    const led = unique('Groupe mené')
    const place = await apiPost<PlaceDetailDto>(
      await roleSession('admin'),
      `/api/teams/${team.slug}/places`,
      {
        name: unique('Parvis de la cathédrale'),
        address: '1 place des Halles, Chartres',
        startPlace: true,
        endPlace: false,
        geometry: { type: 'Point', coordinates: [1.4875, 48.4469] },
      } satisfies PlaceRequest
    )
    const ride = await newRide(organizer, team.slug, unique('Sortie menée'), {
      status: 'DRAFT',
      startPlaceId: place.id,
      groups: [{ name: led, leaderId: organizer.user.id }],
    })
    expect(ride.startPlace?.id, 'precondition: the ride starts from the place').toBe(place.id)
    await signIn(page.context(), organizer)
    await page.goto(ridePath(team.slug, ride.slug))
    await expect(main(page).getByRole('heading', { name: ride.name, level: 2 })).toBeVisible()
    // Preconditions: a draft whose group shows its leader.
    await expect(main(page).getByText('Brouillon', { exact: true })).toBeVisible()
    await expect(
      groupCard(page, led).getByText(organizer.user.displayName, { exact: true })
    ).toBeVisible()

    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Publier' }).click()
    await expect(toasts(page).filter({ hasText: 'Sortie publiée avec succès' })).toBeVisible()
    await expect(main(page).getByText('Publié', { exact: true })).toBeVisible()
    const published = await readRide(organizer, team.slug, ride.slug)
    expect(published.status).toBe('PUBLISHED')
    expect(published.groups[0].leader?.id, 'the group keeps its leader').toBe(organizer.user.id)
    expect(published.startPlace?.id, 'the ride keeps its start place').toBe(place.id)
    await expect(
      groupCard(page, led).getByText(organizer.user.displayName, { exact: true })
    ).toBeVisible()
  })

  test('a ride whose group leader has left the team can still be published, cancelled and saved', async ({
    page,
  }) => {
    const { team, organizer, member } = await ridingTeam('meneur parti')
    const led = unique('Groupe du meneur parti')
    const ride = await newRide(organizer, team.slug, unique('Sortie sans son meneur'), {
      status: 'DRAFT',
      groups: [{ name: led, leaderId: member.user.id }],
    })
    // The leader leaves the team; the group keeps them, as the javadoc intends.
    await apiPost(member, `/api/teams/${team.slug}/members/leave`)
    const before = await readRide(organizer, team.slug, ride.slug)
    expect(before.groups[0].leader?.id, 'precondition: the group still names its leader').toBe(
      member.user.id
    )

    await signIn(page.context(), organizer)
    await page.goto(ridePath(team.slug, ride.slug))
    await expect(main(page).getByRole('heading', { name: ride.name, level: 2 })).toBeVisible()
    await expect(main(page).getByText('Brouillon', { exact: true })).toBeVisible()
    const shown = await watchToasts(page)

    /** Runs `act`, which saves the ride, and requires that save to succeed — its body otherwise. */
    const saving = async (step: string, act: () => Promise<void>) => {
      const saved = page.waitForResponse(
        (r) =>
          r.request().method() === 'PUT' &&
          new URL(r.url()).pathname === `/api/teams/${team.slug}/rides/${ride.slug}`
      )
      await act()
      const response = await saved
      expect(response.status(), `${step}: ${await response.text()}`).toBe(200)
    }

    // --- Publish, from the page's actions menu.
    await saving('publish', async () => {
      const menu = await openActionsMenu(page)
      await menu.getByRole('menuitem', { name: 'Publier' }).click()
    })
    await expect(toasts(page).filter({ hasText: 'Sortie publiée avec succès' })).toBeVisible()
    await expect(main(page).getByText('Publié', { exact: true })).toBeVisible()
    expect((await readRide(organizer, team.slug, ride.slug)).status).toBe('PUBLISHED')

    // --- Cancel.
    await saving('cancel', async () => {
      const menu = await openActionsMenu(page)
      await menu.getByRole('menuitem', { name: 'Annuler la sortie' }).click()
      const confirm = page.getByRole('dialog', { name: 'Annuler la sortie' })
      await confirm.getByRole('button', { name: 'Annuler la sortie' }).click()
      await expect(confirm).toBeHidden()
    })
    await expect(toasts(page).filter({ hasText: 'Sortie annulée avec succès' })).toBeVisible()
    await expect(main(page).getByText('Annulé', { exact: true })).toBeVisible()
    expect((await readRide(organizer, team.slug, ride.slug)).status).toBe('CANCELLED')

    // --- Edit, and save without changing anything.
    const edit = main(page).getByRole('link', { name: 'Modifier' })
    await hydrated(edit)
    await edit.click()
    await expect(
      main(page).getByRole('heading', { name: 'Modifier la sortie', level: 1 })
    ).toBeVisible()
    await expect(main(page).getByRole('textbox', { name: 'Nom du groupe' })).toHaveValue(led)
    await saving('save', () => main(page).getByRole('button', { name: 'Enregistrer' }).click())
    await expect(page).toHaveURL(new RegExp(`/sorties/${ride.slug}$`))
    await expect(toasts(page).filter({ hasText: 'Sortie mise à jour avec succès' })).toBeVisible()

    const after = await readRide(organizer, team.slug, ride.slug)
    expect(after.status).toBe('CANCELLED')
    expect(after.groups[0].leader?.id, 'the group keeps its leader').toBe(member.user.id)
    expect(await shown()).not.toContainEqual(
      expect.stringContaining(
        "La personne choisie comme capitaine n'appartient pas à cette équipe."
      )
    )
  })
})

test.describe('ride templates', () => {
  test('an organizer creates a template, then a ride from it', async ({ page }) => {
    const { team, organizer } = await ridingTeam('modèles')
    const templateName = unique('Modèle du dimanche')
    const description = 'Départ du local, arrêt boulangerie.'
    const first = unique('Groupe A')
    const second = unique('Groupe B')

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/admin/modeles-sortie`)
    await expect(
      main(page).getByRole('heading', { name: 'Modèles de sortie', level: 2 })
    ).toBeVisible()
    await expect(main(page).getByText('Aucun modèle', { exact: true })).toBeVisible()
    const create = main(page).getByRole('link', { name: 'Créer un modèle' }).first()
    await hydrated(create)
    await create.click()
    await expect(
      main(page).getByRole('heading', { name: 'Créer un modèle', level: 1 })
    ).toBeVisible()

    const name = main(page).getByRole('textbox', { name: 'Nom du modèle' })
    await hydrated(name)
    await name.fill(templateName)
    await richText(main(page)).fill(description)
    const groupNames = main(page).getByRole('textbox', { name: 'Nom du groupe' })
    const capacities = main(page).getByRole('textbox', { name: 'Taille max' })
    await groupNames.first().fill(first)
    await capacities.first().fill('6')
    await main(page).getByRole('button', { name: 'Ajouter un groupe' }).click()
    await expect(groupNames).toHaveCount(2)
    await groupNames.nth(1).fill(second)
    await capacities.nth(1).fill('10')
    await main(page).getByRole('button', { name: 'Créer le modèle' }).click()

    // Back on the list, which now holds it.
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/admin/modeles-sortie$`))
    await expect(main(page).getByText(templateName, { exact: true })).toBeVisible()
    const templates = await readTemplates(organizer, team.slug)
    expect(templates.templates).toHaveLength(1)
    const [template] = templates.templates
    expect(template.name).toBe(templateName)
    expect(template.markdown.trim()).toBe(description)
    expect(template.groups.map((g) => [g.name, g.maxParticipants])).toEqual([
      [first, 6],
      [second, 10],
    ])

    // --- A ride from it: the template fills the editor, the organizer only names and dates it.
    await page.goto(`/equipes/${team.slug}/sorties/nouvelle`)
    await expect(
      main(page).getByRole('heading', { name: 'Créer une sortie', level: 1 })
    ).toBeVisible()
    const load = main(page).getByRole('button', { name: 'Charger un modèle' })
    await hydrated(load)
    await load.click()
    const picker = page.getByRole('dialog', { name: 'Choisir un modèle' })
    await picker.getByRole('button').filter({ hasText: templateName }).click()
    await expect(picker).toBeHidden()

    const title = main(page).getByRole('textbox', { name: 'Titre de la sortie' })
    await expect(title).toHaveValue(templateName)
    await expect(main(page).getByRole('textbox', { name: 'Nom du groupe' })).toHaveCount(2)
    await expect(main(page).getByRole('textbox', { name: 'Nom du groupe' }).nth(0)).toHaveValue(
      first
    )
    await expect(main(page).getByRole('textbox', { name: 'Nom du groupe' }).nth(1)).toHaveValue(
      second
    )
    await expect(main(page).getByRole('textbox', { name: 'Taille max' }).nth(1)).toHaveValue('10')
    await expect(main(page).getByText(description)).toBeVisible()

    const rideName = unique('Sortie depuis modèle')
    await title.fill(rideName)
    const day = parisDaysAhead(5, 9, 15)
    await pickDateTime(page, main(page).getByRole('button', { name: 'Départ' }), day)
    await main(page).getByRole('button', { name: 'Créer la sortie' }).click()
    await expect(main(page).getByRole('heading', { name: rideName, level: 2 })).toBeVisible()
    await expect(groupCard(page, first).getByText('0/6 personnes')).toBeVisible()
    await expect(groupCard(page, second).getByText('0/10 personnes')).toBeVisible()

    const rideSlug = new URL(page.url()).pathname.split('/').pop()!
    const ride = await readRide(organizer, team.slug, rideSlug)
    expect(ride.name).toBe(rideName)
    expect(ride.media.markdown.trim()).toBe(description)
    expect(parisWallClock(ride.dateTime)).toEqual(day)
    // The template's status (PUBLISHED by default) carries over.
    expect(ride.status).toBe(template.status)
    expect(ride.groups.map((g) => [g.name, g.maxParticipants])).toEqual([
      [first, 6],
      [second, 10],
    ])
    // The template is still there, untouched, for the next ride.
    expect((await readTemplates(organizer, team.slug)).templates.map((t) => t.name)).toEqual([
      templateName,
    ])
  })
})

/**
 * One group of the ride editor (a bordered Paper per group, holding its « Nom du groupe » field),
 * by position — the name field is a controlled input, so a filter on its text would not follow it.
 */
const editorGroup = (page: Page, index: number) =>
  main(page)
    .locator('form .mantine-Paper-root')
    .filter({ has: page.getByRole('textbox', { name: 'Nom du groupe' }) })
    .nth(index)

/** Picks `who` as the leader of an editor group, through the team member search. */
async function pickLeader(group: Locator, who: { user: { displayName: string } }) {
  const search = group.getByPlaceholder("Rechercher un membre de l'équipe...")
  await hydrated(search)
  await search.fill(who.user.displayName)
  await group.getByRole('button', { name: who.user.displayName }).click()
  await expect(search).toHaveCount(0)
  await expect(group.getByText(who.user.displayName, { exact: true })).toBeVisible()
}

test.describe('group leader in the editor', () => {
  test('a leader picked in the editor is saved, shown on its group, kept by an edit of another group, then removed', async ({
    page,
  }) => {
    test.slow()
    const { team, organizer, member: leader } = await ridingTeam('meneur saisi')
    const rideName = unique('Sortie menée depuis l’éditeur')
    const led = unique('Groupe mené')
    const free = unique('Groupe libre')

    // --- Create: the member leads the first group, the second has no leader.
    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/sorties/nouvelle`)
    await expect(
      main(page).getByRole('heading', { name: 'Créer une sortie', level: 1 })
    ).toBeVisible()
    const title = main(page).getByRole('textbox', { name: 'Titre de la sortie' })
    await hydrated(title)
    await title.fill(rideName)
    await editorGroup(page, 0).getByRole('textbox', { name: 'Nom du groupe' }).fill(led)
    await pickLeader(editorGroup(page, 0), leader)
    await main(page).getByRole('button', { name: 'Ajouter un groupe' }).click()
    await editorGroup(page, 1).getByRole('textbox', { name: 'Nom du groupe' }).fill(free)
    await expect(
      editorGroup(page, 1).getByPlaceholder("Rechercher un membre de l'équipe...")
    ).toBeVisible()
    await main(page).getByRole('radio', { name: 'Publié' }).check()
    await main(page).getByRole('button', { name: 'Créer la sortie' }).click()

    await expect(main(page).getByRole('heading', { name: rideName, level: 2 })).toBeVisible()
    const rideSlug = new URL(page.url()).pathname.split('/').pop()!
    const ledCard = groupCard(page, led)
    const freeCard = groupCard(page, free)
    await expect(ledCard.getByText('Capitaine', { exact: true })).toBeVisible()
    await expect(ledCard.getByText(leader.user.displayName, { exact: true })).toBeVisible()
    await expect(ledCard.getByText(organizer.user.displayName)).toHaveCount(0)
    await expect(freeCard).toBeVisible()
    await expect(freeCard.getByText('Capitaine', { exact: true })).toHaveCount(0)
    let saved = await readRide(organizer, team.slug, rideSlug)
    expect(saved.groups.map((g) => [g.name, g.leader?.id])).toEqual([
      [led, leader.user.id],
      [free, undefined],
    ])

    // --- Edit: the row names the leader (not « Nom inconnu »); changing the other group keeps it.
    const openEditor = async () => {
      const edit = main(page).getByRole('link', { name: 'Modifier' })
      await hydrated(edit)
      await edit.click()
      await expect(
        main(page).getByRole('heading', { name: 'Modifier la sortie', level: 1 })
      ).toBeVisible()
      await expect(
        editorGroup(page, 0).getByRole('textbox', { name: 'Nom du groupe' })
      ).toHaveValue(led)
    }
    await openEditor()
    await expect(
      editorGroup(page, 0).getByText(leader.user.displayName, { exact: true })
    ).toBeVisible()
    await expect(main(page).getByText('Nom inconnu', { exact: true })).toHaveCount(0)
    const capacity = editorGroup(page, 1).getByRole('textbox', { name: 'Taille max' })
    await hydrated(capacity)
    await capacity.fill('7')
    await main(page).getByRole('button', { name: 'Enregistrer' }).click()
    await expect(page).toHaveURL(new RegExp(`/sorties/${rideSlug}$`))
    await expect(freeCard.getByText('0/7 personnes')).toBeVisible()
    await expect(ledCard.getByText(leader.user.displayName, { exact: true })).toBeVisible()
    saved = await readRide(organizer, team.slug, rideSlug)
    expect(saved.groups.map((g) => [g.name, g.leader?.id, g.maxParticipants])).toEqual([
      [led, leader.user.id, undefined],
      [free, undefined, 7],
    ])

    // --- Edit again: « Retirer » clears the leader, and the save sends it cleared.
    await openEditor()
    const remove = editorGroup(page, 0).getByRole('button', { name: 'Retirer' })
    await hydrated(remove)
    await remove.click()
    await expect(editorGroup(page, 0).getByText(leader.user.displayName)).toHaveCount(0)
    await expect(
      editorGroup(page, 0).getByPlaceholder("Rechercher un membre de l'équipe...")
    ).toBeVisible()
    await main(page).getByRole('button', { name: 'Enregistrer' }).click()
    await expect(page).toHaveURL(new RegExp(`/sorties/${rideSlug}$`))
    await expect(ledCard).toBeVisible()
    await expect(ledCard.getByText('Capitaine', { exact: true })).toHaveCount(0)
    await expect(ledCard.getByText(leader.user.displayName)).toHaveCount(0)
    // Never the ride's creator in the leader's place.
    await expect(main(page).getByText('Capitaine', { exact: true })).toHaveCount(0)
    saved = await readRide(organizer, team.slug, rideSlug)
    expect(saved.groups.map((g) => [g.name, g.leader])).toEqual([
      [led, undefined],
      [free, undefined],
    ])
  })
})

test.describe('ride templates, edited and deleted', () => {
  test('an organizer renames, removes and adds groups of a template, then deletes it: it is no longer offered to a new ride', async ({
    page,
  }) => {
    test.slow()
    const { team, organizer } = await ridingTeam('modèles modifiés')
    const templateName = unique('Modèle à retoucher')
    const keptName = unique('Modèle qui reste')
    const first = unique('Groupe rapide')
    const second = unique('Groupe à retirer')
    const renamed = unique('Groupe très rapide')
    const added = unique('Groupe ajouté')
    const templateRequest = (name: string, groups: RideTemplateGroupRequest[]) =>
      ({
        name,
        markdown: 'Départ du local.',
        visibility: 'TEAM',
        status: 'PUBLISHED',
        groups,
      }) satisfies RideTemplateRequest
    await apiPost<RideTemplateDto>(
      organizer,
      `/api/teams/${team.slug}/ride-templates`,
      templateRequest(templateName, [
        { name: first, maxParticipants: 6 },
        { name: second, maxParticipants: 10 },
      ])
    )
    // A second template, left alone: the picker showing it is what says the list is in.
    await apiPost<RideTemplateDto>(
      organizer,
      `/api/teams/${team.slug}/ride-templates`,
      templateRequest(keptName, [{ name: unique('Groupe unique') }])
    )

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/admin/modeles-sortie`)
    await expect(
      main(page).getByRole('heading', { name: 'Modèles de sortie', level: 2 })
    ).toBeVisible()
    const row = (name: string) =>
      main(page)
        .locator('.mantine-Paper-root')
        .filter({ has: page.getByText(name, { exact: true }) })
    await expect(row(templateName)).toBeVisible()
    await expect(row(templateName).getByText('2 groupes')).toBeVisible()

    // --- Edit: rename the first group, remove the second, add a third.
    const edit = row(templateName).getByRole('link', { name: 'Modifier' })
    await hydrated(edit)
    await edit.click()
    await expect(
      main(page).getByRole('heading', { name: 'Modifier le modèle', level: 1 })
    ).toBeVisible()
    const names = main(page).getByRole('textbox', { name: 'Nom du groupe' })
    await expect(names).toHaveCount(2)
    await expect(names.nth(0)).toHaveValue(first)
    await expect(names.nth(1)).toHaveValue(second)
    await hydrated(names.nth(0))
    await names.nth(0).fill(renamed)
    const groupPapers = main(page)
      .locator('form .mantine-Paper-root')
      .filter({ has: page.getByRole('textbox', { name: 'Nom du groupe' }) })
    await groupPapers.nth(1).getByRole('button', { name: 'Supprimer' }).click()
    await expect(names).toHaveCount(1)
    await main(page).getByRole('button', { name: 'Ajouter un groupe' }).click()
    await expect(names).toHaveCount(2)
    await names.nth(1).fill(added)
    await main(page).getByRole('textbox', { name: 'Taille max' }).nth(1).fill('12')
    await main(page).getByRole('button', { name: 'Enregistrer' }).click()

    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/admin/modeles-sortie$`))
    await expect(toasts(page).filter({ hasText: 'Modèle mis à jour avec succès' })).toBeVisible()
    await expect(row(templateName).getByText(renamed, { exact: true })).toBeVisible()
    await expect(row(templateName).getByText(added, { exact: true })).toBeVisible()
    await expect(row(templateName).getByText(second, { exact: true })).toHaveCount(0)
    await expect(row(templateName).getByText(first, { exact: true })).toHaveCount(0)
    let template = (await readTemplates(organizer, team.slug)).templates.find(
      (t) => t.name === templateName
    )
    // By sortOrder: the list comes back in no stable order after an edit (see 'a template keeps
    // the order of its groups after an edit' below).
    const bySortOrder = [...(template?.groups ?? [])].sort((a, b) => a.sortOrder - b.sortOrder)
    expect(bySortOrder.map((g) => [g.name, g.maxParticipants])).toEqual([
      [renamed, 6],
      [added, 12],
    ])

    // --- Delete, confirmed.
    const remove = row(templateName).getByRole('button', { name: 'Supprimer' })
    await hydrated(remove)
    await remove.click()
    const confirm = page.getByRole('dialog', { name: 'Supprimer le modèle' })
    await expect(
      confirm.getByText(`Voulez-vous vraiment supprimer le modèle "${templateName}" ?`)
    ).toBeVisible()
    await confirm.getByRole('button', { name: 'Supprimer le modèle' }).click()
    await expect(confirm).toBeHidden()
    await expect(toasts(page).filter({ hasText: 'Modèle supprimé avec succès' })).toBeVisible()
    await expect(row(keptName)).toBeVisible()
    await expect(row(templateName)).toHaveCount(0)
    template = (await readTemplates(organizer, team.slug)).templates.find(
      (t) => t.name === templateName
    )
    expect(template, 'the API no longer lists it').toBeUndefined()

    // --- « Charger un modèle » on a new ride offers the other one only.
    await page.goto(`/equipes/${team.slug}/sorties/nouvelle`)
    await expect(
      main(page).getByRole('heading', { name: 'Créer une sortie', level: 1 })
    ).toBeVisible()
    const load = main(page).getByRole('button', { name: 'Charger un modèle' })
    await hydrated(load)
    await load.click()
    const picker = page.getByRole('dialog', { name: 'Choisir un modèle' })
    await expect(picker.getByRole('button').filter({ hasText: keptName })).toBeVisible()
    await expect(picker.getByRole('button').filter({ hasText: templateName })).toHaveCount(0)
    await expect(picker.getByText(renamed)).toHaveCount(0)
  })

  test('cancelling the deletion keeps the template', async ({ page }) => {
    const { team, organizer } = await ridingTeam('modèle gardé')
    const templateName = unique('Modèle presque supprimé')
    await apiPost<RideTemplateDto>(organizer, `/api/teams/${team.slug}/ride-templates`, {
      name: templateName,
      markdown: '',
      visibility: 'TEAM',
      status: 'PUBLISHED',
      groups: [{ name: unique('Groupe') }],
    } satisfies RideTemplateRequest)

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/admin/modeles-sortie`)
    const row = main(page)
      .locator('.mantine-Paper-root')
      .filter({ has: page.getByText(templateName, { exact: true }) })
    const remove = row.getByRole('button', { name: 'Supprimer' })
    await hydrated(remove)
    await remove.click()
    const confirm = page.getByRole('dialog', { name: 'Supprimer le modèle' })
    await expect(confirm).toBeVisible()
    await confirm.getByRole('button', { name: 'Annuler' }).click()
    await expect(confirm).toBeHidden()
    await expect(row).toBeVisible()
    expect((await readTemplates(organizer, team.slug)).templates.map((t) => t.name)).toEqual([
      templateName,
    ])
  })
})

test.describe('ride templates, regressions', () => {
  test('a template keeps the order of its groups after an edit', async () => {
    // Regression (667574f6): RideTemplate.groups is @OrderBy("sortOrder") — before, an edit that kept a group
    // and added one gave the groups back in the wrong order 17 times out of 20. Five templates, so
    // the order holding by chance on all of them is out of reach.
    const { team, organizer } = await ridingTeam('ordre des groupes')
    const orders: string[][] = []
    for (let i = 0; i < 5; i++) {
      const created = await apiPost<RideTemplateDto>(
        organizer,
        `/api/teams/${team.slug}/ride-templates`,
        {
          name: unique('Modèle ordonné'),
          markdown: '',
          visibility: 'TEAM',
          status: 'PUBLISHED',
          groups: [{ name: 'Premier' }, { name: 'Retiré' }],
        } satisfies RideTemplateRequest
      )
      // What EditRideTemplatePage sends for « rename the first, remove the second, add one ».
      await apiPut<RideTemplateDto>(
        organizer,
        `/api/teams/${team.slug}/ride-templates/${created.slug}`,
        {
          name: created.name,
          markdown: '',
          visibility: 'TEAM',
          status: 'PUBLISHED',
          groups: [{ id: created.groups[0].id, name: 'Premier renommé' }, { name: 'Ajouté' }],
        } satisfies RideTemplateRequest
      )
      const read = await apiGet<RideTemplateDto>(
        organizer,
        `/api/teams/${team.slug}/ride-templates/${created.slug}`
      )
      orders.push(read.groups.map((g) => g.name))
    }
    expect(orders).toEqual(Array(5).fill(['Premier renommé', 'Ajouté']))
  })
})

test.describe('a route from the ride editor', () => {
  test('« Créer un nouveau parcours » from the route picker creates the route and selects it for the ride', async ({
    page,
  }) => {
    // Regression (74efdc0d): RouteEditor's form stops its submit's propagation — before, React carried
    // the modal's `submit` through the portal to the ride's <form>, which was created at once, as a
    // draft without the route.
    test.slow()
    const { team, organizer } = await ridingTeam('parcours créé')
    const rideName = unique('Sortie au parcours neuf')
    const routeName = unique('Boucle créée en route')
    const ridePosts: string[] = []
    page.on('request', (request) => {
      if (
        request.method() === 'POST' &&
        new URL(request.url()).pathname === `/api/teams/${team.slug}/rides`
      )
        ridePosts.push(request.url())
    })

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/sorties/nouvelle`)
    await expect(
      main(page).getByRole('heading', { name: 'Créer une sortie', level: 1 })
    ).toBeVisible()
    const title = main(page).getByRole('textbox', { name: 'Titre de la sortie' })
    await hydrated(title)
    await title.fill(rideName)
    await main(page).getByRole('textbox', { name: 'Nom du groupe' }).fill(unique('Groupe'))

    // The ride's route picker (the first; the others are the groups').
    await main(page).getByRole('button', { name: 'Sélectionner un parcours' }).first().click()
    const picker = page.getByRole('dialog', { name: 'Sélectionner un parcours pour la sortie' })
    const createNew = picker.getByRole('button', { name: 'Créer un nouveau parcours' })
    await expect(createNew).toBeVisible()
    await createNew.click()
    await expect(picker).toBeHidden()

    const modal = page.getByRole('dialog', { name: 'Créer un nouveau parcours' })
    await expect(modal).toBeVisible()
    await modal.locator('input[type="file"][accept=".gpx"]').setInputFiles({
      name: 'boucle-neuve.gpx',
      mimeType: 'application/gpx+xml',
      buffer: Buffer.from(gpxOf(routeName, windingTrack(80))),
    })
    const nameInput = modal.getByRole('textbox', { name: 'Nom du parcours' })
    await expect(nameInput).toHaveValue('boucle-neuve')
    await nameInput.fill(routeName)
    const created = page.waitForResponse(
      (r) =>
        r.request().method() === 'POST' &&
        new URL(r.url()).pathname === `/api/teams/${team.slug}/routes`
    )
    await modal.getByRole('button', { name: 'Créer le parcours' }).click()
    const createdResponse = await created
    expect(createdResponse.status()).toBe(201)
    const route = (await createdResponse.json()) as RouteDto
    expect(route.name).toBe(routeName)
    // Creating the route creates nothing else: a ride's submit would have left before it.
    expect(ridePosts, 'no ride is created with the route').toEqual([])

    // Back on the ride editor, the modal closed, the new route chosen for the ride.
    await expect(modal).toBeHidden()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/sorties/nouvelle$`))
    await expect(title).toHaveValue(rideName)
    await expect(main(page).getByText(routeName)).toBeVisible()
    // Only the group is still without a route.
    await expect(main(page).getByText('Aucun parcours sélectionné')).toHaveCount(1)

    await main(page).getByRole('button', { name: 'Créer la sortie' }).click()
    await expect(main(page).getByRole('heading', { name: rideName, level: 2 })).toBeVisible()
    const rideSlug = new URL(page.url()).pathname.split('/').pop()!
    const saved = await readRide(organizer, team.slug, rideSlug)
    expect(saved.routeSlug).toBe(route.slug)
    const stored = await getRoute(organizer, team.slug, route.slug)
    expect(stored.name).toBe(routeName)
    // 79 steps of 50 m eastward, on a 300 m sine northward (windingTrack): ~5 250 m along the track.
    expect(stored.distance).toBeGreaterThan(5_100)
    expect(stored.distance).toBeLessThan(5_400)
  })

  test('a public ride on a members-only route is refused with a translated message, the form kept and nothing created', async ({
    page,
  }) => {
    const owner = await roleSession('admin')
    const team = await newTeam(owner, unique('Flow sorties publique'), { visibility: 'PUBLIC' })
    const organizer = await newUser(unique('Organisatrice'))
    await addMember(owner, team.slug, organizer, 'ORGANIZER')
    const routeName = unique('Parcours réservé')
    const route = await newRoute(organizer, team.slug, routeName, windingTrack(60), {
      visibility: 'TEAM',
    })
    const rideName = unique('Sortie publique')
    const group = unique('Groupe ouvert')

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/sorties/nouvelle`)
    await expect(
      main(page).getByRole('heading', { name: 'Créer une sortie', level: 1 })
    ).toBeVisible()
    const title = main(page).getByRole('textbox', { name: 'Titre de la sortie' })
    await hydrated(title)
    await title.fill(rideName)
    await main(page).getByRole('textbox', { name: 'Nom du groupe' }).fill(group)
    // A public team's ride is born public: its editor offers the choice.
    await expect(main(page).getByRole('radio', { name: 'Public', exact: true })).toBeChecked()
    await main(page).getByRole('button', { name: 'Sélectionner un parcours' }).first().click()
    const picker = page.getByRole('dialog', { name: 'Sélectionner un parcours pour la sortie' })
    await picker.getByRole('button').filter({ hasText: routeName }).click()
    await expect(picker).toBeHidden()

    const shown = await watchToasts(page)
    const refused = page.waitForResponse(
      (r) =>
        r.request().method() === 'POST' &&
        new URL(r.url()).pathname === `/api/teams/${team.slug}/rides`
    )
    await main(page).getByRole('button', { name: 'Créer la sortie' }).click()
    const response = await refused
    expect(response.status()).toBe(400)
    expect(((await response.json()) as { code?: string }).code).toBe('PUBLIC_RIDE_PRIVATE_ROUTE')

    await expect(
      toasts(page).filter({ hasText: 'Une sortie publique ne peut pas utiliser un parcours privé' })
    ).toBeVisible()
    expect(await shown()).not.toContainEqual(expect.stringContaining('PUBLIC_RIDE_PRIVATE_ROUTE'))
    // Still on the editor, with everything typed.
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/sorties/nouvelle$`))
    await expect(title).toHaveValue(rideName)
    await expect(main(page).getByRole('textbox', { name: 'Nom du groupe' })).toHaveValue(group)
    await expect(main(page).getByText(routeName)).toBeVisible()
    await expect(main(page).getByRole('radio', { name: 'Public', exact: true })).toBeChecked()
    // Nothing was created.
    const count = await apiGet<CountResponse>(
      organizer,
      `/api/teams/${team.slug}/publications/count`
    )
    expect(count.total).toBe(0)

    // Choosing « Équipe uniquement » is the way out: the same ride is created.
    await main(page).getByRole('radio', { name: 'Équipe uniquement' }).check()
    await main(page).getByRole('button', { name: 'Créer la sortie' }).click()
    await expect(main(page).getByRole('heading', { name: rideName, level: 2 })).toBeVisible()
    const rideSlug = new URL(page.url()).pathname.split('/').pop()!
    const saved = await readRide(organizer, team.slug, rideSlug)
    expect(saved.visibility).toBe('TEAM')
    expect(saved.routeSlug).toBe(route.slug)
  })
})

test.describe('restoring a ride', () => {
  test('« Restaurer la sortie » turns a cancelled ride back into a draft, keeping its description, leaders and routes', async ({
    page,
  }) => {
    const { team, organizer, member: leader } = await ridingTeam('restaurée')
    const rideRouteName = unique('Boucle principale')
    const groupRouteName = unique('Boucle du groupe')
    const rideRoute = await newRoute(organizer, team.slug, rideRouteName, windingTrack(60))
    const groupRoute = await newRoute(organizer, team.slug, groupRouteName, windingTrack(40))
    const led = unique('Groupe mené')
    const description = `Rendez-vous au local, ${unique('texte')}.`
    const ride = await newRide(organizer, team.slug, unique('Sortie à restaurer'), {
      status: 'CANCELLED',
      media: markdownMedia(description),
      routeSlug: rideRoute.slug,
      groups: [{ name: led, leaderId: leader.user.id, routeSlug: groupRoute.slug }],
    })

    await signIn(page.context(), organizer)
    await page.goto(ridePath(team.slug, ride.slug))
    await expect(main(page).getByRole('heading', { name: ride.name, level: 2 })).toBeVisible()
    await expect(main(page).getByText('Annulé', { exact: true })).toBeVisible()

    const menu = await openActionsMenu(page)
    await expect(menu.getByRole('menuitem', { name: 'Publier' })).toHaveCount(0)
    await menu.getByRole('menuitem', { name: 'Restaurer la sortie' }).click()
    const confirm = page.getByRole('dialog', { name: 'Restaurer la sortie' })
    await expect(
      confirm.getByText(
        'Voulez-vous vraiment restaurer cette sortie ? Elle repassera en brouillon.'
      )
    ).toBeVisible()
    await confirm.getByRole('button', { name: 'Restaurer la sortie' }).click()
    await expect(confirm).toBeHidden()
    await expect(toasts(page).filter({ hasText: 'Sortie restaurée avec succès' })).toBeVisible()
    await expect(main(page).getByText('Brouillon', { exact: true })).toBeVisible()
    await expect(main(page).getByText('Annulé', { exact: true })).toHaveCount(0)
    await expect(main(page).getByText(description)).toBeVisible()
    await expect(
      groupCard(page, led).getByText(leader.user.displayName, { exact: true })
    ).toBeVisible()

    const restored = await readRide(organizer, team.slug, ride.slug)
    expect(restored.status).toBe('DRAFT')
    expect(restored.media.markdown.trim()).toBe(description)
    expect(restored.routeSlug).toBe(rideRoute.slug)
    expect(restored.groups.map((g) => [g.name, g.leader?.id, g.routeSlug])).toEqual([
      [led, leader.user.id, groupRoute.slug],
    ])
    // A draft again: publishable from the same menu.
    const again = await openActionsMenu(page)
    await expect(again.getByRole('menuitem', { name: 'Publier' })).toBeVisible()
  })

  test('a team admin restores a deleted ride from its page, with its leaders and routes', async ({
    page,
  }) => {
    const { team, organizer, member: leader } = await ridingTeam('supprimée')
    const route = await newRoute(organizer, team.slug, unique('Boucle gardée'), windingTrack(40))
    const led = unique('Groupe mené')
    const ride = await newRide(organizer, team.slug, unique('Sortie supprimée'), {
      routeSlug: route.slug,
      groups: [{ name: led, leaderId: leader.user.id }],
    })
    await apiDelete(organizer, `/api/teams/${team.slug}/rides/${ride.slug}`)
    expect(
      await findRide(leader, team.slug, ride.slug),
      'precondition: gone for members'
    ).toBeNull()

    // The team's admin (the platform admin owns every team of this file) still reads it.
    const admin = await roleSession('admin')
    await signIn(page.context(), admin)
    await page.goto(ridePath(team.slug, ride.slug))
    await expect(main(page).getByRole('heading', { name: ride.name, level: 2 })).toBeVisible()
    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Restaurer', exact: true }).click()
    await expect(toasts(page).filter({ hasText: 'Sortie restaurée avec succès' })).toBeVisible()
    await expect(main(page).getByText('Publié', { exact: true })).toBeVisible()

    const restored = await readRide(leader, team.slug, ride.slug)
    expect(restored.status).toBe('PUBLISHED')
    expect(restored.routeSlug).toBe(route.slug)
    expect(restored.groups.map((g) => [g.name, g.leader?.id])).toEqual([[led, leader.user.id]])
    const reopened = await openActionsMenu(page)
    await expect(reopened.getByRole('menuitem', { name: 'Restaurer', exact: true })).toHaveCount(0)
  })
})

test.describe('editing a ride that has registrations', () => {
  /** The editor's « Nom du groupe » fields hold `expected`, in that order and no others. */
  async function expectGroupNames(page: Page, expected: string[]) {
    const names = main(page).getByRole('textbox', { name: 'Nom du groupe' })
    await expect(names).toHaveCount(expected.length)
    for (const [i, name] of expected.entries()) await expect(names.nth(i)).toHaveValue(name)
  }

  test('moving, renaming and redescribing groups keeps each registration in its own group, and each leader on theirs', async ({
    page,
    browser,
  }) => {
    // The editor keeps each group's id in its form values (rideFormData.ts:144-145, the initial
    // values of EditRidePage.tsx:88), and
    // RideService.updateRide matches groups by that id (RideService.java:262-274) — the
    // list position only sets sortOrder. A form that lost the id (a row keyed by index, a reorder that
    // rebuilt the rows) would have the server delete the group and its registrations, then create
    // a new one under the same name.
    test.slow()
    const { team, organizer, member } = await ridingTeam('inscrits gardés')
    const leader = await newUser(unique('Meneuse'))
    await addMember(await roleSession('admin'), team.slug, leader)
    const joined = unique('Groupe rejoint')
    const renamed = unique('Groupe rejoint renommé')
    const second = unique('Groupe du milieu')
    const led = unique('Groupe mené')
    const description = `Nouveau point de café, ${unique('texte')}.`
    const ride = await newRide(organizer, team.slug, unique('Sortie remaniée'), {
      groups: [
        { name: joined, maxParticipants: 10 },
        { name: second, maxParticipants: 10 },
        { name: led, maxParticipants: 10, leaderId: leader.user.id },
      ],
    })
    const [joinedId, secondId, ledId] = ride.groups.map((g) => g.id)
    await apiPost(member, `/api/teams/${team.slug}/rides/${ride.slug}/groups/${joinedId}/join`)

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/sorties/${ride.slug}/modifier`)
    await expect(
      main(page).getByRole('heading', { name: 'Modifier la sortie', level: 1 })
    ).toBeVisible()
    const names = main(page).getByRole('textbox', { name: 'Nom du groupe' })
    await expect(names).toHaveCount(3)
    await expect(names.nth(0)).toHaveValue(joined)

    // The joined group goes down twice (to the end), then is renamed; the description changes.
    const down = editorGroup(page, 0).getByRole('button', { name: 'Déplacer vers le bas' })
    await hydrated(down)
    await down.click()
    await expect(names.nth(1)).toHaveValue(joined)
    await editorGroup(page, 1).getByRole('button', { name: 'Déplacer vers le bas' }).click()
    await expectGroupNames(page, [second, led, joined])
    await names.nth(2).fill(renamed)
    await richText(main(page)).fill(description)
    await main(page).getByRole('button', { name: 'Enregistrer' }).click()
    await expect(page).toHaveURL(new RegExp(`/sorties/${ride.slug}$`))
    await expect(toasts(page).filter({ hasText: 'Sortie mise à jour avec succès' })).toBeVisible()

    const saved = await readRide(organizer, team.slug, ride.slug)
    expect(saved.media.markdown.trim()).toBe(description)
    expect(
      saved.groups.map((g) => [g.id, g.name, g.countParticipants, g.leader?.id]),
      'same ids, new order, the registration and the leader where they were'
    ).toEqual([
      [secondId, second, 0, undefined],
      [ledId, led, 0, leader.user.id],
      [joinedId, renamed, 1, undefined],
    ])
    const asMember = await readRide(member, team.slug, ride.slug)
    expect(asMember.registered).toBe(true)
    expect(asMember.registeredGroupId).toBe(joinedId)

    // The member's page says so: registered in the renamed group, which has no leader — never the
    // ride's creator in its place.
    const { context: memberContext, page: memberPage } = await pageAs(browser, member)
    try {
      await memberPage.goto(ridePath(team.slug, ride.slug))
      await expect(
        main(memberPage).getByRole('heading', { name: ride.name, level: 2 })
      ).toBeVisible()
      const card = groupCard(memberPage, renamed)
      await expect(card.getByText("J'y vais", { exact: true })).toBeVisible()
      await expect(card.getByText('1/10 personnes')).toBeVisible()
      await expect(card.getByText('Capitaine', { exact: true })).toHaveCount(0)
      await expect(card.getByText(organizer.user.displayName)).toHaveCount(0)
      await expect(
        groupCard(memberPage, led).getByText(leader.user.displayName, { exact: true })
      ).toBeVisible()
      await expect(main(memberPage).getByText(joined, { exact: true })).toHaveCount(0)
    } finally {
      await memberContext.close()
    }
  })

  test('removing a group that has a registration asks first, and its riders are told', async ({
    page,
    browser,
  }) => {
    // Decided on 2026-09-28 (34431a89): RideEditor asks before dropping a group that has riders,
    // and RideService.updateRide publishes RIDE_GROUP_REMOVED to them (the organizer who removed it
    // is not told). The registrations still go with the group (RideGroup.participations, cascade
    // ALL, orphanRemoval). A group with no rider is removed without a dialog, as before.
    const { team, organizer, member } = await ridingTeam('groupe retiré')
    const doomed = unique('Groupe retiré')
    const kept = unique('Groupe gardé')
    const empty = unique('Groupe vide')
    const ride = await newRide(organizer, team.slug, unique('Sortie amputée'), {
      groups: [
        { name: doomed, maxParticipants: 10 },
        { name: kept, maxParticipants: 10 },
        { name: empty, maxParticipants: 10 },
      ],
    })
    const [doomedId, keptId] = ride.groups.map((g) => g.id)
    await apiPost(member, `/api/teams/${team.slug}/rides/${ride.slug}/groups/${doomedId}/join`)
    const before = await readRide(member, team.slug, ride.slug)
    expect(before.registeredGroupId, 'precondition: registered in the doomed group').toBe(doomedId)

    await signIn(page.context(), organizer)
    await page.goto(`/equipes/${team.slug}/sorties/${ride.slug}/modifier`)
    await expect(
      main(page).getByRole('heading', { name: 'Modifier la sortie', level: 1 })
    ).toBeVisible()
    await expectGroupNames(page, [doomed, kept, empty])

    // A group with no rider goes at once, without a dialog.
    const removeEmpty = editorGroup(page, 2).getByRole('button', { name: 'Supprimer' })
    await hydrated(removeEmpty)
    await removeEmpty.click()
    await expectGroupNames(page, [doomed, kept])
    await expect(page.getByRole('dialog')).toHaveCount(0)

    // A group with a rider asks first, and says what will happen; cancelling keeps it.
    const remove = editorGroup(page, 0).getByRole('button', { name: 'Supprimer' })
    await remove.click()
    const dialog = page.getByRole('dialog', { name: 'Retirer un groupe avec des inscriptions' })
    await expect(dialog).toBeVisible()
    await expect(dialog).toContainText(
      "Ce groupe compte 1 inscription. À l'enregistrement, elle sera supprimée et la personne prévenue."
    )
    await dialog.getByRole('button', { name: 'Annuler' }).click()
    await expect(dialog).toHaveCount(0)
    await expectGroupNames(page, [doomed, kept])

    await remove.click()
    await dialog.getByRole('button', { name: 'Retirer le groupe' }).click()
    await expect(dialog).toHaveCount(0)
    await expectGroupNames(page, [kept])

    const saved = page.waitForResponse(
      (r) =>
        r.request().method() === 'PUT' &&
        new URL(r.url()).pathname === `/api/teams/${team.slug}/rides/${ride.slug}`
    )
    await main(page).getByRole('button', { name: 'Enregistrer' }).click()
    expect((await saved).status()).toBe(200)
    await expect(page).toHaveURL(new RegExp(`/sorties/${ride.slug}$`))
    await expect(groupCard(page, kept)).toBeVisible()
    await expect(main(page).getByText(doomed, { exact: true })).toHaveCount(0)

    const after = await readRide(member, team.slug, ride.slug)
    expect(after.groups.map((g) => [g.id, g.countParticipants])).toEqual([[keptId, 0]])
    expect(after.registered, 'the registration went with its group').toBe(false)
    expect(after.registeredGroupId).toBeUndefined()
    expect(after.participantCount).toBe(0)

    // The rider is told, by the group's name; the organizer who removed it is not.
    const told = await waitForNotification(
      member,
      (n) => n.type === 'RIDE_GROUP_REMOVED' && n.excerpt === doomed,
      'RIDE_GROUP_REMOVED for the removed group'
    )
    expect(told.subjectSlug).toBe(ride.slug)
    await expectNoNotification(
      organizer,
      (n) => n.type === 'RIDE_GROUP_REMOVED' && n.excerpt === doomed,
      'the organizer who removed the group is not told'
    )

    // The member finds the ride open again, and can join the remaining group.
    const { context: memberContext, page: memberPage } = await pageAs(browser, member)
    try {
      await memberPage.goto(ridePath(team.slug, ride.slug))
      await expect(
        main(memberPage).getByRole('heading', { name: ride.name, level: 2 })
      ).toBeVisible()
      const card = groupCard(memberPage, kept)
      await expect(card.getByText('0/10 personnes')).toBeVisible()
      await expect(card.getByRole('button', { name: 'Rejoindre' })).toBeVisible()
      await expect(main(memberPage).getByText("J'y vais", { exact: true })).toHaveCount(0)
    } finally {
      await memberContext.close()
    }
  })
})
