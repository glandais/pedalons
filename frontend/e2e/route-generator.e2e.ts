import type {
  GeneratedRouteDto,
  RouteGeneratorRequest,
  RouteGeneratorResponse,
} from '../src/api/dto'
import { encode2 } from '../src/lib/polyline'
import { addMember, getTeam, newTeam, newUser, setTeamAttributes, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import {
  coordinatesOf,
  getRoute,
  newRoute,
  stubBasemap,
  stubElevation,
  stubRouter,
  traceMapPixels,
  windingTrack,
} from './support/routes'
import { hydrated, toasts } from './support/ui'
import type { Page } from '@playwright/test'

/**
 * The team route generator's site (ledger WEB-179, plan docs/plans/archive/2026-11-13-generateur-boucles-equipe-lot4.md):
 * the page /equipes/{slug}/parcours/generer (RouteGeneratorPage), the same panel in the route
 * editor's dialog, « Ouvrir dans l'éditeur » (a replacing import that keeps no file, so the save
 * draws the planner quota) and the exclusion box of the route form.
 *
 * The e2e stack runs osm-route-details without a graph (it serves the altitude only), so the real
 * endpoint answers GENERATOR_UNAVAILABLE. One test makes that real call; the others stub
 * POST /api/teams/{slug}/route-generator, as gpx-planner.e2e.ts stubs the router. A real
 * generation is checked by hand on a local stack with the graph (lot 3b plan).
 */

test.setTimeout(120_000)

/** Where the candidates are: the winding track's start, in the Beauce. */
const START = '48.4469,1.4875'
const GENERATE_PATH = (slug: string) => `/equipes/${slug}/parcours/generer`
const ROUTE_NEW_PATH = (slug: string) => `/equipes/${slug}/parcours/nouveau`

/** An organizer, a team with the planner on, two ROAD routes and one GRAVEL route, and a member. */
function setup() {
  return (async () => {
    const owner = await newUser('generator-owner')
    const team = await newTeam(owner, unique('Équipe générateur'), {
      geometry: { type: 'Point', coordinates: [1.4875, 48.4469] },
    })
    await setTeamAttributes(team, { enableRoutePlanner: true })
    const track = windingTrack(120)
    const road1 = await newRoute(owner, team.slug, unique('Route un'), track)
    const road2 = await newRoute(owner, team.slug, unique('Route deux'), track)
    const gravel = await newRoute(owner, team.slug, unique('Gravel un'), track, {
      surfaceType: 'GRAVEL',
    })
    const member = await newUser('generator-member')
    await addMember(team.slug, member)
    return { owner, team, road1, road2, gravel, member }
  })()
}
let fixture: ReturnType<typeof setup> | undefined
const seeded = () => (fixture ??= setup())

/** Three candidates shaped like the winding track, `shift` degrees of latitude apart. */
function candidates(): GeneratedRouteDto[] {
  return [0, 0.002, 0.004].map((shift, i) => {
    const line = windingTrack(120).map(([lat, lon]) => [lon, lat + shift])
    const lons = line.map((c) => c[0])
    const lats = line.map((c) => c[1])
    return {
      polyline: encode2(line),
      distanceM: 5950 + i * 400,
      ascentM: 40 + i * 10,
      descentM: 40 + i * 10,
      teamShare: [0.8, 1, 0.3][i],
      unpavedShare: 0,
      sharedM: i === 0 ? 1200 : 0,
      crossings: 0,
      bounds: {
        minLon: Math.min(...lons),
        maxLon: Math.max(...lons),
        minLat: Math.min(...lats),
        maxLat: Math.max(...lats),
      },
    }
  })
}

/** Answers the generator with `candidates()` and records each body. */
async function stubGenerator(page: Page) {
  const bodies: RouteGeneratorRequest[] = []
  const response: RouteGeneratorResponse = {
    candidates: candidates(),
    partialCoverage: false,
  }
  await page.route('**/api/teams/*/route-generator', async (route) => {
    bodies.push(route.request().postDataJSON() as RouteGeneratorRequest)
    await route.fulfill({ json: response })
  })
  return { bodies, first: response.candidates[0] }
}

const generateButton = (page: Page) => page.getByRole('button', { name: 'Générer', exact: true })
const cards = (page: Page) => page.getByTestId('generated-route-card')

test('the organizer reaches the generator from the routes list, and the real answer says the generator is unavailable', async ({
  context,
  page,
}) => {
  const { owner, team } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  const watched = toasts(page)

  await page.goto(`/equipes/${team.slug}/parcours`)
  const entry = page.getByRole('main').getByRole('link', { name: 'Générer un parcours' })
  await hydrated(entry)
  await entry.click()
  await expect(page).toHaveURL(GENERATE_PATH(team.slug))
  await expect(page.getByRole('heading', { level: 1, name: 'Générer un parcours' })).toBeVisible()

  // An explicit start, as a shared link carries it
  await page.goto(`${GENERATE_PATH(team.slug)}?s=${START}`)
  // Two ROAD routes against one GRAVEL: « Route » is preselected
  await expect(page.getByRole('radio', { name: 'Route', exact: true })).toBeChecked()
  await hydrated(generateButton(page))
  await generateButton(page).click()
  await expect(page.getByText(/Le générateur de parcours est indisponible/)).toBeVisible()
  // The panel words the failure itself: no toast
  await expect(watched).toHaveCount(0)
})

test('stubbed candidates: three cards and lines, other proposals ask seed 1, a far end drops the bearing', async ({
  context,
  page,
  isMobile,
}) => {
  const { owner, team } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  const generator = await stubGenerator(page)

  await page.goto(`${GENERATE_PATH(team.slug)}?s=${START}`)
  await hydrated(generateButton(page))
  await generateButton(page).click()
  await expect(cards(page)).toHaveCount(3)
  expect(generator.bodies).toHaveLength(1)
  expect(generator.bodies[0]).toMatchObject({ distanceKm: 50, type: 'ROAD', seed: 0 })
  expect(generator.bodies[0].start).toBeDefined()

  const canvas = page.getByTestId('route-generator-map').locator('canvas.maplibregl-canvas').first()
  await expect(canvas).toBeVisible()
  await expect.poll(() => traceMapPixels(page, canvas)).toBeGreaterThan(0)

  await page.getByRole('button', { name: 'Autres propositions' }).click()
  await expect.poll(() => generator.bodies.length).toBe(2)
  expect(generator.bodies[1].seed).toBe(1)

  // A far end (about 85 km from the start for 50 km wished): the compass is out, no bearing sent
  await page.goto(`${GENERATE_PATH(team.slug)}?s=${START}&e=48.9,2.4&cap=N&go=true`)
  await expect(page.getByRole('button', { name: 'Nord', exact: true })).toBeDisabled()
  await expect(page.getByText("L'arrivée est loin du départ", { exact: false })).toBeVisible()
  await expect(cards(page)).toHaveCount(3)
  const last = generator.bodies.at(-1)!
  expect(last.end).toBeDefined()
  expect('bearing' in last).toBe(false)
  void isMobile
})

test("« Ouvrir dans l'éditeur » loads the candidate with no router call and draws the planner quota; coming back sends no new request", async ({
  context,
  page,
  isMobile,
}) => {
  test.skip(isMobile, "the planner of the form is the mouse's inline map")
  const { owner, team } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  await stubElevation(page)
  const routerRequests = await stubRouter(page)
  const generator = await stubGenerator(page)
  const quotaBefore = (await getTeam(owner, team.slug)).plannerQuota?.used ?? 0

  await page.goto(`${GENERATE_PATH(team.slug)}?s=${START}&t=GRAVEL`)
  await hydrated(generateButton(page))
  await generateButton(page).click()
  await expect(cards(page)).toHaveCount(3)
  expect(generator.bodies[0].type).toBe('GRAVEL')
  await cards(page).first().getByRole('button', { name: "Ouvrir dans l'éditeur" }).click()

  await expect(page).toHaveURL(ROUTE_NEW_PATH(team.slug))
  const main = page.getByRole('main')
  await expect(main.getByLabel(/^Nom/)).toHaveValue(/Parcours généré de/)
  await expect(main.locator('canvas.maplibregl-canvas').first()).toBeVisible()
  const saved = page.waitForResponse(
    (r) => r.request().method() === 'POST' && r.url().endsWith(`/api/teams/${team.slug}/routes`)
  )
  await main.getByRole('button', { name: 'Créer le parcours' }).click()
  expect((await saved).ok()).toBe(true)
  await expect(page).not.toHaveURL(ROUTE_NEW_PATH(team.slug))

  // No routing provider was called, the type is the generated one, the line is the candidate's
  expect(routerRequests).toHaveLength(0)
  const slug = new URL(page.url()).pathname.split('/').at(-1)!
  const route = await getRoute(owner, team.slug, slug)
  expect(route.surfaceType).toBe('GRAVEL')
  const line = coordinatesOf(route)
  const [lon0, lat0] = line[0]
  const [lonN, latN] = line.at(-1)!
  const wanted = windingTrack(120)
  const metres = (lat: number, lon: number, [wLat, wLon]: [number, number, number]) =>
    Math.hypot((lat - wLat) * 111_320, (lon - wLon) * 111_320 * Math.cos((wLat * Math.PI) / 180))
  // The first candidate is the track itself, shifted by 0
  expect(metres(lat0, lon0, wanted[0])).toBeLessThan(15)
  expect(metres(latN, lonN, wanted.at(-1)!)).toBeLessThan(15)
  // A drawn track counts: the file would not have
  expect((await getTeam(owner, team.slug)).plannerQuota?.used).toBe(quotaBefore + 1)

  // Back to the generator: the cache answers
  const posts = generator.bodies.length
  await page.goBack()
  await page.goBack()
  await expect(page).toHaveURL(new RegExp(`${GENERATE_PATH(team.slug)}`))
  await expect(cards(page)).toHaveCount(3)
  expect(generator.bodies).toHaveLength(posts)
})

test("from the editor's opening panel, a candidate chosen in the dialog goes to the planner", async ({
  context,
  page,
  isMobile,
}) => {
  test.skip(isMobile, "the planner of the form is the mouse's inline map")
  const { owner, team } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  await stubElevation(page)
  await stubRouter(page)
  await stubGenerator(page)

  await page.goto(ROUTE_NEW_PATH(team.slug))
  const main = page.getByRole('main')
  const open = main.getByRole('button', { name: 'Générer un parcours' })
  await hydrated(open)
  await open.click()
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByRole('heading', { name: 'Générer un parcours' })).toBeVisible()
  await expect(dialog.getByText('Aucune proposition pour le moment')).toBeVisible()
  // The team's location is the start: nothing to place
  await dialog.getByRole('button', { name: 'Générer', exact: true }).click()
  await expect(dialog.getByTestId('generated-route-card')).toHaveCount(3)
  await dialog.getByRole('button', { name: 'Utiliser ce parcours' }).first().click()
  await expect(dialog).toHaveCount(0)
  await expect(main.locator('canvas.maplibregl-canvas').first()).toBeVisible()
  await expect(main.getByLabel(/^Nom/)).toHaveValue(/Parcours généré de/)
})

test('the exclusion box is saved and reread, and gone on a team without the planner', async ({
  context,
  page,
}) => {
  const { owner, team, road1 } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  const editPath = `/equipes/${team.slug}/parcours/${road1.slug}/modifier`
  const box = () => page.getByRole('main').getByLabel('Ne pas utiliser pour générer des parcours')

  await page.goto(editPath)
  await hydrated(box())
  await expect(box()).not.toBeChecked()
  await box().check()
  const saved = page.waitForResponse(
    (r) => r.request().method() === 'PUT' && r.url().endsWith(`/routes/${road1.slug}`)
  )
  await page.getByRole('main').getByRole('button', { name: 'Enregistrer' }).click()
  expect((await saved).ok()).toBe(true)
  expect((await getRoute(owner, team.slug, road1.slug)).excludedFromGenerator).toBe(true)

  await page.goto(editPath)
  await hydrated(box())
  await expect(box()).toBeChecked()
  await box().uncheck()
  const again = page.waitForResponse(
    (r) => r.request().method() === 'PUT' && r.url().endsWith(`/routes/${road1.slug}`)
  )
  await page.getByRole('main').getByRole('button', { name: 'Enregistrer' }).click()
  expect((await again).ok()).toBe(true)
  expect((await getRoute(owner, team.slug, road1.slug)).excludedFromGenerator).toBe(false)
})

test('a member sees no button and is sent back to the list; a team without the planner shows neither the button nor the box', async ({
  browser,
  context,
  page,
}) => {
  const { team, member, road1 } = await seeded()

  // The member
  await signIn(context, member)
  await page.goto(`/equipes/${team.slug}/parcours`)
  await expect(page.getByRole('heading', { name: 'Parcours', level: 2 })).toBeVisible()
  await expect(page.getByRole('link', { name: 'Générer un parcours' })).toHaveCount(0)
  await page.goto(GENERATE_PATH(team.slug))
  await expect(page).toHaveURL(`/equipes/${team.slug}/parcours`)

  // The organizer of a team whose planner is off. A team is born with it on (docs/LEDGER_*.md
  // BILL-10), and a free user owns one team: another owner, and the platform admin's switch
  const plainOwner = await newUser('generator-plain')
  const plain = await newTeam(plainOwner, unique('Équipe sans tracé'))
  const route = await newRoute(plainOwner, plain.slug, unique('Sans tracé'), windingTrack(60))
  await setTeamAttributes(plain, { enableRoutePlanner: false })
  const ownerContext = await browser.newContext()
  const ownerPage = await ownerContext.newPage()
  await signIn(ownerContext, plainOwner)
  await ownerPage.goto(`/equipes/${plain.slug}/parcours`)
  await expect(ownerPage.getByRole('heading', { name: 'Parcours', level: 2 })).toBeVisible()
  await expect(ownerPage.getByRole('link', { name: 'Générer un parcours' })).toHaveCount(0)
  await ownerPage.goto(`/equipes/${plain.slug}/parcours/${route.slug}/modifier`)
  await expect(
    ownerPage.getByRole('main').getByLabel('Ne pas utiliser pour générer des parcours')
  ).toHaveCount(0)
  await ownerContext.close()
  void road1
})

test('gravel at the « Beaucoup » stop sends unpaved HIGH, and the URL keeps it as ch', async ({
  context,
  page,
}) => {
  const { owner, team } = await seeded()
  await signIn(context, owner)
  await stubBasemap(page)
  const generator = await stubGenerator(page)

  await page.goto(`${GENERATE_PATH(team.slug)}?s=${START}&t=GRAVEL`)
  await hydrated(generateButton(page))
  await page.getByText('Beaucoup', { exact: true }).click()
  await expect(page).toHaveURL(/ch=HIGH/)
  await generateButton(page).click()
  await expect(cards(page)).toHaveCount(3)
  expect(generator.bodies[0]).toMatchObject({ type: 'GRAVEL', unpaved: 'HIGH' })
})
