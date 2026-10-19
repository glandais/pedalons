import { ErrorCode } from '../src/api/dto'
import type { ErrorResponse, GpxPreviewDto, RouterResponse } from '../src/api/dto'
import { expectOk } from './support/api'
import { newTeam, newUser, setTeamAttributes, signIn } from './support/data'
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
import type { BrowserContext, Locator, Page } from '@playwright/test'
import {
  gpxOf,
  newRoute,
  routePath,
  routerAnswer,
  stubBasemap,
  stubRouter,
  traceMapPixels,
  watchRouter,
  windingTrack,
  type GpxPoint,
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
  if (!isMobile) {
    const pointCount = main.getByText(/^Tracé de \d+ points$/)
    await expect(pointCount).toBeVisible()
    expect(Number((await pointCount.textContent())!.match(/\d+/)![0])).toBeGreaterThan(2)
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
  // The editing state goes with the name (the server derives the track from it), never the points
  const sent = savedResponse.request().postDataJSON() as {
    name: string
    points?: unknown
    plannerState?: {
      junctions: { kind: string }[]
      pieces: { mode: string; line?: string }[]
    }
  }
  expect(sent.name).toBe(name)
  expect(sent.points).toBeUndefined()
  expect(sent.plannerState?.junctions.map((j) => j.kind)).toEqual(['CONTROL', 'CONTROL'])
  expect(sent.plannerState?.pieces.map((piece) => piece.mode)).toEqual(['ROUTED'])
  expect(sent.plannerState?.pieces[0].line?.length).toBeGreaterThan(0)
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
const editorOf = (page: Page, isMobile: boolean, name?: string) =>
  isMobile
    ? // The editor is told by its map (its name follows the route's, which an import can set)
      name === undefined
      ? page.getByRole('dialog').filter({ has: page.locator('canvas.maplibregl-canvas') })
      : page.getByRole('dialog', { name, exact: true })
    : page.getByRole('main')

/** Opens the fullscreen editor from the form on a finger; on a mouse the map is already in the page. */
async function startDrawing(page: Page, isMobile: boolean) {
  const main = page.getByRole('main')
  if (!isMobile) return main
  // Nothing of the map is built until the editor is opened.
  await expect(main.locator('canvas.maplibregl-canvas')).toHaveCount(0)
  // « Modifier le tracé » once an import has given the form a track
  const draw = main.getByRole('button', { name: /^(Tracer le parcours|Modifier le tracé)$/ })
  await hydrated(draw)
  await draw.click()
  const dialog = editorOf(page, isMobile)
  await expect(dialog).toBeVisible()
  return dialog
}

/**
 * Accessible name of the n-th control point: « Point 2 sur 3 », the start and the finish told in
 * words (« Départ, point 1 sur 3 », « Arrivée, point 3 sur 3 »).
 */
const markerName = (n: number) => new RegExp(`^(?:(?:Départ|Arrivée), p|P)oint ${n} sur \\d+$`)

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
  const marker = (n: number) => surface.getByRole('button', { name: markerName(n) })
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

  // A finger press, a drag, a lift: raw touch events (Playwright can only tap).
  const cdp = await context.newCDPSession(page)
  const touch = (type: 'touchStart' | 'touchMove' | 'touchEnd', at?: { x: number; y: number }) =>
    cdp.send('Input.dispatchTouchEvent', { type, touchPoints: at ? [at] : [] })

  return {
    main,
    surface,
    page,
    isMobile,
    canvas,
    touch,
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
  const legs = [...routerRequests]
  routerRequests.length = 0
  return legs
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
    const { page: p, marker, points, settled, routerRequests } = planner
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
    await expect(marker(4)).toBeVisible()
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

  test('one tap on the trace inserts a point (touch), with no ghost to tap a second time', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a tap is a touch gesture: covered by the mobile project')
    const planner = await openPlanner({ context, page, isMobile })
    const { marker, points, settled, routerRequests } = planner
    await drawThreePoints(planner)

    const centre = async (n: number) => {
      const b = await marker(n).boundingBox()
      if (!b) throw new Error(`marker ${n} has no box`)
      return { x: b.x + b.width / 2, y: b.y + b.height / 2 }
    }
    const [first, second] = [await centre(1), await centre(2)]
    // Safari's sequence for a tap, which Chromium's own tap does not reproduce: touch pointer
    // events, then a compatibility mousemove and mouse button events, and a click that carries no
    // pointer type. That mousemove used to show the mouse's ghost point, the click then bailed
    // out, and a second tap, on the ghost, was needed to insert (seen on an iPhone).
    await page.evaluate(
      async ({ x, y }) => {
        const target = document.elementFromPoint(x, y)
        if (!target) throw new Error('nothing under the tap')
        const at = { clientX: x, clientY: y, bubbles: true, cancelable: true, view: window }
        const touch = { ...at, pointerId: 7, pointerType: 'touch', isPrimary: true }
        target.dispatchEvent(new PointerEvent('pointerdown', touch))
        target.dispatchEvent(new PointerEvent('pointerup', touch))
        target.dispatchEvent(new MouseEvent('mousemove', at))
        // Safari sends the click a moment later: long enough for React to render what the move did.
        await new Promise((resolve) => setTimeout(resolve, 50))
        target.dispatchEvent(new MouseEvent('mousedown', { ...at, button: 0, buttons: 1 }))
        target.dispatchEvent(new MouseEvent('mouseup', { ...at, button: 0 }))
        target.dispatchEvent(new MouseEvent('click', { ...at, button: 0, detail: 1 }))
      },
      { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 }
    )

    await settled()
    await expect(points(4)).toBeVisible()
    await expect(marker(4)).toBeVisible()
    expect(routerRequests, 'the cut segment, before and after the new point').toHaveLength(2)
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

/** The « Ligne droite » toggle: the bar's button on a finger, the map's control on a mouse. */
const directToggle = (page: Page, isMobile: boolean) =>
  isMobile
    ? page.getByRole('dialog').getByRole('button', { name: 'Ligne droite', exact: true })
    : page.getByRole('button', { name: /^Ligne droite \(ou /, exact: false })

/** The non-blocking warning about a long straight leg, in the form. */
const directWarning = (page: Page) =>
  page.getByRole('main').getByText(/en ligne droite \(pointillés\)/)

test.describe('straight lines, visible (B6)', () => {
  test.setTimeout(90_000)

  test('the toggle draws without the router, and warns about a long straight leg', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, clickMap, points, settled, routerRequests } = planner
    const toggle = directToggle(page, isMobile)

    await clickMap(-120, 0)
    await expect(points(1)).toBeVisible()
    await expect(toggle).toHaveAttribute('aria-pressed', 'false')
    await toggle.click()
    await expect(toggle).toHaveAttribute('aria-pressed', 'true')
    await clickMap(0, 60)
    await expect(points(2)).toBeVisible()
    await settled()
    await clickMap(100, 0)
    await expect(points(3)).toBeVisible()
    await settled()
    expect(routerRequests, 'straight-line mode never asks the router').toHaveLength(0)

    await toggle.click()
    await expect(toggle).toHaveAttribute('aria-pressed', 'false')
    await clickMap(60, -80)
    await expect(points(4)).toBeVisible()
    await settled()
    expect(routerRequests, 'back to routing').toHaveLength(1)

    if (isMobile) {
      await surface.getByRole('button', { name: 'Terminer' }).click()
      await expect(surface).toBeHidden()
    }
    await expect(directWarning(page)).toBeVisible()
  })

  test('the toggle survives the move of the map between the form and the editor', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { main, surface, clickMap, points, settled, routerRequests } = planner
    const toggle = directToggle(page, isMobile)
    await clickMap(-120, 0)
    await expect(points(1)).toBeVisible()
    await toggle.click()
    await expect(toggle).toHaveAttribute('aria-pressed', 'true')

    if (isMobile) {
      await surface.getByRole('button', { name: 'Terminer' }).click()
      await expect(surface).toBeHidden()
      await main.getByRole('button', { name: 'Modifier le tracé' }).click()
      await expect(surface).toBeVisible()
    } else {
      await main.getByRole('button', { name: 'Agrandir' }).click()
      const dialog = page.getByRole('dialog', { name: 'Tracé', exact: true })
      await expect(dialog).toBeVisible()
      await expect(toggle).toHaveAttribute('aria-pressed', 'true')
      await dialog.getByRole('button', { name: 'Terminer' }).first().click()
      await expect(dialog).toBeHidden()
    }
    await expect(toggle).toHaveAttribute('aria-pressed', 'true')

    await clickMap(100, 40)
    await expect(points(2)).toBeVisible()
    await settled()
    expect(routerRequests).toHaveLength(0)
  })

  test('deleting a point between two straight legs asks nothing of the router', async ({
    context,
    page,
    isMobile,
  }) => {
    const { marker, clickMap, points, settled, routerRequests } = await openPlanner({
      context,
      page,
      isMobile,
    })
    const toggle = directToggle(page, isMobile)
    await clickMap(-120, 0)
    await expect(points(1)).toBeVisible()
    await toggle.click()
    await clickMap(0, 40)
    await expect(points(2)).toBeVisible()
    await settled()
    await clickMap(100, 0)
    await expect(points(3)).toBeVisible()
    await settled()
    await toggle.click()
    await expect(toggle).toHaveAttribute('aria-pressed', 'false')

    // Neither the key nor the toggle: the legs it replaces are all straight
    await marker(2).click({ button: 'right' })
    await settled()
    await expect(points(2)).toBeVisible()
    await expect(marker(3)).toHaveCount(0)
    expect(routerRequests).toHaveLength(0)
  })

  test('undo and redo bring a straight line back and take it away, with no request', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'the keyboard shortcuts of a mouse')
    const planner = await openPlanner({ context, page, isMobile })
    const { clickMap, points, settled, routerRequests } = planner
    await drawThreePoints(planner)

    await clickMap(-130, 90, ['Alt'])
    await expect(points(4)).toBeVisible()
    await settled()
    await expect(directWarning(page)).toBeVisible()

    await page.keyboard.press('Control+z')
    await expect(points(3)).toBeVisible()
    await expect(directWarning(page)).toBeHidden()
    await page.keyboard.press('Control+Shift+z')
    await expect(points(4)).toBeVisible()
    await expect(directWarning(page)).toBeVisible()
    expect(routerRequests).toHaveLength(0)
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
    await expect(dialog.getByRole('button', { name: markerName(1) })).toBeVisible()
    await expect(dialog.getByRole('button', { name: markerName(2) })).toBeVisible()
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
      surface.getByRole('button', { name: 'Ligne droite', exact: true }),
      surface.getByRole('button', { name: 'Profil' }),
      surface.getByRole('button', { name: 'Aide : gestes' }),
      // In the toolbar above the map, out of the bar (no room left for it at 360 px)
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

  test('« Me localiser » is a toggle: a second click hides the position without moving the map', async ({
    context,
    page,
    isMobile,
  }) => {
    await context.grantPermissions(['geolocation'])
    await context.setGeolocation({ latitude: 48.86, longitude: 2.35 })
    const { surface } = await openPlanner({ context, page, isMobile })
    const locate = surface.getByRole('button', { name: 'Me localiser' })
    const dot = surface.locator('.maplibregl-user-location-dot')

    await locate.click()
    await expect(dot).toBeVisible()
    await expect(locate).toHaveAttribute('aria-pressed', 'true')
    const startHere = surface.getByRole('button', { name: 'Démarrer ici' })
    await expect(startHere).toBeVisible()

    // Pan away from the position: a click that flew back would carry the popup along.
    const located = await startHere.boundingBox()
    await surface.locator('canvas.maplibregl-canvas').first().focus()
    await page.keyboard.press('ArrowRight')
    await page.keyboard.press('ArrowDown')
    await page.waitForTimeout(500) // the keyboard pan eases
    const before = await startHere.boundingBox()
    expect(before, 'the keyboard pan moved the map').not.toEqual(located)

    await locate.click()
    await expect(dot).toHaveCount(0)
    await expect(locate).toHaveAttribute('aria-pressed', 'false')
    await page.waitForTimeout(500)
    expect(await startHere.boundingBox()).toEqual(before)
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
  const first = surface.getByRole('button', { name: markerName(1) })
  await expect(first).toBeVisible()
  const last = surface.getByRole('button', { name: /point \d+ sur \d+$/i }).last()

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

/**
 * A loaded track shaped like an L, opened in the planner: 3 km east, then 3 km north, its corner an
 * anchor (one of the small white points a loaded track is pinned by) drawn where the end's x meets
 * the start's y. The corner is about 2 121 m off the straight line from the start to the end, so
 * it shows from zoom 11, within the frame of the whole track. The router is simulated and counted.
 */
async function openLTrack({
  context,
  page,
  isMobile,
  elevation = () => 150,
}: {
  context: BrowserContext
  page: Page
  isMobile: boolean
  /** Elevation of the i-th of the 121 points of the track (default: flat). */
  elevation?: (i: number) => number
}) {
  test.setTimeout(90_000)
  const { owner } = await plannerSite()
  await signInPlanner(context)
  await stubBasemap(page)
  const routerRequests = await stubRouter(page)

  const [lat0, lon0] = [48.4469, 1.4875]
  const perLat = 111_320
  const perLon = perLat * Math.cos((lat0 * Math.PI) / 180)
  const leg = Array.from({ length: 61 }, (_, i) => i * 50)
  const track: [number, number, number][] = [
    ...leg.map((east): [number, number, number] => [lat0, lon0 + east / perLon, 0]),
    ...leg
      .slice(1)
      .map((north): [number, number, number] => [lat0 + north / perLat, lon0 + 3000 / perLon, 0]),
  ].map(([lat, lon], i): [number, number, number] => [lat, lon, elevation(i)])
  const name = unique('Tracé en L')
  const preview = await onHost(PLANNER_HOST, owner, async (api) =>
    expectOk<GpxPreviewDto>(
      await api.post('/api/gpx-previews', {
        multipart: {
          gpxFile: {
            name: 'l.gpx',
            mimeType: 'application/gpx+xml',
            buffer: Buffer.from(gpxOf(name, track)),
          },
        },
      })
    )
  )

  await page.goto(`${origin}/outils-gpx/${preview.id}/modifier`)
  // A finger opens the editor from the form, a mouse already has the map in the page.
  if (isMobile) {
    const edit = page.getByRole('main').getByRole('button', { name: 'Modifier le tracé' })
    await hydrated(edit)
    await edit.click()
  }
  const surface = editorOf(page, isMobile, name)
  const marker = (n: number) => surface.getByRole('button', { name: markerName(n) })
  await expect(marker(2)).toBeVisible()
  await expect(marker(3)).toHaveCount(0)
  // On a mouse the map sits in the form, below the fold of a 1280x720 window: raw mouse and touch
  // events land where they are told, never scrolling, so the map is brought into view first.
  const canvas = surface.locator('canvas.maplibregl-canvas').first()
  await canvas.evaluate((el) => el.scrollIntoView({ block: 'center', inline: 'center' }))
  const centre = async (n: number) => {
    const b = await marker(n).boundingBox()
    if (!b) throw new Error(`marker ${n} has no box`)
    return { x: b.x + b.width / 2, y: b.y + b.height / 2 }
  }
  const [start, end] = [await centre(1), await centre(2)]
  const corner = { x: end.x, y: start.y }
  const viewport = page.viewportSize()
  if (!viewport) throw new Error('the page has no viewport')
  for (const p of [start, end, corner]) {
    expect(p.x, 'the L is inside the window').toBeGreaterThan(0)
    expect(p.x).toBeLessThan(viewport.width)
    expect(p.y, 'the L is inside the window').toBeGreaterThan(0)
    expect(p.y).toBeLessThan(viewport.height)
  }
  const settled = async () => {
    await expect(surface.getByRole('status', { name: "Calcul de l'itinéraire..." })).toHaveCount(0)
  }

  // A finger press, a drag, a lift: raw touch events (Playwright can only tap).
  const cdp = await context.newCDPSession(page)
  const touch = (type: 'touchStart' | 'touchMove' | 'touchEnd', at?: { x: number; y: number }) =>
    cdp.send('Input.dispatchTouchEvent', { type, touchPoints: at ? [at] : [] })

  return {
    page,
    isMobile,
    preview,
    surface,
    canvas,
    cdp,
    marker,
    centre,
    corner,
    start,
    end,
    settled,
    routerRequests,
    startLonLat: [lon0, lat0] as const,
    endLonLat: [lon0 + 3000 / perLon, lat0 + 3000 / perLat] as const,
    touch,
  }
}

test('a finger drags an anchor of a loaded track: the trace is routed again through it', async ({
  context,
  page,
  isMobile,
}) => {
  test.skip(!isMobile, 'a finger gesture: covered by the mobile project')
  const { marker, centre, corner, start, touch, routerRequests } = await openLTrack({
    context,
    page,
    isMobile,
  })
  const drop = { x: corner.x - 60, y: corner.y - 60 }

  await touch('touchStart', corner)
  for (let i = 1; i <= 8; i++) {
    await touch('touchMove', {
      x: corner.x + ((drop.x - corner.x) * i) / 8,
      y: corner.y + ((drop.y - corner.y) * i) / 8,
    })
  }
  await touch('touchEnd')

  // The corner is now a control point of its own, between the two ends: the two segments on
  // either side of it are routed, and the map did not pan under the finger.
  await expect(marker(3)).toBeVisible()
  await expect.poll(() => routerRequests.length).toBe(2)
  const moved = await centre(2)
  expect(Math.abs(moved.x - drop.x), 'the new point is where the finger lifted').toBeLessThan(20)
  expect(Math.abs(moved.y - drop.y)).toBeLessThan(20)
  const startAfter = await centre(1)
  expect(Math.abs(startAfter.x - start.x), 'the map did not pan').toBeLessThan(2)
})

test.describe('deleting an anchor of a loaded track', () => {
  test.setTimeout(90_000)

  const DELETE = 'Supprimer le point'

  test('a right click on the corner offers to delete it: one request, from the start to the end', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a mouse gesture: the finger has its own long press')
    const l = await openLTrack({ context, page, isMobile })
    const { marker, corner, routerRequests, settled, startLonLat, endLonLat } = l

    await page.mouse.click(corner.x, corner.y, { button: 'right' })
    const item = page.getByRole('menuitem', { name: DELETE })
    await expect(item).toBeVisible()
    // The two points the trace would be routed between, joined while the menu is open.
    await expect(page.getByTestId('planner-bound')).toHaveCount(2)

    await item.click()
    await settled()
    expect(routerRequests, 'one segment from the start to the end').toHaveLength(1)
    expect(routerRequests[0].from.lng).toBeCloseTo(startLonLat[0], 4)
    expect(routerRequests[0].from.lat).toBeCloseTo(startLonLat[1], 4)
    expect(routerRequests[0].to.lng).toBeCloseTo(endLonLat[0], 4)
    expect(routerRequests[0].to.lat).toBeCloseTo(endLonLat[1], 4)
    await expect(marker(2)).toBeVisible()
    await expect(marker(3)).toHaveCount(0)

    // The new trace is routed, not loaded: a right click on it offers nothing, nor does a click
    // far from any trace.
    const sample = routerAnswer({
      from: { lng: startLonLat[0], lat: startLonLat[1] },
      to: { lng: endLonLat[0], lat: endLonLat[1] },
    } as Parameters<typeof routerAnswer>[0]).route.coordinates[6]
    const [s, e] = [await l.centre(1), await l.centre(2)]
    const pxPerLon = (e.x - s.x) / (endLonLat[0] - startLonLat[0])
    const pxPerLat = (e.y - s.y) / (endLonLat[1] - startLonLat[1])
    const onTrace = {
      x: s.x + (sample[0] - startLonLat[0]) * pxPerLon,
      y: s.y + (sample[1] - startLonLat[1]) * pxPerLat,
    }
    await page.mouse.click(onTrace.x, onTrace.y, { button: 'right' })
    await page.mouse.click(s.x, e.y, { button: 'right' })
    await page.waitForTimeout(300)
    await expect(page.getByRole('menuitem', { name: DELETE })).toHaveCount(0)
    expect(routerRequests).toHaveLength(1)
  })

  test('Alt + right click deletes the corner in a straight line: no request', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a mouse gesture')
    const { corner, routerRequests, settled } = await openLTrack({ context, page, isMobile })

    await page.keyboard.down('Alt')
    await page.mouse.click(corner.x, corner.y, { button: 'right' })
    await page.keyboard.up('Alt')
    await page.getByRole('menuitem', { name: DELETE }).click()
    await settled()
    expect(routerRequests, 'a straight line is never routed').toHaveLength(0)

    await page.mouse.click(corner.x, corner.y, { button: 'right' })
    await page.waitForTimeout(300)
    await expect(page.getByRole('menuitem', { name: DELETE })).toHaveCount(0)
  })

  test('a long press on the corner opens its menu, and lifting the finger inserts nothing', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a finger gesture')
    const { marker, corner, touch, routerRequests, settled } = await openLTrack({
      context,
      page,
      isMobile,
    })

    await touch('touchStart', corner)
    await page.waitForTimeout(800) // the menu opens after 500 ms without movement
    await touch('touchEnd')

    const item = page.getByRole('menuitem', { name: DELETE })
    await expect(item).toBeVisible()
    await page.waitForTimeout(900) // past the grace in which a synthesised click is ignored
    await expect(item).toBeVisible()
    await expect(page.getByTestId('planner-bound')).toHaveCount(2)
    await expect(marker(3)).toHaveCount(0)
    expect(routerRequests, 'the release inserted no point').toHaveLength(0)

    await item.click()
    await settled()
    expect(routerRequests).toHaveLength(1)
  })

  test('a press that moves is a drag, not a long press', async ({ context, page, isMobile }) => {
    test.skip(!isMobile, 'a finger gesture')
    const { marker, corner, touch, routerRequests } = await openLTrack({
      context,
      page,
      isMobile,
    })
    const drop = { x: corner.x - 60, y: corner.y - 60 }

    // 4 px: past the drag's tolerance (3 px), within the browser's slop (its touchmove is held
    // back, the pointermove is not). Sent at once: the press redraws the map, and on a busy machine
    // a move sent later can reach the page after the 500 ms of the long press.
    await touch('touchStart', corner)
    await touch('touchMove', { x: corner.x + 4, y: corner.y })
    await page.waitForTimeout(700)
    await expect(page.getByRole('menuitem', { name: DELETE })).toHaveCount(0)
    for (let i = 1; i <= 8; i++) {
      await touch('touchMove', {
        x: corner.x + ((drop.x - corner.x) * i) / 8,
        y: corner.y + ((drop.y - corner.y) * i) / 8,
      })
    }
    await touch('touchEnd')

    await expect(marker(3)).toBeVisible()
    await expect.poll(() => routerRequests.length).toBe(2)
  })

  test('deleting after zooming in routes between the neighbours, never around a routed anchor', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a mouse gesture')
    const planner = await openPlanner({ context, page, isMobile })
    const { marker, settled, routerRequests } = planner
    const legs = await drawThreePoints(planner)

    // The simulated router bows its segments: their routed anchors show from zoom 14, and the old
    // bounds (the nearest visible anchors) stopped there instead of at the markers.
    const where = async () => {
      const b = await marker(2).boundingBox()
      if (!b) throw new Error('the second marker has no box')
      return { x: b.x + b.width / 2, y: b.y + b.height / 2 }
    }
    // The map opens at zoom 9: each zoom level doubles the distance between two markers on screen.
    const gap = async () => {
      const [a, b] = await Promise.all([marker(1).boundingBox(), marker(2).boundingBox()])
      if (!a || !b) throw new Error('a marker has no box')
      return Math.hypot(a.x - b.x, a.y - b.y)
    }
    const initialGap = await gap()
    const at = await where()
    await page.mouse.move(at.x, at.y)
    for (let i = 0; i < 40 && (await gap()) < initialGap * 2 ** 5; i++) {
      await page.mouse.wheel(0, -500)
      await page.waitForTimeout(100)
    }
    // The zoom eases: wait for the marker to stop moving.
    let previous = await marker(2).boundingBox()
    await expect
      .poll(async () => {
        const now = await marker(2).boundingBox()
        const still = JSON.stringify(now) === JSON.stringify(previous)
        previous = now
        return still
      })
      .toBe(true)
    // The precondition: zoom 14 or more, where the routed anchors show (and the old bounds broke)
    expect(await gap(), 'zoomed in to level 14').toBeGreaterThanOrEqual(initialGap * 2 ** 5)

    await marker(2).click({ button: 'right' })
    await settled()
    expect(routerRequests, 'one segment joins the neighbours').toHaveLength(1)
    expect(routerRequests[0].from.lng).toBeCloseTo(legs[0].from.lng, 6)
    expect(routerRequests[0].from.lat).toBeCloseTo(legs[0].from.lat, 6)
    expect(routerRequests[0].to.lng).toBeCloseTo(legs[1].to.lng, 6)
    expect(routerRequests[0].to.lat).toBeCloseTo(legs[1].to.lat, 6)
  })

  test('undoing a deleted corner brings it back without a request', async ({
    context,
    page,
    isMobile,
  }) => {
    const { surface, corner, touch, routerRequests, settled } = await openLTrack({
      context,
      page,
      isMobile,
    })
    const item = page.getByRole('menuitem', { name: DELETE })
    const openMenu = async () => {
      if (isMobile) {
        await touch('touchStart', corner)
        await page.waitForTimeout(800)
        await touch('touchEnd')
      } else {
        await page.mouse.click(corner.x, corner.y, { button: 'right' })
      }
      await expect(item).toBeVisible()
    }

    await openMenu()
    await item.click()
    await settled()
    expect(routerRequests).toHaveLength(1)

    const shortcut = (label: string, keys: string) => (isMobile ? label : `${label} (${keys})`)
    await surface.getByRole('button', { name: shortcut('Annuler', 'Ctrl+Z'), exact: true }).click()
    await settled()
    expect(routerRequests, 'history replays what it kept').toHaveLength(1)

    // The anchor is back: its menu opens again.
    await openMenu()
    await page.keyboard.press('Escape')
    await expect(item).toHaveCount(0)
    expect(routerRequests).toHaveLength(1)
  })
})

test.describe('elevation profile while editing (B1)', () => {
  test.setTimeout(90_000)

  /** The planner's D+, as the status shows it (the chip on a finger, the bar on a mouse). */
  const ascendOf = (page: Page, text: string) => page.getByText(text, { exact: true }).first()
  const strip = (page: Page) => page.getByTestId('planner-elevation-strip').first()

  test('the D+ is the routers: +100 m for two legs, +150 m for a third', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { clickMap, points, settled, routerRequests } = planner
    await clickMap(-120, 0)
    await expect(points(1)).toBeVisible()
    await clickMap(0, 40)
    await expect(points(2)).toBeVisible()
    await settled()
    await clickMap(100, 0)
    await expect(points(3)).toBeVisible()
    await settled()
    await expect(ascendOf(page, '+100 m')).toBeVisible()
    expect(routerRequests).toHaveLength(2)

    await clickMap(130, 60)
    await expect(points(4)).toBeVisible()
    await settled()
    await expect(ascendOf(page, '+150 m')).toBeVisible()
    expect(routerRequests).toHaveLength(3)
  })

  test('a straight line after a routed leg leaves the D+ as it was and costs no request', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { clickMap, points, settled, routerRequests } = planner
    await drawThreePoints(planner)
    await expect(ascendOf(page, '+100 m')).toBeVisible()

    const toggle = directToggle(page, isMobile)
    await toggle.click()
    await expect(toggle).toHaveAttribute('aria-pressed', 'true')
    await clickMap(130, 60)
    await expect(points(4)).toBeVisible()
    await settled()
    // The straight line ends past the last elevation known: nothing climbed
    await expect(ascendOf(page, '+100 m')).toBeVisible()
    expect(routerRequests).toHaveLength(0)
  })

  test('undoing a point brings the previous D+ back, with no request', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, points, settled, routerRequests } = planner
    await drawThreePoints(planner)
    await expect(ascendOf(page, '+100 m')).toBeVisible()
    const shortcut = (label: string, keys: string) => (isMobile ? label : `${label} (${keys})`)
    await surface.getByRole('button', { name: shortcut('Annuler', 'Ctrl+Z'), exact: true }).click()
    await settled()
    await expect(points(2)).toBeVisible()
    await expect(ascendOf(page, '+50 m')).toBeVisible()
    expect(routerRequests).toHaveLength(0)
  })

  test('hovering the profile shows its point on the map, and the map still takes a click after', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a mouse hover')
    const planner = await openPlanner({ context, page, isMobile })
    const { clickMap, points, settled } = planner
    await drawThreePoints(planner)
    const marker = page.getByTestId('planner-hover-marker')
    await expect(marker).toHaveCount(0)

    await strip(page).scrollIntoViewIfNeeded()
    const box = await strip(page).boundingBox()
    if (!box) throw new Error('the elevation strip has no box')
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2)
    await page.mouse.move(box.x + box.width / 2 + 5, box.y + box.height / 2)
    await expect(marker).toBeVisible()

    await page.mouse.move(box.x + box.width / 2, box.y - 400)
    await expect(marker).toHaveCount(0)

    await clickMap(130, 60)
    await expect(points(4)).toBeVisible()
    await settled()
  })

  test('on a finger the profile sits above the bar, folds and unfolds, and the map keeps its room', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a finger-only layout')
    await page.setViewportSize({ width: 360, height: 640 })
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, canvas, clickMap, points, settled } = planner
    await clickMap(-60, 0)
    await expect(points(1)).toBeVisible()
    await clickMap(40, 40)
    await expect(points(2)).toBeVisible()
    await settled()

    const fold = surface.getByRole('button', { name: "Replier le graphe d'altitude" })
    await expect(strip(page)).toBeVisible()
    const stripBox = await strip(page).boundingBox()
    const undo = await surface.getByRole('button', { name: 'Annuler' }).boundingBox()
    if (!stripBox || !undo) throw new Error('missing box')
    expect(stripBox.y + stripBox.height, 'the profile is above the bar').toBeLessThanOrEqual(
      undo.y + 1
    )
    await expect(surface.getByRole('button', { name: 'Terminer' })).toBeVisible()
    const mapOpen = await canvas.boundingBox()
    expect(mapOpen!.height, 'the map keeps room with the profile open').toBeGreaterThanOrEqual(200)

    await fold.click()
    const unfold = surface.getByRole('button', { name: "Déplier le graphe d'altitude" })
    await expect(unfold).toBeVisible()
    // The canvas resizes on a later frame (map.resize from its ResizeObserver)
    await expect
      .poll(async () => (await canvas.boundingBox())!.height)
      .toBeGreaterThan(mapOpen!.height)
    await unfold.click()
    await expect(fold).toBeVisible()
  })

  test('a reopened track starts at the stored D+, and deleting its corner counts the new leg', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a mouse gesture: the finger has its own long press')
    // 100 m -> 200 m east, then 200 m -> 230 m north
    const { preview, corner, settled, routerRequests } = await openLTrack({
      context,
      page,
      isMobile,
      elevation: (i) => (i <= 60 ? 100 + (100 * i) / 60 : 200 + (30 * (i - 60)) / 60),
    })
    await expect(ascendOf(page, `+${Math.round(preview.elevationGain)} m`)).toBeVisible()

    await page.mouse.click(corner.x, corner.y, { button: 'right' })
    await page.getByRole('menuitem', { name: 'Supprimer le point' }).click()
    await settled()
    expect(routerRequests).toHaveLength(1)
    // Both ends are bounds: only the new leg (the stub's +50 m) is left
    await expect(ascendOf(page, '+50 m')).toBeVisible()
  })
})

type Planner = Awaited<ReturnType<typeof openPlanner>>

/** Centre of the n-th marker, in page coordinates. */
async function centreOf(planner: Planner, n: number) {
  const b = await planner.marker(n).boundingBox()
  if (!b) throw new Error(`marker ${n} has no box`)
  return { x: b.x + b.width / 2, y: b.y + b.height / 2 }
}

/** The same, from the top-left corner of the map: immune to the page scrolling between two reads. */
async function inMap(planner: Planner, n: number) {
  const [c, frame] = [await centreOf(planner, n), await planner.canvas.boundingBox()]
  if (!frame) throw new Error('the planner map has no box')
  return { x: c.x - frame.x, y: c.y - frame.y }
}

test.describe('keyboard and accessibility of the points (B7)', () => {
  test.setTimeout(90_000)

  test('the points are named “Point n sur m”, start and finish in words and in shape', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a keyboard matter')
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, clickMap, points } = planner

    await clickMap(-120, 0)
    await expect(points(1)).toBeVisible()
    await expect(
      surface.getByRole('button', { name: 'Départ, point 1 sur 1', exact: true })
    ).toBeVisible()

    await clickMap(0, 40)
    await planner.settled()
    await clickMap(100, 0)
    await expect(points(3)).toBeVisible()
    await planner.settled()
    await expect(
      surface.getByRole('button', { name: 'Départ, point 1 sur 3', exact: true })
    ).toBeVisible()
    await expect(surface.getByRole('button', { name: 'Point 2 sur 3', exact: true })).toBeVisible()
    await expect(
      surface.getByRole('button', { name: 'Arrivée, point 3 sur 3', exact: true })
    ).toBeVisible()
    // The start and the finish carry an icon, a via point is a plain disc
    await expect(planner.marker(1).locator('svg')).toHaveCount(1)
    await expect(planner.marker(2).locator('svg')).toHaveCount(0)
    await expect(planner.marker(3).locator('svg')).toHaveCount(1)
  })

  test('arrows move the focused point and route once, on release: two requests, one undo', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a keyboard matter')
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, marker, canvas, settled, routerRequests } = planner
    await drawThreePoints(planner)
    await canvas.evaluate((el) => el.scrollIntoView({ block: 'center', inline: 'center' }))

    const [first0, second0] = [await inMap(planner, 1), await inMap(planner, 2)]
    await marker(2).focus()
    for (let i = 0; i < 5; i++) await p.keyboard.press('ArrowRight')
    // Nothing is routed while the arrows come; one burst, two requests (both neighbours)
    await expect.poll(() => routerRequests.length).toBe(2)
    await settled()
    // The stub puts the routed point exactly where it was asked to
    const second1 = await inMap(planner, 2)
    expect(Math.abs(second1.x - second0.x - 50)).toBeLessThan(3)
    expect(Math.abs(second1.y - second0.y)).toBeLessThan(3)
    // The arrows did not pan the map: MapLibre never saw them
    const first1 = await inMap(planner, 1)
    expect(Math.abs(first1.x - first0.x)).toBeLessThan(2)
    expect(Math.abs(first1.y - first0.y)).toBeLessThan(2)
    await expect(marker(2)).toBeFocused()

    // Shift: five times further
    await p.keyboard.down('Shift')
    await p.keyboard.press('ArrowDown')
    await p.keyboard.press('ArrowDown')
    await p.keyboard.up('Shift')
    await expect.poll(() => routerRequests.length).toBe(4)
    await settled()
    const second2 = await inMap(planner, 2)
    expect(Math.abs(second2.y - second1.y - 100)).toBeLessThan(3)

    // A key held down is one burst, however many repeats it sends
    for (let i = 0; i < 4; i++) await p.keyboard.down('ArrowLeft')
    await p.keyboard.up('ArrowLeft')
    await expect.poll(() => routerRequests.length).toBe(6)
    await settled()
    expect(routerRequests).toHaveLength(6)
    const second3 = await inMap(planner, 2)
    expect(Math.abs(second3.x - second2.x + 40)).toBeLessThan(3)

    // One undo gives the last burst back, with no request, and the focus stays on a point
    await p.keyboard.press('Control+z')
    await expect.poll(async () => Math.abs((await inMap(planner, 2)).x - second2.x)).toBeLessThan(3)
    expect(routerRequests).toHaveLength(6)
    await expect(planner.surface.locator('[data-planner-index]:focus')).toHaveCount(1)
  })

  test('moving the start by keyboard costs one request', async ({ context, page, isMobile }) => {
    test.skip(isMobile, 'a keyboard matter')
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, marker, routerRequests, settled } = planner
    await drawThreePoints(planner)

    await marker(1).focus()
    for (let i = 0; i < 3; i++) await p.keyboard.press('ArrowUp')
    await expect.poll(() => routerRequests.length).toBe(1)
    await settled()
    expect(routerRequests).toHaveLength(1)
  })

  test('Escape abandons a keyboard move, a ghost drag and a marker drag, with no request', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a keyboard matter')
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, marker, points, canvas, settled, routerRequests } = planner
    await drawThreePoints(planner)
    await canvas.evaluate((el) => el.scrollIntoView({ block: 'center', inline: 'center' }))

    // A burst of arrows
    const origin = await inMap(planner, 2)
    await marker(2).focus()
    for (let i = 0; i < 3; i++) await p.keyboard.press('ArrowRight')
    await p.keyboard.press('Escape')
    // Absence of a deferred commit: only waiting proves it
    await p.waitForTimeout(800)
    expect(routerRequests).toHaveLength(0)
    const back = await inMap(planner, 2)
    expect(Math.abs(back.x - origin.x)).toBeLessThan(2)
    expect(Math.abs(back.y - origin.y)).toBeLessThan(2)
    await expect(marker(2)).toBeFocused()

    // The ghost point dragged out of the trace
    const [first, second] = [await centreOf(planner, 1), await centreOf(planner, 2)]
    const grab = { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 }
    await p.mouse.move(grab.x - 10, grab.y - 10)
    await p.mouse.move(grab.x, grab.y, { steps: 3 })
    await p.mouse.move(grab.x + 1, grab.y, { steps: 2 })
    await p.mouse.down()
    await p.mouse.move(grab.x, grab.y - 110, { steps: 8 })
    await p.keyboard.press('Escape')
    await p.mouse.up()
    await settled()
    await expect(points(3)).toBeVisible()
    await p.waitForTimeout(500)
    expect(routerRequests).toHaveLength(0)
    await expect(points(3)).toBeVisible()

    // A marker dragged with the mouse
    const m2 = await centreOf(planner, 2)
    await p.mouse.move(m2.x, m2.y)
    await p.mouse.down()
    await p.mouse.move(m2.x + 10, m2.y + 110, { steps: 8 })
    await p.keyboard.press('Escape')
    await p.mouse.move(m2.x + 20, m2.y + 120, { steps: 3 })
    await p.mouse.up()
    await settled()
    expect(routerRequests).toHaveLength(0)
    await expect.poll(async () => Math.abs((await centreOf(planner, 2)).y - m2.y)).toBeLessThan(3)
  })

  test('Delete keeps the focus on the points', async ({ context, page, isMobile }) => {
    test.skip(isMobile, 'a keyboard matter')
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, surface, marker, settled, routerRequests } = planner
    await drawThreePoints(planner)

    await marker(2).focus()
    await p.keyboard.press('Delete')
    await settled()
    expect(routerRequests).toHaveLength(1)
    await expect(
      surface.getByRole('button', { name: 'Arrivée, point 2 sur 2', exact: true })
    ).toBeFocused()
  })

  test('Tab follows the order of the points after an insertion', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a keyboard matter')
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, marker, points, settled } = planner
    await drawThreePoints(planner)

    // A point inserted between the first two, by the ghost point
    const [first, second] = [await centreOf(planner, 1), await centreOf(planner, 2)]
    const grab = { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 }
    await p.mouse.move(grab.x - 10, grab.y - 10)
    await p.mouse.move(grab.x, grab.y, { steps: 3 })
    await p.mouse.move(grab.x + 1, grab.y, { steps: 2 })
    await p.mouse.down()
    await p.mouse.move(grab.x, grab.y - 110, { steps: 8 })
    await p.mouse.up()
    await settled()
    await expect(points(4)).toBeVisible()

    await marker(1).focus()
    await p.keyboard.press('Tab')
    await expect(marker(2)).toBeFocused()
    await p.keyboard.press('Tab')
    await expect(marker(3)).toBeFocused()
  })
})

test.describe('scrolling at the edge during a drag (B9)', () => {
  test.setTimeout(90_000)

  /** The shift of marker 1 since `from`, once it exceeds 150 px (the map scrolled under the pointer). */
  async function scrolled(planner: Planner, from: { x: number; y: number }) {
    await expect
      .poll(
        async () => {
          const now = await centreOf(planner, 1)
          return Math.hypot(now.x - from.x, now.y - from.y)
        },
        { timeout: 15_000 }
      )
      .toBeGreaterThan(150)
    const now = await centreOf(planner, 1)
    return { x: now.x - from.x, y: now.y - from.y }
  }

  /** The map stopped scrolling: marker 1 does not move for 300 ms. */
  async function stable(planner: Planner) {
    const before = await centreOf(planner, 1)
    await planner.page.waitForTimeout(300)
    const after = await centreOf(planner, 1)
    expect(Math.hypot(after.x - before.x, after.y - before.y)).toBeLessThan(1)
  }

  /** A point put where the first frame would have shown `shifted`: outside the box measured before. */
  function outside(
    box: { x: number; y: number; width: number; height: number },
    point: { x: number; y: number },
    shift: { x: number; y: number }
  ) {
    const [x, y] = [point.x - shift.x, point.y - shift.y]
    return x < box.x || x > box.x + box.width || y < box.y || y > box.y + box.height
  }

  test('a marker dragged to the edge scrolls the map under the still mouse (mouse)', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a mouse gesture')
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, canvas, settled, routerRequests } = planner
    await drawThreePoints(planner)
    await canvas.evaluate((el) => el.scrollIntoView({ block: 'center', inline: 'center' }))
    const frame = (await canvas.boundingBox())!
    const p1 = await centreOf(planner, 1)
    const from = await centreOf(planner, 2)

    await p.mouse.move(from.x, from.y)
    await p.mouse.down()
    // The top edge, at the middle: the left edge is under the map controls, which swallow the release
    const top = frame.x + frame.width / 2
    await p.mouse.move(top, frame.y + 60, { steps: 6 })
    await p.mouse.move(top, frame.y + 10, { steps: 6 })
    // The mouse stays still: the animation frames do the scrolling
    const shift = await scrolled(planner, p1)
    await p.mouse.up()
    await settled()
    await expect.poll(() => routerRequests.length).toBe(2)
    expect(outside(frame, await centreOf(planner, 2), shift)).toBe(true)
    await stable(planner)
  })

  test('a ghost point dragged to the edge scrolls the map under the still mouse (mouse)', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'a mouse gesture')
    const planner = await openPlanner({ context, page, isMobile })
    const { page: p, canvas, points, settled, routerRequests } = planner
    await drawThreePoints(planner)
    await canvas.evaluate((el) => el.scrollIntoView({ block: 'center', inline: 'center' }))
    const frame = (await canvas.boundingBox())!
    const p1 = await centreOf(planner, 1)
    const [first, second] = [p1, await centreOf(planner, 2)]
    const grab = { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 }

    await p.mouse.move(grab.x - 10, grab.y - 10)
    await p.mouse.move(grab.x, grab.y, { steps: 3 })
    await p.mouse.move(grab.x + 1, grab.y, { steps: 2 })
    await p.mouse.down()
    const top = frame.x + frame.width / 2
    await p.mouse.move(top, frame.y + 60, { steps: 6 })
    await p.mouse.move(top, frame.y + 10, { steps: 6 })
    const shift = await scrolled(planner, p1)
    await p.mouse.up()
    await settled()
    await expect(points(4)).toBeVisible()
    await expect.poll(() => routerRequests.length).toBe(2)
    expect(outside(frame, await centreOf(planner, 2), shift)).toBe(true)
    await stable(planner)
  })

  test('a marker dragged to the edge scrolls the map under the still finger (touch)', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a finger gesture')
    const planner = await openPlanner({ context, page, isMobile })
    const { canvas, touch, settled, routerRequests } = planner
    await drawThreePoints(planner)
    const frame = (await canvas.boundingBox())!
    const p1 = await centreOf(planner, 1)
    const from = await centreOf(planner, 2)
    const to = { x: frame.x + frame.width - 10, y: from.y }

    await touch('touchStart', from)
    for (let i = 1; i <= 8; i++) {
      await touch('touchMove', {
        x: from.x + ((to.x - from.x) * i) / 8,
        y: from.y,
      })
    }
    const shift = await scrolled(planner, p1)
    await touch('touchEnd')
    await settled()
    await expect.poll(() => routerRequests.length).toBe(2)
    expect(outside(frame, await centreOf(planner, 2), shift)).toBe(true)
    await stable(planner)
  })

  test('an anchor dragged to the edge scrolls the map under the still finger (touch)', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a finger gesture')
    const l = await openLTrack({ context, page, isMobile })
    const { canvas, marker, corner, start, touch, settled, routerRequests } = l
    const frame = (await canvas.boundingBox())!
    const to = { x: corner.x, y: frame.y + 10 }

    await touch('touchStart', corner)
    for (let i = 1; i <= 8; i++) {
      await touch('touchMove', {
        x: corner.x,
        y: corner.y + ((to.y - corner.y) * i) / 8,
      })
    }
    await expect
      .poll(async () => Math.hypot(...Object.values(await relativeToStart(l, start))), {
        timeout: 15_000,
      })
      .toBeGreaterThan(150)
    const shift = await relativeToStart(l, start)
    await touch('touchEnd')
    await settled()
    await expect(marker(3)).toBeVisible()
    await expect.poll(() => routerRequests.length).toBe(2)
    const dropped = await l.centre(2)
    expect(outside(frame, dropped, shift)).toBe(true)
  })

  test('a second finger stops the scrolling and the drag is abandoned (touch)', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a finger gesture')
    const l = await openLTrack({ context, page, isMobile })
    const { canvas, cdp, marker, corner, start, touch, routerRequests } = l
    const frame = (await canvas.boundingBox())!
    const to = { x: corner.x, y: frame.y + 10 }

    await touch('touchStart', corner)
    for (let i = 1; i <= 8; i++) {
      await touch('touchMove', {
        x: corner.x,
        y: corner.y + ((to.y - corner.y) * i) / 8,
      })
    }
    await expect
      .poll(async () => Math.hypot(...Object.values(await relativeToStart(l, start))), {
        timeout: 15_000,
      })
      .toBeGreaterThan(150)

    // A second finger lands: a pinch, whatever the first one had started is over
    const fingers = [
      { ...to, id: 0 },
      // In the middle of the map: away from the controls, which would swallow the touch
      { x: frame.x + frame.width / 2, y: frame.y + frame.height / 2, id: 1 },
    ]
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: fingers })
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: fingers })
    const before = await l.centre(1)
    await page.waitForTimeout(300)
    const after = await l.centre(1)
    expect(Math.hypot(after.x - before.x, after.y - before.y), 'the map stopped').toBeLessThan(1)

    await touch('touchEnd')
    await expect(marker(3)).toHaveCount(0)
    expect(routerRequests).toHaveLength(0)
  })
})

/** How far marker 1 of an L track moved, in page pixels, since it was at `start`. */
async function relativeToStart(
  l: { centre: (n: number) => Promise<{ x: number; y: number }> },
  start: { x: number; y: number }
) {
  const now = await l.centre(1)
  return { x: now.x - start.x, y: now.y - start.y }
}

test.describe('avoiding hills and traffic (C2)', () => {
  test.setTimeout(90_000)

  test('a setting asks nothing of the router, applies to the next leg, and is remembered', async ({
    context,
    page,
    isMobile,
  }) => {
    const { surface, clickMap, points, settled, routerRequests } = await openPlanner({
      context,
      page,
      isMobile,
    })
    await clickMap(-100, 0)
    await expect(points(1)).toBeVisible()

    await surface.getByRole('button', { name: 'Profil' }).click()
    const hills = page.getByRole('slider', { name: 'Côtes' })
    await expect(hills).toBeVisible()
    await hills.focus()
    await page.keyboard.press('Home')
    await expect(hills).toHaveAttribute('aria-valuenow', '0')
    expect(routerRequests, 'turning a knob routes nothing').toHaveLength(0)
    await page.keyboard.press('Escape')
    await expect(hills).toBeHidden()

    await clickMap(100, 30)
    await expect(points(2)).toBeVisible()
    await settled()
    expect(routerRequests).toHaveLength(1)
    expect(routerRequests.at(-1)?.useHills).toBe(0)
    expect(routerRequests.at(-1)?.useRoads, 'the other knob stays the profile’s').toBeUndefined()

    await page.reload()
    await startDrawing(page, isMobile)
    await surface.getByRole('button', { name: 'Profil' }).click()
    await expect(page.getByRole('slider', { name: 'Côtes' })).toHaveAttribute('aria-valuenow', '0')
  })
})

/**
 * The editing state saved with the track and read back (C4a, ledger WEB-100): control points, joins,
 * straight legs and the loaded file survive a save, and reopening a route asks the router for
 * nothing. Nothing here reaches Stadia Maps (the router is simulated).
 */
/** An L-shaped track: 3 km east, then 3 km north, a point every 50 m. */
function lTrack(): [number, number, number][] {
  const [lat0, lon0] = [48.4469, 1.4875]
  const perLat = 111_320
  const perLon = perLat * Math.cos((lat0 * Math.PI) / 180)
  const leg = Array.from({ length: 61 }, (_, i) => i * 50)
  return [
    ...leg.map((east): [number, number, number] => [lat0, lon0 + east / perLon, 150]),
    ...leg
      .slice(1)
      .map((north): [number, number, number] => [lat0 + north / perLat, lon0 + 3000 / perLon, 150]),
  ]
}

/** A tap on the trace between the first two anchors, then the dropped point is the second marker. */
async function insertOnTrace(page: Page, isMobile: boolean, surface: ReturnType<typeof editorOf>) {
  const marker = (n: number) => surface.getByRole('button', { name: markerName(n) })
  const centre = async (n: number) => {
    const b = await marker(n).boundingBox()
    if (!b) throw new Error(`marker ${n} has no box`)
    return { x: b.x + b.width / 2, y: b.y + b.height / 2 }
  }
  const canvas = surface.locator('canvas.maplibregl-canvas').first()
  await canvas.evaluate((el) => el.scrollIntoView({ block: 'center', inline: 'center' }))
  const [start, end] = [await centre(1), await centre(2)]
  // Half way along the first leg of the L, east from the start
  const grab = { x: (start.x + end.x) / 2, y: start.y }
  if (isMobile) {
    await page.evaluate(async ({ x, y }) => {
      const target = document.elementFromPoint(x, y)
      if (!target) throw new Error('nothing under the tap')
      const at = { clientX: x, clientY: y, bubbles: true, cancelable: true, view: window }
      const touch = { ...at, pointerId: 7, pointerType: 'touch', isPrimary: true }
      target.dispatchEvent(new PointerEvent('pointerdown', touch))
      target.dispatchEvent(new PointerEvent('pointerup', touch))
      target.dispatchEvent(new MouseEvent('mousemove', at))
      await new Promise((resolve) => setTimeout(resolve, 50))
      target.dispatchEvent(new MouseEvent('mousedown', { ...at, button: 0, buttons: 1 }))
      target.dispatchEvent(new MouseEvent('mouseup', { ...at, button: 0 }))
      target.dispatchEvent(new MouseEvent('click', { ...at, button: 0, detail: 1 }))
    }, grab)
  } else {
    await page.mouse.move(grab.x - 10, grab.y - 10)
    await page.mouse.move(grab.x, grab.y, { steps: 3 })
    await page.mouse.move(grab.x + 1, grab.y, { steps: 2 })
    await page.mouse.down()
    await page.mouse.move(grab.x, grab.y - 110, { steps: 8 })
    await page.mouse.up()
  }
  return marker
}

/** Deletes the n-th control point: a right click on a mouse, a long press and its menu on a finger. */
async function deleteMarker(
  page: Page,
  context: BrowserContext,
  isMobile: boolean,
  marker: Locator
) {
  if (!isMobile) {
    await marker.click({ button: 'right' })
    return
  }
  const box = await marker.boundingBox()
  if (!box) throw new Error('the marker has no box')
  const at = { x: box.x + box.width / 2, y: box.y + box.height / 2 }
  const cdp = await context.newCDPSession(page)
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [at] })
  await page.waitForTimeout(800)
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
  await page.getByRole('menuitem', { name: 'Supprimer le point' }).click()
}

test.describe('planner state saved and read back (C4a)', () => {
  test.setTimeout(120_000)

  /** Counts the reads of the saved editing state (GET …/planner-state) a page makes. */
  const watchStateReads = (page: Page) => {
    const reads: string[] = []
    page.on('request', (r) => {
      if (r.method() === 'GET' && r.url().includes('/planner-state')) reads.push(r.url())
    })
    return reads
  }

  /** On a finger the map is in the fullscreen editor, opened from the form; on a mouse it is in the page. */
  async function openEditor(page: Page, isMobile: boolean, name: string) {
    if (isMobile) {
      const edit = page.getByRole('main').getByRole('button', { name: 'Modifier le tracé' })
      await hydrated(edit)
      await edit.click()
    }
    return editorOf(page, isMobile, name)
  }

  test('a drawn track with a straight leg is read back as it was, with no routing request', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { main, surface, clickMap, points, settled, routerRequests } = planner
    await drawThreePoints(planner)
    const toggle = directToggle(page, isMobile)
    await toggle.click()
    await expect(toggle).toHaveAttribute('aria-pressed', 'true')
    // Far enough for a long straight leg (the warning shows from 300 m)
    await clickMap(-100, 90)
    await expect(points(4)).toBeVisible()
    await settled()

    if (isMobile) {
      await surface.getByRole('button', { name: 'Terminer' }).click()
      await expect(surface).toBeHidden()
    }
    const name = unique('Tracé relu')
    await main.getByRole('textbox', { name: 'Nom du parcours' }).fill(name)
    const saved = page.waitForResponse(
      (r) => r.url().endsWith('/api/gpx-previews/from-points') && r.request().method() === 'POST'
    )
    await main.getByRole('button', { name: 'Enregistrer' }).click()
    const response = await saved
    expect(response.ok()).toBe(true)
    // The editing state goes, not the points: the server derives the track from it
    const sent = response.request().postDataJSON() as Record<string, unknown>
    expect(sent.points).toBeUndefined()
    expect(sent.plannerState).toMatchObject({ version: 1 })
    const preview = (await response.json()) as GpxPreviewDto

    routerRequests.length = 0
    const reads = watchStateReads(page)
    await page.goto(`${origin}/outils-gpx/${preview.id}/modifier`)
    await expect(directWarning(page)).toBeVisible()
    const editor = await openEditor(page, isMobile, name)
    await expect(editor.getByText('4 points', { exact: true })).toBeVisible()
    for (const n of [1, 2, 3, 4]) {
      await expect(editor.getByRole('button', { name: markerName(n) })).toBeVisible()
    }
    expect(routerRequests, 'reading the state asks nothing of the router').toHaveLength(0)
    expect(reads, 'one read of the saved state').toHaveLength(1)
  })

  test('a new title sends neither the points nor the state, and the control points stay', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { main, surface, routerRequests } = planner
    await drawThreePoints(planner)
    if (isMobile) {
      await surface.getByRole('button', { name: 'Terminer' }).click()
      await expect(surface).toBeHidden()
    }
    const name = unique('Tracé renommé')
    await main.getByRole('textbox', { name: 'Nom du parcours' }).fill(name)
    const created = page.waitForResponse(
      (r) => r.url().endsWith('/api/gpx-previews/from-points') && r.request().method() === 'POST'
    )
    await main.getByRole('button', { name: 'Enregistrer' }).click()
    const preview = (await (await created).json()) as GpxPreviewDto

    await page.goto(`${origin}/outils-gpx/${preview.id}/modifier`)
    const field = main.getByRole('textbox', { name: 'Nom du parcours' })
    await hydrated(field)
    await expect(field).toHaveValue(name)
    const renamed = `${name} bis`
    await field.fill(renamed)
    const update = page.waitForRequest(
      (r) => r.method() === 'PUT' && r.url().endsWith(`/api/gpx-previews/${preview.id}`)
    )
    await main.getByRole('button', { name: 'Enregistrer' }).click()
    const body = (await update).postData() ?? ''
    expect(body).not.toContain('"points"')
    expect(body).not.toContain('plannerState')
    await expect(page).toHaveURL(`${origin}/outils-gpx/${preview.id}`)

    routerRequests.length = 0
    await page.goto(`${origin}/outils-gpx/${preview.id}/modifier`)
    const editor = await openEditor(page, isMobile, renamed)
    await expect(editor.getByText('3 points', { exact: true })).toBeVisible()
    expect(routerRequests).toHaveLength(0)
  })

  /** A team of its own with the planner open, and an L-shaped route in it (3 km east, 3 km north). */
  async function lRoute() {
    const owner = await newUser(unique('Admin tracé'))
    const team = await newTeam(owner, unique('Équipe tracé'))
    await setTeamAttributes(team, { enableRoutePlanner: true })
    const track = lTrack()
    const name = unique('Boucle en L')
    const route = await newRoute(owner, team.slug, name, track)
    return { owner, team, route, name }
  }

  test('a route without a saved state opens as an import: a point inserted on it is deleted with no request', async ({
    context,
    page,
    isMobile,
  }) => {
    const { owner, team, route, name } = await lRoute()
    await signIn(context, owner)
    await stubBasemap(page)
    const routerRequests = await stubRouter(page)
    const settled = (surface: ReturnType<typeof editorOf>) =>
      expect(surface.getByRole('status', { name: "Calcul de l'itinéraire..." })).toHaveCount(0)

    await page.goto(`${routePath(team.slug, route.slug)}/modifier`)
    let surface = await openEditor(page, isMobile, name)
    await expect(surface.getByText('2 points', { exact: true })).toBeVisible()

    const marker = await insertOnTrace(page, isMobile, surface)
    await settled(surface)
    await expect(surface.getByText('3 points', { exact: true })).toBeVisible()
    expect(routerRequests, 'the cut leg, before and after the new point').toHaveLength(2)

    routerRequests.length = 0
    await deleteMarker(page, context, isMobile, marker(2))
    await settled(surface)
    await expect(surface.getByText('2 points', { exact: true })).toBeVisible()
    expect(routerRequests, 'the file between two of its points is given back').toHaveLength(0)

    // Saved and reopened: still the two points, and nothing routed
    if (isMobile) {
      await surface.getByRole('button', { name: 'Terminer' }).click()
      await expect(surface).toBeHidden()
    }
    const saved = page.waitForResponse(
      (r) => r.request().method() === 'PUT' && r.url().endsWith(`/routes/${route.slug}`)
    )
    await page.getByRole('main').getByRole('button', { name: 'Enregistrer' }).click()
    expect((await saved).ok()).toBe(true)
    await page.goto(`${routePath(team.slug, route.slug)}/modifier`)
    surface = await openEditor(page, isMobile, name)
    await expect(surface.getByText('2 points', { exact: true })).toBeVisible()
    expect(routerRequests).toHaveLength(0)
  })

  test('the joins of an import survive a save: after reopening, deleting the inserted point is free', async ({
    context,
    page,
    isMobile,
  }) => {
    const { owner, team, route, name } = await lRoute()
    await signIn(context, owner)
    await stubBasemap(page)
    const routerRequests = await stubRouter(page)

    await page.goto(`${routePath(team.slug, route.slug)}/modifier`)
    let surface = await openEditor(page, isMobile, name)
    await insertOnTrace(page, isMobile, surface)
    await expect(surface.getByText('3 points', { exact: true })).toBeVisible()
    if (isMobile) {
      await surface.getByRole('button', { name: 'Terminer' }).click()
      await expect(surface).toBeHidden()
    }
    const saved = page.waitForRequest(
      (r) => r.method() === 'PUT' && r.url().endsWith(`/routes/${route.slug}`)
    )
    await page.getByRole('main').getByRole('button', { name: 'Enregistrer' }).click()
    expect(await saved).toBeTruthy()
    await expect(page).toHaveURL(routePath(team.slug, route.slug))

    routerRequests.length = 0
    await page.goto(`${routePath(team.slug, route.slug)}/modifier`)
    surface = await openEditor(page, isMobile, name)
    await expect(surface.getByText('3 points', { exact: true })).toBeVisible()
    await deleteMarker(
      page,
      context,
      isMobile,
      surface.getByRole('button', { name: markerName(2) })
    )
    await expect(surface.getByText('2 points', { exact: true })).toBeVisible()
    expect(routerRequests, 'the joins and their provenance were saved').toHaveLength(0)
  })
})

test.describe('importing a GPX file in the planner (C4b)', () => {
  test.setTimeout(120_000)

  /** POST /api/router/import-gpx is the real endpoint here; only the router is simulated. */
  const gpxUpload = (name: string, points: GpxPoint[]) => ({
    name: `${name}.gpx`,
    mimeType: 'application/gpx+xml',
    buffer: Buffer.from(gpxOf(name, points)),
  })

  /** A file of two tracks, in this order, the second one `shiftEast` metres east of the first. */
  const twoTracks = (name: string, shiftEast: number) => {
    const first = windingTrack(120)
    const perLon = 111_320 * Math.cos((48.4469 * Math.PI) / 180)
    const second = first.map(([lat, lon, ele]): GpxPoint => [lat, lon + shiftEast / perLon, ele])
    const trk = (n: string, pts: GpxPoint[]) =>
      `<trk><name>${n}</name><trkseg>${pts
        .map(([lat, lon, ele]) => `<trkpt lat="${lat}" lon="${lon}"><ele>${ele}</ele></trkpt>`)
        .join('')}</trkseg></trk>`
    return {
      name: `${name}.gpx`,
      mimeType: 'application/gpx+xml',
      buffer: Buffer.from(
        `<?xml version="1.0" encoding="UTF-8"?><gpx version="1.1" creator="pedalons-e2e" xmlns="http://www.topografix.com/GPX/1/1"><metadata><name>${name}</name></metadata>${trk('a', first)}${trk('b', second)}</gpx>`
      ),
    }
  }

  const importInput = (page: Page) => page.getByTestId('planner-import-input')
  const choice = (page: Page) => page.getByRole('dialog', { name: 'Importer un fichier GPX' })

  /** Closes the fullscreen editor on a finger, so that the form's own buttons are reachable. */
  async function backToForm(surface: Locator, isMobile: boolean) {
    if (!isMobile) return
    await surface.getByRole('button', { name: 'Terminer' }).click()
    await expect(surface).toBeHidden()
  }

  test('a file imported into an empty planner names the track and is saved as the file itself', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile }, { enter: false })
    const { main, nameField, routerRequests } = planner
    const name = unique('Import intact')
    await importInput(page).setInputFiles(gpxUpload(name, windingTrack(300)))
    // Nothing to lose: no question, and the file names the track
    await expect(nameField).toHaveValue(name)
    await expect(choice(page)).toHaveCount(0)
    await planner.enterEditor()
    await expect(planner.points(2)).toBeVisible()
    await backToForm(planner.surface, isMobile)

    const upload = page.waitForRequest(
      (r) => r.method() === 'POST' && r.url().endsWith('/api/gpx-previews')
    )
    await main.getByRole('button', { name: 'Enregistrer' }).click()
    const request = await upload
    expect(request.headers()['content-type']).toContain('multipart/form-data')
    expect(request.postDataBuffer()?.toString('latin1')).toContain('name="gpxFile"')
    expect(routerRequests, 'importing asks nothing of the router').toHaveLength(0)
    await expect(page).toHaveURL(new RegExp(`${origin}/outils-gpx/[^/]+$`))
  })

  test('a modified import is saved as its state, climb included, and read back without routing', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile }, { enter: false })
    const { main, nameField, routerRequests } = planner
    const name = unique('Import modifié')
    await importInput(page).setInputFiles(gpxUpload(name, windingTrack(300)))
    await expect(nameField).toHaveValue(name)
    await planner.enterEditor()
    await expect(planner.points(2)).toBeVisible()
    // One more point, routed from the end of the file
    await planner.clickMap(0, 160)
    await expect(planner.points(3)).toBeVisible()
    await planner.settled()
    expect(routerRequests, 'the leg to the new point').toHaveLength(1)
    await backToForm(planner.surface, isMobile)

    const saved = page.waitForResponse(
      (r) => r.url().endsWith('/api/gpx-previews/from-points') && r.request().method() === 'POST'
    )
    await main.getByRole('button', { name: 'Enregistrer' }).click()
    const response = await saved
    expect(response.ok()).toBe(true)
    const sent = response.request().postDataJSON() as {
      points?: unknown
      plannerState?: { sources: { climb?: string }[] }
    }
    expect(sent.points).toBeUndefined()
    expect(
      sent.plannerState?.sources[0].climb,
      'the climb of the file travels with it'
    ).toBeTruthy()
    const preview = (await response.json()) as GpxPreviewDto

    routerRequests.length = 0
    await page.goto(`${origin}/outils-gpx/${preview.id}/modifier`)
    const editor = await (async () => {
      if (isMobile) {
        const edit = main.getByRole('button', { name: 'Modifier le tracé' })
        await hydrated(edit)
        await edit.click()
      }
      return editorOf(page, isMobile, name)
    })()
    await expect(editor.getByText('3 points', { exact: true })).toBeVisible()
    expect(routerRequests).toHaveLength(0)
  })

  test('« Ajouter à la fin » joins the file to the drawn route with one routed request', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, points, settled, routerRequests } = planner
    await drawThreePoints(planner)
    routerRequests.length = 0

    await importInput(page).setInputFiles(gpxUpload(unique('Suite'), windingTrack(120)))
    await expect(choice(page)).toBeVisible()
    await choice(page).getByRole('button', { name: 'Ajouter à la fin' }).click()
    await expect(choice(page)).toHaveCount(0)
    await settled()
    // The three drawn points, and the two ends of the file
    await expect(points(5)).toBeVisible()
    expect(routerRequests, 'the join between the route and the file').toHaveLength(1)
    await expect(surface.getByRole('status', { name: "Calcul de l'itinéraire..." })).toHaveCount(0)
  })

  test('« Remplacer le tracé » drops the drawn route, through the tool button, with no request', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, points, routerRequests } = planner
    await drawThreePoints(planner)
    routerRequests.length = 0

    const chooser = page.waitForEvent('filechooser')
    await surface.getByRole('button', { name: 'Importer un fichier GPX', exact: true }).click()
    await (await chooser).setFiles(gpxUpload(unique('Remplaçant'), windingTrack(120)))
    await choice(page).getByRole('button', { name: 'Remplacer le tracé' }).click()
    await expect(points(2)).toBeVisible()
    expect(routerRequests).toHaveLength(0)
  })

  test('a cancelled choice imports nothing', async ({ context, page, isMobile }) => {
    const planner = await openPlanner({ context, page, isMobile })
    const { points } = planner
    await drawThreePoints(planner)
    await importInput(page).setInputFiles(gpxUpload(unique('Annulé'), windingTrack(120)))
    await choice(page).getByRole('button', { name: 'Annuler', exact: true }).click()
    await expect(choice(page)).toHaveCount(0)
    await expect(points(3)).toBeVisible()
  })

  test('a file of two tracks keeps both, joined by a straight line that asks nothing of the router', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile }, { enter: false })
    const { routerRequests } = planner
    await importInput(page).setInputFiles(twoTracks(unique('Deux pistes'), 4000))
    await planner.enterEditor()
    // The two ends of each track
    await expect(planner.points(4)).toBeVisible()
    // 4 km between the tracks: the straight leg is long enough for the warning
    await expect(directWarning(page)).toBeVisible()
    expect(routerRequests).toHaveLength(0)
  })

  test('a team route is replaced by a file and saved as an upload of it', async ({
    context,
    page,
  }) => {
    const owner = await newUser(unique('Admin import'))
    const team = await newTeam(owner, unique('Équipe import'))
    await setTeamAttributes(team, { enableRoutePlanner: true })
    const route = await newRoute(owner, team.slug, unique('Parcours à remplacer'), windingTrack(80))
    await signIn(context, owner)
    await stubBasemap(page)
    const routerRequests = await stubRouter(page)

    await page.goto(`${routePath(team.slug, route.slug)}/modifier`)
    await hydrated(importInput(page))
    await importInput(page).setInputFiles(gpxUpload(unique('Nouveau fichier'), windingTrack(200)))
    await expect(choice(page)).toBeVisible()
    await choice(page).getByRole('button', { name: 'Remplacer le tracé' }).click()
    await expect(choice(page)).toHaveCount(0)

    const saved = page.waitForRequest(
      (r) => r.method() === 'PUT' && r.url().endsWith(`/routes/${route.slug}`)
    )
    await page.getByRole('main').getByRole('button', { name: 'Enregistrer' }).click()
    const request = await saved
    expect(request.headers()['content-type']).toContain('multipart/form-data')
    expect(request.postDataBuffer()?.toString('latin1')).toContain('name="gpxFile"')
    expect(routerRequests).toHaveLength(0)
  })

  test('the joins of an imported file survive a save: after reopening, deleting a point between two joins is free', async ({
    context,
    page,
    isMobile,
  }) => {
    const planner = await openPlanner({ context, page, isMobile }, { enter: false })
    const { main, nameField, routerRequests } = planner
    const name = unique('Import en L')
    await importInput(page).setInputFiles(gpxUpload(name, lTrack()))
    await expect(nameField).toHaveValue(name)
    await planner.enterEditor()
    const marker = await insertOnTrace(page, isMobile, planner.surface)
    await planner.settled()
    await expect(planner.points(3)).toBeVisible()
    expect(routerRequests, 'the cut leg, before and after the new point').toHaveLength(2)

    routerRequests.length = 0
    await deleteMarker(page, context, isMobile, marker(2))
    await planner.settled()
    await expect(planner.points(2)).toBeVisible()
    expect(routerRequests, 'the imported pieces between two joins are given back').toHaveLength(0)

    // Insert again, save, reopen: the pieces come back from the saved state
    await insertOnTrace(page, isMobile, planner.surface)
    await planner.settled()
    await expect(planner.points(3)).toBeVisible()
    await backToForm(planner.surface, isMobile)
    const saved = page.waitForResponse(
      (r) => r.url().endsWith('/api/gpx-previews/from-points') && r.request().method() === 'POST'
    )
    await main.getByRole('button', { name: 'Enregistrer' }).click()
    const preview = (await (await saved).json()) as GpxPreviewDto

    routerRequests.length = 0
    await page.goto(`${origin}/outils-gpx/${preview.id}/modifier`)
    if (isMobile) {
      const edit = main.getByRole('button', { name: 'Modifier le tracé' })
      await hydrated(edit)
      await edit.click()
    }
    const editor = editorOf(page, isMobile, name)
    await expect(editor.getByText('3 points', { exact: true })).toBeVisible()
    await deleteMarker(page, context, isMobile, editor.getByRole('button', { name: markerName(2) }))
    await expect(editor.getByText('2 points', { exact: true })).toBeVisible()
    expect(routerRequests, 'nothing was asked of the router after reopening').toHaveLength(0)
  })
})
