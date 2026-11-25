import type {
  RetouchedRouteDto,
  RouteRetouchOfferDto,
  RouteRetouchRequest,
  RouteRetouchResponse,
} from '../src/api/dto'
import { encode2 } from '../src/lib/polyline'
import { apiPost } from './support/api'
import { addMember, newTeam, newUser, setTeamAttributes, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import {
  newRoute,
  routePath,
  stubBasemap,
  stubElevation,
  stubRouter,
  traceMapPixels,
  windingTrack,
} from './support/routes'
import { openActionsMenu } from './support/ui'
import type { Page } from '@playwright/test'

/**
 * Retouching a saved route from its page (ledger API-212, plan
 * docs/plans/2026-11-24-retouche-parcours-lot7c.md): « Retoucher » menu, the dialog, the proposals
 * over the original, « Ouvrir dans le planificateur ».
 *
 * WRITTEN, NOT RUN (the session that wrote it was not allowed to start the e2e stack). The e2e
 * stack's engine has no graph, so the real offer answers ENGINE_UNAVAILABLE: one test makes that
 * real call, the others stub GET and POST .../routes/{slug}/retouch as route-generator.e2e.ts stubs
 * the generator.
 */

test.setTimeout(120_000)

const ROUTE_NEW_PATH = (slug: string) => `/equipes/${slug}/parcours/nouveau`

function setup() {
  return (async () => {
    const owner = await newUser('retouch-owner')
    const team = await newTeam(owner, unique('Équipe retouche'), {
      geometry: { type: 'Point', coordinates: [1.4875, 48.4469] },
    })
    await setTeamAttributes(team, { enableRoutePlanner: true })
    const route = await newRoute(owner, team.slug, unique('Boucle'), windingTrack(120))
    const member = await newUser('retouch-member')
    await addMember(team.slug, member)
    const place = await apiPost<{ id: string; name: string }>(
      owner,
      `/api/teams/${team.slug}/places`,
      {
        name: 'Café du port',
        startPlace: false,
        endPlace: true,
        geometry: { type: 'Point', coordinates: [1.49, 48.45] },
      }
    )
    return { owner, team, route, member, place }
  })()
}
let fixture: ReturnType<typeof setup> | undefined
const seeded = () => (fixture ??= setup())

const OFFER: RouteRetouchOfferDto = {
  available: true,
  operations: ['RESIZE', 'MOVE_END'],
  originalDistanceM: 5_900,
  minDistanceKm: 4.2,
  maxDistanceKm: 7.6,
  // Below 0.9 km, so that the tests' 5 km target (5.9 km today) is a change and not the dead zone.
  minChangeKm: 0.5,
  maxChangeShare: 0.3,
  endSnapM: 500,
  proposalsMax: 3,
  rideType: 'ROAD',
}

/** Three proposals shaped like the winding track, `shift` degrees of latitude apart. */
function proposals(): RetouchedRouteDto[] {
  return [0, 0.002, 0.004].map((shift, i) => {
    const line = windingTrack(120).map(([lat, lon]) => [lon, lat + shift])
    const lons = line.map((c) => c[0])
    const lats = line.map((c) => c[1])
    return {
      polyline: encode2(line),
      distanceM: 5_000 + i * 300,
      ascentM: 40 + i * 10,
      descentM: 40 + i * 10,
      kind: 'SHORTEN',
      keptShare: 0.8,
      unmatchedM: 0,
      changed: {
        fromM: 2_000,
        toM: 3_000,
        newM: 900,
        startIndex: 30,
        endIndex: 60,
        teamShare: 0.5,
        unpavedShare: 0,
        crossings: 0,
      },
      bounds: {
        minLon: Math.min(...lons),
        maxLon: Math.max(...lons),
        minLat: Math.min(...lats),
        maxLat: Math.max(...lats),
      },
    }
  })
}

async function stubOffer(page: Page, offer: RouteRetouchOfferDto) {
  await page.route('**/api/teams/*/routes/*/retouch', async (route) => {
    if (route.request().method() !== 'GET') return route.fallback()
    await route.fulfill({ json: offer })
  })
}

/** Answers the POST with `proposals()`, or with the given refusal, and records each body. */
async function stubRetouch(page: Page, refusal?: { status: number; code: string }) {
  const bodies: RouteRetouchRequest[] = []
  await page.route('**/api/teams/*/routes/*/retouch', async (route) => {
    if (route.request().method() !== 'POST') return route.fallback()
    bodies.push(route.request().postDataJSON() as RouteRetouchRequest)
    if (refusal) {
      await route.fulfill({
        status: refusal.status,
        json: { code: refusal.code, message: refusal.code },
      })
      return
    }
    const response: RouteRetouchResponse = {
      operation: 'RESIZE',
      originalDistanceM: 5_900,
      originalAscentM: 60,
      originalDescentM: 60,
      targetDistanceM: 5_000,
      candidates: proposals(),
    }
    await route.fulfill({ json: response })
  })
  return bodies
}

// An editor's « Retoucher » is a section of the « Modifier ▾ » menu (its operations as items)
const retouchItem = (page: Page) => page.getByRole('menuitem', { name: 'Ajuster la distance' })
const cards = (page: Page) => page.getByTestId('retouched-route-card')

test('the real offer says the engine cannot retouch: the page has no « Retoucher »', async ({
  context,
  page,
}) => {
  const { owner, team, route } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  await page.goto(routePath(team.slug, route.slug))
  await expect(page.getByRole('heading', { level: 1, name: route.name })).toBeVisible()
  // « Dupliquer » is in the menu behind « Modifier » (docs/LEDGER_*.md WEB-206)
  await expect(
    (await openActionsMenu(page)).getByRole('menuitem', { name: 'Dupliquer' })
  ).toBeVisible()
  await expect(retouchItem(page)).toHaveCount(0)
})

test('adjust the distance: three cards before → after, the next seed on « Autres propositions », the changed stretch painted', async ({
  context,
  page,
}) => {
  const { owner, team, route } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  await stubOffer(page, OFFER)
  const bodies = await stubRetouch(page)

  await page.goto(routePath(team.slug, route.slug))
  await openActionsMenu(page)
  await page.getByRole('menuitem', { name: 'Ajuster la distance' }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByText(/Actuellement 5,9/)).toBeVisible()
  await dialog.getByLabel('Distance visée').fill('5')
  await dialog.getByRole('button', { name: 'Proposer' }).click()
  await expect(cards(page)).toHaveCount(3)
  expect(bodies).toHaveLength(1)
  expect(bodies[0]).toMatchObject({ targetDistanceKm: 5, seed: 0 })
  expect(bodies[0].end).toBeUndefined()
  await expect(cards(page).first()).toContainText('5,9')
  await expect(cards(page).first()).toContainText('→')

  const canvas = dialog.getByTestId('route-retouch-map').locator('canvas.maplibregl-canvas').first()
  await expect(canvas).toBeVisible()
  await expect.poll(() => traceMapPixels(page, canvas)).toBeGreaterThan(0)

  await dialog.getByRole('button', { name: 'Autres propositions' }).click()
  await expect.poll(() => bodies.length).toBe(2)
  expect(bodies[1].seed).toBe(1)
})

test('a refused shortening is an answer: blue message, the finish and the generator', async ({
  context,
  page,
}) => {
  const { owner, team, route } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  await stubOffer(page, OFFER)
  await stubRetouch(page, { status: 400, code: 'ROUTE_RETOUCH_NO_SHORTER' })

  await page.goto(routePath(team.slug, route.slug))
  await openActionsMenu(page)
  await page.getByRole('menuitem', { name: 'Ajuster la distance' }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByLabel('Distance visée').fill('5')
  await dialog.getByRole('button', { name: 'Proposer' }).click()
  await expect(dialog.getByText(/ne se raccourcit pas à 5/)).toBeVisible()
  await expect(dialog.getByRole('button', { name: 'Réessayer' })).toHaveCount(0)
  await dialog.getByRole('link', { name: 'Ouvrir le générateur' }).click()
  await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/parcours/generer\\?.*d=10`))
  await expect(page).toHaveURL(/s=/)
})

test('move the finish to a place of the team: the request carries end.placeId', async ({
  context,
  page,
}) => {
  const { owner, team, route, place } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  await stubOffer(page, OFFER)
  const bodies = await stubRetouch(page)

  await page.goto(routePath(team.slug, route.slug))
  await openActionsMenu(page)
  await page.getByRole('menuitem', { name: "Déplacer l'arrivée" }).click()
  const dialog = page.getByRole('dialog')
  await dialog
    .getByPlaceholder(/lieu|Rechercher/i)
    .first()
    .fill('Café')
  await dialog.getByText('Café du port').click()
  await dialog.getByRole('button', { name: 'Proposer' }).click()
  await expect(cards(page)).toHaveCount(3)
  expect(bodies[0].end).toEqual({ placeId: place.id })
  expect(bodies[0].targetDistanceKm).toBeUndefined()
})

test('« Ouvrir dans le planificateur » loads the proposal in a new route named « (retouché) », no router call', async ({
  context,
  page,
  isMobile,
}) => {
  test.skip(isMobile, "the planner of the form is the mouse's inline map")
  const { owner, team, route } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  await stubElevation(page)
  const routerRequests = await stubRouter(page)
  await stubOffer(page, OFFER)
  await stubRetouch(page)

  await page.goto(routePath(team.slug, route.slug))
  await openActionsMenu(page)
  await page.getByRole('menuitem', { name: 'Ajuster la distance' }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByLabel('Distance visée').fill('5')
  await dialog.getByRole('button', { name: 'Proposer' }).click()
  await expect(cards(page)).toHaveCount(3)
  await dialog.getByRole('button', { name: 'Ouvrir dans le planificateur' }).click()

  await expect(page).toHaveURL(ROUTE_NEW_PATH(team.slug))
  const main = page.getByRole('main')
  await expect(main.getByLabel(/^Nom/)).toHaveValue(/\(retouché\)$/)
  await expect(main.locator('canvas.maplibregl-canvas').first()).toBeVisible()
  expect(routerRequests).toHaveLength(0)
})

test('a member who may not plan has no button; a route still being analysed shows it disabled', async ({
  browser,
  context,
  page,
}) => {
  const { team, route, member } = await seeded()

  // The member: the offer is NOT_ALLOWED, nothing is shown (the real answer, no stub)
  await signIn(context, member)
  await stubBasemap(page)
  await page.goto(routePath(team.slug, route.slug))
  await expect(page.getByRole('heading', { level: 1, name: route.name })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Retoucher', exact: true })).toHaveCount(0)

  // NOT_READY, stubbed: disabled, with its reason
  const other = await browser.newContext()
  const otherPage = await other.newPage()
  const { owner } = await seeded()
  await signIn(other, owner)
  await stubBasemap(otherPage)
  await stubOffer(otherPage, {
    available: false,
    operations: [],
    unavailableReason: 'NOT_READY',
  })
  await otherPage.goto(routePath(team.slug, route.slug))
  const menu = await openActionsMenu(otherPage)
  const notReady = menu.getByRole('menuitem', { name: /Retoucher/ })
  await expect(notReady).toBeDisabled()
  await expect(notReady).toContainText("en cours d'analyse")
  await other.close()
})

test('an order anomaly has its own message', async ({ context, page }) => {
  const { owner, team, route } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  await stubOffer(page, OFFER)
  await stubRetouch(page, { status: 400, code: 'ROUTE_RETOUCH_ORDER_ANOMALY' })

  await page.goto(routePath(team.slug, route.slug))
  await openActionsMenu(page)
  await page.getByRole('menuitem', { name: 'Ajuster la distance' }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByLabel('Distance visée').fill('7')
  await dialog.getByRole('button', { name: 'Proposer' }).click()
  await expect(dialog.getByText(/repasse sur elle-même/)).toBeVisible()
})
