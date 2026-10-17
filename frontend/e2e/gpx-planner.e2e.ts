import { ErrorCode } from '../src/api/dto'
import type { ErrorResponse, GpxPreviewDto, RouterResponse } from '../src/api/dto'
import {
  PLANNER_CENTER,
  PLANNER_HOST,
  PLANNER_PIN_HOST,
  hostGet,
  originOf,
  plannerSite,
  signInPlanner,
} from './support/domains'
import { expect, test, unique } from './support/fixtures'
import type { BrowserContext, Page } from '@playwright/test'
import { stubBasemap, stubRouter, traceMapPixels, watchRouter } from './support/routes'
import { hydrated } from './support/ui'

/**
 * The GPX tools' planner (« Créer un parcours », /outils-gpx/nouveau — CreateGpxPreviewPage.tsx,
 * GpxPreviewEditor.tsx, RoutePlanner.tsx), which `localhost` keeps closed (routes-render.e2e.ts,
 * gpxToolsNew). It runs on a domain of its own with `enableGpxPlanner` on, reached through an
 * alias pinned to a team located in Paris, so that the map opens on Paris at the team zoom
 * (ConfigService.java defaultCenter) — support/domains.ts plannerSite.
 *
 * Two clicks on the map are two control points; the segment between them is routed by the backend
 * (POST /api/router) and drawn; saving sends the routed points to POST /api/gpx-previews/from-points,
 * which runs the GPX pipeline and returns the preview the page then opens.
 *
 * Routing goes to the Stadia Maps API and is billed per request: every test here answers
 * POST /api/router itself (stubRouter, support/routes.ts) and counts the requests, which is also the
 * cost of each gesture — except the first drawing test, which reaches the real router (one request
 * per Playwright project, watchRouter) when scripts/e2e.sh found a key, and simulates it otherwise (E2E_NO_ROUTING).
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
  await signInPlanner(context)
  await stubBasemap(page)
  // The one test that reaches Stadia Maps, when a key is present: one billed request.
  const routerRequests = process.env.E2E_NO_ROUTING
    ? await stubRouter(page)
    : await watchRouter(page)
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
  expect(router.ok(), 'the router answers').toBe(true)
  expect(routerRequests).toHaveLength(1)
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

/**
 * The planner, opened straight on its page with the basemap and the router simulated. Gestures are
 * driven on the map's canvas; the markers are found by their accessible name (« Point 2 »), the
 * routed segments counted on `routerRequests`.
 */
async function openPlanner({ context, page }: { context: BrowserContext; page: Page }) {
  await signInPlanner(context)
  await stubBasemap(page)
  const routerRequests = await stubRouter(page)
  const main = page.getByRole('main')

  await page.goto(`${origin}/outils-gpx/nouveau`)
  await expect(page.getByRole('heading', { level: 1, name: 'Créer un parcours' })).toBeVisible()
  const nameField = main.getByRole('textbox', { name: 'Nom du parcours' })
  await hydrated(nameField)

  const canvas = main.locator('canvas.maplibregl-canvas').first()
  await expect(canvas).toBeVisible()
  const box = await canvas.boundingBox()
  if (!box) throw new Error('the planner map has no box')

  /** A position in the canvas, in canvas pixels from its top-left corner. */
  const at = (dx: number, dy: number) => ({ x: box.width / 2 + dx, y: box.height / 2 + dy })
  /** Page coordinates of a canvas position. */
  const onPage = (dx: number, dy: number) => {
    const { x, y } = at(dx, dy)
    return { x: box.x + x, y: box.y + y }
  }
  const marker = (n: number) => main.getByRole('button', { name: `Point ${n}`, exact: true })
  const points = (n: number) => main.getByText(n === 1 ? '1 point' : `${n} points`, { exact: true })
  /** The calculation overlay is gone: the gesture's routing is over and the map answers again. */
  const settled = async () => {
    await expect(main.getByRole('status', { name: "Calcul de l'itinéraire..." })).toHaveCount(0)
  }

  /** Clicks the map at an offset from its centre, with the straight-line modifier keys held. */
  const clickMap = async (dx: number, dy: number, modifiers: ('Control' | 'Alt')[] = []) => {
    await canvas.click({ position: at(dx, dy), modifiers })
  }

  return {
    main,
    page,
    canvas,
    nameField,
    routerRequests,
    at,
    onPage,
    marker,
    points,
    settled,
    clickMap,
  }
}

/** Three control points: 0 request for the first, then one routed segment each. */
async function drawThreePoints(planner: Awaited<ReturnType<typeof openPlanner>>) {
  const { clickMap, points, settled, routerRequests } = planner
  await clickMap(-120, 0)
  await expect(points(1)).toBeVisible()
  expect(routerRequests, 'the first point needs no routing').toHaveLength(0)
  await clickMap(0, 40)
  await expect(points(2)).toBeVisible()
  await settled()
  await clickMap(100, 0)
  await expect(points(3)).toBeVisible()
  await settled()
  expect(routerRequests, 'one routed segment per added point').toHaveLength(2)
  routerRequests.length = 0
}

test.describe('the planner gestures, with a simulated router', () => {
  test.setTimeout(90_000)

  test('adding points: one routing per point after the first, none in straight-line mode', async ({
    context,
    page,
  }) => {
    const planner = await openPlanner({ context, page })
    const { clickMap, points, settled, routerRequests } = planner
    await drawThreePoints(planner)

    // Ctrl and Alt both draw a straight line (Alt for macOS, where Ctrl+click is a right click): a
    // point is added, nothing is asked of the router.
    await clickMap(130, 60, ['Control'])
    await expect(points(4)).toBeVisible()
    await settled()
    await clickMap(150, -60, ['Alt'])
    await expect(points(5)).toBeVisible()
    await settled()
    expect(routerRequests, 'straight-line points are never routed').toHaveLength(0)
  })

  test('dragging a point reroutes its two neighbouring segments, once', async ({
    context,
    page,
  }) => {
    const planner = await openPlanner({ context, page })
    const { page: p, marker, points, settled, routerRequests, onPage } = planner
    await drawThreePoints(planner)

    const middle = await marker(2).boundingBox()
    if (!middle) throw new Error('the second marker has no box')
    const from = { x: middle.x + middle.width / 2, y: middle.y + middle.height / 2 }
    const to = onPage(10, 110)

    await p.mouse.move(from.x, from.y)
    await p.mouse.down()
    await p.mouse.move((from.x + to.x) / 2, (from.y + to.y) / 2, { steps: 5 })
    await p.mouse.move(to.x, to.y, { steps: 5 })
    await p.mouse.up()

    await settled()
    await expect(points(3)).toBeVisible()
    expect(routerRequests, 'from the previous point, and to the next one').toHaveLength(2)
    // The moved point follows the pointer.
    await expect
      .poll(async () => {
        const moved = await marker(2).boundingBox()
        return moved ? Math.abs(moved.y + moved.height / 2 - to.y) : Infinity
      })
      .toBeLessThan(20)
  })

  test('dragging out of the trace inserts a point, and the click that ends it adds none', async ({
    context,
    page,
  }) => {
    const planner = await openPlanner({ context, page })
    const { page: p, main, marker, points, settled, routerRequests } = planner
    await drawThreePoints(planner)

    // Grab the trace halfway between the first two points, read where they are drawn now: the map
    // can have moved since the clicks (the toolbar above it changes height with the first point).
    const centre = async (n: number) => {
      const b = await marker(n).boundingBox()
      if (!b) throw new Error(`marker ${n} has no box`)
      return { x: b.x + b.width / 2, y: b.y + b.height / 2 }
    }
    const [first, second] = [await centre(1), await centre(2)]
    const grab = { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 }
    const drop = { x: grab.x, y: grab.y - 110 }
    await p.mouse.move(grab.x - 10, grab.y - 10)
    await p.mouse.move(grab.x, grab.y, { steps: 3 })
    // Hovering the trace shows the ghost point; give React a render before pressing.
    await p.mouse.move(grab.x + 1, grab.y, { steps: 2 })
    await p.mouse.down()
    await p.mouse.move(drop.x, drop.y, { steps: 8 })
    await p.mouse.up()

    await settled()
    await expect(points(4)).toBeVisible()
    await expect(main.getByRole('button', { name: 'Point 4', exact: true })).toBeVisible()
    // The two halves of the cut segment: before the new point and after it. The click the mouse-up
    // ends with must not have added a point of its own (the operation lock drops it).
    expect(routerRequests).toHaveLength(2)
  })

  test('a right click deletes a point and reroutes around it', async ({ context, page }) => {
    const planner = await openPlanner({ context, page })
    const { marker, points, settled, routerRequests } = planner
    await drawThreePoints(planner)

    await marker(2).click({ button: 'right' })
    await settled()
    await expect(points(2)).toBeVisible()
    await expect(marker(3)).toHaveCount(0)
    expect(routerRequests, 'one segment joins the neighbours').toHaveLength(1)
  })

  test('an exhausted routing quota is explained under the planner and adds no point', async ({
    context,
    page,
  }) => {
    const planner = await openPlanner({ context, page })
    const { main, clickMap, points, settled } = planner
    await drawThreePoints(planner)

    // The router now answers like the backend does when the Stadia monthly quota is spent.
    const refused: unknown[] = []
    await page.route('**/api/router', async (route) => {
      if (route.request().method() !== 'POST') return route.fallback()
      refused.push(route.request().postDataJSON())
      const body: ErrorResponse = { code: ErrorCode.ROUTING_QUOTA_EXCEEDED }
      await route.fulfill({ status: 503, json: body })
    })

    await clickMap(-100, 90)
    await expect(
      main.getByText("Le service d'itinéraires a atteint son quota mensuel. Réessayez plus tard.")
    ).toBeVisible()
    await settled()
    expect(refused).toHaveLength(1)
    await expect(points(3)).toBeVisible()
    // The planner says it inline: the global toast would repeat it.
    await expect(page.getByText("Le service de calcul d'itinéraire a atteint")).toHaveCount(0)
  })

  test('a long press deletes a point from its menu (touch)', async ({
    context,
    page,
    isMobile,
  }) => {
    // The press is a real touchscreen gesture, only meaningful on the touch project (Pixel 7).
    test.skip(!isMobile, 'long press is a touch gesture: covered by the mobile project')
    const planner = await openPlanner({ context, page })
    const { marker, points, settled, routerRequests } = planner
    await drawThreePoints(planner)

    const box = await marker(2).boundingBox()
    if (!box) throw new Error('the second marker has no box')
    const [x, y] = [box.x + box.width / 2, box.y + box.height / 2]
    // Playwright's touchscreen can only tap: the press is sent to the browser as raw touch events.
    const cdp = await context.newCDPSession(page)
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] })
    await page.waitForTimeout(800) // the menu opens after 500 ms without movement
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })

    await page.getByRole('menuitem', { name: 'Supprimer le point' }).click()
    await settled()
    await expect(points(2)).toBeVisible()
    expect(routerRequests).toHaveLength(1)
  })

  test('Ctrl+Z undoes and Ctrl+Shift+Z redoes the trace, without asking the router again', async ({
    context,
    page,
  }) => {
    const planner = await openPlanner({ context, page })
    const { page: p, main, points, settled, routerRequests } = planner
    await drawThreePoints(planner)

    await p.keyboard.press('Control+z')
    await expect(points(2)).toBeVisible()
    await p.keyboard.press('Control+Shift+z')
    await expect(points(3)).toBeVisible()
    // The same, from the map's buttons.
    await main.getByRole('button', { name: /^Annuler \(/ }).click()
    await expect(points(2)).toBeVisible()
    await main.getByRole('button', { name: /^Rétablir/ }).click()
    await expect(points(3)).toBeVisible()
    await settled()
    expect(routerRequests, 'history replays what it kept').toHaveLength(0)
  })

  test('Ctrl+Z in a text field edits the text and leaves the trace alone', async ({
    context,
    page,
  }) => {
    const planner = await openPlanner({ context, page })
    const { page: p, nameField, points } = planner
    await drawThreePoints(planner)

    await nameField.click()
    await nameField.pressSequentially('Boucle du dimanche')
    await p.keyboard.press('Control+z')
    await expect(points(3)).toBeVisible()
    await p.keyboard.press('Control+Shift+z')
    await expect(points(3)).toBeVisible()
    // Not even a late undo: give the page a moment to (wrongly) react, then look again.
    await p.waitForTimeout(300)
    await expect(points(3)).toBeVisible()
  })
})
