import type { ConsoleMessage, Page } from '@playwright/test'
import type { GpxPreviewDto, SurfaceSpanDto } from '../src/api/dto'
import { expectOk, withApi } from './support/api'
import { newTeam, newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import {
  gpxOf,
  newRoute,
  routePath,
  stubBasemap,
  trackLength,
  windingTrack,
  withTrackSurfaces,
} from './support/routes'
import { pageHydrated } from './support/ui'

/**
 * The surface along a saved track (docs/LEDGER_*.md WEB-100, C1b), on the route sheet and on the
 * GPX tools' preview: the breakdown bar, its legend, the OpenStreetMap credit and the switch that
 * colours the profile and the line by surface.
 *
 * The stack computes nothing (the surface computation is off in `.env.e2e`, and a test must never
 * reach Stadia Maps): the browser is handed the route / the preview with the surface the worker
 * would have stored (`withTrackSurfaces`). The page is reached by a client-side navigation, the
 * only read that goes through the browser.
 */

test.beforeEach(async ({ page }) => {
  await stubBasemap(page)
})

/** Moves the hydrated app to `path` the way a `<Link>` does: a history push, no document request. */
async function clientNavigate(page: Page, path: string) {
  await page.goto('/')
  await pageHydrated(page)
  await page.evaluate((to) => {
    window.history.pushState(null, '', to)
    window.dispatchEvent(new PopStateEvent('popstate'))
  }, path)
}

/** Asphalte 40 %, gravier 20 %, sentier 30 %, hors réseau 10 % of a track of `length` metres. */
function spansOf(length: number): SurfaceSpanDto[] {
  return [
    { from: 0, to: 0.4 * length, surface: 'PAVED' },
    { from: 0.4 * length, to: 0.6 * length, surface: 'GRAVEL' },
    { from: 0.6 * length, to: 0.9 * length, surface: 'PATH' },
    { from: 0.9 * length, to: length, surface: 'OFF_NETWORK' },
  ]
}

function watchConsoleErrors(page: Page) {
  const errors: string[] = []
  page.on('console', (message: ConsoleMessage) => {
    if (message.type() === 'error') errors.push(message.text())
  })
  page.on('pageerror', (error) => errors.push(error.message))
  return errors
}

async function ownRoute(label: string) {
  const owner = await newUser(unique('Admin revêtement'))
  const team = await newTeam(owner, unique(`Revêtement ${label}`))
  const name = unique('Boucle revêtue')
  const route = await newRoute(owner, team.slug, name, windingTrack(300))
  return { owner, team, name, route }
}

test('a route sheet shows its surface breakdown and colours the profile and the line by it', async ({
  page,
  context,
}) => {
  const { owner, team, name, route } = await ownRoute('fiche')
  await signIn(context, owner)
  await withTrackSurfaces(page, `/api/teams/${team.slug}/routes/${route.slug}`, (track) => ({
    surfaceState: 'READY',
    surfaces: spansOf(trackLength(track)),
  }))
  const errors = watchConsoleErrors(page)

  await clientNavigate(page, routePath(team.slug, route.slug!))
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()

  const summary = main.getByTestId('route-surface-summary')
  await expect(summary).toBeVisible()
  await expect(main.getByTestId('route-surface-bar')).toBeVisible()
  const legend = main.getByTestId('route-surface-legend')
  await expect(legend).toContainText('Asphalte 40 %')
  await expect(legend).toContainText('Compacté, gravier 20 %')
  await expect(legend).toContainText('Sentier 30 %')
  await expect(legend).toContainText('Hors réseau 10 %')
  await expect(legend).not.toContainText('Terre')
  const credit = main.getByTestId('route-surface-attribution').getByRole('link')
  await expect(credit).toHaveText('© contributeurs OpenStreetMap')
  await expect(credit).toHaveAttribute('href', 'https://www.openstreetmap.org/copyright')

  // The grade colours the profile and the line until the viewer asks for the surface.
  const grade = summary.getByRole('radio', { name: 'Pente' })
  const surface = summary.getByRole('radio', { name: 'Revêtement' })
  await expect(grade).toBeChecked()
  // Mantine hides the radio inputs: the click goes to their label, as the viewer's does
  await summary.getByText('Revêtement', { exact: true }).click()
  await expect(surface).toBeChecked()
  await expect(main.locator('canvas').first()).toBeVisible()
  await summary.getByText('Pente', { exact: true }).click()
  await expect(grade).toBeChecked()
  expect(errors, 'no error on the console').toEqual([])
})

test('a route sheet whose surface is being computed says so, without bar nor switch', async ({
  page,
  context,
}) => {
  const { owner, team, name, route } = await ownRoute('en cours')
  await signIn(context, owner)
  await withTrackSurfaces(page, `/api/teams/${team.slug}/routes/${route.slug}`, () => ({
    surfaceState: 'PENDING',
  }))

  await clientNavigate(page, routePath(team.slug, route.slug!))
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()

  await expect(main.getByTestId('route-surface-pending')).toHaveText(
    'Revêtement en cours de calcul'
  )
  await expect(main.getByTestId('route-surface-bar')).toHaveCount(0)
  await expect(main.getByRole('radio', { name: 'Revêtement' })).toHaveCount(0)
})

test('the GPX tools preview shows the surface breakdown', async ({ page, context }) => {
  const user = await newUser(unique('Cycliste revêtement'))
  const name = unique('Aperçu revêtu')
  const preview = await withApi(user, async (api) =>
    expectOk<GpxPreviewDto>(
      await api.post('/api/gpx-previews', {
        multipart: {
          gpxFile: {
            name: 'trace.gpx',
            mimeType: 'application/gpx+xml',
            buffer: Buffer.from(gpxOf(name, windingTrack(300))),
          },
        },
      })
    )
  )
  await signIn(context, user)
  await withTrackSurfaces(page, `/api/gpx-previews/${preview.id}`, (track) => ({
    surfaceState: 'READY',
    surfaces: spansOf(trackLength(track)),
  }))

  await clientNavigate(page, `/outils-gpx/${preview.id}`)
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { level: 1, name })).toBeVisible()

  await expect(main.getByTestId('route-surface-bar')).toBeVisible()
  await expect(main.getByTestId('route-surface-legend')).toContainText('Asphalte 40 %')
  await expect(main.getByTestId('route-surface-attribution')).toBeVisible()
})
