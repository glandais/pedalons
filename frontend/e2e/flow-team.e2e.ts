import type { Browser, Locator, Page } from '@playwright/test'
import type { AddMemberRequest } from '../src/api/dto'
import { apiGetOrNull, apiPost, ApiError, type AuthResponse } from './support/api'
import {
  addMember,
  getTeam as teamAs,
  newTeam,
  newTeamPage,
  newUser,
  roleSession,
  setTeamAttributes,
  signIn,
} from './support/data'
import { EDITOR_LABEL, richText, typeRichText } from './support/editor'
import { expect, test, unique } from './support/fixtures'
import {
  discordWebhook,
  joinStatus,
  listedTeams,
  pageOf,
  pagesOf,
  publicTeam,
  rosterOf,
  webhookOf,
} from './support/flow-team'
import { findRide, groupCard, newRide, openRide, readRide, ridePath } from './support/rides'
import { rawDocument, reactQueryState, sessionCookie } from './support/ssr'
import { entityCard, hydrated, pageAs, pageHydrated, watchToasts } from './support/ui'

/**
 * The team journey, through the UI only — the minimum nominal path: a user creates a team with the
 * form, edits its settings (name, description, modules), manages its members from the admin
 * screens, writes a custom page, and the team shows on /equipes to the audience its visibility
 * gives it; a member leaves it, and its owner deletes it. Each step is checked on the page and read back through the API.
 *
 * Every test builds its own owner (never a platform admin: its rights short-circuit the checks under
 * test) and its own team. A member is added by the platform admin through the API: a team is born
 * with addMemberAllowed=false, and then its own admins cannot add anyone directly.
 */

const main = (page: Page) => page.getByRole('main')
const teamNav = (page: Page) => page.getByRole('navigation', { name: "Navigation de l'équipe" })
const adminNav = (page: Page) =>
  page.getByRole('navigation', { name: "Navigation de la gestion de l'équipe" })

/** The team page's heading: the team really is the one shown. */
const teamHeading = (page: Page, name: string) =>
  page.getByRole('heading', { level: 1, name, exact: true })

/** The slug the app navigated to after /equipes/{slug}. */
function slugIn(page: Page): string {
  const match = new URL(page.url()).pathname.match(/^\/equipes\/([^/]+)$/)
  if (!match) throw new Error(`not on a team page: ${page.url()}`)
  return match[1]
}

/** The row of the admin member list holding `displayName` (the rows have no role of their own). */
function memberRow(page: Page, displayName: string): Locator {
  return main(page)
    .getByText(displayName, { exact: true })
    .locator('xpath=ancestor::div[contains(@class, "mantine-Group-root")][last()]')
}

/** A team card of the /equipes grid. */
const teamCard = (page: Page, name: string) => entityCard(main(page), name)

/**
 * Writes `text` in the form's rich-text editor (`label`: its accessible name), and checks the form
 * holds it: its « n/max caractères » counter follows the editor.
 */
async function writeRichText(form: Locator, label: string, text: string, max: number) {
  await typeRichText(form, text, label)
  await expect(form.getByText(`${text.length}/${max} caractères`, { exact: true })).toBeVisible()
}

test.describe('creating a team', () => {
  test('a signed-in user creates a team with the form and lands on it, as its admin', async ({
    context,
    page,
  }) => {
    const owner = await newUser('Flow team creator')
    const name = unique('Équipe créée')
    const about = 'Nous roulons le dimanche matin depuis la place du marché'
    await signIn(context, owner)

    // From the team list, where the call to action lives.
    await page.goto('/equipes')
    await expect(page.getByRole('heading', { level: 2, name: 'Équipes' })).toBeVisible()
    const create = main(page).getByRole('link', { name: 'Créer une équipe' })
    await hydrated(create)
    await create.click()
    await expect(page).toHaveURL(/\/equipes\/nouvelle$/)
    await expect(page.getByRole('heading', { level: 1, name: 'Créer une équipe' })).toBeVisible()

    const form = main(page).locator('form')
    const nameInput = form.getByRole('textbox', { name: "Nom de l'équipe" })
    await hydrated(nameInput)
    const submit = form.getByRole('button', { name: "Créer l'équipe" })
    await expect(submit, 'precondition: a nameless team cannot be submitted').toBeDisabled()
    await nameInput.fill(name)
    await writeRichText(form, EDITOR_LABEL.team, about, 2000)
    // Every module starts on but the member directory; turning the ads off is kept.
    const ads = form.getByRole('checkbox', { name: 'Activer les annonces' })
    await expect(ads).toBeChecked()
    await expect(
      form.getByRole('checkbox', { name: 'Ouvrir le trombinoscope aux membres' })
    ).not.toBeChecked()
    await ads.uncheck()
    await submit.click()

    await expect(page.getByText('Équipe créée avec succès', { exact: true })).toBeVisible()
    await expect(page).toHaveURL(/\/equipes\/[^/]+$/)
    await expect(teamHeading(page, name)).toBeVisible()
    const slug = slugIn(page)
    // The creator runs it: « Gérer » is there, and the modules follow the form.
    await expect(page.getByRole('link', { name: 'Gérer', exact: true })).toBeVisible()
    await expect(teamNav(page).getByRole('link', { name: 'Parcours' })).toBeVisible()
    await expect(teamNav(page).getByRole('link', { name: 'Agenda', exact: true })).toBeVisible()
    await expect(teamNav(page).getByRole('link', { name: 'Annonces' })).toHaveCount(0)

    // The description is the team's « À propos ».
    await teamNav(page).getByRole('link', { name: 'À propos' }).click()
    await expect(
      page.getByRole('heading', { level: 2, name: "À propos de l'équipe" })
    ).toBeVisible()
    await expect(main(page).getByText(about)).toBeVisible()
    await expect(main(page).getByText('1 membre', { exact: true })).toBeVisible()

    // And the API holds what was typed.
    const saved = await teamAs(owner, slug)
    expect(saved).toMatchObject({
      name,
      role: 'ADMIN',
      visibility: 'TEAM',
      memberCount: 1,
      enableAds: false,
      enableRoutes: true,
      enableRides: true,
      enableTrips: true,
      enablePosts: true,
      enableMemberDirectory: false,
    })
    expect(saved.about.markdown.trim()).toBe(about)
  })
})

test.describe('team settings', () => {
  test('the owner renames the team, rewrites its description and turns modules off, and the team shows it', async ({
    context,
    page,
  }) => {
    const owner = await newUser('Flow team settings owner')
    const team = await newTeam(owner, unique('Réglages'), {
      media: { markdown: 'Ancienne description', assets: { images: [], attachments: [] } },
      enableMemberDirectory: false,
    })
    const renamed = unique('Réglages renommée')
    const about = 'Club de gravel ouvert à tous les niveaux'
    await signIn(context, owner)

    await page.goto(`/equipes/${team.slug}`)
    await expect(teamHeading(page, team.name)).toBeVisible()
    await expect(
      teamNav(page).getByRole('link', { name: 'Parcours' }),
      'precondition: the routes module starts on'
    ).toBeVisible()
    await expect(teamNav(page).getByRole('link', { name: 'Agenda', exact: true })).toBeVisible()

    // « Gérer », then the settings tab of the team's admin area.
    const manage = page.getByRole('link', { name: 'Gérer', exact: true })
    await hydrated(manage)
    await manage.click()
    await expect(page.getByRole('heading', { level: 2, name: "Gestion de l'équipe" })).toBeVisible()
    await adminNav(page).getByRole('link', { name: 'Paramètres' }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/admin/parametres$`))
    await expect(
      page.getByRole('heading', { level: 2, name: "Paramètres de l'équipe" })
    ).toBeVisible()

    const nameInput = main(page).getByRole('textbox', { name: "Nom de l'équipe" })
    const form = main(page)
      .locator('form')
      .filter({ has: page.getByRole('textbox', { name: "Nom de l'équipe" }) })
    await expect(nameInput).toHaveValue(team.name)
    await expect(richText(form, EDITOR_LABEL.team)).toHaveText('Ancienne description')
    await nameInput.fill(renamed)
    await writeRichText(form, EDITOR_LABEL.team, about, 2000)

    // Routes off takes rides and trips down with it.
    const routes = form.getByRole('checkbox', { name: 'Activer les parcours' })
    const rides = form.getByRole('checkbox', { name: 'Activer les sorties' })
    const trips = form.getByRole('checkbox', { name: 'Activer les voyages' })
    await routes.uncheck()
    await expect(rides).not.toBeChecked()
    await expect(rides).toBeDisabled()
    await expect(trips).not.toBeChecked()
    await expect(trips).toBeDisabled()
    await form.getByRole('checkbox', { name: 'Activer les posts' }).uncheck()
    await form.getByRole('checkbox', { name: 'Ouvrir le trombinoscope aux membres' }).check()
    await form.getByRole('button', { name: 'Enregistrer' }).click()

    await expect(page.getByText('Équipe mise à jour avec succès', { exact: true })).toBeVisible()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}$`))
    await expect(teamHeading(page, renamed)).toBeVisible()
    await expect(
      teamNav(page).getByRole('link', { name: 'À propos' }),
      'precondition: the team nav is rendered'
    ).toBeVisible()
    await expect(teamNav(page).getByRole('link', { name: 'Parcours' })).toHaveCount(0)
    await expect(teamNav(page).getByRole('link', { name: 'Agenda', exact: true })).toHaveCount(0)
    await expect(teamNav(page).getByRole('link', { name: 'Annonces' })).toBeVisible()

    await teamNav(page).getByRole('link', { name: 'À propos' }).click()
    await expect(main(page).getByText(about)).toBeVisible()
    await expect(main(page).getByText('Ancienne description')).toHaveCount(0)

    // Still there on a fresh load — the server's state, not the client cache.
    await page.reload()
    await expect(teamHeading(page, renamed)).toBeVisible()
    await expect(main(page).getByText(about)).toBeVisible()

    const saved = await teamAs(owner, team.slug)
    expect(saved).toMatchObject({
      name: renamed,
      enableRoutes: false,
      enableRides: false,
      enableTrips: false,
      enablePosts: false,
      enableAds: true,
      enableMemberDirectory: true,
    })
    expect(saved.about.markdown.trim()).toBe(about)
  })
})

test.describe('members', () => {
  test('the owner makes a member an organizer, then removes them, from the member screen', async ({
    context,
    page,
  }) => {
    const owner = await newUser('Flow team members owner')
    const member = await newUser('Flow team member')
    const team = await newTeam(owner, unique('Membres'))
    await addMember(await roleSession('admin'), team.slug, member)
    await signIn(context, owner)

    await page.goto(`/equipes/${team.slug}`)
    await expect(teamHeading(page, team.name)).toBeVisible()
    const manage = page.getByRole('link', { name: 'Gérer', exact: true })
    await hydrated(manage)
    await manage.click()
    await adminNav(page).getByRole('link', { name: 'Membres' }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/admin/membres$`))
    await expect(
      main(page).getByRole('heading', { level: 2, name: 'Membres', exact: true })
    ).toBeVisible()

    // Both rows: the owner, who can touch neither their role nor their membership here…
    const own = memberRow(page, owner.user.displayName)
    await expect(own.getByText('(vous)')).toBeVisible()
    await expect(own.getByText('Administrateur', { exact: true })).toBeVisible()
    await expect(own.getByRole('button', { name: 'Modifier' })).toHaveCount(0)
    await expect(own.getByRole('button', { name: 'Retirer' })).toHaveCount(0)
    // …and the member.
    const row = memberRow(page, member.user.displayName)
    await expect(row.getByText('Membre', { exact: true })).toBeVisible()

    // Promote.
    await row.getByRole('button', { name: 'Modifier' }).click()
    await row.getByRole('combobox', { name: `Rôle de ${member.user.displayName}` }).click()
    await page.getByRole('option', { name: 'Organisateur' }).click()
    await row.getByRole('button', { name: 'Enregistrer' }).click()
    await expect(row.getByText('Organisateur', { exact: true })).toBeVisible()
    await expect(row.getByRole('button', { name: 'Enregistrer' })).toHaveCount(0)
    await expect.poll(async () => (await teamAs(member, team.slug)).role).toBe('ORGANIZER')

    await page.reload()
    await expect(
      memberRow(page, member.user.displayName).getByText('Organisateur', { exact: true })
    ).toBeVisible()

    // Remove.
    await memberRow(page, member.user.displayName).getByRole('button', { name: 'Retirer' }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('Voulez-vous vraiment retirer ce membre ?')).toBeVisible()
    await dialog.getByRole('button', { name: 'Retirer' }).click()
    await expect(page.getByText("Membre retiré de l'équipe", { exact: true })).toBeVisible()
    await expect(main(page).getByText(member.user.displayName, { exact: true })).toHaveCount(0)
    await expect(main(page).getByText(owner.user.displayName, { exact: true })).toBeVisible()

    await page.reload()
    await expect(main(page).getByText(owner.user.displayName, { exact: true })).toBeVisible()
    await expect(main(page).getByText(member.user.displayName, { exact: true })).toHaveCount(0)

    const roster = await rosterOf(owner, team.slug)
    expect(roster.members.map((m) => m.user.id)).toEqual([owner.user.id])
    expect((await teamAs(owner, team.slug)).memberCount).toBe(1)
  })

  test('an owner can only invite once the platform admin allows it, and never adds directly before', async ({
    context,
    page,
  }) => {
    const owner = await newUser('Flow team closed owner')
    const candidate = await newUser('Flow team candidate')
    const team = await newTeam(owner, unique('Ajout fermé'))
    expect(team.addMemberAllowed, 'precondition: a team is born closed').toBe(false)

    // The API refuses the owner a direct add…
    const request: AddMemberRequest = { userId: candidate.user.id, role: 'MEMBER' }
    const refused = await apiPost(owner, `/api/teams/${team.slug}/members`, request).catch(
      (error: unknown) => error
    )
    expect(refused).toBeInstanceOf(ApiError)
    expect((refused as ApiError).code).toBe('TEAM_ADD_MEMBER_NOT_ALLOWED')

    // …and the member screen offers no way in.
    await signIn(context, owner)
    await page.goto(`/equipes/${team.slug}/admin/membres`)
    await expect(
      main(page).getByRole('heading', { level: 2, name: 'Membres', exact: true })
    ).toBeVisible()
    await expect(
      memberRow(page, owner.user.displayName).getByText('(vous)'),
      'precondition: the member list is rendered'
    ).toBeVisible()
    await expect(main(page).getByRole('button', { name: 'Inviter par e-mail' })).toHaveCount(0)

    // Once the platform admin allows it, the invitation button appears.
    await setTeamAttributes(team, { addMemberAllowed: true })
    await page.reload()
    await expect(main(page).getByRole('button', { name: 'Inviter par e-mail' })).toBeVisible()
    await expect(main(page).getByText(candidate.user.displayName, { exact: true })).toHaveCount(0)
  })
})

test.describe('team pages', () => {
  test('the owner writes a custom page, it becomes a tab of the team, and an edit replaces it', async ({
    browser,
    context,
    page,
  }) => {
    const owner = await newUser('Flow team pages owner')
    const member = await newUser('Flow team pages member')
    const team = await newTeam(owner, unique('Pages'))
    await addMember(await roleSession('admin'), team.slug, member)
    const title = unique('Règlement')
    const content = 'Casque obligatoire et respect du code de la route'
    const retitled = unique('Charte')
    const recontent = 'Casque obligatoire et lumières la nuit'
    await signIn(context, owner)

    await page.goto(`/equipes/${team.slug}/admin/pages`)
    await expect(page.getByRole('heading', { level: 2, name: "Pages de l'équipe" })).toBeVisible()
    await expect(main(page).getByText('0 page sur 3 maximum')).toBeVisible()
    const add = main(page).getByRole('link', { name: 'Ajouter une page' }).first()
    await hydrated(add)
    await add.click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/admin/pages/nouvelle$`))
    await expect(page.getByRole('heading', { level: 2, name: 'Créer une page' })).toBeVisible()

    const titleInput = main(page).getByLabel('Titre de la page')
    const form = main(page)
      .locator('form')
      .filter({ has: page.getByLabel('Titre de la page') })
    await hydrated(titleInput)
    await titleInput.fill(title)
    await writeRichText(form, EDITOR_LABEL.teamPage, content, 10000)
    await expect(form.getByRole('combobox', { name: 'Visibilité' })).toHaveValue(
      'Équipe uniquement'
    )
    await form.getByRole('button', { name: 'Créer la page' }).click()

    await expect(page.getByText('Page créée avec succès', { exact: true })).toBeVisible()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/admin/pages$`))
    await expect(main(page).getByText('1 page sur 3 maximum')).toBeVisible()
    const row = main(page).locator('[draggable="true"]').filter({ hasText: title })
    await expect(row).toBeVisible()

    const [summary] = await pagesOf(owner, team.slug)
    expect(summary).toMatchObject({ title, visibility: 'TEAM' })
    const created = await pageOf(owner, team.slug, summary.slug)
    expect(created.media.markdown.trim()).toBe(content)

    // The page is a tab of the team, for its members.
    await page.goto(`/equipes/${team.slug}`)
    await expect(teamHeading(page, team.name)).toBeVisible()
    await teamNav(page).getByRole('link', { name: title }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/pages/${summary.slug}$`))
    await expect(main(page).getByRole('heading', { level: 2, name: title })).toBeVisible()
    await expect(main(page).getByText(content)).toBeVisible()

    // Edit it from the admin list.
    await page.goto(`/equipes/${team.slug}/admin/pages`)
    const editLink = main(page)
      .locator('[draggable="true"]')
      .filter({ hasText: title })
      .getByRole('link')
    await hydrated(editLink)
    await editLink.click()
    await expect(page).toHaveURL(
      new RegExp(`/equipes/${team.slug}/admin/pages/${summary.slug}/modifier$`)
    )
    const editTitle = main(page).getByLabel('Titre de la page')
    const editForm = main(page)
      .locator('form')
      .filter({ has: page.getByLabel('Titre de la page') })
    await expect(editTitle).toHaveValue(title)
    await expect(richText(editForm, EDITOR_LABEL.teamPage)).toHaveText(content)
    await editTitle.fill(retitled)
    await writeRichText(editForm, EDITOR_LABEL.teamPage, recontent, 10000)
    await editForm.getByRole('button', { name: 'Enregistrer' }).click()

    await expect(page.getByText('Page mise à jour avec succès', { exact: true })).toBeVisible()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/admin/pages$`))
    await expect(
      main(page).locator('[draggable="true"]').filter({ hasText: retitled })
    ).toBeVisible()
    await expect(main(page).getByText(title, { exact: true })).toHaveCount(0)

    const edited = await pageOf(owner, team.slug, summary.slug)
    expect(edited.title).toBe(retitled)
    expect(edited.media.markdown.trim()).toBe(recontent)

    // A plain member reads the new version.
    const { context: memberContext, page: memberPage } = await pageAs(browser, member)
    try {
      await memberPage.goto(`/equipes/${team.slug}`)
      await expect(teamHeading(memberPage, team.name)).toBeVisible()
      await expect(teamNav(memberPage).getByRole('link', { name: title })).toHaveCount(0)
      await teamNav(memberPage).getByRole('link', { name: retitled }).click()
      await expect(
        main(memberPage).getByRole('heading', { level: 2, name: retitled })
      ).toBeVisible()
      await expect(main(memberPage).getByText(recontent)).toBeVisible()
    } finally {
      await memberContext.close()
    }
  })
})

/** Opens /equipes filtered on `name` in a context of its own (anonymous when `who` is undefined). */
async function teamListAs(browser: Browser, who: AuthResponse | undefined, name: string) {
  const { context, page } = await pageAs(browser, who)
  // role=all: a signed-in visitor's list defaults to their own teams.
  await page.goto(`/equipes?q=${encodeURIComponent(name)}${who ? '&role=all' : ''}`)
  await expect(page.getByRole('heading', { level: 2, name: 'Équipes' })).toBeVisible()
  return { context, page }
}

/** Whether /equipes shows the team `name` to `who` — asserting the list did render either way. */
async function expectListed(
  browser: Browser,
  who: AuthResponse | undefined,
  name: string,
  listed: boolean
) {
  const { context, page } = await teamListAs(browser, who, name)
  try {
    if (listed) {
      await expect(teamCard(page, name)).toBeVisible()
    } else {
      // The filtered empty state is the list having answered, with nothing.
      await expect(main(page).getByText('Aucune équipe trouvée', { exact: true })).toBeVisible()
      await expect(teamCard(page, name)).toHaveCount(0)
    }
  } finally {
    await context.close()
  }
}

test.describe('the team list', () => {
  test('a members-only team is listed to its members alone; made public in the settings, to everyone', async ({
    browser,
    context,
    page,
  }) => {
    const owner = await newUser('Flow team list owner')
    const member = await newUser('Flow team list member')
    const outsider = await newUser('Flow team list outsider')
    const team = await newTeam(owner, unique('Annuaire'))
    await addMember(await roleSession('admin'), team.slug, member)

    // Members only: its members find it, nobody else does.
    await expectListed(browser, owner, team.name, true)
    await expectListed(browser, member, team.name, true)
    await expectListed(browser, outsider, team.name, false)
    await expectListed(browser, undefined, team.name, false)

    // The platform admin lets the owner choose; the owner makes it public in the settings.
    await setTeamAttributes(team, { visibilityEditable: true })
    await signIn(context, owner)
    await page.goto(`/equipes/${team.slug}/admin/parametres`)
    const nameInput = main(page).getByRole('textbox', { name: "Nom de l'équipe" })
    const form = main(page)
      .locator('form')
      .filter({ has: page.getByRole('textbox', { name: "Nom de l'équipe" }) })
    await hydrated(nameInput)
    const visibility = form.getByRole('combobox', { name: "Visibilité de l'équipe" })
    await expect(visibility).toHaveValue('Équipe uniquement')
    await visibility.click()
    await page.getByRole('option', { name: 'Public', exact: true }).click()
    await expect(visibility).toHaveValue('Public')
    await form.getByRole('button', { name: 'Enregistrer' }).click()
    await expect(page.getByText('Équipe mise à jour avec succès', { exact: true })).toBeVisible()
    await expect(teamHeading(page, team.name)).toBeVisible()
    expect((await teamAs(owner, team.slug)).visibility).toBe('PUBLIC')

    await expectListed(browser, outsider, team.name, true)
    await expectListed(browser, undefined, team.name, true)
    expect((await listedTeams(undefined, team.name)).teams.map((t) => t.id)).toEqual([team.id])

    // An anonymous visitor follows the card to the team.
    const { context: anonymous, page: visitor } = await teamListAs(browser, undefined, team.name)
    try {
      const card = teamCard(visitor, team.name)
      await hydrated(card)
      await card.click()
      await expect(visitor).toHaveURL(new RegExp(`/equipes/${team.slug}$`))
      await expect(teamHeading(visitor, team.name)).toBeVisible()
    } finally {
      await anonymous.close()
    }
  })
})

/** The team header's call to join, next to its title. */
const joinButton = (page: Page) => page.getByRole('button', { name: "Rejoindre l'équipe" })

test.describe('joining a team', () => {
  test('a signed-in user joins a public, joinable team from its page, and can then join its rides', async ({
    context,
    page,
  }) => {
    const owner = await newUser('Flow team join owner')
    const joiner = await newUser('Flow team joiner')
    const team = await publicTeam(owner, unique('Adhésion libre'), true)
    const group = unique('Groupe ouvert')
    const ride = await newRide(owner, team.slug, unique('Sortie publique'), {
      visibility: 'PUBLIC',
      groups: [{ name: group }],
    })
    await signIn(context, joiner)

    // A public ride of a team they are not in: they read it, but may not join it yet.
    await openRide(page, team.slug, ride)
    await expect(
      main(page).getByText('Rejoignez cette équipe pour participer aux sorties.')
    ).toBeVisible()
    await expect(
      groupCard(page, group).getByRole('button', { name: 'Rejoindre', exact: true })
    ).toHaveCount(0)

    // The alert leads to the team, whose header offers to join it.
    const viewTeam = main(page).getByRole('link', { name: "Voir l'équipe" })
    await hydrated(viewTeam)
    await viewTeam.click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}$`))
    await expect(teamHeading(page, team.name)).toBeVisible()
    await expect(page.getByRole('button', { name: "Quitter l'équipe" })).toHaveCount(0)
    const join = joinButton(page)
    await hydrated(join)
    const joined = page.waitForResponse(
      (r) => r.request().method() === 'POST' && r.url().endsWith(`/teams/${team.slug}/members/join`)
    )
    await join.click()
    expect((await joined).status()).toBe(201)

    // The header swaps « Rejoindre » for « Quitter », with no « Gérer »: a plain member.
    await expect(page.getByRole('button', { name: "Quitter l'équipe" })).toBeVisible()
    await expect(joinButton(page)).toHaveCount(0)
    await expect(page.getByRole('link', { name: 'Gérer', exact: true })).toHaveCount(0)
    expect(await teamAs(joiner, team.slug)).toMatchObject({ role: 'MEMBER', memberCount: 2 })
    const roster = await rosterOf(owner, team.slug)
    expect(roster.members.find((m) => m.user.id === joiner.user.id)?.role).toBe('MEMBER')

    // The server's state, not the client cache.
    await page.reload()
    await expect(teamHeading(page, team.name)).toBeVisible()
    await expect(page.getByRole('button', { name: "Quitter l'équipe" })).toBeVisible()
    await expect(joinButton(page)).toHaveCount(0)

    // The team's ride is theirs to join now.
    await openRide(page, team.slug, ride)
    await expect(
      main(page).getByText('Rejoignez cette équipe pour participer aux sorties.')
    ).toHaveCount(0)
    const card = groupCard(page, group)
    const joinRide = card.getByRole('button', { name: 'Rejoindre', exact: true })
    await hydrated(joinRide)
    await joinRide.click()
    await expect(card.getByText("J'y vais", { exact: true })).toBeVisible()
    await expect
      .poll(async () => (await readRide(joiner, team.slug, ride.slug)).registered)
      .toBe(true)
  })

  test('a public team that takes no join request offers no join button, and the API refuses the join', async ({
    context,
    page,
  }) => {
    const owner = await newUser('Flow team closed join owner')
    const visitor = await newUser('Flow team closed join visitor')
    const team = await publicTeam(owner, unique('Adhésion fermée'), false)
    expect(team, 'precondition: a public team, born closed to join requests').toMatchObject({
      visibility: 'PUBLIC',
      joinable: false,
    })

    // The API refuses the join, and they stay out.
    expect(await joinStatus(visitor, team.slug)).toBe(403)
    expect((await teamAs(visitor, team.slug)).role ?? null).toBeNull()

    // …so the page does not offer it.
    await signIn(context, visitor)
    await page.goto(`/equipes/${team.slug}`)
    await expect(teamHeading(page, team.name)).toBeVisible()
    await pageHydrated(page)
    await expect(page.getByRole('button', { name: "Quitter l'équipe" })).toHaveCount(0)
    await expect(joinButton(page)).toHaveCount(0)

    // Counter-check, same visitor and session: once the platform admin opens the team, it does.
    await setTeamAttributes(team, { joinable: true })
    await page.reload()
    await expect(teamHeading(page, team.name)).toBeVisible()
    await expect(joinButton(page)).toBeVisible()
  })
})

/**
 * What someone who may not (or no longer) see a team meets on its pages: the team page and its tabs
 * send them back to /equipes — after React Query's retries of the refused read, hence the timeout —
 * and a ride page says the ride is not there.
 */
async function expectTeamGone(page: Page, teamSlug: string, rideSlug: string) {
  await page.goto(`/equipes/${teamSlug}`)
  await expect(page).toHaveURL(/\/equipes$/, { timeout: 20_000 })
  await expect(page.getByRole('heading', { level: 2, name: 'Équipes' })).toBeVisible()
  await page.goto(ridePath(teamSlug, rideSlug))
  await expect(main(page).getByRole('heading', { name: 'Sortie non trouvée' })).toBeVisible({
    timeout: 20_000,
  })
}

test.describe('leaving a team', () => {
  test('a member leaves from the team page, and its members-only content is closed to them', async ({
    browser,
    context,
    page,
  }) => {
    // Every closed page waits out React Query's retries (~7 s) before redirecting.
    test.slow()
    const owner = await newUser('Flow team leave owner')
    const member = await newUser('Flow team leaver')
    const team = await newTeam(owner, unique('Départ'))
    await addMember(await roleSession('admin'), team.slug, member)
    const ride = await newRide(owner, team.slug, unique('Sortie des membres'))
    const pageTitle = unique('Consignes')
    const teamPage = await newTeamPage(
      owner,
      team.slug,
      pageTitle,
      'Rendez-vous devant la boulangerie'
    )
    await signIn(context, member)

    await page.goto(`/equipes/${team.slug}`)
    await expect(teamHeading(page, team.name)).toBeVisible()
    await expect(
      teamNav(page).getByRole('link', { name: pageTitle }),
      'precondition: a member sees the members-only page'
    ).toBeVisible()
    await expect(page.getByRole('link', { name: 'Gérer', exact: true })).toHaveCount(0)

    const leave = page.getByRole('button', { name: "Quitter l'équipe" })
    await hydrated(leave)
    await leave.click()
    const dialog = page.getByRole('dialog', { name: "Quitter l'équipe" })
    await expect(dialog.getByText('Voulez-vous vraiment quitter cette équipe ?')).toBeVisible()
    const left = page.waitForResponse(
      (r) =>
        r.request().method() === 'POST' && r.url().endsWith(`/teams/${team.slug}/members/leave`)
    )
    await dialog.getByRole('button', { name: "Quitter l'équipe" }).click()
    expect((await left).ok()).toBe(true)

    // Back on the team list, where the team no longer is theirs.
    await expect(page).toHaveURL(/\/equipes$/)
    await expect(page.getByRole('heading', { level: 2, name: 'Équipes' })).toBeVisible()
    await expectListed(browser, member, team.name, false)
    await expectListed(browser, owner, team.name, true)

    // Its pages are closed to them now…
    await expectTeamGone(page, team.slug, ride.slug)
    await page.goto(`/equipes/${team.slug}/pages/${teamPage.slug}`)
    await expect(page).toHaveURL(/\/equipes$/, { timeout: 20_000 })

    // …and to the API.
    const refused = await teamAs(member, team.slug).catch((error: unknown) => error)
    expect(refused).toBeInstanceOf(ApiError)
    expect((refused as ApiError).status).toBe(403)
    expect(await findRide(member, team.slug, ride.slug)).toBeNull()
    const roster = await rosterOf(owner, team.slug)
    expect(roster.members.map((m) => m.user.id)).toEqual([owner.user.id])
    expect((await teamAs(owner, team.slug)).memberCount).toBe(1)
  })
})

test.describe('deleting a team', () => {
  test('the owner deletes the team from the settings danger zone; it leaves /equipes and its pages close', async ({
    browser,
    context,
    page,
  }) => {
    // Every closed page waits out React Query's retries (~7 s) before redirecting.
    test.slow()
    const owner = await newUser('Flow team delete owner')
    const member = await newUser('Flow team delete member')
    const team = await newTeam(owner, unique('Suppression'))
    await addMember(await roleSession('admin'), team.slug, member)
    const ride = await newRide(owner, team.slug, unique('Sortie supprimée'))
    await signIn(context, owner)

    // The admin runs the team: they cannot leave it, only delete it.
    await page.goto(`/equipes/${team.slug}`)
    await expect(teamHeading(page, team.name)).toBeVisible()
    await expect(page.getByRole('link', { name: 'Gérer', exact: true })).toBeVisible()
    await expect(page.getByRole('button', { name: "Quitter l'équipe" })).toHaveCount(0)
    await expectListed(browser, member, team.name, true)

    await page.goto(`/equipes/${team.slug}/admin/parametres`)
    await expect(
      page.getByRole('heading', { level: 2, name: "Paramètres de l'équipe" })
    ).toBeVisible()
    await expect(
      main(page).getByRole('heading', { level: 2, name: 'Zone de danger' })
    ).toBeVisible()
    const remove = main(page).getByRole('button', { name: "Supprimer l'équipe" })
    await hydrated(remove)

    // Cancelling keeps it.
    await remove.click()
    const dialog = page.getByRole('dialog', { name: 'Zone de danger' })
    await expect(dialog.getByText(team.name, { exact: false })).toBeVisible()
    await dialog.getByRole('button', { name: 'Annuler' }).click()
    await expect(dialog).toBeHidden()
    expect((await teamAs(owner, team.slug)).name, 'cancelled: the team is there').toBe(team.name)

    await remove.click()
    const deleted = page.waitForResponse(
      (r) => r.request().method() === 'DELETE' && r.url().endsWith(`/api/teams/${team.slug}`)
    )
    await dialog.getByRole('button', { name: "Oui, supprimer l'équipe" }).click()
    expect((await deleted).ok()).toBe(true)
    await expect(page.getByText('Équipe supprimée avec succès', { exact: true })).toBeVisible()
    await expect(page).toHaveURL(/\/equipes$/)
    await expect(page.getByRole('heading', { level: 2, name: 'Équipes' })).toBeVisible()

    // Gone from the list, for its owner and its member alike.
    await expectListed(browser, owner, team.name, false)
    await expectListed(browser, member, team.name, false)

    // Its pages close, for the member too.
    const { context: memberContext, page: memberPage } = await pageAs(browser, member)
    try {
      await expectTeamGone(memberPage, team.slug, ride.slug)
    } finally {
      await memberContext.close()
    }

    // The API answers 404, to everyone — the platform admin included.
    expect(await apiGetOrNull(owner, `/api/teams/${team.slug}`)).toBeNull()
    expect(await apiGetOrNull(member, `/api/teams/${team.slug}`)).toBeNull()
    expect(await apiGetOrNull(await roleSession('admin'), `/api/teams/${team.slug}`)).toBeNull()
    expect(await findRide(member, team.slug, ride.slug)).toBeNull()
  })
})

test.describe('regressions', () => {
  test('a custom page’s row actions are named for the page, not the team', async ({
    context,
    page,
  }) => {
    // TeamPagesAdminPage labelled a page's edit link « Modifier l’équipe » and its delete button
    // and confirmation « Supprimer l’équipe » (fixed 2026-09-25).
    const owner = await newUser('Flow team page labels')
    const team = await newTeam(owner, unique('Libellés'))
    const title = unique('FAQ')
    await newTeamPage(owner, team.slug, title, 'Questions fréquentes')
    await signIn(context, owner)

    await page.goto(`/equipes/${team.slug}/admin/pages`)
    const row = main(page).locator('[draggable="true"]').filter({ hasText: title })
    await expect(row, 'precondition: the page is listed').toBeVisible()
    await expect(row.getByRole('link'), 'precondition: one edit link').toHaveCount(1)
    await expect(row.getByRole('button'), 'precondition: one delete button').toHaveCount(1)
    await expect(row.getByRole('link')).toHaveAccessibleName('Modifier')
    const remove = row.getByRole('button')
    await expect(remove).toHaveAccessibleName('Supprimer')
    await hydrated(remove)
    await remove.click()
    const dialog = page.getByRole('dialog', { name: 'Supprimer la page' })
    await expect(
      dialog.getByText(`Voulez-vous vraiment supprimer la page "${title}" ?`, { exact: false })
    ).toBeVisible()
    await expect(dialog.getByRole('button', { name: 'Supprimer', exact: true })).toBeVisible()
    await expect(dialog.getByRole('button', { name: /équipe/ })).toHaveCount(0)
  })

  test('the description editor of the team form has an accessible name', async ({
    context,
    page,
  }) => {
    // MarkdownEditor dropped the ariaLabel MediaEditor passed it: the Tiptap textbox of every form
    // (team, ride, trip, post, route, ad, team page, ride template) was unnamed (fixed 2026-09-25).
    const owner = await newUser('Flow team editor name')
    await signIn(context, owner)
    await page.goto('/equipes/nouvelle')
    const form = main(page).locator('form')
    await expect(
      form.getByRole('textbox', { name: "Nom de l'équipe" }),
      'precondition: the form is rendered'
    ).toBeVisible()
    await expect(richText(form, EDITOR_LABEL.team)).toHaveAttribute('contenteditable', 'true')
  })

  test('the team deletion confirmation shows the team name, not HTML markup', async ({
    context,
    page,
  }) => {
    // TeamSettingsPage passed teams.settings.dangerZone.deleteWarning, which holds
    // <strong>{{teamName}}</strong>, to ConfirmDialog as a plain string: the tags showed as text
    // (fixed 2026-09-25: <Trans>).
    const owner = await newUser('Flow team delete markup')
    const team = await newTeam(owner, unique('Balises'))
    await signIn(context, owner)
    await page.goto(`/equipes/${team.slug}/admin/parametres`)
    const remove = main(page).getByRole('button', { name: "Supprimer l'équipe" })
    await hydrated(remove)
    await remove.click()
    const dialog = page.getByRole('dialog', { name: 'Zone de danger' })
    await expect(dialog.locator('strong').filter({ hasText: team.name })).toHaveText(team.name)
    await expect(dialog.getByText('<strong>', { exact: false })).toHaveCount(0)
    await expect(
      dialog.getByText(`Voulez-vous vraiment supprimer ${team.name} ?`, { exact: false })
    ).toBeVisible()
  })

  test('the role picker of a member row has an accessible name', async ({ context, page }) => {
    // TeamMemberList rendered the role <Select> without a label or aria-label (fixed 2026-09-25).
    const owner = await newUser('Flow team role picker owner')
    const member = await newUser('Flow team role picker member')
    const team = await newTeam(owner, unique('Sélecteur de rôle'))
    await addMember(await roleSession('admin'), team.slug, member)
    await signIn(context, owner)

    await page.goto(`/equipes/${team.slug}/admin/membres`)
    const row = memberRow(page, member.user.displayName)
    const edit = row.getByRole('button', { name: 'Modifier' })
    await hydrated(edit)
    await edit.click()
    await expect(row.getByRole('combobox')).toHaveAccessibleName(
      `Rôle de ${member.user.displayName}`
    )
  })
})

/**
 * The team's outgoing webhook, in the settings (TeamWebhookSettings.tsx): its URL is a secret — a
 * Discord or Slack webhook URL is enough to post to the channel — so the API only ever returns it
 * masked (TeamWebhookService.java:147-152), the input starts empty, and an empty input on save
 * keeps the current URL (TeamWebhookSettings.tsx:106-112 omits it, TeamWebhookService.java:55-66
 * keeps it). Nothing is ever posted: the team publishes nothing, and the test message is not sent.
 */
test.describe('the team webhook', () => {
  const webhookPath = (slug: string) => `/api/teams/${slug}/webhook`

  test('the owner saves a Discord webhook, shown masked; a language-only change keeps it; a private address is refused; removing asks first', async ({
    context,
    page,
  }) => {
    test.setTimeout(90_000)
    const owner = await newUser('Flow team webhook owner')
    const team = await newTeam(owner, unique('Webhook'))
    const secret = discordWebhook()
    const masked = `https://discord.com/…${secret.token.slice(-4)}`
    await signIn(context, owner)

    await page.goto(`/equipes/${team.slug}/admin/parametres`)
    // The webhook's own block, below the team form — which has an « Enregistrer » of its own.
    const section = main(page)
      .locator('div')
      .filter({ has: page.getByRole('heading', { level: 2, name: 'Webhook' }) })
      .filter({ has: page.getByRole('textbox', { name: 'URL du webhook' }) })
      .last()
    const url = section.getByRole('textbox', { name: 'URL du webhook' })
    const save = section.getByRole('button', { name: 'Enregistrer' })
    await hydrated(url)
    await expect(url).toHaveValue('')
    // The first save needs a URL.
    await expect(save).toBeDisabled()

    // 1. A Discord URL, saved: from now on it is only ever shown masked.
    await url.fill(secret.url)
    const saved = page.waitForResponse(
      (r) => r.url().endsWith(webhookPath(team.slug)) && r.request().method() === 'PUT'
    )
    await save.click()
    expect((await saved).ok()).toBe(true)
    await expect(page.getByText('Webhook enregistré', { exact: true })).toBeVisible()
    await expect(section.getByText('Adresse actuelle :', { exact: true })).toBeVisible()
    await expect(section.getByText(masked, { exact: true })).toBeVisible()
    await expect(section.getByText('Discord', { exact: true })).toBeVisible()
    await expect(url).toHaveValue('')
    await expect(url).toHaveAttribute('placeholder', masked)
    expect(await webhookOf(owner, team.slug)).toMatchObject({
      configured: true,
      maskedUrl: masked,
      kind: 'DISCORD',
      language: 'fr',
      enabled: true,
    })
    expect(await page.content()).not.toContain(secret.token)

    // 2. Only the language changes, the URL field left empty: the request carries no URL, and the
    // webhook keeps its own.
    const language = section.getByRole('combobox', { name: 'Langue' })
    await language.click()
    await page
      .getByRole('listbox', { name: 'Langue' })
      .getByRole('option', { name: 'English' })
      .click()
    await expect(language).toHaveValue('English')
    const kept = page.waitForResponse(
      (r) => r.url().endsWith(webhookPath(team.slug)) && r.request().method() === 'PUT'
    )
    await save.click()
    const keptResponse = await kept
    expect(keptResponse.ok()).toBe(true)
    expect(keptResponse.request().postDataJSON()).toEqual({ language: 'en', enabled: true })
    await expect(page.getByText('Webhook enregistré', { exact: true }).first()).toBeVisible()
    expect(await webhookOf(owner, team.slug)).toMatchObject({
      configured: true,
      maskedUrl: masked,
      kind: 'DISCORD',
      language: 'en',
    })
    // A fresh load reads it back from the server.
    await page.reload()
    await expect(section.getByText(masked, { exact: true })).toBeVisible()
    await expect(section.getByRole('combobox', { name: 'Langue' })).toHaveValue('English')

    // 3. Neither the server-rendered document nor its dehydrated query cache holds the secret.
    const document = await rawDocument(`/equipes/${team.slug}/admin/parametres`, {
      cookie: sessionCookie(owner),
    })
    expect(document.status).toBe(200)
    expect(document.html).not.toContain(secret.token)
    expect(JSON.stringify(reactQueryState(document.html))).not.toContain(secret.token)
    expect(
      await page.evaluate(
        () => window.document.getElementById('ssr-query-state')?.textContent ?? '{}'
      )
    ).not.toContain(secret.token)
    expect(await page.content()).not.toContain(secret.token)

    // 4. An address on the loopback is refused, with the translated message — once — and the
    // webhook in place stays.
    const toastsSeen = await watchToasts(page)
    await hydrated(url)
    await url.fill('http://127.0.0.1/hook')
    const refused = page.waitForResponse(
      (r) => r.url().endsWith(webhookPath(team.slug)) && r.request().method() === 'PUT'
    )
    await save.click()
    expect((await refused).status()).toBe(400)
    const message = "L'URL doit être en https et pointer vers une adresse publique."
    await expect(page.getByText(message, { exact: true })).toBeVisible()
    expect((await toastsSeen()).filter((text) => text.includes(message))).toHaveLength(1)
    expect((await webhookOf(owner, team.slug)).maskedUrl).toBe(masked)

    // 5. Removing asks first: cancelled, nothing changes…
    const remove = section.getByRole('button', { name: 'Supprimer le webhook' })
    await remove.click()
    let dialog = page.getByRole('dialog', { name: 'Supprimer le webhook' })
    await expect(dialog.getByText(/ne seront plus publiées à cette adresse/)).toBeVisible()
    await dialog.getByRole('button', { name: 'Annuler' }).click()
    await expect(dialog).toBeHidden()
    expect((await webhookOf(owner, team.slug)).configured).toBe(true)

    // …confirmed, the webhook is gone, and the form is back to its first state.
    await remove.click()
    dialog = page.getByRole('dialog', { name: 'Supprimer le webhook' })
    const deleted = page.waitForResponse(
      (r) => r.url().endsWith(webhookPath(team.slug)) && r.request().method() === 'DELETE'
    )
    await dialog.getByRole('button', { name: 'Supprimer le webhook' }).click()
    expect((await deleted).ok()).toBe(true)
    await expect(page.getByText('Webhook supprimé', { exact: true })).toBeVisible()
    await expect(section.getByText('Adresse actuelle :', { exact: true })).toHaveCount(0)
    await expect(remove).toHaveCount(0)
    expect(await webhookOf(owner, team.slug)).toMatchObject({ configured: false })
  })
})
