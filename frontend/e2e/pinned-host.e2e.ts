import type { Page } from '@playwright/test'
import type { RideDto, TeamDetailDto } from '../src/api/dto'
import { markdownMedia, roleSession } from './support/data'
import {
  PINNED_HOST,
  PINNED_NAME,
  hostDocument,
  originOf,
  pinnedAlias,
  pinnedTeam,
  signInOn,
} from './support/domains'
import { expect, test, unique } from './support/fixtures'
import { newRide } from './support/rides'
import { ogTags, ssrOutlet } from './support/ssr'
import { entityCard, pageHydrated, watchHydration } from './support/ui'

/**
 * A dedicated hostname pinned to one team (docs/plans/archive/2026-09-27-e2e-coverage-audit.md, P1): `pin-e2e.localhost`, an
 * alias of `localhost` pinned to the team « Pin E2E » (support/domains.ts, created on first use).
 *
 * The app keeps working on its usual router paths (`/equipes/pin-e2e/sorties/x`) while the browser
 * shows clean ones (`/sorties/x`): `pinnedHistory.ts` maps between the two on the client, and
 * `entry-server.tsx` maps the request path in (toRouter) and the hrefs and redirects out
 * (toBrowser) on the server. What can go wrong: a prefixed href leaking into the markup, a
 * hydration mismatch between the two renders, and a redirect between the two spaces that never
 * settles.
 *
 * Setup: a public ride of the pinned team, whose description is the marker the hydration watch
 * looks for (the ride's name would not do: the tab title changes on hydration and holds it).
 */

const PREFIX = '/equipes/pin-e2e'

let team: TeamDetailDto
let ride: RideDto
let marker: string
let origin: string

test.beforeAll(async () => {
  await pinnedAlias()
  team = await pinnedTeam()
  marker = unique('Description épinglée')
  ride = await newRide(await roleSession('admin'), team.slug, unique('Sortie épinglée'), {
    visibility: 'PUBLIC',
    media: markdownMedia(marker),
  })
  origin = originOf(PINNED_HOST)
})

const ridePathOnPin = () => `/sorties/${ride.slug}`

/**
 * The team's agenda narrowed to this run's ride: the pinned team outlives the runs and collects a
 * ride per worker each time, which would push an unfiltered card off the agenda's first page. The
 * team's home is its dashboard (WEB-68), whose short lists offer no search.
 */
const agendaWithRide = () => `/agenda?q=${encodeURIComponent(ride.name)}`

/** The hrefs of every link of `main` — the page's own content. */
const mainHrefs = (page: Page) =>
  page
    .getByRole('main')
    .locator('a[href]')
    .evaluateAll((links) => links.map((link) => link.getAttribute('href') ?? ''))

/** The hrefs of a server-rendered markup. */
const markupHrefs = (html: string) =>
  [...ssrOutlet(html).matchAll(/href="([^"]*)"/g)].map(([, href]) => href)

test("« / » is the pinned team's home, under the alias's own name", async ({ page }) => {
  const watch = await watchHydration(page)
  await page.goto(`${origin}/`)

  await expect(page.getByRole('banner').getByRole('link', { name: PINNED_NAME })).toBeVisible()
  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { name: team.name, exact: true })).toBeVisible()
  await pageHydrated(page)
  await expect(page).toHaveURL(`${origin}/`)
  expect(watch.hydrationErrors).toEqual([])
  expect(watch.pageErrors).toEqual([])
})

test('the agenda opens at its unprefixed URL with the ride, without a mismatch', async ({
  page,
}) => {
  const watch = await watchHydration(page)
  await page.goto(`${origin}${agendaWithRide()}`)

  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { name: team.name, exact: true })).toBeVisible()
  await expect(entityCard(main, ride.name)).toBeVisible()
  await pageHydrated(page)
  await expect(page).toHaveURL(`${origin}${agendaWithRide()}`)
  expect(watch.hydrationErrors).toEqual([])
  expect(watch.pageErrors).toEqual([])
})

test('a ride opens at its unprefixed URL, hydrates without a mismatch and stays there', async ({
  page,
}) => {
  const watch = await watchHydration(page, [marker])
  const response = await page.goto(`${origin}${ridePathOnPin()}`)
  expect(response?.status()).toBe(200)

  const main = page.getByRole('main')
  await expect(main.getByRole('heading', { name: ride.name, exact: true })).toBeVisible()
  await expect(main.getByText(marker)).toBeVisible()
  await pageHydrated(page)
  expect(new URL(page.url()).pathname).toBe(ridePathOnPin())
  expect(watch.hydrationErrors).toEqual([])
  expect(watch.pageErrors).toEqual([])
  expect(await watch.removed()).toEqual([])

  // The link preview names the clean URL on the alias's origin.
  const document = await hostDocument(PINNED_HOST, ridePathOnPin())
  expect(ogTags(document.html)['og:url']).toEqual([`${origin}${ridePathOnPin()}`])
})

test('an agenda card opens the ride on its clean URL, and « back » returns to the agenda', async ({
  page,
}) => {
  await page.goto(`${origin}${agendaWithRide()}`)
  await pageHydrated(page)

  await entityCard(page.getByRole('main'), ride.name).click()
  await expect(page).toHaveURL(`${origin}${ridePathOnPin()}`)
  const main = page.getByRole('main')
  // Its groups: the ride page itself — the agenda card also holds a heading with the ride's name.
  await expect(main.getByTestId('ride-groups')).toBeVisible()
  await expect(main.getByRole('heading', { name: ride.name, exact: true })).toBeVisible()
  // Rendered by the client: its links are in browser space.
  expect((await mainHrefs(page)).filter((href) => href.startsWith(PREFIX))).toEqual([])

  await page.goBack()
  await expect(page).toHaveURL(`${origin}${agendaWithRide()}`)
  await expect(main.getByRole('heading', { name: team.name, exact: true })).toBeVisible()
})

test('a prefixed deep link is replaced by the clean URL once, and stays there', async ({
  page,
}) => {
  const watch = await watchHydration(page, [marker])
  const urls: string[] = []
  page.on('framenavigated', (frame) => {
    if (frame === page.mainFrame()) urls.push(new URL(frame.url()).pathname)
  })

  await page.goto(`${origin}${PREFIX}${ridePathOnPin()}`)
  await expect(page.getByRole('main').getByRole('heading', { name: ride.name })).toBeVisible()
  await pageHydrated(page)

  // The document request, then pinnedHistory's replaceState at boot, and React Router's own
  // (stamping its history index on the entry, same URL) — nothing that keeps rewriting it.
  expect([...new Set(urls)]).toEqual([`${PREFIX}${ridePathOnPin()}`, ridePathOnPin()])
  expect(urls.length).toBeLessThanOrEqual(3)
  await expect(page).toHaveURL(`${origin}${ridePathOnPin()}`)
  expect(watch.hydrationErrors).toEqual([])
  expect(watch.pageErrors).toEqual([])
  expect(await watch.removed()).toEqual([])
})

test('a former feed address leads to the agenda, unprefixed (WEB-68)', async ({ page }) => {
  // The loader's redirect leaves router space for browser space on the server (entry-server).
  await page.goto(`${origin}/?tab=publications&type=ride`)
  await expect(page).toHaveURL(`${origin}/agenda?type=ride`)
  await page.goto(`${origin}/sorties`)
  await expect(page).toHaveURL(`${origin}/agenda`)
})

test('the global pages keep their own path, the team list leads home', async ({ page }) => {
  await page.goto(`${origin}/connexion`)
  await expect(
    page.getByRole('heading', { name: `Bienvenue sur ${PINNED_NAME}`, exact: true })
  ).toBeVisible()
  expect(new URL(page.url()).pathname).toBe('/connexion')

  // No team to browse on a site of one team: the list sends to the home, i.e. the team.
  await page.goto(`${origin}/equipes`)
  await expect(page).toHaveURL(`${origin}/`)
  await expect(
    page.getByRole('main').getByRole('heading', { name: team.name, exact: true })
  ).toBeVisible()
})

test('server-rendered links carry no team prefix', async ({ page }) => {
  // Regression (be29e02f): PinnedHrefs overrides the NavigationContext the links read, on both
  // sides — before, StaticRouterProvider's own navigator ignored the wrapped createHref, so every
  // server-rendered href kept the /equipes/<team> prefix, which hydration does not patch.

  for (const path of ['/', '/agenda', ridePathOnPin()]) {
    const document = await hostDocument(PINNED_HOST, path)
    expect(document.status).toBe(200)
    expect(
      markupHrefs(document.html).filter((href) => href.startsWith(PREFIX)),
      `server markup of ${path}`
    ).toEqual([])
  }

  await page.goto(`${origin}${ridePathOnPin()}`)
  await pageHydrated(page)
  expect((await mainHrefs(page)).filter((href) => href.startsWith(PREFIX))).toEqual([])
})

test.describe('signed in', () => {
  test('the team admin gets their session and the edit link, both unprefixed', async ({
    page,
    context,
  }) => {
    // An alias shares its domain's users: the localhost session is a session here too.
    await signInOn(context, PINNED_HOST, await roleSession('admin'))
    await page.goto(`${origin}${agendaWithRide()}`)
    await pageHydrated(page)

    // Client-side navigation, so the links below are the client's, not the server's.
    await entityCard(page.getByRole('main'), ride.name).click()
    const edit = page.getByRole('main').getByRole('link', { name: 'Modifier', exact: true })
    await expect(edit).toHaveAttribute('href', `${ridePathOnPin()}/modifier`)
    await edit.click()
    await expect(page).toHaveURL(`${origin}${ridePathOnPin()}/modifier`)
    await expect(page.getByRole('heading', { name: 'Modifier la sortie' })).toBeVisible()
  })
})

test('an anonymous visit of a members-only page lands on the login without a redirect loop', async ({
  page,
}) => {
  // Regression (089e686e): the pinned history is created without v5Compat, as a data router
  // expects — before, each of its replaces renotified the router, and <Navigate> to /connexion
  // looped until « Maximum call stack size exceeded ».

  const watch = await watchHydration(page)
  await page.goto(`${origin}/calendrier`)
  await expect(page).toHaveURL(`${origin}/connexion`)
  await expect(
    page.getByRole('heading', { name: `Bienvenue sur ${PINNED_NAME}`, exact: true })
  ).toBeVisible()
  await pageHydrated(page)
  expect(watch.pageErrors).toEqual([])
})
