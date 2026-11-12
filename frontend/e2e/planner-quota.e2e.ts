import type {
  GeoPoint,
  GpxPreviewDto,
  GpxPreviewFromPointsRequest,
  RouteDto,
  RouteRequest,
} from '../src/api/dto'
import { expectOk, withApi, type AuthResponse } from './support/api'
import { freshAddress, markdownMedia, newTeam, newUser, signIn } from './support/data'
import {
  PLANNER_HOST,
  PLANNER_PIN_HOST,
  hostPost,
  originOf,
  registerOn,
  signInOn,
} from './support/domains'
import { expect, test, unique } from './support/fixtures'
import { stubBasemap } from './support/routes'
import { hydrated, toasts } from './support/ui'

/**
 * The free plan's limit on the planner (docs/LEDGER_*.md BILL-10, plan
 * docs/plans/archive/2026-11-11-limites-offre-gratuite.md §3.2 and §5): 20 saves of a drawn track a month
 * per free team, 10 in the GPX tools for whoever is in no unlocked team. No counter is shown; once
 * the month is used up the entry point is disabled with the reason, and a refusal met on the way
 * (a save by someone else in the meantime) opens a dialog instead of a toast.
 *
 * The saves that fill a quota go through the API, with points and no file — what the planner sends
 * and what counts; a GPX file would count nothing. Each test has its own team or user: a quota is
 * spent for the month, so nothing here may touch the seed or the planner site's shared owner.
 *
 * No request reaches Stadia Maps: the backend refuses a calculation at a spent quota before calling
 * it, and the only calculation sent here is that one.
 */

/** Two points in Annecy, a few hundred metres apart: a drawn track as the planner saves it. */
const DRAWN: GeoPoint[] = [
  { lng: 6.1294, lat: 45.8992 },
  { lng: 6.1354, lat: 45.9012 },
]

const routeNewPath = (teamSlug: string) => `/equipes/${teamSlug}/parcours/nouveau`

/** One save of a drawn team route (POST /api/teams/{slug}/routes with points, no file). */
const saveDrawnRoute = (by: AuthResponse, teamSlug: string, name: string) => {
  const request: RouteRequest = {
    name,
    media: markdownMedia(),
    surfaceType: 'ROAD',
    visibility: 'TEAM',
    points: DRAWN,
  }
  return withApi(by, async (api) =>
    expectOk<RouteDto>(
      await api.post(`/api/teams/${teamSlug}/routes`, {
        multipart: {
          route: {
            name: 'route.json',
            mimeType: 'application/json',
            buffer: Buffer.from(JSON.stringify(request)),
          },
        },
      })
    )
  )
}

/** `count` saves, one after the other: each is counted under the team's lock. */
async function fillTeamQuota(by: AuthResponse, teamSlug: string, count: number) {
  for (let i = 1; i <= count; i++) await saveDrawnRoute(by, teamSlug, `Tracé ${i}`)
}

test.describe('team quota', () => {
  test.setTimeout(120_000)

  test('a team whose month is used up keeps the GPX import and closes « Tracer sur la carte », saying why', async ({
    context,
    page,
  }) => {
    const owner = await newUser('quota-owner')
    const team = await newTeam(owner, unique('Quota plein'))
    expect(team.tier).toBe('FREE')
    await fillTeamQuota(owner, team.slug, 20)

    await signIn(context, owner)
    await page.goto(routeNewPath(team.slug))
    const main = page.getByRole('main')
    const draw = main.getByRole('button', { name: 'Tracer sur la carte' })
    await hydrated(draw)
    await expect(draw).toBeDisabled()
    await expect(
      main.getByText(`${team.name} utilise l'offre gratuite`, { exact: false })
    ).toBeVisible()
    await expect(main.getByText("L'import de GPX reste disponible", { exact: false })).toBeVisible()
    await expect(main.getByRole('button', { name: 'Importer un fichier GPX' })).toBeEnabled()
    // No counter anywhere before the limit, and none after it either
    await expect(main.getByText(/20 \/ 20/)).toHaveCount(0)
  })

  test('a calculation refused because the month was used up meanwhile opens the dialog, not a toast', async ({
    context,
    page,
    isMobile,
  }) => {
    // The inline map is the mouse's; on a finger the same refusal goes through the fullscreen editor
    test.skip(isMobile, 'drawn on the inline map of a mouse')
    const owner = await newUser('quota-race')
    const team = await newTeam(owner, unique('Quota en route'))
    await fillTeamQuota(owner, team.slug, 19)

    await signIn(context, owner)
    await stubBasemap(page)
    await page.goto(routeNewPath(team.slug))
    const main = page.getByRole('main')
    const draw = main.getByRole('button', { name: 'Tracer sur la carte' })
    await hydrated(draw)
    await expect(draw).toBeEnabled()
    await draw.click()

    // Another member saves the 20th meanwhile
    await saveDrawnRoute(owner, team.slug, 'Le vingtième')

    const canvas = main.locator('canvas.maplibregl-canvas').first()
    await expect(canvas).toBeVisible()
    const box = await canvas.boundingBox()
    if (!box) throw new Error('the planner map has no box')
    // The first point needs no routing; the second asks for one, which the backend refuses
    await canvas.click({ position: { x: box.width / 2 - 80, y: box.height / 2 } })
    await expect(main.getByText('1 point', { exact: true })).toBeVisible()
    const refused = page.waitForResponse(
      (response) => response.url().endsWith('/api/router') && response.request().method() === 'POST'
    )
    await canvas.click({ position: { x: box.width / 2 + 80, y: box.height / 2 } })
    expect((await refused).status()).toBe(403)

    const dialog = page.getByRole('dialog', { name: 'Enregistrements du mois tous utilisés' })
    await expect(dialog).toBeVisible()
    await expect(
      dialog.getByText(`${team.name} utilise l'offre gratuite`, { exact: false })
    ).toBeVisible()
    await expect(dialog.getByText(/repart le 1er/)).toBeVisible()
    await expect(
      dialog.getByText("un administrateur de l'équipe peut nous contacter", { exact: false })
    ).toBeVisible()
    // The dialog says it: the global toast stays quiet
    await expect(toasts(page)).toHaveCount(0)
    await dialog.getByRole('button', { name: 'Fermer', exact: true }).click()
    await expect(dialog).toHaveCount(0)
  })
})

test.describe('personal quota of the GPX tools', () => {
  test.setTimeout(120_000)

  test('someone in no unlocked team who used their 10 saves sees « Créer un parcours » closed, with the reason', async ({
    context,
    page,
  }) => {
    // The GPX planner is only open on the planner site; a user of its own there, in no team
    const user = await registerOn(PLANNER_HOST, {
      email: freshAddress('quota-perso'),
      displayName: 'Quota perso',
      password: 'e2e-password',
    })
    for (let i = 1; i <= 10; i++) {
      const request: GpxPreviewFromPointsRequest = { name: `Tracé ${i}`, points: DRAWN }
      await hostPost<GpxPreviewDto>(PLANNER_HOST, user, '/api/gpx-previews/from-points', request)
    }

    await signInOn(context, PLANNER_PIN_HOST, user)
    await page.goto(`${originOf(PLANNER_PIN_HOST)}/outils-gpx`)
    const main = page.getByRole('main')
    const create = main.getByRole('button', { name: 'Créer un parcours' })
    await hydrated(create)
    await expect(create).toBeDisabled()
    await expect(
      main.getByText("Vous ne faites partie d'aucune équipe débloquée", { exact: false })
    ).toBeVisible()
    await expect(main.getByText('Rejoindre une équipe débloquée lève cette limite.')).toBeVisible()
    // The file cards stay open
    await expect(main.getByRole('button', { name: 'Choisir un fichier' })).toBeEnabled()
  })
})
