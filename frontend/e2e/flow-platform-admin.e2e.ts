import type { Page } from '@playwright/test'
import type { AdminGpsCredentialDto, AdminTeamDto, ConfigDto, TeamDetailDto } from '../src/api/dto'
import { apiGetOrNull } from './support/api'
import { freshAddress, getTeam, newTeam, newUser, roleSession, signIn } from './support/data'
import { OTHER_HOST, hostGet, hostStatus, originOf, otherDomain } from './support/domains'
import { expect, test, unique } from './support/fixtures'
import { listedTeams } from './support/flow-team'
import {
  ADMIN_BETA_SIGNUPS_PATH,
  ADMIN_TEAMS_PATH,
  adminDomain,
  adminDomainsPathOf,
  adminTeam,
  adminTeamRow,
  adminUser,
  adminUserRow,
  adminUsersSearch,
  aliasesOf,
  aliasesPath,
  betaSignups,
  deleteAlias,
  gpsCredentialsOf,
  credentialRow,
  rowWithCell,
  scratchDomain,
  setPlatformRole,
  toggleTeamArchived,
  uniqueLocalHost,
} from './support/platform-admin'
import { stack } from './support/stack'
import { hydrated, pageAs } from './support/ui'

/**
 * The platform administration, through its screens: the team list (archive, restore), the user
 * list (the platform role), and the « Paramètres plateforme » block of a team's settings, whose
 * governance switches decide what the team's own admins may do.
 *
 * The seeded admin account is shared by every test running in parallel: its own rights are never
 * touched (the self-demotion check only reads its row), the teams archived are the test's own, and
 * the platform role goes to a fresh account.
 */

// The admin's session goes into the page's context, not `test.use(as('admin'))`: a storageState
// in `use` also reaches the Node-side request contexts of support/api.ts, whose refresh_token cookie
// the backend honours — an « anonymous » API read would then be the platform admin's.
test.beforeEach(async ({ context }) => signIn(context, await roleSession('admin')))

const main = (page: Page) => page.getByRole('main')

/** The team settings form, once hydrated. */
async function settingsForm(page: Page, slug: string) {
  await page.goto(`/equipes/${slug}/admin/parametres`)
  const nameInput = main(page).getByRole('textbox', { name: "Nom de l'équipe" })
  await hydrated(nameInput)
  return main(page)
    .locator('form')
    .filter({ has: page.getByRole('textbox', { name: "Nom de l'équipe" }) })
}

const teamHeading = (page: Page, name: string) =>
  page.getByRole('heading', { level: 1, name, exact: true })

test.describe('archiving a team', () => {
  test('the platform admin archives a team from the list: it is gone for its members, and a restore brings it back', async ({
    page,
  }) => {
    const owner = await newUser('Platform archive owner')
    const team = await newTeam(owner, unique('Archivage'))

    await page.goto(ADMIN_TEAMS_PATH)
    const row = adminTeamRow(page, team)
    await expect(row.getByText('Active', { exact: true })).toBeVisible()
    await expect(row.getByText(team.name, { exact: true })).toBeVisible()
    // The row's only control: archive (a toggle icon — see the accessible-name test below).
    const toggle = row.getByRole('button')
    await hydrated(toggle)
    const archived = page.waitForResponse(
      (r) => r.url().endsWith(`/api/admin/teams/${team.id}/toggle-deleted`) && r.ok()
    )
    await toggle.click()
    expect(((await (await archived).json()) as AdminTeamDto).deleted).toBe(true)

    // Its owner no longer reaches it…
    expect(await apiGetOrNull<TeamDetailDto>(owner, `/api/teams/${team.slug}`)).toBeNull()
    // …while the platform list keeps it, marked « Archivée ».
    await page.reload()
    await expect(row.getByText('Archivée', { exact: true })).toBeVisible()

    // Restored (here through the API; from the list, see below), the team is its owner's again.
    await toggleTeamArchived(team)
    expect((await getTeam(owner, team.slug)).role).toBe('ADMIN')
    await page.reload()
    await expect(adminTeamRow(page, team).getByText('Active', { exact: true })).toBeVisible()
  })

  // Regression (ebf14f23): the toggle mutation invalidates the admin team list — before, the row
  // kept its « Active » badge until a reload.
  test('the status badge follows the archive at once, without a reload', async ({ page }) => {
    const owner = await newUser('Platform archive badge owner')
    const team = await newTeam(owner, unique('Archivage badge'))

    await page.goto(ADMIN_TEAMS_PATH)
    const row = adminTeamRow(page, team)
    await expect(row.getByText('Active', { exact: true })).toBeVisible()
    const toggle = row.getByRole('button')
    await hydrated(toggle)
    const archived = page.waitForResponse(
      (r) => r.url().endsWith(`/api/admin/teams/${team.id}/toggle-deleted`) && r.ok()
    )
    await toggle.click()
    expect(
      ((await (await archived).json()) as AdminTeamDto).deleted,
      'precondition: the team is archived'
    ).toBe(true)

    // No reload: the list is read again at once, and the row stays, marked « Archivée ».
    await expect(row.getByText('Archivée', { exact: true })).toBeVisible()
    await expect(row.getByText('Active', { exact: true })).toHaveCount(0)
  })

  // Regression (2270bc79): the admin list and GET /api/admin/teams/{id} include archived teams —
  // before, an archived team left the list and could only be restored through the API.
  test('an archived team stays in the list, marked « Archivée », with a way to restore it', async ({
    page,
  }) => {
    const owner = await newUser('Platform restore owner')
    const team = await newTeam(owner, unique('Restauration'))
    expect((await toggleTeamArchived(team)).deleted, 'precondition: the team is archived').toBe(
      true
    )
    // The admin read answers too, instead of a 404.
    expect((await adminTeam(team)).deleted).toBe(true)

    await page.goto(ADMIN_TEAMS_PATH)
    const row = adminTeamRow(page, team)
    await expect(row.getByText('Archivée', { exact: true })).toBeVisible()
    const restore = row.getByRole('button', { name: "Restaurer l'équipe" })
    await hydrated(restore)
    await restore.click()
    await expect(row.getByText('Active', { exact: true })).toBeVisible()
    expect((await getTeam(owner, team.slug)).role).toBe('ADMIN')
  })
})

test.describe('the platform role', () => {
  test('the platform admin grants the role to a user, who then reaches the platform area; and takes it back', async ({
    browser,
    page,
  }) => {
    const target = await newUser('Platform role target')
    await page.goto(adminUsersSearch(target.user.email))
    const row = adminUserRow(page, target.user.email)
    await expect(row.getByText(target.user.displayName, { exact: true })).toBeVisible()
    await expect(row.getByText('Admin plateforme', { exact: true })).toHaveCount(0)

    const toggle = row.getByRole('button')
    await hydrated(toggle)
    const granted = page.waitForResponse(
      (r) => r.url().endsWith(`/api/admin/users/${target.user.id}/platform-role`) && r.ok()
    )
    await toggle.click()
    await granted
    expect((await adminUser(target.user.id)).platformRole).toBe('PLATFORM_ADMIN')

    try {
      // The new admin's next session carries the role: the platform area opens.
      const { context, page: theirs } = await pageAs(browser, target)
      try {
        await theirs.goto('/plateforme')
        await expect(
          theirs.getByRole('heading', { name: 'Administration plateforme', exact: true })
        ).toBeVisible()
        await expect(theirs).toHaveURL(/\/plateforme$/)
      } finally {
        await context.close()
      }

      // Back on the list (reloaded: see the badge test below), the role is shown, and taken back.
      await page.reload()
      await expect(row.getByText('Admin plateforme', { exact: true })).toBeVisible()
      await hydrated(toggle)
      const revoked = page.waitForResponse(
        (r) => r.url().endsWith(`/api/admin/users/${target.user.id}/platform-role`) && r.ok()
      )
      await toggle.click()
      await revoked
      expect((await adminUser(target.user.id)).platformRole ?? null).toBeNull()
      await page.reload()
      await expect(row.getByText(target.user.displayName, { exact: true })).toBeVisible()
      await expect(row.getByText('Admin plateforme', { exact: true })).toHaveCount(0)
    } finally {
      // Never leave a stray platform admin behind a failed assertion.
      if ((await adminUser(target.user.id)).platformRole)
        await setPlatformRole(target.user.id, undefined)
    }
  })

  test("the platform admin's own row cannot take its own role away", async ({ page, seed }) => {
    await page.goto(adminUsersSearch(seed.admin.email))
    const row = adminUserRow(page, seed.admin.email)
    await expect(row.getByText('Admin plateforme', { exact: true })).toBeVisible()
    const toggle = row.getByRole('button')
    await hydrated(toggle)
    await expect(toggle).toBeDisabled()
  })

  // Regression (ebf14f23): the role mutation invalidates the user list.
  test('the platform role badge follows the grant at once, without a reload', async ({ page }) => {
    const target = await newUser('Platform role badge target')
    try {
      await page.goto(adminUsersSearch(target.user.email))
      const row = adminUserRow(page, target.user.email)
      await expect(row.getByText(target.user.displayName, { exact: true })).toBeVisible()
      const toggle = row.getByRole('button')
      await hydrated(toggle)
      const granted = page.waitForResponse(
        (r) => r.url().endsWith(`/api/admin/users/${target.user.id}/platform-role`) && r.ok()
      )
      await toggle.click()
      await granted
      expect(
        (await adminUser(target.user.id)).platformRole,
        'precondition: the role is granted'
      ).toBe('PLATFORM_ADMIN')

      await expect(row.getByText('Admin plateforme', { exact: true })).toBeVisible()
    } finally {
      await setPlatformRole(target.user.id, undefined)
    }
  })
})

// Regression (ebf14f23): each ActionIcon carries its Tooltip's label as aria-label.
test('the row actions of the platform lists have an accessible name', async ({ page, seed }) => {
  const owner = await newUser('Platform a11y owner')
  const team = await newTeam(owner, unique('Accessibilité'))

  await page.goto(ADMIN_TEAMS_PATH)
  const teamRow = adminTeamRow(page, team)
  await expect(teamRow.getByRole('button'), 'precondition: the row has its button').toHaveCount(1)
  // Soft: the user list's button is checked too, whatever this one gives.
  await expect.soft(teamRow.getByRole('button', { name: "Archiver l'équipe" })).toBeVisible({
    timeout: 2_000,
  })

  await page.goto(adminUsersSearch(seed.admin.email))
  const userRow = adminUserRow(page, seed.admin.email)
  await expect(userRow.getByRole('button')).toHaveCount(1)
  await expect(
    userRow.getByRole('button', {
      name: 'Impossible de retirer votre propre rôle admin plateforme',
    })
  ).toBeVisible({ timeout: 2_000 })
})

test.describe('team governance', () => {
  test("the platform admin lets a team's admins choose its visibility and add members, from the settings; the owner then makes it unlisted", async ({
    browser,
    page,
  }) => {
    test.setTimeout(90_000)
    const owner = await newUser('Platform governance owner')
    const team = await newTeam(owner, unique('Gouvernance'))
    expect(team).toMatchObject({ visibilityEditable: false, addMemberAllowed: false })

    const { context: ownerContext, page: ownerPage } = await pageAs(browser, owner)
    try {
      // Before: the owner reads the visibility, cannot change it, and has no way to add anyone.
      let ownerForm = await settingsForm(ownerPage, team.slug)
      await expect(ownerForm.getByRole('combobox', { name: "Visibilité de l'équipe" })).toHaveCount(
        0
      )
      await expect(ownerForm.getByText('Équipe uniquement', { exact: true })).toBeVisible()
      for (const name of [
        'Autoriser les admins à modifier la visibilité',
        'Autoriser les admins à ajouter des membres',
      ])
        await expect(ownerForm.getByRole('switch', { name })).toBeDisabled()
      await ownerPage.goto(`/equipes/${team.slug}/admin/membres`)
      await expect(
        main(ownerPage).getByRole('heading', { level: 2, name: 'Gestion des membres', exact: true })
      ).toBeVisible()
      await expect(main(ownerPage).getByText(owner.user.displayName)).toBeVisible()
      await expect(main(ownerPage).getByRole('button', { name: 'Inviter par e-mail' })).toHaveCount(
        0
      )

      // The platform admin turns both switches on in the team's settings.
      const form = await settingsForm(page, team.slug)
      await expect(
        form.getByRole('heading', { level: 4, name: 'Paramètres plateforme' })
      ).toBeVisible()
      const visibilityEditable = form.getByRole('switch', {
        name: 'Autoriser les admins à modifier la visibilité',
      })
      const addMemberAllowed = form.getByRole('switch', {
        name: 'Autoriser les admins à ajouter des membres',
      })
      await expect(visibilityEditable).toBeEnabled()
      await expect(visibilityEditable).not.toBeChecked()
      await expect(addMemberAllowed).not.toBeChecked()
      await visibilityEditable.check()
      await addMemberAllowed.check()
      await form.getByRole('button', { name: 'Enregistrer' }).click()
      await expect(page.getByText('Équipe mise à jour avec succès', { exact: true })).toBeVisible()
      await expect(teamHeading(page, team.name)).toBeVisible()
      expect(await adminTeam(team)).toMatchObject({
        visibilityEditable: true,
        addMemberAllowed: true,
        joinable: false,
        visibility: 'TEAM',
      })
      // The settings page reads them back.
      const reread = await settingsForm(page, team.slug)
      await expect(
        reread.getByRole('switch', { name: 'Autoriser les admins à modifier la visibilité' })
      ).toBeChecked()
      await expect(
        reread.getByRole('switch', { name: 'Autoriser les admins à ajouter des membres' })
      ).toBeChecked()

      // After: the owner may invite…
      await ownerPage.goto(`/equipes/${team.slug}/admin/membres`)
      await expect(
        main(ownerPage).getByRole('button', { name: 'Inviter par e-mail' })
      ).toBeVisible()

      // …and choose the visibility: unlisted.
      ownerForm = await settingsForm(ownerPage, team.slug)
      const visibility = ownerForm.getByRole('combobox', { name: "Visibilité de l'équipe" })
      await expect(visibility).toHaveValue('Équipe uniquement')
      await visibility.click()
      await ownerPage.getByRole('option', { name: 'Non répertorié', exact: true }).click()
      await expect(visibility).toHaveValue('Non répertorié')
      await ownerForm.getByRole('button', { name: 'Enregistrer' }).click()
      await expect(
        ownerPage.getByText('Équipe mise à jour avec succès', { exact: true })
      ).toBeVisible()
      await expect(teamHeading(ownerPage, team.name)).toBeVisible()
      expect((await getTeam(owner, team.slug)).visibility).toBe('PUBLIC_UNLISTED')
    } finally {
      await ownerContext.close()
    }

    await expectUnlisted(browser, team)
  })

  test('an unlisted team is missing from /equipes, but open to anyone holding its link', async ({
    browser,
  }) => {
    const owner = await newUser('Platform unlisted owner')
    const team = await newTeam(owner, unique('Non répertoriée'), { visibility: 'PUBLIC_UNLISTED' })
    await expectUnlisted(browser, team)
  })
})

/**
 * `team` is PUBLIC_UNLISTED: /equipes searched on its name shows nothing to an anonymous visitor nor
 * to a signed-in outsider (the API neither), while its URL opens it to both.
 */
async function expectUnlisted(browser: import('@playwright/test').Browser, team: TeamDetailDto) {
  const outsider = await newUser('Platform unlisted outsider')
  expect((await listedTeams(undefined, team.name)).teams).toEqual([])
  expect((await listedTeams(outsider, team.name)).teams).toEqual([])

  for (const who of [undefined, outsider]) {
    const { context, page } = await pageAs(browser, who)
    try {
      // role=all: a signed-in visitor's list defaults to their own teams.
      await page.goto(`/equipes?q=${encodeURIComponent(team.name)}${who ? '&role=all' : ''}`)
      await expect(page.getByRole('heading', { level: 2, name: 'Équipes' })).toBeVisible()
      await expect(main(page).getByText('Aucune équipe trouvée', { exact: true })).toBeVisible()
      await expect(main(page).getByRole('link').filter({ hasText: team.name })).toHaveCount(0)

      const response = await page.goto(`/equipes/${team.slug}`)
      expect(response?.status()).toBe(200)
      await expect(teamHeading(page, team.name)).toBeVisible()
    } finally {
      await context.close()
    }
  }
}

/**
 * The domain screen (AdminDomainsPage.tsx) and its form (DomainFormModal.tsx), which carries the
 * domain's GPS credentials and its dedicated sites (aliases) in sections of its own. Domains
 * cannot be deleted: the rename works on a domain per project and parallel slot, put back to a
 * known state first; the alias is added to `localhost` under a hostname of this run, and removed.
 */
test.describe('domains', () => {
  test('renaming a domain from its form keeps its GPS credentials and its other settings', async ({
    page,
  }) => {
    const fingerprints = 'AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01'
    const stamp = Date.now().toString(36)
    const { domain, credentials } = await scratchDomain(
      {
        name: unique('Domaine'),
        singleTeam: false,
        enableGpxPlanner: true,
        androidFingerprints: fingerprints,
      },
      [
        {
          serviceType: 'GARMIN',
          clientId: `garmin-${stamp}`,
          clientSecret: 'e2e-garmin-secret',
          active: true,
        },
        {
          serviceType: 'WAHOO',
          clientId: `wahoo-${stamp}`,
          clientSecret: 'e2e-wahoo-secret',
          active: false,
        },
      ]
    )
    const renamed = unique('Domaine renommé')

    await page.goto(await adminDomainsPathOf(domain.domain))
    const row = rowWithCell(page.getByRole('main'), domain.domain)
    await expect(row.getByText(domain.name, { exact: true })).toBeVisible()
    // The row's first button: « Modifier » (its tooltip; no accessible name — see below).
    const edit = row.getByRole('button').first()
    await hydrated(edit)
    await edit.click()

    const dialog = page.getByRole('dialog', { name: 'Modifier le domaine' })
    await expect(dialog.getByRole('textbox', { name: 'Domaine', exact: true })).toHaveValue(
      domain.domain
    )
    await expect(dialog.getByRole('textbox', { name: 'Domaine', exact: true })).toBeDisabled()
    for (const credential of credentials)
      await expect(credentialRow(dialog, credential.clientId)).toBeVisible()
    // The Garmin one, created without a protocol: OAuth 2.0, said beside its client id.
    const garmin = credentials.find((c) => c.serviceType === 'GARMIN')!
    await expect(credentialRow(dialog, garmin.clientId)).toContainText('OAuth 2.0')
    const name = dialog.getByRole('textbox', { name: 'Nom', exact: true })
    await expect(name).toHaveValue(domain.name)
    await name.fill(renamed)
    const updated = page.waitForResponse(
      (r) => r.url().endsWith(`/api/admin/domains/${domain.id}`) && r.request().method() === 'PUT'
    )
    await dialog.getByRole('button', { name: 'Enregistrer' }).click()
    const response = await updated
    expect(response.ok()).toBe(true)
    // The form sends the domain's own fields, as they were but for the name — nothing else.
    expect(response.request().postDataJSON()).toEqual({
      name: renamed,
      baseUrl: domain.baseUrl,
      singleTeam: false,
      enableGpxPlanner: true,
      androidFingerprints: fingerprints,
    })
    await expect(page.getByText('Domaine mis à jour avec succès', { exact: true })).toBeVisible()
    await expect(dialog).toBeHidden()
    await expect(row.getByText(renamed, { exact: true })).toBeVisible()

    expect(await adminDomain(domain.domain)).toMatchObject({
      name: renamed,
      baseUrl: domain.baseUrl,
      singleTeam: false,
      enableGpxPlanner: true,
      androidFingerprints: fingerprints,
      active: true,
    })
    const summary = (list: AdminGpsCredentialDto[]) =>
      list
        .map(({ id, serviceType, clientId, active }) => ({ id, serviceType, clientId, active }))
        .sort((a, b) => a.clientId.localeCompare(b.clientId))
    expect(summary(await gpsCredentialsOf(domain))).toEqual(summary(credentials))

    // Opened again, the form lists them still.
    await hydrated(edit)
    await edit.click()
    await expect(dialog.getByRole('textbox', { name: 'Nom', exact: true })).toHaveValue(renamed)
    for (const credential of credentials)
      await expect(credentialRow(dialog, credential.clientId)).toBeVisible()
  })

  test('the platform admin adds a dedicated site pinned to a team; it serves the team until disabled, then is removed', async ({
    browser,
    page,
  }) => {
    test.setTimeout(90_000)
    const owner = await newUser('Platform alias owner')
    const team = await newTeam(owner, unique('Site dédié'), { visibility: 'PUBLIC' })
    const host = uniqueLocalHost('site-e2e')
    const siteName = unique('Site dédié E2E')
    const localhost = await adminDomain(new URL(stack.baseURL).hostname)
    try {
      await page.goto(await adminDomainsPathOf(localhost.domain))
      const edit = rowWithCell(page.getByRole('main'), localhost.domain).getByRole('button').first()
      await hydrated(edit)
      await edit.click()
      const dialog = page.getByRole('dialog', { name: 'Modifier le domaine' })
      await dialog.getByRole('button', { name: 'Ajouter un site dédié' }).click()

      // The alias form — its « URL de base » is not the domain's own, above it.
      const form = dialog
        .locator('.mantine-Paper-root')
        .filter({ has: page.getByRole('textbox', { name: "Nom d'hôte" }) })
      await form.getByRole('textbox', { name: "Nom d'hôte" }).fill(host)
      await form.getByRole('textbox', { name: "Slug de l'équipe épinglée" }).fill(team.slug)
      await form.getByRole('textbox', { name: 'Nom affiché' }).fill(siteName)
      await form.getByRole('textbox', { name: 'URL de base' }).fill(originOf(host))
      const created = page.waitForResponse(
        (r) => r.url().endsWith(aliasesPath(localhost)) && r.request().method() === 'POST'
      )
      await form.getByRole('button', { name: 'Enregistrer' }).click()
      const createdResponse = await created
      expect(createdResponse.ok()).toBe(true)
      expect(await createdResponse.json()).toMatchObject({
        hostname: host,
        pinnedTeamSlug: team.slug,
        name: siteName,
        active: true,
      })
      await expect(page.getByText('Site dédié créé avec succès', { exact: true })).toBeVisible()
      const aliasRow = rowWithCell(dialog, host)
      await expect(aliasRow.getByRole('cell', { name: team.slug, exact: true })).toBeVisible()
      await expect(aliasRow.getByText('Actif', { exact: true })).toBeVisible()

      // The new hostname serves the team, under the site's own name.
      const { context, page: visitor } = await pageAs(browser, undefined)
      try {
        await visitor.goto(`${originOf(host)}/`)
        await expect(
          visitor.getByRole('banner').getByRole('link', { name: siteName })
        ).toBeVisible()
        await expect(
          visitor.getByRole('main').getByRole('heading', { name: team.name, exact: true })
        ).toBeVisible()
      } finally {
        await context.close()
      }
      expect(await hostGet<ConfigDto>(host, undefined, '/api/config')).toMatchObject({
        appName: siteName,
        pinnedTeamSlug: team.slug,
      })

      // Disabled from its row, the hostname no longer resolves to any site.
      const toggled = page.waitForResponse(
        (r) => r.url().endsWith('/toggle-active') && r.request().method() === 'POST'
      )
      await aliasRow.getByRole('button', { name: 'Désactiver le domaine' }).click()
      expect((await toggled).ok()).toBe(true)
      await expect(aliasRow.getByText('Inactif', { exact: true })).toBeVisible()
      await expect(aliasRow.getByRole('button', { name: 'Activer le domaine' })).toBeVisible()
      expect(await hostStatus(host, undefined, '/api/config')).toBe(404)

      // Removed, once confirmed.
      await aliasRow.getByRole('button', { name: 'Supprimer' }).click()
      const confirm = page.getByRole('dialog', { name: 'Supprimer le site dédié' })
      await expect(confirm.getByText(/Ce nom d'hôte ne sera plus accessible/)).toBeVisible()
      await confirm.getByRole('button', { name: 'Confirmer' }).click()
      await expect(page.getByText('Site dédié supprimé avec succès', { exact: true })).toBeVisible()
      await expect(rowWithCell(dialog, host)).toHaveCount(0)
      expect((await aliasesOf(localhost)).map((alias) => alias.hostname)).not.toContain(host)

      // Left without saving the domain itself.
      await dialog.getByRole('button', { name: 'Annuler' }).click()
      await expect(dialog).toBeHidden()
    } finally {
      const left = (await aliasesOf(localhost)).find((alias) => alias.hostname === host)
      if (left) await deleteAlias(localhost, left.id)
    }
  })
})

// Regression (11583113): each ActionIcon carries its Tooltip's label as aria-label, like the team
// and user lists since ebf14f23 — before, a screen reader announced two unnamed buttons per row.
test('the row actions of the domain list have an accessible name', async ({ page }) => {
  await otherDomain()
  await page.goto(await adminDomainsPathOf(OTHER_HOST))
  const row = rowWithCell(page.getByRole('main'), OTHER_HOST)
  await expect(row.getByRole('button'), 'precondition: the row has its two buttons').toHaveCount(2)
  await expect.soft(row.getByRole('button', { name: 'Modifier' })).toBeVisible({ timeout: 2_000 })
  await expect(row.getByRole('button', { name: 'Désactiver le domaine' })).toBeVisible({
    timeout: 2_000,
  })
})

/**
 * The beta sign-up of /applications (AppsPage.tsx, `signUpForBeta`) and its platform list
 * (AdminBetaSignupsPage.tsx). The sign-up is idempotent on the address, whatever its case
 * (BetaSignupService.java:32-37, BetaSignupRepository.existsByEmail), and answers the same either
 * way — the form must not confirm to a prober that an address is already listed.
 */
test.describe('beta sign-ups', () => {
  const submitSignUp = async (page: Page, email: string) => {
    const field = page.getByRole('main').getByRole('textbox', { name: 'Adresse e-mail' })
    await hydrated(field)
    await field.fill(email)
    const sent = page.waitForResponse(
      (r) => r.url().endsWith('/api/beta-signups') && r.request().method() === 'POST'
    )
    await page.getByRole('main').getByRole('button', { name: "S'inscrire" }).click()
    expect((await sent).status()).toBe(204)
    await expect(page.getByRole('heading', { name: 'Inscription enregistrée' })).toBeVisible()
  }

  test('a visitor signs up on /applications, and the platform admin finds the address in the list; signing up again adds nothing', async ({
    browser,
    page,
  }) => {
    const email = freshAddress('beta signup')
    const { context, page: visitor } = await pageAs(browser, undefined)
    try {
      await visitor.goto('/applications')
      await expect(visitor.getByRole('heading', { name: 'Devenir testeur·se' })).toBeVisible()
      // A malformed address stays on the form, with its message.
      const field = visitor.getByRole('main').getByRole('textbox', { name: 'Adresse e-mail' })
      await hydrated(field)
      await field.fill('pas-une-adresse')
      await visitor.getByRole('main').getByRole('button', { name: "S'inscrire" }).click()
      await expect(visitor.getByText('Adresse e-mail invalide', { exact: true })).toBeVisible()

      await submitSignUp(visitor, email)
      // Again, in capitals: the same answer, and no second row.
      await visitor.reload()
      await submitSignUp(visitor, email.toUpperCase())
    } finally {
      await context.close()
    }
    expect(
      (await betaSignups()).signups.filter((signup) => signup.email.toLowerCase() === email)
    ).toEqual([expect.objectContaining({ email })])

    await page.goto(ADMIN_BETA_SIGNUPS_PATH)
    await expect(rowWithCell(page.getByRole('main'), email)).toBeVisible()
    await expect(rowWithCell(page.getByRole('main'), email.toUpperCase())).toHaveCount(0)
  })

  // The list is the platform's, every domain together — like the platform user and team lists,
  // and as BetaSignup.java:18-20 has it (domainId kept « for reporting, never for access control »).
  // A sign-up on another domain goes through, and lands in that one list.
  test('a sign-up on another domain goes through too, and lands in the same platform list', async ({
    browser,
    page,
  }) => {
    await otherDomain()
    const email = freshAddress('beta autre')
    const { context, page: visitor } = await pageAs(browser, undefined)
    try {
      await visitor.goto(`${originOf(OTHER_HOST)}/applications`)
      await submitSignUp(visitor, email)
    } finally {
      await context.close()
    }
    expect((await betaSignups()).signups.map((signup) => signup.email)).toContain(email)
    await page.goto(ADMIN_BETA_SIGNUPS_PATH)
    await expect(rowWithCell(page.getByRole('main'), email)).toBeVisible()
  })
})
