import { writeFileSync } from 'node:fs'
import type { Page } from '@playwright/test'
import type { GpxPreviewDto, GpxPreviewListResponse } from '../src/api/dto'
import { apiGet, apiGetOrNull, expectOk, withApi, type AuthResponse } from './support/api'
import { newTeam, newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { getRoute, gpxOf, routePath, stubBasemap, type GpxPoint } from './support/routes'
import { hydrated, pageAs, toasts } from './support/ui'

/**
 * The GPX tools (« Outils GPX »), through the UI: a signed-in user drops a GPX file on the hub,
 * reads its preview (map, stats, downloads), finds it among their files, renames it, replaces its
 * track, saves it as a route of one of their teams, and deletes it — from the preview and from the
 * list. The preview link is shareable: anyone holding it reads it, only its owner edits it.
 *
 * The drawing tool (« Créer un parcours », /outils-gpx/nouveau) stays out: the e2e domain has
 * enableGpxPlanner off.
 *
 * Each test has its own fresh user, so « Mes fichiers » holds only what the test uploaded.
 */

/** A straight line of `count` points 50 m apart, heading due east out of Annecy. */
function eastward(count: number): GpxPoint[] {
  const [lat0, lon0] = [45.8992, 6.1294]
  const metresPerDegLon = 111_320 * Math.cos((lat0 * Math.PI) / 180)
  return Array.from({ length: count }, (_, i) => [
    lat0,
    Number((lon0 + (i * 50) / metresPerDegLon).toFixed(7)),
    450 + i,
  ])
}

const HUB = '/outils-gpx'
const MY_FILES = '/outils-gpx/mes-fichiers'
const previewPath = (id: string) => `${HUB}/${id}`

/** A preview uploaded as « Outils GPX » does, owned by `owner`. */
const uploadPreview = (owner: AuthResponse, name: string, points: GpxPoint[]) =>
  withApi(owner, async (api) =>
    expectOk<GpxPreviewDto>(
      await api.post('/api/gpx-previews', {
        multipart: {
          gpxFile: {
            name: 'trace.gpx',
            mimeType: 'application/gpx+xml',
            buffer: Buffer.from(gpxOf(name, points)),
          },
        },
      })
    )
  )

const getPreview = (who: AuthResponse | undefined, id: string) =>
  apiGetOrNull<GpxPreviewDto>(who, `/api/gpx-previews/${id}`)

const myPreviews = (owner: AuthResponse) =>
  apiGet<GpxPreviewListResponse>(owner, '/api/gpx-previews')

// The French decimal comma, as the site writes it (docs/LEDGER_*.md WEB-167, D13).
const km = (metres: number) => `${(metres / 1000).toFixed(1).replace('.', ',')} km`

/** Opens a preview's page and waits for its title. Returns the page's main region. */
async function openPreview(page: Page, id: string, name: string) {
  await page.goto(previewPath(id))
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()
  return main
}

/** Opens « Mes fichiers » and waits for its title. Returns the page's main region. */
async function openMyFiles(page: Page) {
  await page.goto(MY_FILES)
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 1, name: 'Lister mes fichiers' })).toBeVisible()
  return main
}

test.beforeEach(async ({ page }) => {
  // The basemap is a third-party CDN, not part of the stack: the map must draw without it.
  await stubBasemap(page)
})

test('a user drops a GPX on the hub, reads its preview, finds it in their files, renames it', async ({
  page,
  context,
}, testInfo) => {
  const user = await newUser(unique('Cycliste outils'))
  const name = unique('Tour du lac')
  const renamed = unique('Tour du lac renommé')
  const gpxPath = testInfo.outputPath('tour-du-lac.gpx')
  // 80 × 50 m = 4 km.
  writeFileSync(gpxPath, gpxOf(name, eastward(81)))

  await signIn(context, user)
  await page.goto(HUB)
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 1, name: 'Outils GPX' })).toBeVisible()
  const choose = main.getByRole('button', { name: 'Choisir un fichier' })
  await hydrated(choose)
  // The button opens the browser's file picker, as it would for a person.
  const chooser = page.waitForEvent('filechooser')
  await choose.click()
  await (await chooser).setFiles(gpxPath)

  // Straight to the preview of the file, named after the GPX's own <name>.
  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()
  await expect(page).toHaveURL(/\/outils-gpx\/[^/?]+$/)
  const id = new URL(page.url()).pathname.split('/').pop()!
  const stored = await getPreview(user, id)
  expect(stored, 'the preview exists').not.toBeNull()
  expect(stored!.name).toBe(name)
  expect(stored!.owned).toBe(true)
  expect(stored!.distance).toBeGreaterThan(3_900)
  expect(stored!.distance).toBeLessThan(4_100)

  // Its stats as the API has them, its map, and its downloads.
  await expect(main.getByText(km(stored!.distance), { exact: true })).toBeVisible()
  await expect(page.locator('canvas.maplibregl-canvas').first()).toBeVisible()
  const gpxLink = main.getByRole('link', { name: 'Télécharger GPX' })
  await expect(main.getByRole('link', { name: 'Télécharger FIT' })).toBeVisible()
  const gpx = await page.request.get((await gpxLink.getAttribute('href'))!)
  expect(gpx.ok()).toBe(true)
  expect(await gpx.text()).toContain('<gpx')

  // Back on the hub, « Voir mes fichiers » lists it.
  await page.goto(HUB)
  const myFiles = main.getByRole('button', { name: 'Voir mes fichiers' })
  await hydrated(myFiles)
  await myFiles.click()
  await expect(main.getByRole('heading', { level: 1, name: 'Lister mes fichiers' })).toBeVisible()
  await expect(page).toHaveURL(MY_FILES)
  await expect(main.getByText(name, { exact: true })).toBeVisible()
  await expect(main.getByText(km(stored!.distance), { exact: true })).toBeVisible()
  // Its only file: one row, one « Voir ».
  const view = main.getByRole('link', { name: 'Voir', exact: true })
  await expect(view).toHaveCount(1)
  await hydrated(view)
  await view.click()
  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()
  await expect(page).toHaveURL(previewPath(id))

  // Rename it.
  const edit = main.getByRole('button', { name: 'Modifier', exact: true })
  await hydrated(edit)
  await edit.click()
  await expect(
    main.getByRole('heading', { level: 1, name: 'Modifier le fichier GPX' })
  ).toBeVisible()
  await expect(page).toHaveURL(`${previewPath(id)}/modifier`)
  const nameInput = main.getByRole('textbox', { name: 'Nom du parcours' })
  await expect(nameInput).toHaveValue(name)
  const save = main.getByRole('button', { name: 'Enregistrer' })
  await hydrated(save)
  await nameInput.fill(renamed)
  await save.click()

  // Back on the preview, under its new name; the track is untouched.
  await expect(main.getByRole('heading', { level: 1, name: renamed })).toBeVisible()
  await expect(page).toHaveURL(previewPath(id))
  await expect(toasts(page).filter({ hasText: 'Fichier mis à jour' })).toBeVisible()
  const after = await getPreview(user, id)
  expect(after!.name).toBe(renamed)
  expect(after!.distance).toBe(stored!.distance)
  // And « Mes fichiers » shows the new name.
  const list = await openMyFiles(page)
  await expect(list.getByText(renamed, { exact: true })).toBeVisible()
  await expect(list.getByText(name, { exact: true })).toHaveCount(0)
})

test("an owner replaces a preview's track with another GPX", async ({
  page,
  context,
}, testInfo) => {
  const user = await newUser(unique('Cycliste remplacement'))
  const name = unique('Trace courte')
  // 2 km, then 6 km.
  const preview = await uploadPreview(user, name, eastward(41))
  expect(preview.distance).toBeLessThan(2_100)
  const longer = testInfo.outputPath('trace-longue.gpx')
  writeFileSync(longer, gpxOf('Trace longue', eastward(121)))

  await signIn(context, user)
  await page.goto(`${previewPath(preview.id)}/modifier`)
  const main = page.getByRole('main')
  const nameInput = main.getByRole('textbox', { name: 'Nom du parcours' })
  await expect(nameInput).toHaveValue(name)
  const save = main.getByRole('button', { name: 'Enregistrer' })
  await hydrated(save)
  // Mantine's FileInput: a button, and the hidden input accepting .gpx.
  await main.locator('input[type="file"][accept=".gpx"]').setInputFiles(longer)
  await expect(main.getByRole('button', { name: 'Fichier GPX' })).toHaveText('trace-longue.gpx')
  await save.click()

  // The name typed in the form wins over the new file's; the stats are the new track's.
  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()
  await expect(page).toHaveURL(previewPath(preview.id))
  const stored = await getPreview(user, preview.id)
  expect(stored!.name).toBe(name)
  expect(stored!.distance).toBeGreaterThan(5_900)
  expect(stored!.distance).toBeLessThan(6_100)
  await expect(main.getByText(km(stored!.distance), { exact: true })).toBeVisible()
})

test("an owner replaces a preview's track with a GPX whose extension is in capitals", async ({
  page,
  context,
}, testInfo) => {
  // Regression (c0e32dec): the extension check is case-insensitive, as in RouteEditor.
  const user = await newUser(unique('Cycliste majuscules'))
  const name = unique('Trace en capitales')
  const preview = await uploadPreview(user, name, eastward(41))
  const upper = testInfo.outputPath('TRACE.GPX')
  writeFileSync(upper, gpxOf('Trace longue', eastward(121)))

  await signIn(context, user)
  await page.goto(`${previewPath(preview.id)}/modifier`)
  const main = page.getByRole('main')
  await expect(main.getByRole('textbox', { name: 'Nom du parcours' })).toHaveValue(name)
  const save = main.getByRole('button', { name: 'Enregistrer' })
  await hydrated(save)
  await main.locator('input[type="file"][accept=".gpx"]').setInputFiles(upper)
  await expect(main.getByRole('alert')).toHaveCount(0)
  await expect(main.getByRole('button', { name: 'Fichier GPX' })).toHaveText('TRACE.GPX', {
    timeout: 5_000,
  })
  await save.click()

  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()
  const stored = await getPreview(user, preview.id)
  expect(stored!.distance).toBeGreaterThan(5_900)
})

test('an owner deletes a preview from its page: its link is gone', async ({ page, context }) => {
  const user = await newUser(unique('Cycliste suppression'))
  const name = unique('Fichier éphémère')
  const preview = await uploadPreview(user, name, eastward(41))

  await signIn(context, user)
  const main = await openPreview(page, preview.id, name)
  const remove = main.getByRole('button', { name: 'Supprimer', exact: true })
  await hydrated(remove)
  await remove.click()
  const dialog = page.getByRole('dialog', { name: 'Supprimer' })
  await expect(dialog).toContainText('Voulez-vous vraiment supprimer ce fichier ?')
  await dialog.getByRole('button', { name: 'Confirmer' }).click()

  // Back on the hub.
  await expect(main.getByRole('heading', { level: 1, name: 'Outils GPX' })).toBeVisible()
  await expect(page).toHaveURL(HUB)
  await expect(toasts(page).filter({ hasText: 'Fichier supprimé' })).toBeVisible()
  expect(await getPreview(user, preview.id), 'the preview is gone').toBeNull()
  // « Mes fichiers » is empty again.
  const list = await openMyFiles(page)
  await expect(list.getByText("Vous n'avez aucun fichier disponible pour le moment.")).toBeVisible()
  await expect(list.getByText(name, { exact: true })).toHaveCount(0)
})

test('an owner deletes one preview from « Mes fichiers »; the other stays', async ({
  page,
  context,
}) => {
  const user = await newUser(unique('Cycliste liste'))
  const kept = unique('Fichier gardé')
  const dropped = unique('Fichier jeté')
  const keptPreview = await uploadPreview(user, kept, eastward(41))
  const droppedPreview = await uploadPreview(user, dropped, eastward(61))

  await signIn(context, user)
  const main = await openMyFiles(page)
  await expect(main.getByText(kept, { exact: true })).toBeVisible()
  await expect(main.getByText(dropped, { exact: true })).toBeVisible()
  await expect(main.getByRole('button', { name: 'Supprimer', exact: true })).toHaveCount(2)

  // A row is a card with no role of its own: the one holding the file's name and a « Supprimer ».
  const row = main
    .locator('.mantine-Card-root')
    .filter({ hasText: dropped })
    .filter({ has: page.getByRole('button', { name: 'Supprimer', exact: true }) })
  const remove = row.getByRole('button', { name: 'Supprimer', exact: true })
  await hydrated(remove)
  await remove.click()
  const dialog = page.getByRole('dialog', { name: 'Supprimer' })
  await dialog.getByRole('button', { name: 'Confirmer' }).click()

  await expect(dialog).toHaveCount(0)
  await expect(main.getByText(dropped, { exact: true })).toHaveCount(0)
  await expect(main.getByText(kept, { exact: true })).toBeVisible()
  await expect(toasts(page).filter({ hasText: 'Fichier supprimé' })).toBeVisible()
  expect(await getPreview(user, droppedPreview.id)).toBeNull()
  expect((await myPreviews(user)).previews.map((p) => p.id)).toEqual([keptPreview.id])
})

test('an owner saves a preview as a route of their team', async ({ page, context }) => {
  const user = await newUser(unique('Cycliste enregistrement'))
  const team = await newTeam(user, unique('Équipe outils GPX'))
  const name = unique('Boucle à garder')
  const preview = await uploadPreview(user, name, eastward(81))

  await signIn(context, user)
  const main = await openPreview(page, preview.id, name)
  const saveAsRoute = main.getByRole('button', { name: 'Enregistrer comme parcours' })
  await hydrated(saveAsRoute)
  await saveAsRoute.click()
  const dialog = page.getByRole('dialog', { name: 'Enregistrer comme parcours' })
  const confirm = dialog.getByRole('button', { name: 'Enregistrer', exact: true })
  await expect(confirm, 'no team chosen yet').toBeDisabled()
  await dialog.getByRole('combobox', { name: 'Équipe' }).click()
  await page.getByRole('option', { name: team.name }).click()
  await expect(confirm).toBeEnabled()
  // The track is copied and processed before the answer, which can outlast an expect under load.
  const saved = page.waitForResponse(
    (r) => r.request().method() === 'POST' && r.url().endsWith(`/routes/${team.slug}`)
  )
  await confirm.click()
  expect((await saved).ok(), 'the route was created').toBe(true)

  // On the new route's page, in that team.
  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/parcours/[^/?]+$`))
  const routeSlug = new URL(page.url()).pathname.split('/').pop()!
  await expect(page).toHaveURL(routePath(team.slug, routeSlug))
  const route = await getRoute(user, team.slug, routeSlug)
  expect(route.name).toBe(name)
  expect(route.distance).toBeCloseTo(preview.distance, -1)
  // The preview itself stays.
  expect(await getPreview(user, preview.id)).not.toBeNull()
})

test('the « Enregistrer comme parcours » modal closes from its named cross', async ({
  page,
  context,
}) => {
  // The modal's close button had no accessible name (fixed 2026-09-25: « Fermer la fenêtre »).
  const user = await newUser(unique('Cycliste fermeture'))
  const name = unique('Boucle hésitante')
  const preview = await uploadPreview(user, name, eastward(41))

  await signIn(context, user)
  const main = await openPreview(page, preview.id, name)
  const saveAsRoute = main.getByRole('button', { name: 'Enregistrer comme parcours' })
  await hydrated(saveAsRoute)
  await saveAsRoute.click()
  const dialog = page.getByRole('dialog', { name: 'Enregistrer comme parcours' })
  await expect(dialog.getByRole('combobox', { name: 'Équipe' })).toBeVisible()
  await dialog.getByRole('button', { name: 'Fermer la fenêtre', exact: true }).click()
  await expect(dialog).toHaveCount(0)
  await expect(saveAsRoute).toBeVisible()
  // Nothing was saved: the user's preview is all there is.
  expect((await myPreviews(user)).previews.map((p) => p.id)).toEqual([preview.id])
})

test.describe('a shared preview link', () => {
  test('anyone holding the link reads it; only its owner may edit or delete it', async ({
    page,
    browser,
  }) => {
    const owner = await newUser(unique('Cycliste propriétaire'))
    const other = await newUser(unique('Cycliste curieux'))
    const name = unique('Trace partagée')
    const preview = await uploadPreview(owner, name, eastward(41))

    // An anonymous visitor: the map, the stats and the downloads, no action.
    const main = await openPreview(page, preview.id, name)
    await expect(main.getByText(km(preview.distance), { exact: true })).toBeVisible()
    await expect(main.getByRole('link', { name: 'Télécharger GPX' })).toBeVisible()
    await expect(main.getByRole('button', { name: 'Modifier', exact: true })).toHaveCount(0)
    await expect(main.getByRole('button', { name: 'Supprimer', exact: true })).toHaveCount(0)
    await expect(main.getByRole('button', { name: 'Enregistrer comme parcours' })).toHaveCount(0)
    expect((await getPreview(undefined, preview.id))!.owned).toBe(false)

    // Another user: may save it as a route, not edit it — the edit page sends them back.
    const { context: otherContext, page: otherPage } = await pageAs(browser, other)
    try {
      await stubBasemap(otherPage)
      const otherMain = await openPreview(otherPage, preview.id, name)
      await expect(
        otherMain.getByRole('button', { name: 'Enregistrer comme parcours' })
      ).toBeVisible()
      await expect(otherMain.getByRole('button', { name: 'Modifier', exact: true })).toHaveCount(0)
      await expect(otherMain.getByRole('button', { name: 'Supprimer', exact: true })).toHaveCount(0)
      await otherPage.goto(`${previewPath(preview.id)}/modifier`)
      await expect(otherPage).toHaveURL(previewPath(preview.id))
      await expect(otherMain.getByRole('heading', { level: 1, name })).toBeVisible()
      // Nor does it land among their files.
      await otherPage.goto(MY_FILES)
      await expect(
        otherMain.getByText("Vous n'avez aucun fichier disponible pour le moment.")
      ).toBeVisible()
    } finally {
      await otherContext.close()
    }
    expect((await getPreview(owner, preview.id))!.name).toBe(name)
  })

  test('the hub needs an account', async ({ page }) => {
    await page.goto(HUB)
    await expect(page).toHaveURL(/\/connexion/)
    await expect(
      page.getByRole('main').getByRole('button', { name: 'Se connecter', exact: true })
    ).toBeVisible()
    await expect(page.getByRole('main').getByRole('heading', { name: 'Outils GPX' })).toHaveCount(0)
  })
})
