import type { Page } from '@playwright/test'
import type { RouteDetailDto } from '../src/api/dto'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { newRide, openRide } from './support/rides'
import {
  coordinatesOf,
  farthestFrom,
  getRoute,
  newRoute,
  newTrip,
  routeMapPath,
  routePath,
  stageMapPath,
  stagePath,
  stubBasemap,
  traceMapPixels,
  watchRouteReads,
  windingTrack,
  type GpxPoint,
} from './support/routes'

/**
 * The five screens that draw a route's COMPLETE trace (docs/LEDGER_*.md WEB-13): route detail, the
 * route's full-screen map, stage detail and the stage's full-screen map (all four through
 * `useGetRoute`), and a ride's group map (`RoutesMapView`, through `useRoutesBulk` WITHOUT
 * `geometry: false`).
 *
 * One route, uploaded as a GPX written here, backs all of them: a stage of a trip rides it, and so
 * does the group of a ride. For each screen the test proves that
 *  - every read of the route the page made — sent from the browser, or prefetched by the SSR server
 *    and handed over in the page — asked for the full geometry (no `geometry=false`, nor any other
 *    parameter) and carried every stored vertex, and that those vertices follow the uploaded track
 *    end to end;
 *  - MapLibre actually drew it: the map canvas shows the trace's colours on a stubbed basemap.
 *
 * Nothing depends on routing (Stadia Maps): the route comes from a GPX, not from the planner.
 */

/**
 * How far the stored geometry may stray from the uploaded points: the backend resamples the track
 * to one point per 10 m, then simplifies it with Douglas-Peucker at 3 m
 * (GpxProcessingService.computeGpx, GPXFilter). A geometry missing a stretch of the track — cut
 * short, or decimated to a few vertices — is hundreds of metres off somewhere on this winding one.
 */
const GEOMETRY_TOLERANCE_M = 15

interface World {
  team: { slug: string }
  viewer: Awaited<ReturnType<typeof newUser>>
  gpx: GpxPoint[]
  route: RouteDetailDto
  trip: { slug: string; stageSlug: string; stageName: string }
  ride: Awaited<ReturnType<typeof newRide>>
}

/**
 * Built once per worker (the route upload runs the whole GPX pipeline) and shared by its tests:
 * nothing here is modified by them, they only look.
 */
let world: Promise<World> | undefined
function sharedWorld(): Promise<World> {
  world ??= (async () => {
    const owner = await roleSession('admin')
    const team = await newTeam(owner, unique('Parcours cartes'))
    const viewer = await newUser(unique('Cycliste'))
    await addMember(owner, team.slug, viewer)

    const gpx = windingTrack(300)
    const created = await newRoute(owner, team.slug, unique('Boucle beauceronne'), gpx)
    const route = await getRoute(owner, team.slug, created.slug)

    const stageName = unique('Étape une')
    const trip = await newTrip(owner, team.slug, unique('Voyage en Beauce'), [
      { name: stageName, routeSlug: route.slug },
    ])
    const stage = trip.stages.find((s) => s.name === stageName)
    if (!stage) throw new Error(`trip ${trip.slug} has no stage named ${stageName}`)

    const ride = await newRide(owner, team.slug, unique('Sortie en Beauce'), {
      groups: [{ name: unique('Groupe carte'), routeSlug: route.slug }],
    })
    return {
      team,
      viewer,
      gpx,
      route,
      trip: { slug: trip.slug, stageSlug: stage.slug, stageName },
      ride,
    }
  })()
  // A failed set-up is not kept: the next test of the worker tries again.
  world.catch(() => {
    world = undefined
  })
  return world
}

test.beforeEach(async ({ page, context }) => {
  const { viewer } = await sharedWorld()
  await stubBasemap(page)
  await signIn(context, viewer)
})

test('the uploaded GPX is stored whole: the reference every screen is held to', async () => {
  const { gpx, route } = await sharedWorld()
  const stored = coordinatesOf(route)
  // A winding 15 km: resampled then simplified, it keeps far more than a handful of vertices.
  expect(stored.length).toBeGreaterThan(100)
  expect(farthestFrom(stored, gpx)).toBeLessThan(GEOMETRY_TOLERANCE_M)
  // Each vertex carries longitude, latitude, elevation and cumulative distance.
  expect(stored.every((vertex) => vertex.length === 4)).toBe(true)
})

/**
 * Waits for MapLibre to have drawn the trace, then checks every read of the route the page made.
 * `via` is the endpoint the screen is documented to read it through.
 */
async function expectFullTrace(
  page: Page,
  watcher: ReturnType<typeof watchRouteReads>,
  { gpx, route, team }: World,
  via: 'single' | 'bulk'
) {
  const canvas = page.locator('canvas.maplibregl-canvas')
  await expect(canvas, 'one MapLibre map on the page').toHaveCount(1)
  await expect(canvas).toBeVisible()
  // The trace is the only colour on a stubbed basemap: poll until the map has drawn it.
  await expect
    .poll(() => traceMapPixels(page, canvas), {
      message: 'the map canvas shows the trace',
      timeout: 20_000,
    })
    .toBeGreaterThan(500)

  const reads = await watcher.reads()
  const endpoint =
    via === 'single'
      ? `/api/teams/${team.slug}/routes/${route.slug}`
      : `/api/teams/${team.slug}/routes/bulk`
  expect(
    reads.map((read) => read.endpoint),
    `the page read the route through ${endpoint}`
  ).toContain(endpoint)

  const stored = coordinatesOf(route)
  for (const read of reads) {
    const label = `${read.source} read of ${read.endpoint} ${JSON.stringify(read.params)}`
    // Nothing but the slug — and on the bulk endpoint, `geometry` only if it asks for it.
    const { geometry, ...others } = read.params
    expect(others, `${label}: no other parameter`).toEqual({})
    if (read.endpoint.endsWith('/bulk'))
      expect(String(geometry ?? true), `${label}: geometry not turned off`).toBe('true')
    else expect(geometry, `${label}: no geometry parameter`).toBeUndefined()

    const delivered = coordinatesOf(read.route)
    expect(delivered.length, `${label}: every stored vertex`).toBe(stored.length)
    expect(delivered, `${label}: the stored geometry, untouched`).toEqual(stored)
    expect(farthestFrom(delivered, gpx), `${label}: follows the GPX end to end`).toBeLessThan(
      GEOMETRY_TOLERANCE_M
    )
  }
}

test('route detail draws the complete trace', async ({ page }) => {
  const w = await sharedWorld()
  const watcher = watchRouteReads(page, w.team.slug, w.route.slug)
  await page.goto(routePath(w.team.slug, w.route.slug))
  await expect(page.getByRole('heading', { level: 1, name: w.route.name })).toBeVisible()
  await expectFullTrace(page, watcher, w, 'single')
})

test("the route's full-screen map draws the complete trace", async ({ page }) => {
  const w = await sharedWorld()
  const watcher = watchRouteReads(page, w.team.slug, w.route.slug)
  await page.goto(routeMapPath(w.team.slug, w.route.slug))
  // A missing route would redirect to the detail page: the full-screen toolbar proves we stayed.
  await expect(page).toHaveURL(new RegExp(`${routeMapPath(w.team.slug, w.route.slug)}$`))
  await expect(page.getByText(w.route.name, { exact: true })).toBeVisible()
  await expectFullTrace(page, watcher, w, 'single')
})

test('stage detail draws the complete trace', async ({ page }) => {
  const w = await sharedWorld()
  const watcher = watchRouteReads(page, w.team.slug, w.route.slug)
  await page.goto(stagePath(w.team.slug, w.trip.slug, w.trip.stageSlug))
  // The title is in the sticky header too.
  await expect(
    page.getByRole('heading', { level: 2, name: w.trip.stageName }).first()
  ).toBeVisible()
  await expect(page.getByRole('heading', { level: 3, name: w.route.name })).toBeVisible()
  await expectFullTrace(page, watcher, w, 'single')
})

test("the stage's full-screen map draws the complete trace", async ({ page }) => {
  const w = await sharedWorld()
  const watcher = watchRouteReads(page, w.team.slug, w.route.slug)
  const path = stageMapPath(w.team.slug, w.trip.slug, w.trip.stageSlug)
  await page.goto(path)
  // A stage without a route would redirect to the stage page: the URL proves we stayed.
  await expect(page).toHaveURL(new RegExp(`${path}$`))
  await expect(page.getByText(w.trip.stageName, { exact: true })).toBeVisible()
  await expectFullTrace(page, watcher, w, 'single')
})

test("a ride group's map draws the complete trace", async ({ page }) => {
  const w = await sharedWorld()
  const watcher = watchRouteReads(page, w.team.slug, w.route.slug)
  await openRide(page, w.team.slug, w.ride)
  await expectFullTrace(page, watcher, w, 'bulk')
})
