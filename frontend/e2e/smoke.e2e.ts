import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { parse } from 'yaml'
import { roleSession, signIn } from './support/data'
import { as, expect, test } from './support/fixtures'
import { escapeRegExp, hydrated, pageHydrated, watchHydration } from './support/ui'

/**
 * What routes-render.e2e.ts, which opens every route as every role, does not cover: the server
 * rendering on its own, and a signed-in visitor kept out of the platform admin area. If these fail,
 * look at the stack before looking at the feature under test.
 */

test.describe('anonymous, without JavaScript', () => {
  test.use({ javaScriptEnabled: false })

  test('a public team page is rendered by the server', async ({ page, seed }) => {
    const response = await page.goto(`/equipes/${seed.team.slug}`)
    expect(response?.status()).toBe(200)
    await expect(page.getByRole('heading', { level: 1, name: seed.team.name })).toBeVisible()
  })
})

test.describe('keyboard', () => {
  // WCAG 2.4.1: the skip link is the page's first stop, and it lands on <main>.
  test('the first Tab reaches the skip link, which moves focus to the main content', async ({
    page,
    seed,
  }) => {
    await page.goto(`/equipes/${seed.team.slug}`)
    await pageHydrated(page)

    await page.keyboard.press('Tab')
    const skip = page.getByRole('link', { name: 'Aller au contenu principal' })
    await expect(skip).toBeFocused()
    await expect(skip).toBeInViewport()

    await page.keyboard.press('Enter')
    await expect(page.getByRole('main')).toBeFocused()
  })
})

test.describe('rider', () => {
  test.use(as('rider'))

  test('the platform admin area is still off limits', async ({ page }) => {
    await page.goto('/plateforme')
    // Sent home, and the home page is up: the session is a real one, not an anonymous visit.
    await expect(page).toHaveURL(/\/$/)
    await expect(
      page.getByRole('main').getByRole('heading', { name: 'Dernières publications' })
    ).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Administration plateforme' })).toHaveCount(0)
  })
})

test.describe('an unknown URL', () => {
  // The router's '*' catch-all renders NotFoundPage, and entry-server.tsx turns that match into a
  // real 404 status — a crawler must not index a « Page non trouvée » as a page.
  for (const path of ['/inconnu', '/equipes/{team}/inconnu', '/plateforme/inconnu'])
    test(`${path} answers 404 with a usable page that leads home`, async ({ page, seed }) => {
      const url = path.replace('{team}', seed.team.slug)
      const { pageErrors, hydrationErrors } = await watchHydration(page)

      const response = await page.goto(url)
      expect(response?.status(), `${url}: document status`).toBe(404)
      await pageHydrated(page)
      const main = page.getByRole('main')
      await expect(main.getByRole('heading', { level: 1, name: '404', exact: true })).toBeVisible()
      await expect(main.getByText('Page non trouvée', { exact: true })).toBeVisible()
      expect(new URL(page.url()).pathname, 'the URL stays as typed').toBe(url)

      // The app is live around it: the link home works in place.
      const back = main.getByRole('link', { name: "Retour à l'accueil" })
      await expect(back).toHaveAttribute('href', '/')
      await hydrated(back)
      await back.click()
      await expect(page).toHaveURL(/\/$/)
      await expect(main.getByRole('heading', { name: 'Dernières publications' })).toBeVisible()

      expect(pageErrors, `${url}: uncaught errors`).toEqual([])
      expect(hydrationErrors, `${url}: hydration errors`).toEqual([])
    })
})

/**
 * Universal links (docs/APP_LINKS.md): iOS reads `/.well-known/apple-app-site-association`, Android
 * `/.well-known/assetlinks.json`, both served by server.js as JSON (the AASA has no extension, so
 * its content type is set by hand — server.js:92-104). The AASA's paths are generated from
 * contracts/routes.yaml (`deeplink: true`, every locale, `{param}` as `*`) by
 * scripts/generate-routes.mjs; a route added to the contract without regenerating is a link the app
 * never receives.
 */
test.describe('app links', () => {
  interface DeeplinkRoute {
    id: string
    path: string | Record<string, string>
    params?: string[]
    web?: boolean
    deeplink?: boolean
  }
  const contractRoutes = () =>
    (
      parse(
        readFileSync(fileURLToPath(new URL('../../contracts/routes.yaml', import.meta.url)), 'utf8')
      ) as { routes: DeeplinkRoute[] }
    ).routes
  /** Every locale's path of a route, its params as `*`, as the generator writes them. */
  const patterns = (route: DeeplinkRoute) =>
    Object.values(typeof route.path === 'string' ? { en: route.path } : route.path).map((path) =>
      (route.params ?? []).reduce((acc, param) => acc.split(`{${param}}`).join('*'), path)
    )

  test('the apple-app-site-association is JSON and lists every deeplink path of the contract', async ({
    request,
  }) => {
    const response = await request.get('/.well-known/apple-app-site-association')
    expect(response.status()).toBe(200)
    expect(response.headers()['content-type']).toMatch(/^application\/json/)
    const aasa = (await response.json()) as {
      applinks: { details: { appID: string; paths: string[] }[] }
      webcredentials?: { apps: string[] }
    }
    const [detail] = aasa.applinks.details
    expect(detail.appID).toMatch(/^\w+\.fr\.pedalons\.mobile$/)
    // Passkeys: the same app may use this site's credentials.
    expect(aasa.webcredentials?.apps).toContain(detail.appID)

    const deeplinks = contractRoutes().filter((route) => route.deeplink)
    const expected = [...new Set(deeplinks.flatMap(patterns))]
    expect(expected, 'the contract declares deeplinks').toContain('/equipes/*/sorties/*')
    // Pages without an app screen are excluded first (`NOT …`, docs/LEDGER_*.md MOB-58): the
    // first matching entry wins, and a deeplink wildcard would otherwise capture them.
    const exclusions = detail.paths.filter((path) => path.startsWith('NOT '))
    expect(detail.paths.slice(0, exclusions.length)).toEqual(exclusions)
    expect(detail.paths.slice(exclusions.length).sort()).toEqual(expected.sort())
    // `*` crosses `/` in the AASA: no exclusion may cover a deeplink's own path.
    const matches = (pattern: string, path: string) =>
      new RegExp(
        `^${pattern
          .split('*')
          .map((part) => part.replace(/[.+?^${}()|[\]\\]/g, '\\$&'))
          .join('.*')}$`
      ).test(path)
    for (const deeplink of expected) {
      const sample = deeplink.split('*').join('x')
      for (const exclusion of exclusions) {
        expect(matches(exclusion.slice('NOT '.length), sample), `${exclusion} vs ${sample}`).toBe(
          false
        )
      }
    }
  })

  test('assetlinks.json is JSON and hands the Android app its links and the credentials', async ({
    request,
  }) => {
    const response = await request.get('/.well-known/assetlinks.json')
    expect(response.status()).toBe(200)
    expect(response.headers()['content-type']).toMatch(/^application\/json/)
    const statements = (await response.json()) as {
      relation: string[]
      target: { namespace: string; package_name: string; sha256_cert_fingerprints: string[] }
    }[]
    const app = statements.find((s) => s.target.package_name === 'fr.pedalons.mobile')
    expect(app?.target.namespace).toBe('android_app')
    expect(app?.relation).toEqual(
      expect.arrayContaining([
        'delegate_permission/common.handle_all_urls',
        'delegate_permission/common.get_login_creds',
      ])
    )
    expect(app?.target.sha256_cert_fingerprints.length).toBeGreaterThan(0)
  })

  /**
   * The deeplinks with no web page (`web: false`): the app handles them, but the same link opened
   * where the app is not installed — a desktop, a phone without it — lands on the site.
   * Regression (6f702165): each redirects to the closest web page (`webFallback` in routes.yaml) —
   * sign-in, the profile, the team list, the team; before, each answered the « Page non trouvée »
   * 404, and /equipes/decouvrir was read as a team named « decouvrir ».
   */
  const landings: {
    path: (team: string) => string
    to: (team: string) => string
    signedIn: boolean
  }[] = [
    { path: () => '/inscription', to: () => '/connexion', signedIn: false },
    { path: () => '/equipes/decouvrir', to: () => '/equipes', signedIn: true },
    // /equipes/{team}/membres left this list with WEB-1, /profil/participations with the profile
    // redesign (now /profil/sorties): both are web pages now.
  ]
  for (const landing of landings) {
    const label = landing.path('{team}')
    test(`the app-only deeplink ${label} lands on a web page, not a 404`, async ({
      page,
      context,
      seed,
    }) => {
      // The rider is a member of the seeded team.
      if (landing.signedIn) await signIn(context, await roleSession('rider'))
      const path = landing.path(seed.team.slug)
      const response = await page.goto(path)
      await pageHydrated(page)
      await expect(
        page.getByRole('main').getByText('Page non trouvée', { exact: true })
      ).toHaveCount(0)
      expect(response?.status(), `${path}: status`).toBeLessThan(400)
      await expect(page).toHaveURL(new RegExp(`${escapeRegExp(landing.to(seed.team.slug))}(\\?|$)`))
    })
  }
})
