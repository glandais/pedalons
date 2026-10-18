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
  routerAnswer,
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

  test('one tap on the trace inserts a point (touch), with no ghost to tap a second time', async ({
    context,
    page,
    isMobile,
  }) => {
    test.skip(!isMobile, 'a tap is a touch gesture: covered by the mobile project')
    const planner = await openPlanner({ context, page, isMobile })
    const { surface, marker, points, settled, routerRequests } = planner
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
    await expect(surface.getByRole('button', { name: 'Point 4', exact: true })).toBeVisible()
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
  const marker = (n: number) => surface.getByRole('button', { name: `Point ${n}`, exact: true })
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
