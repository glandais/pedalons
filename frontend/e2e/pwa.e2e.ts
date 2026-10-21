import type { Page, Request } from '@playwright/test'
import { PushPlatform, type ConfigDto, type PushDeviceRegistration } from '../src/api/dto'
import { apiGet, apiPost } from './support/api'
import { newUser, roleSession } from './support/data'
import {
  OTHER_HOST,
  OTHER_NAME,
  PINNED_HOST,
  PINNED_NAME,
  hostDocument,
  hostGet,
  otherDomain,
  pinnedAlias,
} from './support/domains'
import { headerControls, signOutFromHeader } from './support/flow-account'
import { expect, test, unique } from './support/fixtures'
import {
  WEB_PUSH_TOKEN_KEY,
  cacheNames,
  fireInstallPrompt,
  installPromptDouble,
  manifestOf,
  namedMeta,
  promptCount,
  waitForServiceWorker,
  watchFirebase,
} from './support/pwa'
import { authState, rawDocument, sessionCookie, ssrOutlet } from './support/ssr'
import { stack } from './support/stack'
import { hydrated, pageAs, pageHydrated, watchHydration } from './support/ui'

/**
 * The site installed as an app (a404b9ba, frontend/CLAUDE.md § « Installable site (PWA) and web
 * push »):
 *
 * - a service worker (`public/sw.js`) that caches nothing and has no `fetch` handler — the SSR HTML
 *   is per visitor and embeds an access token, so a worker serving pages would hand one member's
 *   session to the next person on that browser;
 * - a manifest built per domain by `server.js:125-154`, named after the site;
 * - install offers computed after hydration (`lib/install/useInstallOffer.ts`): the phone banner,
 *   the header's menu entry, the card of `/applications`;
 * - web push, off on this stack (no `FCM_WEB_*`: `ConfigDto.webPush` is absent) — so no push
 *   section and no Firebase — and the browser's token unregistered at sign-out
 *   (`store/authStore.ts:154-162`).
 *
 * A registered worker outlives its page within a browser context: every test that lets one
 * register opens a context of its own (`pageAs`).
 */

const LOCAL_HOST = new URL(stack.baseURL).hostname

/** The banner's message (`install.banner.message`) — no apostrophe, so it reads the same escaped. */
const BANNER_MESSAGE = 'Installez le site comme une application'

const installBanner = (page: Page) => page.getByRole('alert').filter({ hasText: BANNER_MESSAGE })

test.describe('the service worker', () => {
  test('/sw.js is served uncached and allowed to control the whole site', async ({ request }) => {
    const response = await request.get('/sw.js')
    expect(response.status()).toBe(200)
    const headers = response.headers()
    // server.js:115-123 — express.static would give it 31 days, and a browser would keep running a
    // stale worker for that long.
    expect(headers['cache-control']).toBe('no-cache')
    expect(headers['service-worker-allowed']).toBe('/')
    expect(headers['content-type']).toMatch(/^application\/javascript/)
  })

  test('controls the page yet serves nothing: reloads come from the network, and no cache is ever made', async ({
    browser,
  }) => {
    const { context, page } = await pageAs(browser, await roleSession('rider'))
    try {
      const fromWorker: string[] = []
      const workerRequests: string[] = []
      page.on('response', (response) => {
        if (response.fromServiceWorker()) fromWorker.push(response.url())
      })
      // Requests the worker makes itself — bar the browser's update check of its own script, which
      // Chromium attributes to the worker.
      context.on('request', (request) => {
        if (request.serviceWorker() && new URL(request.url()).pathname !== '/sw.js')
          workerRequests.push(request.url())
      })

      await page.goto('/')
      const scope = await waitForServiceWorker(page)
      expect(scope).toBe(`${stack.baseURL.replace(/\/$/, '')}/`)
      expect(context.serviceWorkers().map((worker) => new URL(worker.url()).pathname)).toEqual([
        '/sw.js',
      ])

      // Controlled from now on — and still every byte comes from the server.
      const reload = await page.reload()
      expect(reload?.fromServiceWorker()).toBe(false)
      expect(reload?.headers()['cache-control']).toContain('no-store')
      await pageHydrated(page)
      expect(await page.evaluate(() => navigator.serviceWorker.controller != null)).toBe(true)
      await page.goto('/applications')
      await pageHydrated(page)

      expect(fromWorker).toEqual([])
      expect(workerRequests).toEqual([])
      expect(await cacheNames(page)).toEqual([])
    } finally {
      await context.close()
    }
  })

  test("after one member signs out, the next one on that browser gets a page of their own, not the first one's", async ({
    browser,
    isMobile,
  }) => {
    const first = await newUser(unique('PWA premier'))
    const second = await newUser(unique('PWA second'))
    const { context, page } = await pageAs(browser, first)
    try {
      const before = await page.goto('/')
      expect(authState((await before?.text()) ?? '')?.user?.id).toBe(first.user.id)
      await waitForServiceWorker(page)
      await pageHydrated(page)

      await signOutFromHeader(page, isMobile, first.user.displayName)
      await expect(page).toHaveURL(/\/connexion$/)

      const main = page.getByRole('main')
      const submit = main.getByRole('button', { name: 'Se connecter', exact: true })
      await hydrated(submit)
      await main.getByRole('textbox', { name: 'Adresse e-mail' }).fill(second.user.email)
      await main.getByRole('textbox', { name: 'Mot de passe' }).fill(second.password)
      await submit.click()
      await expect(page).not.toHaveURL(/\/connexion$/)

      // The document the server renders now: the second member's, fetched from the network.
      const response = await page.reload()
      expect(response?.fromServiceWorker()).toBe(false)
      const html = (await response?.text()) ?? ''
      expect(authState(html)?.user?.id).toBe(second.user.id)
      expect(html).not.toContain(first.user.id)
      expect(html).not.toContain(first.user.displayName)
      expect(await cacheNames(page)).toEqual([])
    } finally {
      await context.close()
    }
  })
})

test.describe('the manifest', () => {
  test.beforeAll(async () => {
    await otherDomain()
    await pinnedAlias()
  })

  test('each site serves a manifest named after itself, and its pages link it', async () => {
    const localName = (await hostGet<ConfigDto>(LOCAL_HOST, undefined, '/api/config')).appName
    const sites = [
      { host: LOCAL_HOST, name: localName },
      { host: OTHER_HOST, name: OTHER_NAME },
      { host: PINNED_HOST, name: PINNED_NAME },
    ]
    expect(new Set(sites.map((site) => site.name)).size).toBe(sites.length)

    for (const { host, name } of sites) {
      const { headers, manifest } = await manifestOf(host)
      expect(headers['content-type'], host).toMatch(/^application\/manifest\+json/)
      // One URL, one body per host: a shared cache must key it on the host (server.js:147-152).
      expect(headers.vary, host).toMatch(/\bHost\b/)
      expect(headers.vary, host).toMatch(/\bX-Forwarded-Host\b/)
      expect(manifest.name, host).toBe(name)
      expect(manifest.short_name.length, host).toBeLessThanOrEqual(12)
      expect(name.startsWith(manifest.short_name.trim()), host).toBe(true)
      expect(manifest).toMatchObject({ id: '/', start_url: '/', scope: '/', display: 'standalone' })
      expect(manifest.icons.some((icon) => icon.purpose === 'maskable')).toBe(true)

      // The page links it, and names the iOS home-screen icon the same way (seo.ts).
      const document = await hostDocument(host, '/')
      expect(document.status, host).toBe(200)
      expect(document.html, host).toContain('<link rel="manifest" href="/manifest.webmanifest"')
      expect(namedMeta(document.html, 'apple-mobile-web-app-title'), host).toEqual([name])
    }
  })

  test('there is no static manifest beside it', async ({ request }) => {
    // A public/manifest.json would be served by express.static with the brand's name on every
    // site (frontend/CLAUDE.md).
    for (const path of ['/manifest.json', '/site.webmanifest']) {
      const response = await request.get(path, { maxRedirects: 0 })
      expect(response.headers()['content-type'] ?? '', path).not.toMatch(/manifest\+json|json/)
    }
  })
})

test.describe('the install offer', () => {
  test('on a phone, the banner appears once the browser offers to install, « Installer » opens its prompt, and a closed banner stays closed', async ({
    browser,
    isMobile,
  }) => {
    test.skip(!isMobile, 'the banner is hiddenFrom="sm" — phones only')
    const { context, page } = await pageAs(browser, undefined)
    try {
      await installPromptDouble(page)
      const watch = await watchHydration(page)
      await page.goto('/')
      await pageHydrated(page)
      // Nothing before the browser has offered anything: the offer is only known after hydration.
      await expect(installBanner(page)).toHaveCount(0)

      await fireInstallPrompt(page)
      const banner = installBanner(page)
      await expect(banner).toBeVisible()
      const appName = (await apiGet<ConfigDto>(undefined, '/api/config')).appName
      await expect(banner).toContainText(`${appName} sur votre écran d'accueil`)

      await banner.getByRole('button', { name: 'Installer', exact: true }).click()
      await expect.poll(() => promptCount(page)).toBe(1)
      // A prompt can be shown once: the offer goes with it.
      await expect(banner).toHaveCount(0)
      expect(watch.hydrationErrors).toEqual([])
      expect(watch.pageErrors).toEqual([])

      // A new visit, a new prompt: the banner is back — until it is closed.
      await page.reload()
      await pageHydrated(page)
      await fireInstallPrompt(page)
      await expect(installBanner(page)).toBeVisible()
      await installBanner(page).getByRole('button', { name: 'Ne plus proposer' }).click()
      await expect(installBanner(page)).toHaveCount(0)

      await page.reload()
      await pageHydrated(page)
      await fireInstallPrompt(page)
      // The drawer still offers it (the menu entry is not the banner)...
      const drawer = await headerControls(page, true)
      await expect(drawer.getByRole('link', { name: "Installer l'application" })).toBeVisible()
      // ...the banner does not.
      await expect(installBanner(page)).toHaveCount(0)
    } finally {
      await context.close()
    }
  })

  test('the server renders no install offer, signed in or not', async () => {
    const anonymous = await rawDocument('/')
    const signedIn = await rawDocument('/', { cookie: sessionCookie(await roleSession('rider')) })
    expect(authState(signedIn.html)?.user).not.toBeNull()
    for (const { html } of [anonymous, signedIn]) {
      const markup = ssrOutlet(html)
      expect(markup).not.toContain(BANNER_MESSAGE)
      expect(markup).not.toContain('Installer l')
    }
  })

  test("on a desktop, the account menu offers « Installer l'application », which leads to the apps page", async ({
    browser,
    isMobile,
  }) => {
    test.skip(isMobile, 'the account menu is the desktop header; the phone has the banner')
    const rider = await roleSession('rider')
    const { context, page } = await pageAs(browser, rider)
    try {
      await installPromptDouble(page)
      await page.goto('/')
      await pageHydrated(page)
      const account = page.getByRole('banner').getByRole('button', { name: rider.user.displayName })
      await hydrated(account)
      await account.click()
      await expect(page.getByRole('menuitem', { name: 'Se déconnecter' })).toBeVisible()
      await expect(page.getByRole('menuitem', { name: "Installer l'application" })).toHaveCount(0)
      await page.keyboard.press('Escape')

      await fireInstallPrompt(page)
      await account.click()
      // The entry lays out every app rather than picking one: it leads to /applications, whose
      // « Application web » card holds the prompt.
      await page.getByRole('menuitem', { name: "Installer l'application" }).click()
      await expect(page).toHaveURL(/\/applications$/)
      expect(await promptCount(page)).toBe(0)
      // No banner on a desktop layout, even with an offer.
      await expect(installBanner(page)).toBeHidden()
    } finally {
      await context.close()
    }
  })

  test('the « Application web » card of /applications installs through the prompt, and says how otherwise', async ({
    browser,
  }) => {
    const { context, page } = await pageAs(browser, undefined)
    try {
      await installPromptDouble(page)
      await page.goto('/applications')
      await pageHydrated(page)
      const main = page.getByRole('main')
      const card = main
        .locator('div')
        .filter({ has: page.getByRole('heading', { name: 'Application web', exact: true }) })
        .last()
      await expect(card).toContainText('Disponible')
      // No prompt from the browser: the card points to the browser's own menu.
      await expect(card).toContainText('Depuis le menu de votre navigateur')
      await expect(card.getByRole('button', { name: 'Installer' })).toHaveCount(0)

      await fireInstallPrompt(page, 'accepted')
      const install = card.getByRole('button', { name: 'Installer' })
      await expect(install).toBeVisible()
      await install.click()
      await expect.poll(() => promptCount(page)).toBe(1)
      await expect(card.getByRole('button', { name: 'Installer' })).toHaveCount(0)
      await expect(card).toContainText('Depuis le menu de votre navigateur')
    } finally {
      await context.close()
    }
  })
})

test.describe('web push, on a server without it', () => {
  test('the profile offers no push for this device, and no page loads Firebase', async ({
    browser,
  }) => {
    const config = await apiGet<ConfigDto>(undefined, '/api/config')
    expect(
      config.webPush ?? null,
      'the e2e stack has no FCM_WEB_* — ConfigDto.webPush must be absent'
    ).toBeNull()

    const { context, page } = await pageAs(browser, await roleSession('rider'))
    try {
      const firebase = watchFirebase(context)
      await page.goto('/')
      await pageHydrated(page)
      await page.goto('/profil/notifications')
      await pageHydrated(page)
      // The page itself is there (the rider's team gives it its mute switches)...
      const main = page.getByRole('main')
      await expect(main.getByRole('heading', { name: 'Notifications', exact: true })).toBeVisible()
      await expect(main.getByRole('heading', { name: 'Annonces des équipes' })).toBeVisible()
      // ...but not the « this device » block (WebPushSettings.tsx).
      await expect(main.getByRole('heading', { name: 'Sur cet appareil' })).toHaveCount(0)
      await page.goto('/applications')
      await pageHydrated(page)
      expect(firebase).toEqual([])
    } finally {
      await context.close()
    }
  })

  test('signing out unregisters the browser first, while the session still holds', async ({
    browser,
    isMobile,
  }) => {
    const user = await newUser(unique('PWA push'))
    const token = `e2e-web-${unique('token').replace(/[^A-Za-z0-9]/g, '-')}`
    await apiPost(user, '/api/push-devices', {
      token,
      platform: PushPlatform.WEB,
      deviceName: 'Chrome · e2e',
    } satisfies PushDeviceRegistration)

    const { context, page } = await pageAs(browser, user)
    try {
      const firebase = watchFirebase(context)
      const calls: Request[] = []
      page.on('request', (request) => {
        const { pathname } = new URL(request.url())
        if (pathname.startsWith('/api/push-devices') || pathname === '/api/auth/logout')
          calls.push(request)
      })
      await page.goto('/')
      await pageHydrated(page)
      // What enableWebPush leaves behind (webPush.ts:storeToken).
      await page.evaluate(
        ([key, value]) => localStorage.setItem(key, value),
        [WEB_PUSH_TOKEN_KEY, token]
      )

      // The token goes in the body, never in the URL the access log records (docs/LEDGER_*.md API-45).
      const unregistered = page.waitForResponse(
        (response) =>
          response.request().method() === 'POST' &&
          new URL(response.url()).pathname === '/api/push-devices/unregister'
      )
      await signOutFromHeader(page, isMobile, user.user.displayName)
      const response = await unregistered
      expect(response.status()).toBe(204)
      expect(response.request().headers().authorization).toMatch(/^Bearer /)
      expect(response.request().postDataJSON()).toEqual({ token })
      await expect(page).toHaveURL(/\/connexion$/)

      expect(calls.map((call) => `${call.method()} ${new URL(call.url()).pathname}`)).toEqual([
        'POST /api/push-devices/unregister',
        'POST /api/auth/logout',
      ])
      expect(await page.evaluate((key) => localStorage.getItem(key), WEB_PUSH_TOKEN_KEY)).toBeNull()
      expect(firebase).toEqual([])
    } finally {
      await context.close()
    }
  })
})
