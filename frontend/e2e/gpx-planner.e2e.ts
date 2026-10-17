import type { GpxPreviewDto, RouterResponse } from '../src/api/dto'
import {
  PLANNER_CENTER,
  PLANNER_HOST,
  PLANNER_PIN_HOST,
  hostGet,
  originOf,
  plannerSite,
  signInOn,
} from './support/domains'
import { expect, test, unique } from './support/fixtures'
import { stubBasemap, traceMapPixels } from './support/routes'
import { hydrated } from './support/ui'

/**
 * The GPX tools' planner (« Créer un parcours », /outils-gpx/nouveau — CreateGpxPreviewPage.tsx,
 * GpxPreviewEditor.tsx, RoutePlanner.tsx), which `localhost` keeps closed (routes-render.e2e.ts,
 * gpxToolsNew). It runs on a domain of its own with `enableGpxPlanner` on, reached through an
 * alias pinned to a team located in Paris, so that the map opens on Paris at the team zoom
 * (ConfigService.java defaultCenter) — support/domains.ts plannerSite.
 *
 * Two clicks on the map are two control points; the segment between them is routed by the backend
 * (POST /api/router → the Stadia Maps API, with the key scripts/e2e.sh passes on: see e2e/README.md) and drawn;
 * saving sends the routed points to POST /api/gpx-previews/from-points, which runs the GPX pipeline
 * and returns the preview the page then opens.
 */

const origin = originOf(PLANNER_PIN_HOST)

test('the planner site opens the map on its team, and says the planner is open', async () => {
  const { team } = await plannerSite()
  const config = await hostGet<{
    enableGpxPlanner: boolean
    pinnedTeamSlug?: string
    defaultCenter: { lat: number; lon: number; zoom: number }
  }>(PLANNER_PIN_HOST, undefined, '/api/config')
  expect(config).toMatchObject({
    enableGpxPlanner: true,
    pinnedTeamSlug: team.slug,
    defaultCenter: { lon: PLANNER_CENTER[0], lat: PLANNER_CENTER[1], zoom: 9 },
  })
})

test('a user draws a route from two points on the map, sees it routed and traced, and saves it', async ({
  context,
  page,
}) => {
  test.setTimeout(90_000)
  const { owner } = await plannerSite()
  await signInOn(context, PLANNER_PIN_HOST, owner)
  await stubBasemap(page)
  const main = page.getByRole('main')

  // From the hub, whose « Créer un parcours » card only shows when the planner is open.
  await page.goto(`${origin}/outils-gpx`)
  await expect(page.getByRole('heading', { level: 1, name: 'Outils GPX' })).toBeVisible()
  const start = main.getByRole('button', { name: 'Créer un parcours' })
  await hydrated(start)
  await start.click()
  await expect(page).toHaveURL(`${origin}/outils-gpx/nouveau`)
  await expect(page.getByRole('heading', { level: 1, name: 'Créer un parcours' })).toBeVisible()

  // The planner's map — not the mini-map of the cursor's surroundings, on desktop.
  const canvas = main.locator('canvas.maplibregl-canvas').first()
  await expect(canvas).toBeVisible()
  const box = await canvas.boundingBox()
  if (!box) throw new Error('the planner map has no box')
  const [x, y] = [box.width / 2, box.height / 2]

  // Two clicks, a few kilometres apart around the map's centre: two control points, one routed
  // segment.
  await canvas.click({ position: { x: x - 40, y } })
  await expect(main.getByText('1 point', { exact: true })).toBeVisible()
  const routed = page.waitForResponse(
    (r) => r.url().endsWith('/api/router') && r.request().method() === 'POST'
  )
  await canvas.click({ position: { x: x + 40, y: y + 20 } })
  await expect(main.getByText('2 points', { exact: true })).toBeVisible()
  const router = await routed
  expect(router.ok(), 'the router (Stadia Maps) answers').toBe(true)
  const segment = (await router.json()) as RouterResponse
  const segmentLength = segment.dist ?? 0
  expect(segmentLength).toBeGreaterThan(1_000)
  await expect(main.getByText("Calcul de l'itinéraire...", { exact: true })).toHaveCount(0)

  // The segment is traced on the map, measured in the toolbar, and the editor holds its points
  // (« Tracé de n points » counts the routed track's points, not the two clicks — 98735ab1).
  await expect.poll(() => traceMapPixels(page, canvas), { timeout: 10_000 }).toBeGreaterThan(100)
  await expect(
    main.getByText(`${(segmentLength / 1000).toFixed(1)} km`, { exact: true })
  ).toBeVisible()
  const pointCount = main.getByText(/^Tracé de \d+ points$/)
  await expect(pointCount).toBeVisible()
  const routedPoints = Number((await pointCount.textContent())!.match(/\d+/)![0])
  expect(routedPoints).toBeGreaterThan(2)

  // Named and saved: the preview opens, drawn from those points.
  const name = unique('Tracé planifié')
  await main.getByRole('textbox', { name: 'Nom du parcours' }).fill(name)
  const saved = page.waitForResponse(
    (r) => r.url().endsWith('/api/gpx-previews/from-points') && r.request().method() === 'POST'
  )
  await main.getByRole('button', { name: 'Enregistrer' }).click()
  const savedResponse = await saved
  expect(savedResponse.ok()).toBe(true)
  const sent = savedResponse.request().postDataJSON() as {
    name: string
    points: { lat: number; lng: number }[]
  }
  expect(sent.name).toBe(name)
  expect(sent.points).toHaveLength(routedPoints)
  const preview = (await savedResponse.json()) as GpxPreviewDto

  await expect(page.getByText('Parcours créé', { exact: true })).toBeVisible()
  await expect(page).toHaveURL(`${origin}/outils-gpx/${preview.id}`)
  await expect(main.getByRole('heading', { name, exact: true })).toBeVisible()

  const stored = await hostGet<GpxPreviewDto>(
    PLANNER_HOST,
    owner,
    `/api/gpx-previews/${preview.id}`
  )
  expect(stored).toMatchObject({ name, owned: true })
  // The pipeline measured the routed line: its length, give or take the elevation and smoothing.
  expect(stored.distance).toBeGreaterThan(segmentLength * 0.9)
  expect(stored.distance).toBeLessThan(segmentLength * 1.1)
  expect(stored.tracks).toHaveLength(1)
  expect(stored.tracks[0].line.coordinates.length).toBeGreaterThan(2)
})
