import type { Page, Route } from '@playwright/test'
import type { AuthResponse } from './support/api'
import { newAd } from './support/ads'
import { newTeam, newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { newPost, postPath } from './support/posts'
import { newRide, ridePath } from './support/rides'
import { newRoute, newTrip, routePath, tripPath, windingTrack } from './support/routes'
import { hydrated, pageHydrated, watchToasts } from './support/ui'

/**
 * A 500 is not a « not found », and a 404 is read once (docs/plans/archive/2026-09-27-e2e-coverage-audit.md, P1).
 *
 * `QueryStateBoundary` tells three outcomes of a detail query apart: a recoverable error (5xx,
 * network) renders « Chargement impossible » with « Réessayer »; a 404 renders the page's own
 * « introuvable »; anything else renders the entity. `queryClient.ts` retries a 5xx (three times,
 * 1 s → 2 s → 4 s) but never a 4xx other than 401/408/429 — a missing entity is the server's final
 * answer.
 *
 * Every case runs on a **client navigation**: a document request is rendered by the SSR server,
 * whose API calls never cross the browser, so `page.route` could not fail them. The page starts on
 * the home feed, hydrated, then moves to the entity's URL as a `<PrefetchLink>` click would — a
 * history push the data router picks up (its loader runs the route's prefetch, then the page
 * mounts). Going through the router rather than clicking a card keeps the hover prefetch out of the
 * request count.
 *
 * Setup: a members-only team of a fresh user (its ADMIN), holding one entity of each kind.
 */

interface Target {
  kind: 'ride' | 'trip' | 'post' | 'route' | 'ad' | 'team'
  /** The entity's page. */
  path: (teamSlug: string, slug: string) => string
  /** The API resource the page reads the entity from. */
  api: (teamSlug: string, slug: string) => string
  /** The title of the page's « not found » state. */
  notFound: string
}

const TARGETS: Target[] = [
  {
    kind: 'ride',
    path: ridePath,
    api: (team, slug) => `/api/teams/${team}/rides/${slug}`,
    notFound: 'Sortie non trouvée',
  },
  {
    kind: 'trip',
    path: tripPath,
    api: (team, slug) => `/api/teams/${team}/trips/${slug}`,
    notFound: 'Voyage introuvable',
  },
  {
    kind: 'post',
    path: postPath,
    api: (team, slug) => `/api/teams/${team}/posts/${slug}`,
    notFound: 'Publication introuvable',
  },
  {
    kind: 'route',
    path: routePath,
    api: (team, slug) => `/api/teams/${team}/routes/${slug}`,
    notFound: 'Parcours introuvable',
  },
  {
    kind: 'ad',
    path: (team, slug) => `/equipes/${team}/annonces/${slug}`,
    api: (team, slug) => `/api/teams/${team}/classifieds/${slug}`,
    notFound: 'Annonce introuvable',
  },
  {
    kind: 'team',
    path: (team) => `/equipes/${team}`,
    api: (team) => `/api/teams/${team}`,
    // The team page has no « not found » state: an unknown team sends to the team list
    // (TeamUnavailable).
    notFound: '',
  },
]

const ERROR_TITLE = 'Chargement impossible'
const RETRY = 'Réessayer'

interface Setup {
  owner: AuthResponse
  teamSlug: string
  entities: Record<Target['kind'], { slug: string; name: string }>
}

let setup: Setup

test.beforeAll(async () => {
  const owner = await newUser('errors-owner')
  const team = await newTeam(owner, unique('Erreurs'))
  const [ride, trip, post, route, ad] = await Promise.all([
    newRide(owner, team.slug, unique('Sortie en panne')),
    newTrip(owner, team.slug, unique('Voyage en panne'), [{ name: unique('Étape') }]),
    newPost(owner, team.slug, unique('Article en panne')),
    newRoute(owner, team.slug, unique('Parcours en panne'), windingTrack(50)),
    newAd(owner, team.slug, { name: unique('Annonce en panne'), price: 10 }),
  ])
  setup = {
    owner,
    teamSlug: team.slug,
    entities: {
      ride: ride,
      trip: trip,
      post: post,
      route: route,
      ad: ad,
      team: { slug: team.slug, name: team.name },
    },
  }
})

test.beforeEach(async ({ context }) => {
  await signIn(context, setup.owner)
})

/**
 * Moves the hydrated app to `path` the way a `<Link>` does: a history push, which the data router
 * turns into a navigation (loader, then render) — no document request.
 */
async function clientNavigate(page: Page, path: string) {
  await page.evaluate((to) => {
    window.history.pushState(null, '', to)
    window.dispatchEvent(new PopStateEvent('popstate'))
  }, path)
}

/** Opens the home feed and waits until the app has taken over — the start of every case. */
async function startOnHome(page: Page) {
  await page.goto('/')
  await pageHydrated(page)
}

/** Counts the browser's GETs of exactly `apiPath` (no sub-resource, whatever the query string). */
function countReads(page: Page, apiPath: string) {
  let reads = 0
  page.on('request', (request) => {
    if (request.method() === 'GET' && new URL(request.url()).pathname === apiPath) reads += 1
  })
  return () => reads
}

const isPath = (apiPath: string) => (url: URL) => url.pathname === apiPath

/** A backend failure as GlobalExceptionMapper writes it. */
const fail500 = (route: Route) =>
  route.fulfill({ status: 500, json: { code: 'INTERNAL_ERROR', message: 'Internal error' } })

for (const target of TARGETS) {
  test.describe(`${target.kind}`, () => {
    // A 5xx goes through the retry cycle (1 + 2 + 4 s) — twice for the team today, see below.
    test.describe.configure({ timeout: 60_000 })

    test(`a 500 on the ${target.kind} shows « ${ERROR_TITLE} », and « ${RETRY} » loads it`, async ({
      page,
    }) => {
      // Regression (b43994e2): a failing team was taken for an unknown one — the team page
      // <Navigate>d to the team list instead of saying the server failed.

      const entity = setup.entities[target.kind]
      const apiPath = target.api(setup.teamSlug, entity.slug)
      const reads = countReads(page, apiPath)
      const matcher = isPath(apiPath)
      await page.route(matcher, fail500)
      await startOnHome(page)

      await clientNavigate(page, target.path(setup.teamSlug, entity.slug))

      const main = page.getByRole('main')
      const alert = main.getByRole('alert').filter({ hasText: ERROR_TITLE })
      // The server is named: a 500 is no lost connection (RL11).
      await expect(alert).toContainText("Le serveur n'a pas pu répondre", { timeout: 30_000 })
      if (target.notFound)
        await expect(main.getByRole('heading', { name: target.notFound })).toHaveCount(0)
      // Retried: a 5xx is worth another try, unlike a 404 — one cycle, the loader's: 1 + 3 retries
      // (see « requested once » below for the breadcrumb that used to run a second one).
      expect(reads()).toBe(4)

      // The backend is back: « Réessayer » reads the entity again, and the page shows it.
      await page.unroute(matcher)
      const readsBefore = reads()
      const retry = alert.getByRole('button', { name: RETRY })
      await hydrated(retry)
      await retry.click()
      await expect(main.getByRole('heading', { name: entity.name, exact: true })).toBeVisible()
      await expect(alert).toHaveCount(0)
      expect(reads()).toBeGreaterThan(readsBefore)
    })

    test(`an unknown ${target.kind} is requested once`, async ({ page }) => {
      // Regression (ee1871f8): useBreadcrumbData's observers abstain while the query is in error —
      // before, switching them to the entity's key (setOptions ignores retryOnMount) read again
      // what the loader had just failed: a 404 twice, a 500 through a second retry cycle.
      // The team is also read by useBreadcrumb's nav dropdowns, guarded the same way since 65903236.

      const slug = `absent-${Date.now().toString(36)}`
      const teamSlug = target.kind === 'team' ? slug : setup.teamSlug
      const reads = countReads(page, target.api(teamSlug, slug))
      await startOnHome(page)

      await navigateToUnknown(page, target, slug)

      expect(reads()).toBe(1)
    })

    test(`an unknown ${target.kind} shows its « not found » without a toast`, async ({ page }) => {
      // Regression (0d392613): a 404 on a GET shows no toast — the page says « introuvable » itself.

      const slug = `absent-${Date.now().toString(36)}`
      await startOnHome(page)
      const shown = await watchToasts(page)

      await navigateToUnknown(page, target, slug)

      expect(await shown()).toEqual([])
    })
  })
}

/**
 * Navigates to an entity that does not exist and waits until the page has settled on its answer: the
 * entity's « not found » state, or for a team, the team list it redirects to.
 */
async function navigateToUnknown(page: Page, target: Target, slug: string) {
  const teamSlug = target.kind === 'team' ? slug : setup.teamSlug
  await clientNavigate(page, target.path(teamSlug, slug))
  if (target.kind === 'team') {
    await expect(page).toHaveURL(/\/equipes$/)
  } else {
    await expect(
      page.getByRole('main').getByRole('heading', { name: target.notFound })
    ).toBeVisible()
    // Not an error: a 404 is final.
    await expect(page.getByRole('main').getByText(ERROR_TITLE)).toHaveCount(0)
  }
  await page.waitForLoadState('networkidle')
}
