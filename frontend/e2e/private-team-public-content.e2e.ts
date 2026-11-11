import type { Page } from '@playwright/test'
import type { RideDto } from '../src/api/dto'
import { apiGet } from './support/api'
import {
  addMember,
  getTeam,
  newTeam,
  newUser,
  roleSession,
  setTeamAttributes,
  signIn,
} from './support/data'
import { expect, test, unique } from './support/fixtures'
import { adminTeam } from './support/platform-admin'
import { newRide, ridePath } from './support/rides'
import { rawDocument, ssrOutlet } from './support/ssr'
import { hydrated, pageAs, pageHydrated } from './support/ui'

/**
 * The public content of a private team (docs/LEDGER_*.md WEB-166, API-176; plan
 * `docs/plans/2026-11-11-visibilite-contenu-equipe-privee.md` §5).
 *
 * A platform admin lets a private team publish by link (`publicContentAllowed`, decision D2). Its
 * public ride is then readable by anyone holding the link, rendered from the ride's embedded team
 * summary — `GET team` stays closed (`accessible: false`), so the page never asks for it and never
 * links to it — and kept out of search engines (`permissions.indexable`, decision D1). The team
 * itself still answers 404, as a team that never existed. Going private is confirmed first: all
 * the team's content turns « Équipe » (decision D3).
 *
 * Never modifies the seed: every team here is the test's own.
 */

const main = (page: Page) => page.getByRole('main')
/** The comment section's heading, « Commentaires (n) »: only a reader allowed to comment has it. */
const commentsHeading = (page: Page) =>
  main(page).getByRole('heading', { name: /^Commentaires \(\d+\)$/ })

/** A private team allowed to publish by link, its owner (an ADMIN) and one PUBLIC ride. */
async function privateTeamWithPublicRide(label: string) {
  const owner = await newUser(unique(`Capitaine ${label}`))
  const team = await newTeam(owner, unique(`Équipe privée ${label}`))
  expect(team.visibility).toBe('TEAM')
  await setTeamAttributes(team, { publicContentAllowed: true })
  const ride = await newRide(owner, team.slug, unique(`Sortie ouverte ${label}`), {
    visibility: 'PUBLIC',
  })
  return { owner, team, ride }
}

test.describe('a public ride of a private team, read by link', () => {
  test('an anonymous visitor opens it: the ride, its team named but not linked, no way in', async ({
    browser,
  }) => {
    const { team, ride } = await privateTeamWithPublicRide('lien')
    const { context, page } = await pageAs(browser, undefined)
    try {
      const teamReads: string[] = []
      page.on('request', (request) => {
        const path = new URL(request.url()).pathname
        if (path === `/api/teams/${team.slug}`) teamReads.push(path)
      })
      const response = await page.goto(ridePath(team.slug, ride.slug))
      expect(response?.status()).toBe(200)
      await pageHydrated(page)
      await expect(main(page).getByRole('heading', { name: ride.name, level: 2 })).toBeVisible()
      // The team's name from the ride's summary, with no link to a team that would answer 404.
      const banner = main(page).getByTestId('team-context-banner')
      await expect(banner).toContainText(team.name)
      await expect(banner.getByRole('link')).toHaveCount(0)
      await expect(
        main(page).locator(`a[href$="/equipes/${team.slug}"], a[href$="/teams/${team.slug}"]`)
      ).toHaveCount(0)
      // Nothing of the members': no registration, no comments.
      await expect(main(page).getByRole('button', { name: 'Rejoindre' })).toHaveCount(0)
      await expect(commentsHeading(page)).toHaveCount(0)
      await expect(main(page).getByText('Connectez-vous', { exact: false })).toBeVisible()
      // The browser never asked for the team (`accessible: false`).
      expect(teamReads).toEqual([])
    } finally {
      await context.close()
    }
  })

  test("a signed-in non-member gets no more of the members' than an anonymous visitor", async ({
    browser,
  }) => {
    const { owner, team, ride } = await privateTeamWithPublicRide('non-membre')
    const stranger = await newUser(unique('Hors équipe'))
    const { context, page } = await pageAs(browser, stranger)
    const { context: ownerContext, page: ownerPage } = await pageAs(browser, owner)
    try {
      // `permissions.canRegister` and `canComment` are false: no registration, no comments.
      await page.goto(ridePath(team.slug, ride.slug))
      await pageHydrated(page)
      await expect(main(page).getByRole('heading', { name: ride.name, level: 2 })).toBeVisible()
      await expect(main(page).getByRole('button', { name: 'Rejoindre' })).toHaveCount(0)
      await expect(commentsHeading(page)).toHaveCount(0)
      // The control: a member of the same team reads the comments of the same ride.
      await ownerPage.goto(ridePath(team.slug, ride.slug))
      await pageHydrated(ownerPage)
      await expect(commentsHeading(ownerPage)).toBeVisible()
    } finally {
      await context.close()
      await ownerContext.close()
    }
  })

  test('its server document is a 200, out of search engines, its ride inside', async () => {
    const { team, ride } = await privateTeamWithPublicRide('document')
    const document = await rawDocument(ridePath(team.slug, ride.slug))
    expect(document.status).toBe(200)
    expect(ssrOutlet(document.html)).toContain(ride.name)
    // Readable by link only, never indexed (decision D1): `permissions.indexable` is false.
    expect(document.html).toContain('<meta name="robots" content="noindex" />')
    expect(document.html).not.toContain('rel="canonical"')
    const anonymous = await apiGet<RideDto>(undefined, `/api/teams/${team.slug}/rides/${ride.slug}`)
    expect(anonymous.team.accessible).toBe(false)
    expect(anonymous.permissions.indexable).toBe(false)
  })

  test('the team itself still answers 404, as a team that never existed', async () => {
    const { team } = await privateTeamWithPublicRide('fermée')
    expect((await rawDocument(`/equipes/${team.slug}`)).status).toBe(404)
    expect((await rawDocument(`/equipes/${team.slug}/agenda`)).status).toBe(404)
    // And a ride of the same team left « Équipe » is no more found than its team.
    const owner = await roleSession('admin')
    const closed = await newRide(owner, team.slug, unique('Sortie fermée'), { visibility: 'TEAM' })
    expect((await rawDocument(ridePath(team.slug, closed.slug))).status).toBe(404)
  })
})

test.describe('the platform admin switch', () => {
  // The admin's session goes into the page's context, as in flow-platform-admin.e2e.ts: in
  // `test.use` it would also reach the Node-side API contexts.
  test.beforeEach(async ({ context }) => signIn(context, await roleSession('admin')))

  test('turning « contenu public par lien » on lets the private team’s organizers publish outside', async ({
    browser,
    page,
  }) => {
    test.setTimeout(90_000)
    const owner = await newUser(unique('Capitaine interrupteur'))
    const team = await newTeam(owner, unique('Équipe à ouvrir'))
    const organizer = await newUser(unique('Organisation'))
    await addMember(await roleSession('admin'), team.slug, organizer, 'ORGANIZER')
    expect((await adminTeam(team)).publicContentAllowed).toBe(false)

    // Before: a private team's ride editor has nothing to choose — « Équipe » only, no field.
    const { context: organizerContext, page: organizerPage } = await pageAs(browser, organizer)
    try {
      await organizerPage.goto(`/equipes/${team.slug}/sorties/nouvelle`)
      await hydrated(main(organizerPage).getByRole('textbox', { name: 'Titre de la sortie' }))
      await expect(
        main(organizerPage).getByRole('radio', { name: 'Public', exact: true })
      ).toHaveCount(0)

      // The platform admin turns the switch on in the team's settings.
      await page.goto(`/equipes/${team.slug}/admin/parametres`)
      const nameInput = main(page).getByRole('textbox', { name: "Nom de l'équipe" })
      await hydrated(nameInput)
      const form = main(page).locator('form').filter({ has: nameInput })
      const allowed = form.getByRole('switch', { name: 'Autoriser le contenu public par lien' })
      await expect(allowed).toBeEnabled()
      await expect(allowed).not.toBeChecked()
      await allowed.check()
      await form.getByRole('button', { name: 'Enregistrer' }).click()
      await expect(page.getByText('Équipe mise à jour avec succès', { exact: true })).toBeVisible()
      expect(await adminTeam(team)).toMatchObject({
        publicContentAllowed: true,
        visibility: 'TEAM',
      })
      expect((await getTeam(owner, team.slug)).allowedContentVisibilities.ride).toEqual([
        'TEAM',
        'PUBLIC_UNLISTED',
        'PUBLIC',
      ])

      // After: the editor offers the three, starts from « Équipe » (`defaultContentVisibility`),
      // and says what « Public » means in a private team.
      await organizerPage.goto(`/equipes/${team.slug}/sorties/nouvelle`)
      await hydrated(main(organizerPage).getByRole('textbox', { name: 'Titre de la sortie' }))
      await expect(
        main(organizerPage).getByRole('radio', { name: 'Équipe uniquement' })
      ).toBeChecked()
      await expect(
        main(organizerPage).getByRole('radio', { name: 'Public', exact: true })
      ).toBeVisible()
      await expect(main(organizerPage).getByTestId('visibility-private-team-hint')).toContainText(
        'toute personne qui a le lien'
      )
    } finally {
      await organizerContext.close()
    }
  })

  test('making a team private asks first, saying all its content turns « Équipe »', async ({
    page,
  }) => {
    const owner = await roleSession('admin')
    const team = await newTeam(owner, unique('Équipe qui se ferme'), { visibility: 'PUBLIC' })
    const ride = await newRide(owner, team.slug, unique('Sortie publique'), {
      visibility: 'PUBLIC',
    })

    await page.goto(`/equipes/${team.slug}/admin/parametres`)
    const nameInput = main(page).getByRole('textbox', { name: "Nom de l'équipe" })
    await hydrated(nameInput)
    const form = main(page).locator('form').filter({ has: nameInput })
    const visibility = form.getByRole('combobox', { name: "Visibilité de l'équipe" })
    await visibility.click()
    await page.getByRole('option', { name: 'Équipe uniquement', exact: true }).click()
    await form.getByRole('button', { name: 'Enregistrer' }).click()

    const confirm = page.getByRole('dialog', { name: "Rendre l'équipe privée ?" })
    await expect(confirm).toContainText('passera en « Équipe uniquement »')
    // Cancelled: nothing changes.
    await confirm.getByRole('button', { name: 'Annuler' }).click()
    await expect(confirm).toBeHidden()
    expect((await getTeam(owner, team.slug)).visibility).toBe('PUBLIC')

    await form.getByRole('button', { name: 'Enregistrer' }).click()
    await confirm.getByRole('button', { name: 'Rendre privée' }).click()
    await expect(page.getByText('Équipe mise à jour avec succès', { exact: true })).toBeVisible()
    expect((await getTeam(owner, team.slug)).visibility).toBe('TEAM')
    const closed = await apiGet<RideDto>(owner, `/api/teams/${team.slug}/rides/${ride.slug}`)
    expect(closed.visibility).toBe('TEAM')
  })
})
