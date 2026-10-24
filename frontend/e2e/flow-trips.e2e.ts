import type { Locator, Page } from '@playwright/test'
import type { CommentListResponse, TripDto, TripRequest } from '../src/api/dto'
import { ApiError, apiDelete, apiGet, apiPost, apiPut } from './support/api'
import { calendarEvent, openCalendar, teamEvents } from './support/calendar'
import { addMember, markdownMedia, newTeam, newUser, roleSession, signIn } from './support/data'
import {
  frenchDateTime,
  openPicker,
  parisDaysAhead,
  parisInstant,
  parisWallClock,
  pickDateTime,
  twoDaysThisMonth,
  wallTimeOf,
} from './support/dates'
import { letEditorSettle, richText } from './support/editor'
import { expect, test, unique } from './support/fixtures'
import { about, expectNoNotification, waitForNotification } from './support/notifications'
import {
  fetchTrip,
  newRoute,
  newTrip,
  stagePath,
  stubBasemap,
  traceMapPixels,
  tripNewPath,
  tripPath,
  windingTrack,
} from './support/routes'
import {
  pastPublishAt,
  pickIntoEmptyPicker,
  waitForAutoPublish,
} from './support/scheduled-publication'
import { entityCard, hydrated, openActionsMenu, pageAs, startsWith, toasts } from './support/ui'

/**
 * Trips, the nominal journey through the web UI: a team admin creates a trip and its two stages
 * with the form (dates, a route on one of them), reads the trip page (stages in order, map), a
 * member registers and leaves, the team admin edits a stage, deletes another, then deletes the
 * trip. The team calendar lists the stages — never the trip itself, by design (docs/LEDGER_*.md MOB-6).
 *
 * Every test owns its team: a fresh user creates it — and so is its ADMIN, not a mere teamAdmin: a
 * deleted trip stays readable to them — and the platform admin adds the member (a team's own admins
 * may not, see data.ts addMember).
 */

async function tripTeam(label: string) {
  const teamAdmin = await newUser(unique('Admin voyages'))
  const team = await newTeam(teamAdmin, unique(`Voyages ${label}`))
  return { teamAdmin, team }
}

/** The stage cards of the trip page, in page order (each is a link to its stage). */
const stageCards = (main: Locator) => main.getByRole('link', { name: /^\d+ / })

/** A team of its own, with a member the platform admin added. */
async function tripTeamWithMember(label: string) {
  const { teamAdmin, team } = await tripTeam(label)
  const member = await newUser(unique('Membre'))
  await addMember(await roleSession('admin'), team.slug, member)
  return { teamAdmin, team, member }
}

/** The team agenda (WEB-68), loaded — its count shown — before any presence or absence check. */
async function openFeed(page: Page, teamSlug: string) {
  await page.goto(`/equipes/${teamSlug}/agenda`)
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { name: 'Agenda', level: 2 })).toBeVisible()
  await expect(main.getByText(/^\d+ sorties? (et|ou) voyages? à venir$/)).toBeVisible()
  return main
}

/** Opens the trip page and waits for its title and its stage list. */
async function openTrip(page: Page, teamSlug: string, tripSlug: string, name: string) {
  await page.goto(tripPath(teamSlug, tripSlug))
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 2, name })).toBeVisible()
  await expect(main.getByRole('heading', { level: 3, name: 'Étapes' })).toBeVisible()
  return main
}

/** The request that leaves `trip` as it is, but for `changes` — tripToRequest, in short. */
const requestOf = (trip: TripDto, changes: Partial<TripRequest>): TripRequest => ({
  name: trip.name,
  media: trip.media,
  dateTime: wallTimeOf(trip.dateTime, trip.timezone),
  status: trip.status,
  visibility: trip.visibility,
  routeSlug: trip.routeSlug,
  publishAt: trip.publishAt && wallTimeOf(trip.publishAt, trip.timezone),
  stages: trip.stages.map((stage) => ({
    id: stage.id,
    name: stage.name,
    dateTime: wallTimeOf(stage.dateTime, stage.timezone ?? trip.timezone),
    routeSlug: stage.route?.slug,
    media: stage.media,
  })),
  ...changes,
})

test('a team admin creates a trip and its two stages with the form; the calendar shows the stages', async ({
  page,
}) => {
  const { teamAdmin, team } = await tripTeam('création')
  // The route exists beforehand: picking it is the form's job, drawing it is not.
  const route = await newRoute(teamAdmin, team.slug, unique('Boucle beauceronne'), windingTrack())
  const tripName = unique('Voyage en Beauce')
  const first = { name: unique('Chartres – Bonneval'), when: twoDaysThisMonth()[0] }
  const second = { name: unique('Bonneval – Châteaudun'), when: twoDaysThisMonth()[1] }

  await stubBasemap(page)
  await signIn(page.context(), teamAdmin)
  await page.goto(tripNewPath(team.slug))
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 1, name: 'Créer un voyage' })).toBeVisible()

  // Details tab.
  const title = main.getByRole('textbox', { name: 'Titre du voyage' })
  await hydrated(title)
  await title.fill(tripName)
  await main.getByRole('radio', { name: 'Publié' }).check()

  // Stage 1 — the form starts with one: its name, its date, and the route.
  await main.getByRole('tab', { name: /Étape 1$/ }).click()
  let panel = main.getByRole('tabpanel')
  await panel.getByRole('textbox', { name: "Nom de l'étape" }).fill(first.name)
  await pickDateTime(page, panel.getByRole('button', { name: 'Date/Heure' }), first.when)
  await panel.getByRole('button', { name: 'Sélectionner un parcours' }).click()
  const routePicker = page.getByRole('dialog', { name: "Sélectionner le parcours de l'étape" })
  await routePicker.getByRole('button', { name: startsWith(route.name) }).click()
  await expect(routePicker).toBeHidden()
  await expect(panel.getByText(route.name)).toBeVisible()
  await expect(panel.getByText('Aucun parcours sélectionné')).toHaveCount(0)

  // Stage 2 — added with its tab, no route.
  await main.getByRole('tab', { name: 'Ajouter une étape' }).click()
  await expect(main.getByRole('tab', { name: /^2 Étape 2$/, selected: true })).toBeVisible()
  panel = main.getByRole('tabpanel')
  await panel.getByRole('textbox', { name: "Nom de l'étape" }).fill(second.name)
  await pickDateTime(page, panel.getByRole('button', { name: 'Date/Heure' }), second.when)
  await expect(panel.getByText('Aucun parcours sélectionné')).toBeVisible()

  await main.getByRole('button', { name: 'Créer le voyage' }).click()
  await expect(toasts(page).filter({ hasText: 'Voyage créé avec succès' })).toBeVisible()
  await expect(page).toHaveURL(/\/voyages\/(?!nouveau)[^/]+$/)
  const tripSlug = new URL(page.url()).pathname.split('/').pop()!

  // The trip page: title, status, both stages in the order they were entered, and the map.
  await expect(main.getByRole('heading', { level: 2, name: tripName })).toBeVisible()
  await expect(main.getByText('Publié', { exact: true })).toBeVisible()
  await expect(main.getByText('2 étapes', { exact: true })).toBeVisible()
  const cards = stageCards(main)
  await expect(cards).toHaveCount(2)
  await expect(cards.nth(0)).toHaveAccessibleName(startsWith(`1 ${first.name}`))
  await expect(cards.nth(0)).toContainText(frenchDateTime(first.when))
  await expect(cards.nth(0).getByRole('button', { name: 'Voir le parcours' })).toBeVisible()
  await expect(cards.nth(1)).toHaveAccessibleName(startsWith(`2 ${second.name}`))
  await expect(cards.nth(1)).toContainText(frenchDateTime(second.when))
  await expect(cards.nth(1).getByRole('button', { name: 'Voir le parcours' })).toHaveCount(0)

  const canvas = page.locator('canvas.maplibregl-canvas')
  await expect(canvas, 'one map on the trip page').toHaveCount(1)
  await expect(canvas).toBeVisible()
  // The first stage's route is the only colour on the stubbed basemap.
  await expect
    .poll(() => traceMapPixels(page, canvas), {
      message: 'the map draws the stage route',
      timeout: 20_000,
    })
    .toBeGreaterThan(500)

  // What was saved is what was typed.
  const trip = await fetchTrip(teamAdmin, team.slug, tripSlug)
  expect(trip).not.toBeNull()
  expect(trip!.name).toBe(tripName)
  expect(trip!.status).toBe('PUBLISHED')
  expect(trip!.stages.map((s) => s.name)).toEqual([first.name, second.name])
  expect(parisWallClock(trip!.stages[0].dateTime)).toEqual(first.when)
  expect(parisWallClock(trip!.stages[1].dateTime)).toEqual(second.when)
  expect(trip!.stages[0].route?.slug).toBe(route.slug)
  expect(trip!.stages[1].route).toBeUndefined()

  // The calendar: one event per stage, and none for the trip.
  const month = parisWallClock(new Date())
  const events = await teamEvents(
    teamAdmin,
    team.slug,
    new Date(Date.UTC(month.year, month.month - 2, 1)),
    new Date(Date.UTC(month.year, month.month + 1, 1))
  )
  expect(events.map((e) => [e.type, e.title, e.tripSlug])).toEqual(
    expect.arrayContaining([
      ['TRIP_STAGE', first.name, tripSlug],
      ['TRIP_STAGE', second.name, tripSlug],
    ])
  )
  expect(events.filter((e) => e.title === tripName)).toEqual([])

  for (const stage of [second, first]) {
    await openCalendar(page, team.slug, stage.when)
    await expect(calendarEvent(page, stage.name)).toBeVisible()
    await expect(calendarEvent(page, tripName)).toHaveCount(0)
  }
  // A stage event leads to its stage.
  await calendarEvent(page, first.name).click()
  await expect(page).toHaveURL(new RegExp(`/voyages/${tripSlug}/etapes/${trip!.stages[0].slug}$`))
  // Its name heads both the page and the stage's own block.
  await expect(main.getByRole('heading', { level: 2, name: first.name }).first()).toBeVisible()
})

test.describe('registration', () => {
  test('a member registers to a trip from its page, then leaves it', async ({ page }) => {
    const { teamAdmin, team } = await tripTeam('inscription')
    const member = await newUser(unique('Voyageuse'))
    await addMember(await roleSession('admin'), team.slug, member)
    const trip = await newTrip(teamAdmin, team.slug, unique('Voyage à rejoindre'), [
      { name: unique('Étape unique') },
    ])

    await signIn(page.context(), member)
    let main = await openTrip(page, team.slug, trip.slug, trip.name)
    await expect(main.getByText('0 personne', { exact: true })).toBeVisible()
    await expect(main.getByRole('heading', { name: 'Personnes inscrites' })).toHaveCount(0)
    // A member is no organizer: no way to edit.
    await expect(main.getByRole('link', { name: 'Modifier' })).toHaveCount(0)

    const join = main.getByRole('button', { name: 'Rejoindre le voyage' })
    await hydrated(join)
    await join.click()
    await expect(toasts(page).filter({ hasText: 'Inscription au voyage confirmée' })).toBeVisible()
    await expect(main.getByRole('button', { name: 'Quitter le voyage' })).toBeVisible()
    await expect(join).toHaveCount(0)
    await expect(main.getByText('1 personne', { exact: true }).first()).toBeVisible()
    await expect(main.getByRole('heading', { level: 3, name: 'Personnes inscrites' })).toBeVisible()

    let saved = await fetchTrip(member, team.slug, trip.slug)
    expect(saved!.participants?.map((p) => p.id)).toEqual([member.user.id])

    // The server's state, not only the page's.
    main = await openTrip(page, team.slug, trip.slug, trip.name)
    const leave = main.getByRole('button', { name: 'Quitter le voyage' })
    await hydrated(leave)
    await leave.click()
    await expect(
      toasts(page).filter({ hasText: 'Désinscription du voyage confirmée' })
    ).toBeVisible()
    await expect(main.getByRole('button', { name: 'Rejoindre le voyage' })).toBeVisible()
    await expect(main.getByText('0 personne', { exact: true })).toBeVisible()
    await expect(main.getByRole('heading', { name: 'Personnes inscrites' })).toHaveCount(0)

    saved = await fetchTrip(member, team.slug, trip.slug)
    expect(saved!.participants ?? []).toEqual([])
  })
})

test('a team admin edits a stage, deletes the other one, then deletes the trip', async ({
  page,
  browser,
}) => {
  const { teamAdmin, team } = await tripTeam('édition')
  const member = await newUser(unique('Membre'))
  await addMember(await roleSession('admin'), team.slug, member)
  const kept = unique('Étape gardée')
  const dropped = unique('Étape abandonnée')
  const trip = await newTrip(teamAdmin, team.slug, unique('Voyage à remanier'), [
    { name: kept },
    { name: dropped },
  ])
  const [keptStage, droppedStage] = trip.stages
  const renamed = unique('Étape renommée')
  const rescheduled = parisDaysAhead(12, 18, 45)

  await signIn(page.context(), teamAdmin)
  // For letEditorSettle(), before deleting a stage (see below).
  await page.clock.install()
  let main = await openTrip(page, team.slug, trip.slug, trip.name)
  await expect(stageCards(main)).toHaveCount(2)
  const edit = main.getByRole('link', { name: 'Modifier' })
  await hydrated(edit)
  await edit.click()
  await expect(main.getByRole('heading', { level: 1, name: 'Modifier le voyage' })).toBeVisible()

  // Edit the first stage: its name and its date.
  const firstTab = main.getByRole('tab', { name: startsWith(`1 ${kept}`) })
  await hydrated(firstTab)
  await firstTab.click()
  let panel = main.getByRole('tabpanel')
  const stageName = panel.getByRole('textbox', { name: "Nom de l'étape" })
  await expect(stageName).toHaveValue(kept)
  await stageName.fill(renamed)
  await pickDateTime(page, panel.getByRole('button', { name: 'Date/Heure' }), rescheduled)

  // Delete the second one.
  await main.getByRole('tab', { name: startsWith(`2 ${dropped}`) }).click()
  panel = main.getByRole('tabpanel')
  await expect(panel.getByRole('textbox', { name: "Nom de l'étape" })).toHaveValue(dropped)
  // Opening the tab queues an update in the stage's editor, and deleting the stage before it is
  // handed over crashes the form — pinned in « app defects » below. A person reads the stage
  // before deleting it; this is that pause.
  await letEditorSettle(page)
  await panel.getByRole('button', { name: 'Supprimer' }).click()
  await expect(main.getByRole('tab', { name: startsWith(`2 `) })).toHaveCount(0)
  await expect(main.getByRole('tab', { name: startsWith(`1 ${renamed}`) })).toBeVisible()

  await main.getByRole('button', { name: 'Enregistrer' }).click()
  await expect(toasts(page).filter({ hasText: 'Voyage mis à jour avec succès' })).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`${tripPath(team.slug, trip.slug)}$`))
  await expect(main.getByRole('heading', { level: 2, name: trip.name })).toBeVisible()
  await expect(main.getByText('1 étape', { exact: true })).toBeVisible()
  const cards = stageCards(main)
  await expect(cards).toHaveCount(1)
  await expect(cards.first()).toHaveAccessibleName(startsWith(`1 ${renamed}`))
  await expect(cards.first()).toContainText(frenchDateTime(rescheduled))
  await expect(main.getByText(dropped)).toHaveCount(0)

  // The same stage was edited in place, the other one is gone.
  const saved = await fetchTrip(teamAdmin, team.slug, trip.slug)
  expect(saved!.stages.map((s) => [s.id, s.name])).toEqual([[keptStage.id, renamed]])
  expect(parisWallClock(saved!.stages[0].dateTime)).toEqual(rescheduled)
  await page.goto(stagePath(team.slug, trip.slug, droppedStage.slug))
  await expect(main.getByRole('heading', { name: 'Étape introuvable' })).toBeVisible()

  // Delete the trip, from its page's actions menu.
  main = await openTrip(page, team.slug, trip.slug, trip.name)
  const menu = await openActionsMenu(page)
  await menu.getByRole('menuitem', { name: 'Supprimer' }).click()
  const confirm = page.getByRole('dialog', { name: 'Supprimer' })
  await expect(confirm).toContainText('Voulez-vous vraiment supprimer ce voyage ?')
  await confirm.getByRole('button', { name: 'Supprimer' }).click()
  await expect(toasts(page).filter({ hasText: 'Voyage supprimé avec succès' })).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/agenda$`))

  // Soft-deleted: gone for the members, still readable (and restorable) by the team's admins.
  expect(await fetchTrip(member, team.slug, trip.slug)).toBeNull()
  expect((await fetchTrip(teamAdmin, team.slug, trip.slug))?.deleted).toBe(true)
  const { context: memberContext, page: memberPage } = await pageAs(browser, member)
  try {
    await memberPage.goto(tripPath(team.slug, trip.slug))
    // The page retries the 404 three times before saying so (see the defect test below).
    await expect(
      memberPage.getByRole('main').getByRole('heading', { name: 'Voyage introuvable' })
    ).toBeVisible({ timeout: 15_000 })
  } finally {
    await memberContext.close()
  }
})

test.describe('publication states', () => {
  test('a trip created as a draft is hidden from members until it is published from its page', async ({
    page,
    browser,
  }) => {
    const { teamAdmin, team, member } = await tripTeamWithMember('brouillon')
    const tripName = unique('Voyage en brouillon')

    await signIn(page.context(), teamAdmin)
    await page.goto(tripNewPath(team.slug))
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { level: 1, name: 'Créer un voyage' })).toBeVisible()
    const title = main.getByRole('textbox', { name: 'Titre du voyage' })
    await hydrated(title)
    await title.fill(tripName)
    // A draft is the form's default.
    await expect(main.getByRole('radio', { name: 'Brouillon' })).toBeChecked()
    await main.getByRole('tab', { name: /Étape 1$/ }).click()
    await main
      .getByRole('tabpanel')
      .getByRole('textbox', { name: "Nom de l'étape" })
      .fill(unique('Étape'))
    await main.getByRole('button', { name: 'Créer le voyage' }).click()
    await expect(toasts(page).filter({ hasText: 'Voyage créé avec succès' })).toBeVisible()
    await expect(page).toHaveURL(/\/voyages\/(?!nouveau)[^/]+$/)
    const tripSlug = new URL(page.url()).pathname.split('/').pop()!
    await expect(main.getByRole('heading', { level: 2, name: tripName })).toBeVisible()
    await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()
    expect((await fetchTrip(teamAdmin, team.slug, tripSlug))?.status).toBe('DRAFT')

    const reader = await pageAs(browser, member)
    try {
      // --- A draft: members see nothing of it.
      expect(await fetchTrip(member, team.slug, tripSlug), 'a draft is 404 to a member').toBeNull()
      let memberMain = await openFeed(reader.page, team.slug)
      await expect(
        memberMain.getByText('0 sortie ou voyage à venir', { exact: true })
      ).toBeVisible()
      await expect(entityCard(memberMain, tripName)).toHaveCount(0)

      // --- Published from the trip page's menu.
      const menu = await openActionsMenu(page)
      await menu.getByRole('menuitem', { name: 'Publier' }).click()
      await expect(toasts(page).filter({ hasText: 'Voyage publié avec succès' })).toBeVisible()
      await expect(main.getByText('Publié', { exact: true })).toBeVisible()
      await expect(main.getByText('Brouillon', { exact: true })).toHaveCount(0)
      expect((await fetchTrip(teamAdmin, team.slug, tripSlug))?.status).toBe('PUBLISHED')

      // --- The member finds it in the feed, and may register.
      memberMain = await openFeed(reader.page, team.slug)
      const card = entityCard(memberMain, tripName)
      await expect(card).toBeVisible()
      await hydrated(card)
      await card.click()
      await expect(reader.page).toHaveURL(new RegExp(`${tripPath(team.slug, tripSlug)}$`))
      await expect(memberMain.getByRole('heading', { level: 2, name: tripName })).toBeVisible()
      await expect(memberMain.getByRole('button', { name: 'Rejoindre le voyage' })).toBeVisible()
    } finally {
      await reader.context.close()
    }
  })

  test('a trip scheduled in the editor is published by the scheduler and announced in the team’s name', async ({
    page,
    browser,
  }) => {
    // The scheduler runs once a minute, then the notification dispatcher every 15 s.
    test.setTimeout(240_000)
    const { teamAdmin, team, member } = await tripTeamWithMember('programmé')
    const tripName = unique('Voyage programmé')
    const publishOn = parisDaysAhead(1, 7, 15)
    const main = page.getByRole('main')

    await test.step('the team admin schedules a draft in the form', async () => {
      await signIn(page.context(), teamAdmin)
      await page.goto(tripNewPath(team.slug))
      await expect(main.getByRole('heading', { level: 1, name: 'Créer un voyage' })).toBeVisible()
      const title = main.getByRole('textbox', { name: 'Titre du voyage' })
      await hydrated(title)
      await title.fill(tripName)
      // Only a draft offers a scheduled publication.
      await expect(main.getByRole('radio', { name: 'Brouillon' })).toBeChecked()
      await pickIntoEmptyPicker(
        page,
        main.getByRole('button', { name: 'Publication programmée' }),
        publishOn
      )
      await main.getByRole('tab', { name: /Étape 1$/ }).click()
      await main
        .getByRole('tabpanel')
        .getByRole('textbox', { name: "Nom de l'étape" })
        .fill(unique('Étape'))
      await main.getByRole('button', { name: 'Créer le voyage' }).click()
      await expect(toasts(page).filter({ hasText: 'Voyage créé avec succès' })).toBeVisible()
      await expect(page).toHaveURL(/\/voyages\/(?!nouveau)[^/]+$/)
    })
    const tripSlug = new URL(page.url()).pathname.split('/').pop()!

    await test.step('before the date: a draft that says when, hidden from members', async () => {
      await expect(main.getByRole('heading', { level: 2, name: tripName })).toBeVisible()
      await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()
      await expect(
        main.getByText(`Publication programmée pour le ${frenchDateTime(publishOn)}`, {
          exact: true,
        })
      ).toBeVisible()
      const saved = await fetchTrip(teamAdmin, team.slug, tripSlug)
      expect(saved?.status).toBe('DRAFT')
      expect(new Date(saved!.publishAt!).toISOString()).toBe(parisInstant(publishOn))
      expect(await fetchTrip(member, team.slug, tripSlug), 'a draft is 404 to a member').toBeNull()
    })

    await test.step('the date comes: the scheduler publishes it, keeping its own date', async () => {
      const saved = (await fetchTrip(teamAdmin, team.slug, tripSlug))!
      await apiPut(
        teamAdmin,
        `/api/teams/${team.slug}/trips/${tripSlug}`,
        requestOf(saved, { publishAt: pastPublishAt() })
      )
      await waitForAutoPublish(() => fetchTrip(teamAdmin, team.slug, tripSlug))
      const published = (await fetchTrip(teamAdmin, team.slug, tripSlug))!
      expect(published.publishAt, 'the schedule is spent').toBeUndefined()
      expect(published.dateTime, 'a trip keeps its own date').toBe(saved.dateTime)

      await page.reload()
      await expect(main.getByText('Publié', { exact: true })).toBeVisible()
      await expect(main.getByText(/^Publication programmée/)).toHaveCount(0)
    })

    await test.step('the members are told in the team’s name; the author is not told', async () => {
      const found = await waitForNotification(
        member,
        about('TRIP_PUBLISHED', tripSlug),
        'the TRIP_PUBLISHED notification'
      )
      expect(found.actorName, 'nobody pressed « Publier »').toBeUndefined()
      expect(found).toMatchObject({
        teamName: team.name,
        subjectType: 'TRIP',
        subjectName: tripName,
      })
      // The scheduler passes the author as the actor, who is spared their own announcement.
      await expectNoNotification(teamAdmin, about('TRIP_PUBLISHED', tripSlug), 'the author')

      const reader = await pageAs(browser, member)
      try {
        const memberMain = reader.page.getByRole('main')
        await reader.page.goto('/notifications')
        const entry = memberMain.getByRole('link').filter({ hasText: tripName })
        await expect(entry).toContainText(`${team.name} a publié un voyage`)
        await hydrated(entry)
        await entry.click()
        await expect(reader.page).toHaveURL(new RegExp(`${tripPath(team.slug, tripSlug)}$`))
        await expect(memberMain.getByRole('heading', { level: 2, name: tripName })).toBeVisible()
      } finally {
        await reader.context.close()
      }
    })
  })

  test('a team admin unpublishes a trip: it goes back to draft, out of the members’ sight', async ({
    page,
    browser,
  }) => {
    const { teamAdmin, team, member } = await tripTeamWithMember('dépublication')
    const trip = await newTrip(teamAdmin, team.slug, unique('Voyage à dépublier'), [
      { name: unique('Étape') },
    ])

    const reader = await pageAs(browser, member)
    try {
      // Precondition: published, the member sees it.
      let memberMain = await openFeed(reader.page, team.slug)
      await expect(entityCard(memberMain, trip.name)).toBeVisible()

      await signIn(page.context(), teamAdmin)
      const main = await openTrip(page, team.slug, trip.slug, trip.name)
      await expect(main.getByText('Publié', { exact: true })).toBeVisible()
      const menu = await openActionsMenu(page)
      await menu.getByRole('menuitem', { name: 'Dépublier' }).click()
      const confirm = page.getByRole('dialog', { name: 'Dépublier' })
      await expect(confirm).toContainText(
        'Voulez-vous vraiment dépublier ce voyage ? Il reviendra au statut brouillon.'
      )
      await confirm.getByRole('button', { name: 'Dépublier' }).click()
      await expect(confirm).toBeHidden()
      await expect(toasts(page).filter({ hasText: 'Voyage dépublié avec succès' })).toBeVisible()
      await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()
      // Back to draft, it can be published again.
      const again = await openActionsMenu(page)
      await expect(again.getByRole('menuitem', { name: 'Publier' })).toBeVisible()
      await page.keyboard.press('Escape')
      expect((await fetchTrip(teamAdmin, team.slug, trip.slug))?.status).toBe('DRAFT')

      // Gone for the member.
      expect(await fetchTrip(member, team.slug, trip.slug), 'a draft is 404 to a member').toBeNull()
      memberMain = await openFeed(reader.page, team.slug)
      await expect(
        memberMain.getByText('0 sortie ou voyage à venir', { exact: true })
      ).toBeVisible()
      await expect(entityCard(memberMain, trip.name)).toHaveCount(0)
    } finally {
      await reader.context.close()
    }
  })

  test('a team admin cancels a trip: it says « Annulé » and takes no more registrations', async ({
    page,
    browser,
  }) => {
    const { teamAdmin, team, member } = await tripTeamWithMember('annulation')
    const trip = await newTrip(teamAdmin, team.slug, unique('Voyage annulé'), [
      { name: unique('Étape') },
    ])

    await signIn(page.context(), teamAdmin)
    const main = await openTrip(page, team.slug, trip.slug, trip.name)
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()
    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Annuler le voyage' }).click()
    const confirm = page.getByRole('dialog', { name: 'Annuler le voyage' })
    await expect(confirm).toContainText('Voulez-vous vraiment annuler ce voyage ?')
    await confirm.getByRole('button', { name: 'Annuler le voyage' }).click()
    await expect(confirm).toBeHidden()
    await expect(toasts(page).filter({ hasText: 'Voyage annulé avec succès' })).toBeVisible()
    await expect(main.getByText('Annulé', { exact: true })).toBeVisible()
    expect((await fetchTrip(teamAdmin, team.slug, trip.slug))?.status).toBe('CANCELLED')

    // The member still finds it, marked cancelled, and cannot register any more.
    const reader = await pageAs(browser, member)
    try {
      const feed = await openFeed(reader.page, team.slug)
      const card = entityCard(feed, trip.name)
      await expect(card).toBeVisible()
      await expect(card.getByText('Annulé', { exact: true })).toBeVisible()

      const memberMain = await openTrip(reader.page, team.slug, trip.slug, trip.name)
      await expect(memberMain.getByText('Annulé', { exact: true })).toBeVisible()
      await expect(memberMain.getByText('0 personne', { exact: true })).toBeVisible()
      await expect(memberMain.getByRole('button', { name: 'Rejoindre le voyage' })).toHaveCount(0)
      // Nor through the API.
      const refused = await apiPost(
        member,
        `/api/teams/${team.slug}/trips/${trip.slug}/join`
      ).catch((error: unknown) => error)
      expect(refused).toBeInstanceOf(ApiError)
      expect((refused as ApiError).status).toBe(403)
      expect((await fetchTrip(member, team.slug, trip.slug))?.participants ?? []).toEqual([])
    } finally {
      await reader.context.close()
    }
  })
})

test.describe('regressions', () => {
  test('the stage date picker speaks French', async ({ page }) => {
    // There was no DatesProvider anywhere: every @mantine/dates picker spoke English — « September
    // 2026 », « Mo Tu We » — on the French site (fixed 2026-09-25: AppProviders passes the page's
    // language to DatesProvider).
    const { teamAdmin, team } = await tripTeam('sélecteur')
    await signIn(page.context(), teamAdmin)
    await page.goto(tripNewPath(team.slug))
    const main = page.getByRole('main')
    const title = main.getByRole('textbox', { name: 'Titre du voyage' })
    await hydrated(title)
    await main.getByRole('tab', { name: /Étape 1$/ }).click()
    const field = main.getByRole('tabpanel').getByRole('button', { name: 'Date/Heure' })
    const [, day, month, year] = /^(\d{2})\/(\d{2})\/(\d{4})/.exec((await field.textContent())!)!
    const dropdown = await openPicker(page, field)
    // Preconditions: the dropdown is open on the value's month, and the page itself is French.
    await expect(dropdown.getByRole('table')).toBeVisible()
    await expect(main.getByText('Date/Heure', { exact: true })).toBeVisible()
    const frenchMonth = new Intl.DateTimeFormat('fr-FR', { month: 'long', timeZone: 'UTC' }).format(
      new Date(Date.UTC(Number(year), Number(month) - 1, 15))
    )
    await expect(
      dropdown.getByRole('button', { name: `${Number(day)} ${frenchMonth} ${year}`, exact: true })
    ).toBeVisible({ timeout: 2_000 })
  })

  test("publishing a draft trip from its page keeps its stages' routes", async ({ page }) => {
    // TripDetailPage published by sending the TripDto back as the request ({ ...trip, status }): a
    // stage's `route` is not the request's `routeSlug`, so the update cleared every stage's route
    // (and start/end places) — unpublish and cancel too (fixed 2026-09-25).
    const { teamAdmin, team } = await tripTeam('publication')
    const route = await newRoute(teamAdmin, team.slug, unique('Boucle'), windingTrack(100))
    const trip = await newTrip(
      teamAdmin,
      team.slug,
      unique('Voyage à publier'),
      [{ name: unique('Étape tracée'), routeSlug: route.slug }],
      { status: 'DRAFT' }
    )
    await signIn(page.context(), teamAdmin)
    const main = await openTrip(page, team.slug, trip.slug, trip.name)
    // Preconditions: a draft whose stage has its route.
    await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()
    await expect(
      stageCards(main).first().getByRole('button', { name: 'Voir le parcours' })
    ).toBeVisible()

    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Publier' }).click()
    await expect(toasts(page).filter({ hasText: 'Voyage publié avec succès' })).toBeVisible()
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()
    const published = await fetchTrip(teamAdmin, team.slug, trip.slug)
    expect(published?.status).toBe('PUBLISHED')
    expect(published?.stages[0].route?.slug, 'the stage keeps its route').toBe(route.slug)
  })

  test('a trip that is not there is not requested again and again', async ({ page }) => {
    // A 404 is an answer, not a failure: the query client used to retry it three times with a
    // 1 s / 2 s / 4 s backoff — ~8 s of skeleton and four reads before « introuvable » on every
    // detail page (fixed 2026-09-25).
    const { teamAdmin, team } = await tripTeam('absent')
    await signIn(page.context(), teamAdmin)
    const endpoint = `/api/teams/${team.slug}/trips/voyage-absent`
    const reads: string[] = []
    page.on('request', (request) => {
      if (new URL(request.url()).pathname === endpoint) reads.push(request.method())
    })
    await page.goto(tripPath(team.slug, 'voyage-absent'))
    // Precondition: the page does end on its not-found state.
    await expect(
      page.getByRole('main').getByRole('heading', { name: 'Voyage introuvable' })
    ).toBeVisible({
      timeout: 15_000,
    })
    // One read is enough.
    expect(reads.length, 'browser reads of the missing trip').toBeLessThanOrEqual(1)
  })

  test('deleting a stage right after opening it does not crash the form', async ({ page }) => {
    // Opening a stage's tab queues an update in that stage's editor. When MarkdownEditor flushed
    // its 150 ms debounce on unmount, deleting the stage within those 150 ms wrote
    // stages.<index>.media on an index the form no longer had: a TypeError, and the ErrorBoundary
    // in place of the form. The unmount cancels again; the blur still flushes (fixed 2026-09-25).
    const { teamAdmin, team } = await tripTeam('suppression étape')
    const kept = unique('Étape gardée')
    const dropped = unique('Étape abandonnée')
    const trip = await newTrip(teamAdmin, team.slug, unique('Voyage à élaguer'), [
      { name: kept },
      { name: dropped },
    ])
    await signIn(page.context(), teamAdmin)
    await page.clock.install()
    await page.goto(`${tripPath(team.slug, trip.slug)}/modifier`)
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { level: 1, name: 'Modifier le voyage' })).toBeVisible()
    const tab = main.getByRole('tab', { name: startsWith(`2 ${dropped}`) })
    await hydrated(tab)
    // The clock stands still from here: the delete lands inside the debounce whatever the
    // machine's speed.
    await page.clock.pauseAt(Date.now() + 60_000)
    await tab.click()
    const panel = main.getByRole('tabpanel')
    await expect(panel.getByRole('textbox', { name: "Nom de l'étape" })).toHaveValue(dropped)
    // Precondition: the stage's editor is mounted, and the stage can be deleted.
    await expect(richText(panel)).toBeVisible()
    await panel.getByRole('button', { name: 'Supprimer' }).click()
    await page.clock.resume()

    await expect(main.getByRole('tab', { name: startsWith(`1 ${kept}`) })).toBeVisible({
      timeout: 2_000,
    })
    await expect(main.getByRole('tab', { name: startsWith('2 ') })).toHaveCount(0)
    await expect(main.getByRole('heading', { name: 'Une erreur est survenue' })).toHaveCount(0)
  })
})

/**
 * Undoing a deletion or a cancellation from the trip page's menu. Both used to lose what they put
 * back: the menu sent the TripDto back as the request, clearing every stage's route (see
 * « regressions » above) — so each restoration is checked to bring back the text and the routes
 * too, not only the status.
 */
/**
 * A stage carries its own thread, apart from the trip's (docs/LEDGER_*.md API-11). It is addressed by
 * the stage's slug alone, and a stage is no publication: the trip's author is told, and the
 * notification opens the trip.
 */
test('a member comments on a stage: its own thread, the trip author is told and sent to the trip', async ({
  page,
}) => {
  const { teamAdmin, team, member } = await tripTeamWithMember('fil d’étape')
  const trip = await newTrip(teamAdmin, team.slug, unique('Voyage commenté'), [
    { name: unique('Étape commentée') },
    { name: unique('Étape muette') },
  ])
  const [stage, quiet] = trip.stages
  const comment = `On dort au gîte ${unique('msg')}`

  await signIn(page.context(), member)
  await page.goto(stagePath(team.slug, trip.slug, stage.slug))
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 2, name: stage.name }).first()).toBeVisible()
  await expect(main.getByRole('heading', { name: 'Commentaires (0)' })).toBeVisible()
  const commentBox = main.getByRole('textbox', { name: /Écrivez un commentaire/ })
  await hydrated(commentBox)
  await commentBox.fill(comment)
  await main.getByRole('button', { name: 'Envoyer le commentaire' }).click()
  await expect(main.getByText(comment, { exact: true })).toBeVisible()
  await expect(main.getByRole('heading', { name: 'Commentaires (1)' })).toBeVisible()

  // The stage's thread only: neither the trip's nor the other stage's.
  const thread = (path: string) =>
    apiGet<CommentListResponse>(teamAdmin, `/api/teams/${team.slug}/${path}/comments`)
  expect((await thread(`stages/${stage.slug}`)).items.map((c) => c.content)).toEqual([comment])
  expect((await thread(`trips/${trip.slug}`)).items).toEqual([])
  expect((await thread(`stages/${quiet.slug}`)).items).toEqual([])
  const saved = await fetchTrip(member, team.slug, trip.slug)
  expect(saved!.commentCount).toBe(0)
  expect(saved!.stages.map((s) => s.commentCount)).toEqual([1, 0])

  await page.goto(stagePath(team.slug, trip.slug, quiet.slug))
  await expect(main.getByRole('heading', { name: 'Commentaires (0)' })).toBeVisible()
  await expect(main.getByText(comment, { exact: true })).toHaveCount(0)

  const notification = await waitForNotification(
    teamAdmin,
    about('COMMENT_ON_MY_PUBLICATION', trip.slug),
    'the comment on the stage'
  )
  expect(notification.subjectType).toBe('TRIP')
  expect(notification.excerpt).toBe(comment)
  await expectNoNotification(member, about('COMMENT_ON_MY_PUBLICATION', trip.slug), 'the commenter')
})

test.describe('restoring', () => {
  const MARKDOWN = '## Programme\n\nDépart **à 8 h** devant le club.'

  /** A published trip with a formatted text and a stage on a route, in a team with a member. */
  async function tracedTrip(label: string) {
    const { teamAdmin, team, member } = await tripTeamWithMember(label)
    const route = await newRoute(teamAdmin, team.slug, unique('Boucle'), windingTrack(100))
    const trip = await newTrip(
      teamAdmin,
      team.slug,
      unique(`Voyage ${label}`),
      [{ name: unique('Étape tracée'), routeSlug: route.slug }],
      { media: markdownMedia(MARKDOWN) }
    )
    return { teamAdmin, team, member, route, trip }
  }

  /** The trip's text is intact, and its stage still on its route. */
  function expectIntact(trip: TripDto | null, routeSlug: string) {
    expect(trip?.media.markdown.trim(), 'the text').toBe(MARKDOWN)
    expect(
      trip?.stages.map((stage) => stage.route?.slug),
      'the stage route'
    ).toEqual([routeSlug])
  }

  test('a team admin restores a deleted trip: the members get it back, text and routes included', async ({
    page,
    browser,
  }) => {
    const { teamAdmin, team, member, route, trip } = await tracedTrip('restauré')
    await apiDelete(teamAdmin, `/api/teams/${team.slug}/trips/${trip.slug}`)
    // Precondition: gone for the member, still there — flagged — for the team admin.
    expect(await fetchTrip(member, team.slug, trip.slug)).toBeNull()
    expect((await fetchTrip(teamAdmin, team.slug, trip.slug))?.deleted).toBe(true)

    await signIn(page.context(), teamAdmin)
    const main = await openTrip(page, team.slug, trip.slug, trip.name)
    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Restaurer' }).click()
    await expect(toasts(page).filter({ hasText: 'Voyage restauré avec succès' })).toBeVisible()
    // Restored, the menu no longer offers it.
    const again = await openActionsMenu(page)
    await expect(again.getByRole('menuitem', { name: 'Supprimer' })).toBeVisible()
    await expect(again.getByRole('menuitem', { name: 'Restaurer' })).toHaveCount(0)
    await page.keyboard.press('Escape')
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()

    const restored = await fetchTrip(teamAdmin, team.slug, trip.slug)
    expect(restored).toMatchObject({ deleted: false, status: 'PUBLISHED' })
    expectIntact(restored, route.slug)

    // The member finds it again, in the feed and on its page, stage route included.
    const reader = await pageAs(browser, member)
    try {
      expectIntact(await fetchTrip(member, team.slug, trip.slug), route.slug)
      const feed = await openFeed(reader.page, team.slug)
      await expect(entityCard(feed, trip.name)).toBeVisible()
      const memberMain = await openTrip(reader.page, team.slug, trip.slug, trip.name)
      await expect(memberMain.getByRole('heading', { level: 2, name: 'Programme' })).toBeVisible()
      await expect(memberMain.locator('strong', { hasText: 'à 8 h' })).toBeVisible()
      await expect(
        stageCards(memberMain).first().getByRole('button', { name: 'Voir le parcours' })
      ).toBeVisible()
    } finally {
      await reader.context.close()
    }
  })

  test('a cancelled trip is restored to a draft, out of the members’ sight until published again', async ({
    page,
  }) => {
    const { teamAdmin, team, member, route, trip } = await tracedTrip('réactivé')
    await apiPut(
      teamAdmin,
      `/api/teams/${team.slug}/trips/${trip.slug}`,
      requestOf(trip, { status: 'CANCELLED' })
    )
    // Precondition: cancelled, and a member still reads it.
    expect((await fetchTrip(member, team.slug, trip.slug))?.status).toBe('CANCELLED')

    await signIn(page.context(), teamAdmin)
    const main = await openTrip(page, team.slug, trip.slug, trip.name)
    await expect(main.getByText('Annulé', { exact: true })).toBeVisible()
    const menu = await openActionsMenu(page)
    await menu.getByRole('menuitem', { name: 'Restaurer le voyage' }).click()
    const confirm = page.getByRole('dialog', { name: 'Restaurer le voyage' })
    await expect(confirm).toContainText(
      'Voulez-vous vraiment restaurer ce voyage ? Il reviendra au statut brouillon.'
    )
    await confirm.getByRole('button', { name: 'Restaurer le voyage' }).click()
    await expect(confirm).toBeHidden()
    await expect(toasts(page).filter({ hasText: 'Voyage restauré avec succès' })).toBeVisible()
    await expect(main.getByText('Brouillon', { exact: true })).toBeVisible()
    await expect(main.getByText('Annulé', { exact: true })).toHaveCount(0)

    const draft = await fetchTrip(teamAdmin, team.slug, trip.slug)
    expect(draft?.status).toBe('DRAFT')
    expectIntact(draft, route.slug)
    expect(await fetchTrip(member, team.slug, trip.slug), 'a draft is 404 to a member').toBeNull()

    // A draft again, it is published the usual way — and comes back whole.
    const publish = await openActionsMenu(page)
    await publish.getByRole('menuitem', { name: 'Publier' }).click()
    await expect(toasts(page).filter({ hasText: 'Voyage publié avec succès' })).toBeVisible()
    await expect(main.getByText('Publié', { exact: true })).toBeVisible()
    const published = await fetchTrip(member, team.slug, trip.slug)
    expect(published?.status).toBe('PUBLISHED')
    expectIntact(published, route.slug)
  })
})
