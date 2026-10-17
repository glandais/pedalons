import { ErrorCode } from '../src/api/dto'
import type { ErrorResponse, GpxPreviewDto, RouterResponse } from '../src/api/dto'
import { expectOk } from './support/api'
import {
  PLANNER_CENTER,
  PLANNER_HOST,
  PLANNER_PIN_HOST,
  hostGet,
  onHost,
  originOf,
  plannerSite,
  signInPlanner,
} from './support/domains'
import { expect, test, unique } from './support/fixtures'
import type { BrowserContext, Page } from '@playwright/test'
import {
  gpxOf,
  stubBasemap,
  stubRouter,
  traceMapPixels,
  watchRouter,
  windingTrack,
} from './support/routes'
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
  isMobile,
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

  // On a finger the form holds a still preview: the map is in the fullscreen editor, opened here.
  const surface = await startDrawing(page, isMobile)

  // The planner's map — not the mini-map of the cursor's surroundings, on desktop.
  const canvas = surface.locator('canvas.maplibregl-canvas').first()
  await expect(canvas).toBeVisible()
  const box = await canvas.boundingBox()
  if (!box) throw new Error('the planner map has no box')
  const [x, y] = [box.width / 2, box.height / 2]

  // Two clicks, a few kilometres apart around the map's centre: two control points, one routed
  // segment.
  await canvas.click({ position: { x: x - 40, y } })
  await expect(surface.getByText('1 point', { exact: true })).toBeVisible()
  const routed = page.waitForResponse(
    (r) => r.url().endsWith('/api/router') && r.request().method() === 'POST'
  )
  await canvas.click({ position: { x: x + 40, y: y + 20 } })
  await expect(surface.getByText('2 points', { exact: true })).toBeVisible()
  const router = await routed
  expect(router.ok(), 'the router answers').toBe(true)
  expect(routerRequests).toHaveLength(1)
  const segment = (await router.json()) as RouterResponse
  const segmentLength = segment.dist ?? 0
  expect(segmentLength).toBeGreaterThan(1_000)
  await expect(surface.getByText("Calcul de l'itinéraire...", { exact: true })).toHaveCount(0)

  // The segment is traced on the map, measured in the toolbar (the preview, on a finger), and the
  // editor holds its points (« Tracé de n points » counts the routed track's points, not the two
  // clicks — 98735ab1).
  await expect.poll(() => traceMapPixels(page, canvas), { timeout: 10_000 }).toBeGreaterThan(100)
  if (isMobile) {
    await surface.getByRole('button', { name: 'Terminer' }).click()
    await expect(surface).toBeHidden()
  }
  await expect(
    main.getByText(`${(segmentLength / 1000).toFixed(1)} km`, { exact: true })
  ).toBeVisible()
  // On a finger the form shows the preview card instead, whose count is the control points: the
  // routed points are then only checked in what is sent.
  let routedPoints: number | undefined
  if (!isMobile) {
    const pointCount = main.getByText(/^Tracé de \d+ points$/)
    await expect(pointCount).toBeVisible()
    routedPoints = Number((await pointCount.textContent())!.match(/\d+/)![0])
    expect(routedPoints).toBeGreaterThan(2)
  }

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
  if (routedPoints === undefined) expect(sent.points.length).toBeGreaterThan(2)
  else expect(sent.points).toHaveLength(routedPoints)
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
 * Where the planner's map and tools are: the page on a mouse, the fullscreen editor (a dialog named
 * after the route, « Tracé » while it has no name) on a finger. A finger's form holds a still
 * preview and a button; the editor opens on a tap of it, never by itself.
 */
const editorOf = (page: Page, isMobile: boolean, name = 'Tracé') =>
  isMobile ? page.getByRole('dialog', { name, exact: true }) : page.getByRole('main')

/** Opens the fullscreen editor from the form on a finger; on a mouse the map is already in the page. */
async function startDrawing(page: Page, isMobile: boolean) {
  const main = page.getByRole('main')
  if (!isMobile) return main
  // Nothing of the map is built until the editor is opened.
  await expect(main.locator('canvas.maplibregl-canvas')).toHaveCount(0)
  const draw = main.getByRole('button', { name: 'Tracer le parcours' })
  await hydrated(draw)
  await draw.click()
  const dialog = editorOf(page, isMobile)
  await expect(dialog).toBeVisible()
  return dialog
}

/**
 * The planner, opened straight on its page with the basemap and the router simulated. Gestures are
 * driven on the map's canvas; the markers are found by their accessible name (« Point 2 »), the
 * routed segments counted on `routerRequests`. On a finger the map lives in the fullscreen editor,
 * opened here unless `enter` is false: `main` is always the form, `surface` the editor.
 */
async function openPlanner(
  { context, page, isMobile }: { context: BrowserContext; page: Page; isMobile: boolean },
  { enter = true }: { enter?: boolean } = {}
) {
  await signInPlanner(context)
  await stubBasemap(page)
  const routerRequests = await stubRouter(page)
  const main = page.getByRole('main')

  await page.goto(`${origin}/outils-gpx/nouveau`)
  await expect(page.getByRole('heading', { level: 1, name: 'Créer un parcours' })).toBeVisible()
  const nameField = main.getByRole('textbox', { name: 'Nom du parcours' })
  await hydrated(nameField)

  const surface = editorOf(page, isMobile)
  if (enter) await startDrawing(page, isMobile)

  const canvas = surface.locator('canvas.maplibregl-canvas').first()
  const box = async () => {
    await expect(canvas).toBeVisible()
    const b = await canvas.boundingBox()
    if (!b) throw new Error('the planner map has no box')
    return b
  }
  // The geometry is read when first needed (a test that enters later has no canvas yet).
  const first = enter ? await box() : undefined
  let measured = first

  /** A position in the canvas, in canvas pixels from its top-left corner. */
  const at = (dx: number, dy: number) => ({
    x: measured!.width / 2 + dx,
    y: measured!.height / 2 + dy,
  })
  /** Page coordinates of a canvas position. */
  const onPage = (dx: number, dy: number) => {
    const { x, y } = at(dx, dy)
    return { x: measured!.x + x, y: measured!.y + y }
  }
  const marker = (n: number) => surface.getByRole('button', { name: `Point ${n}`, exact: true })
  const points = (n: number) =>
    surface.getByText(n === 1 ? '1 point' : `${n} points`, { exact: true })
  /** The calculation overlay is gone: the gesture's routing is over and the map answers again. */
  const settled = async () => {
    await expect(surface.getByRole('status', { name: "Calcul de l'itinéraire..." })).toHaveCount(0)
  }

  /** Clicks the map at an offset from its centre, with the straight-line modifier keys held. */
  const clickMap = async (dx: number, dy: number, modifiers: ('Control' | 'Alt')[] = []) => {
    await canvas.click({ position: at(dx, dy), modifiers })
  }

  /** Opens the fullscreen editor, once the test is ready for it, and measures the map. */
  const enterEditor = async () => {
    await startDrawing(page, isMobile)
    measured = await box()
  }

  return {
    main,
    surface,
    page,
    isMobile,
    canvas,
    nameField,
    routerRequests,
    at,
    onPage,
    marker,
    points,
    settled,
    clickMap,
    enterEditor,
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
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { clickMap, points, settled, routerRequests, canvas } = planner
    // The bar above the map keeps its height when the first point fills it: the map is not
    // resized, so its content does not slide. Measured against the map's own container (the page
    // may scroll between the two measures), right after the first point.
    const frame = canvas.locator('xpath=ancestor::div[contains(@class,"maplibregl-map")][1]')
    // A bar that grows above the map shrinks the flex box the map fills: the heights catch it.
    const measure = async () => {
      const [c, f] = await Promise.all([canvas.boundingBox(), frame.boundingBox()])
      if (!c || !f) throw new Error('the planner map has no box')
      return { height: c.height, frameHeight: f.height }
    }
    const before = await measure()
    await clickMap(-120, 0)
    await expect(points(1)).toBeVisible()
    await settled()
    const after = await measure()
    expect(after.height, 'the map is not resized at the first point').toBe(before.height)
    expect(after.frameHeight, 'the map frame is not resized at the first point').toBe(
      before.frameHeight
    )
    await clickMap(0, 40)
    await expect(points(2)).toBeVisible()
    await settled()
    await clickMap(100, 0)
    await expect(points(3)).toBeVisible()
    await settled()
    expect(routerRequests, 'one routed segment per added point').toHaveLength(2)
    routerRequests.length = 0

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
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
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
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, surface, marker, points, settled, routerRequests } = planner
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
    await expect(surface.getByRole('button', { name: 'Point 4', exact: true })).toBeVisible()
    // The two halves of the cut segment: before the new point and after it. The click the mouse-up
    // ends with must not have added a point of its own (the operation lock drops it).
    expect(routerRequests).toHaveLength(2)
  })

  test('a right click deletes a point and reroutes around it', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
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
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, clickMap, points, settled } = planner
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
    // Under the map on a mouse, in the chip above the bottom bar on a finger.
    await expect(
      surface.getByText(
        "Le service d'itinéraires a atteint son quota mensuel. Réessayez plus tard."
      )
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
    const planner = await openPlanner({ context, page, isMobile })
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
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, surface, points, settled, routerRequests } = planner
    await drawThreePoints(planner)

    await p.keyboard.press('Control+z')
    await expect(points(2)).toBeVisible()
    await p.keyboard.press('Control+Shift+z')
    await expect(points(3)).toBeVisible()
    // The same, from the map's buttons.
    // « Annuler (Ctrl+Z) » on a mouse, where the form below has a plain « Annuler » of its own; on a
    // finger the bottom bar's button has no shortcut in its name.
    const shortcut = (label: string, keys: string) => (isMobile ? label : `${label} (${keys})`)
    await surface.getByRole('button', { name: shortcut('Annuler', 'Ctrl+Z'), exact: true }).click()
    await expect(points(2)).toBeVisible()
    await surface
      .getByRole('button', { name: shortcut('Rétablir', 'Ctrl+Maj+Z'), exact: true })
      .click()
    await expect(points(3)).toBeVisible()
    await settled()
    expect(routerRequests, 'history replays what it kept').toHaveLength(0)
  })

  test('Ctrl+Z in a text field edits the text and leaves the trace alone', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, main, nameField, points } = planner
    await drawThreePoints(planner)

    // On a finger the name is behind the editor: close it first. The map then stays mounted off
    // screen, and its shortcuts must stay silent — the form's text is not the trace's business.
    if (isMobile) {
      await planner.surface.getByRole('button', { name: 'Terminer' }).click()
      await expect(planner.surface).toBeHidden()
    }
    const traceStillThere = isMobile ? main.getByText('3 points', { exact: true }) : points(3)

    await nameField.click()
    await nameField.pressSequentially('Boucle du dimanche')
    await p.keyboard.press('Control+z')
    await expect(traceStillThere).toBeVisible()
    await p.keyboard.press('Control+Shift+z')
    await expect(traceStillThere).toBeVisible()
    // Not even a late undo: give the page a moment to (wrongly) react, then look again.
    await p.waitForTimeout(300)
    await expect(traceStillThere).toBeVisible()
  })
})

test.describe('the fullscreen editor, over the form', () => {
  test.setTimeout(90_000)

  test('a mouse enlarges the map in place: same points, same router bill, and shrinks it back', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a finger has no inline map to enlarge: covered by the other scenarios')
    const planner = await openPlanner({ context, page, isMobile })
    const { main, clickMap, marker, points, settled, routerRequests } = planner
    await clickMap(-100, 0)
    await expect(points(1)).toBeVisible()
    await clickMap(100, 30)
    await expect(points(2)).toBeVisible()
    await settled()
    expect(routerRequests).toHaveLength(1)

    await main.getByRole('button', { name: 'Agrandir' }).click()
    const dialog = page.getByRole('dialog', { name: 'Tracé', exact: true })
    await expect(dialog).toBeVisible()
    // The same map moved, not rebuilt: its points are all there, and nothing was asked of the router.
    await expect(dialog.getByRole('button', { name: 'Point 1', exact: true })).toBeVisible()
    await expect(dialog.getByRole('button', { name: 'Point 2', exact: true })).toBeVisible()
    await expect(dialog.getByText('2 points', { exact: true })).toBeVisible()
    expect(routerRequests).toHaveLength(1)

    await dialog.getByRole('button', { name: 'Terminer' }).first().click()
    await expect(dialog).toBeHidden()
    await expect(marker(1)).toBeVisible()
    await expect(marker(2)).toBeVisible()
    await expect(points(2)).toBeVisible()
    await settled()
    expect(routerRequests, 'opening and closing the editor never route').toHaveLength(1)
  })

  test('the back button closes the editor and forward reopens it; the form keeps its URL and its text', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile }, { enter: false })
    const { main, nameField, routerRequests } = planner
    const url = `${origin}/outils-gpx/nouveau`
    await nameField.fill('Sortie du soir')

    // A finger opens the editor from the preview, a mouse by enlarging the map.
    if (isMobile) await main.getByRole('button', { name: 'Tracer le parcours' }).click()
    else await main.getByRole('button', { name: 'Agrandir' }).click()
    const dialog = page.getByRole('dialog', { name: 'Sortie du soir', exact: true })
    await expect(dialog).toBeVisible()

    await page.goBack()
    await expect(dialog).toBeHidden()
    await expect(page).toHaveURL(url)
    await expect(nameField).toHaveValue('Sortie du soir')

    await page.goForward()
    await expect(dialog).toBeVisible()
    await expect(page).toHaveURL(url)

    // Closed again, a further back leaves the page as usual.
    await page.goBack()
    await expect(dialog).toBeHidden()
    await page.goBack()
    await expect(page).not.toHaveURL(url)
    expect(routerRequests).toHaveLength(0)
  })

  test('on a mouse, Escape closes an open map panel and never the editor', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'Escape is a keyboard matter')
    const { main } = await openPlanner({ context, page, isMobile })
    await main.getByRole('button', { name: 'Agrandir' }).click()
    const dialog = page.getByRole('dialog', { name: 'Tracé', exact: true })
    await expect(dialog).toBeVisible()

    await dialog.getByRole('button', { name: 'Aide : gestes' }).click()
    const help = page.getByText('Gestes du planificateur', { exact: true })
    await expect(help).toBeVisible()
    // The pointer still rests on the button, so its tooltip shows: one Escape is enough anyway.
    await page.keyboard.press('Escape')
    await expect(help).toBeHidden()
    await expect(dialog).toBeVisible()

    // Nothing else to close: Escape does not leave the editor (« Terminer » or back do).
    await page.keyboard.press('Escape')
    await page.waitForTimeout(300)
    await expect(dialog).toBeVisible()
  })

  test('on a finger, one map only, kept across closing and reopening, with its trace', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a finger-only layout')
    const planner = await openPlanner({ context, page, isMobile })
    const { main, surface, clickMap, marker, points, settled, routerRequests } = planner
    const canvases = page.locator('canvas.maplibregl-canvas')
    await expect(canvases).toHaveCount(1)

    await clickMap(-100, 0)
    await expect(points(1)).toBeVisible()
    await clickMap(100, 30)
    await expect(points(2)).toBeVisible()
    await settled()
    expect(routerRequests).toHaveLength(1)

    await surface.getByRole('button', { name: 'Terminer' }).click()
    await expect(surface).toBeHidden()
    // The form shows the still preview with the figures; the map waits off screen.
    await expect(main.getByTestId('planner-silhouette')).toBeVisible()
    await expect(main.getByText(/^\d+([.,]\d+)? km$/).first()).toBeVisible()
    await expect(canvases).toHaveCount(0)

    await main.getByRole('button', { name: 'Modifier le tracé' }).click()
    await expect(surface).toBeVisible()
    await expect(canvases).toHaveCount(1)
    await expect(marker(1)).toBeVisible()
    await expect(marker(2)).toBeVisible()
    expect(routerRequests, 'reopening the editor never routes').toHaveLength(1)
  })

  test('on a finger, the tools and the zoom buttons are at least 44 px', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a finger-only layout')
    const { surface, clickMap, points } = await openPlanner({ context, page, isMobile })
    await clickMap(0, 0)
    await expect(points(1)).toBeVisible()

    const targets = [
      surface.getByRole('button', { name: 'Annuler' }),
      surface.getByRole('button', { name: 'Rétablir' }),
      surface.getByRole('button', { name: 'Profil' }),
      surface.getByRole('button', { name: 'Aide : gestes' }),
      surface.getByRole('button', { name: 'Effacer' }),
      surface.getByRole('button', { name: 'Terminer' }),
      surface.getByRole('button', { name: 'Zoomer', exact: true }),
      surface.getByRole('button', { name: 'Dézoomer', exact: true }),
    ]
    for (const target of targets) {
      const box = await target.boundingBox()
      if (!box) throw new Error('a tool has no box')
      expect(box.width).toBeGreaterThanOrEqual(44)
      expect(box.height).toBeGreaterThanOrEqual(44)
    }
  })
})

test.describe('the fullscreen bar on a narrow phone', () => {
  test.setTimeout(90_000)

  test('« Terminer » fits in a 360 px wide screen', async ({ context, page, isMobile }) => {
    test.skip(!isMobile, 'a finger-only layout')
    await page.setViewportSize({ width: 360, height: 740 })
    const { surface, clickMap, points } = await openPlanner({ context, page, isMobile })
    await clickMap(0, 0)
    await expect(points(1)).toBeVisible()
    const done = await surface.getByRole('button', { name: 'Terminer' }).boundingBox()
    if (!done) throw new Error('« Terminer » has no box')
    expect(done.x).toBeGreaterThanOrEqual(0)
    expect(done.x + done.width).toBeLessThanOrEqual(360)
  })
})

test.describe('starting from a place', () => {
  test.setTimeout(90_000)

  /** Answers the place search (autocomplete, then the details of the chosen place) from the page. */
  async function stubGeocoding(page: Page, place: { lng: number; lat: number }) {
    const calls: string[] = []
    await page.route('https://api-eu.stadiamaps.com/geocoding/**', async (route) => {
      const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' }
      if (route.request().method() === 'OPTIONS') {
        return route.fulfill({ status: 204, headers: cors })
      }
      const url = route.request().url()
      calls.push(url)
      const properties = {
        gid: 'openstreetmap:venue:node/1',
        layer: 'venue',
        name: 'Vélodrome de test',
        precision: 'centroid',
        coarse_location: 'Paris, France',
      }
      const geometry = { type: 'Point', coordinates: [place.lng, place.lat] }
      await route.fulfill({
        headers: cors,
        json: {
          type: 'FeatureCollection',
          // The autocomplete has no geometry: the control then asks the details of the place.
          features: [
            url.includes('place_details')
              ? { type: 'Feature', properties, geometry }
              : { type: 'Feature', properties },
          ],
        },
      })
    })
    return calls
  }

  test('a found place offers « Démarrer ici »: the first point, no routing', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, points, marker, routerRequests } = planner
    await stubGeocoding(page, { lng: PLANNER_CENTER[0] + 0.02, lat: PLANNER_CENTER[1] + 0.01 })

    await surface.getByPlaceholder('Rechercher un lieu…').fill('velodrome')
    await surface.getByText('Vélodrome de test', { exact: true }).click()

    const startHere = surface.getByRole('button', { name: 'Démarrer ici' })
    await expect(startHere).toBeVisible()
    await startHere.click()
    await expect(points(1)).toBeVisible()
    await expect(marker(1)).toBeVisible()
    await expect(startHere).toHaveCount(0)
    expect(routerRequests, 'the first point needs no routing').toHaveLength(0)
  })

  test('« Ma position » offers « Démarrer ici » too', async ({ context, page, isMobile }) => {
    await context.grantPermissions(['geolocation'])
    await context.setGeolocation({ latitude: 48.86, longitude: 2.35 })
    const { surface, points, routerRequests } = await openPlanner({ context, page, isMobile })

    await surface.getByRole('button', { name: 'Me localiser' }).click()
    const startHere = surface.getByRole('button', { name: 'Démarrer ici' })
    await expect(startHere).toBeVisible()
    await startHere.click()
    await expect(points(1)).toBeVisible()
    expect(routerRequests).toHaveLength(0)
  })
})

test('opening a long preview for editing frames the whole track, on any screen', async ({
  context,
  page,
  isMobile,
}) => {
  test.setTimeout(90_000)
  const { owner } = await plannerSite()
  await signInPlanner(context)
  await stubBasemap(page)
  const routerRequests = await stubRouter(page)

  // 80 km of winding road: wider than any phone screen at the zoom the old heuristic picked.
  const name = unique('Long tracé')
  const preview = await onHost(PLANNER_HOST, owner, async (api) =>
    expectOk<GpxPreviewDto>(
      await api.post('/api/gpx-previews', {
        multipart: {
          gpxFile: {
            name: 'long.gpx',
            mimeType: 'application/gpx+xml',
            buffer: Buffer.from(gpxOf(name, windingTrack(1600))),
          },
        },
      })
    )
  )

  await page.goto(`${origin}/outils-gpx/${preview.id}/modifier`)
  const main = page.getByRole('main')
  const edit = main.getByRole('button', { name: 'Modifier le tracé' })
  if (isMobile) {
    await hydrated(edit)
    await edit.click()
  }
  const surface = editorOf(page, isMobile, name)
  const canvas = surface.locator('canvas.maplibregl-canvas').first()
  await expect(canvas).toBeVisible()
  const first = surface.getByRole('button', { name: 'Point 1', exact: true })
  await expect(first).toBeVisible()
  const last = surface.getByRole('button', { name: /^Point \d+$/ }).last()

  const frame = await canvas.boundingBox()
  if (!frame) throw new Error('the planner map has no box')
  for (const marker of [first, last]) {
    const box = await marker.boundingBox()
    if (!box) throw new Error('an end marker has no box')
    const [x, y] = [box.x + box.width / 2, box.y + box.height / 2]
    expect(x, 'inside the map, horizontally').toBeGreaterThan(frame.x)
    expect(x).toBeLessThan(frame.x + frame.width)
    expect(y, 'inside the map, vertically').toBeGreaterThan(frame.y)
    expect(y).toBeLessThan(frame.y + frame.height)
  }
  expect(routerRequests, 'framing a track asks nothing of the router').toHaveLength(0)
})
