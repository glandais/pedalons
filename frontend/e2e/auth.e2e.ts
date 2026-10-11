import type { Page, Route } from '@playwright/test'
import type { UserDto } from '../src/api/dto'
import { apiGet, expectOk, loginWithPassword, withApi } from './support/api'
import { newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { meFromSession, sessionCookie } from './support/flow-account'
import { stack } from './support/stack'
import { hydrated, mainNavLink, watchToasts } from './support/ui'

/**
 * Session refresh, as two tabs — or the SSR server and the browser — do it: at the same moment, on
 * the same session. Every one of them used to fail but one, with a 500 (AuthService.refreshToken
 * updated the User row, whose @Version collided; fixed 2026-09-25). Since the token rotates
 * (docs/LEDGER_*.md SEC-27), exactly one of them gets a new token; the others fall inside the grace
 * of that rotation and get an access token without one.
 */
test('concurrent refreshes of one session all succeed', async () => {
  const user = await newUser('auth concurrent refresh')
  const statuses = await Promise.all(
    Array.from({ length: 8 }, () =>
      fetch(`${stack.baseURL}/api/auth/refresh`, {
        method: 'POST',
        headers: { 'X-Refresh-Token': user.refreshToken },
      }).then((response) => response.status)
    )
  )
  expect(statuses).toEqual(Array(8).fill(200))
})

/**
 * The server render refreshes the session of every document it renders, and the refresh rotates
 * the token (docs/LEDGER_*.md SEC-27): the document must hand the browser its new cookie. Kept from
 * it, the browser would present the old token again on its next document — refreshed without a new
 * token within the rotation's minute, rotated again from the old one after it (docs/LEDGER_*.md
 * API-94).
 */
test('each server-rendered document hands the browser its rotated session cookie', async ({
  page,
}) => {
  const user = await newUser('auth rotated cookie')
  await signIn(page.context(), user)
  const before = await sessionCookie(page.context())

  await page.goto('/profil')
  await expect(
    page.getByRole('main').getByRole('heading', { name: 'Profil', exact: true })
  ).toBeVisible()
  const first = await sessionCookie(page.context())
  expect(first, 'the document rotated the cookie').not.toBe(before)

  await page.reload()
  await expect(
    page.getByRole('main').getByRole('heading', { name: 'Profil', exact: true })
  ).toBeVisible()
  expect(await sessionCookie(page.context()), 'and the next one again').not.toBe(first)
  // The browser's current token is the session's: it refreshes, and rotates in turn.
  expect((await meFromSession(page.context())).id).toBe(user.user.id)
})

/**
 * The browser's side of an expired access token (axiosInstance.ts, the response interceptor): a
 * 401 is answered by one POST /api/auth/refresh with the session cookie, then the request is
 * replayed with the new token — invisibly. The access token lives 15 minutes, so the tests make the
 * API answer 401 through `page.route` rather than wait; everything else is the real backend.
 */
test.describe('an access token refused by the API', () => {
  /** Every POST /api/auth/refresh the page sends, and what the backend answered. */
  function watchRefreshes(page: Page) {
    const answers: { status: number; accessToken?: string }[] = []
    page.on('response', async (response) => {
      if (!response.url().endsWith('/api/auth/refresh')) return
      const body = response.ok() ? ((await response.json()) as { accessToken: string }) : undefined
      answers.push({ status: response.status(), accessToken: body?.accessToken })
    })
    return answers
  }

  /**
   * Answers 401 — as the backend does for an expired token — to the first `times` requests to
   * `url` with `method`; lets every later one through. Returns the Authorization header each
   * request carried.
   */
  async function refuseOnce(page: Page, url: string, method: string, times = 1) {
    const seen: (string | undefined)[] = []
    let refused = 0
    await page.route(url, async (route) => {
      const request = route.request()
      if (request.method() !== method) return route.fallback()
      seen.push((await request.headerValue('authorization')) ?? undefined)
      if (refused < times) {
        refused++
        return route.fulfill({ status: 401, contentType: 'application/json', body: '{}' })
      }
      return route.fallback()
    })
    return seen
  }

  /** Signs a fresh user in and opens the profile's preferences, hydrated, on the units control. */
  async function openUnits(page: Page, label: string) {
    const user = await newUser(label)
    await signIn(page.context(), user)
    await page.goto('/profil/preferences')
    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: 'Préférences', exact: true })).toBeVisible()
    const imperial = main.getByRole('radio', { name: 'Impérial (mi, ft)' })
    await hydrated(imperial)
    return { user, main, imperial }
  }

  test('one refused call is refreshed once and replayed, with no error shown', async ({ page }) => {
    const { user, main, imperial } = await openUnits(page, unique('Jeton expiré'))
    const refreshes = watchRefreshes(page)
    const saves = await refuseOnce(page, '**/api/users/me', 'PUT')
    const shown = await watchToasts(page)

    const saved = page.waitForResponse(
      (r) => r.request().method() === 'PUT' && r.url().endsWith('/api/users/me') && r.ok()
    )
    await main.getByText('Impérial (mi, ft)', { exact: true }).click()
    await saved
    await expect(imperial).toBeChecked()

    expect(saves, 'the save, then its replay').toHaveLength(2)
    expect(refreshes).toHaveLength(1)
    expect(refreshes[0].status).toBe(200)
    expect(saves[1], 'the replay carries the refreshed token').toBe(
      `Bearer ${refreshes[0].accessToken}`
    )
    expect((await meFromSession(user)).unitSystem).toBe('IMPERIAL')
    // What any save of the profile says — no error, no « session expired ».
    expect(await shown()).toEqual(['Profil mis à jour avec succès'])
    await expect(page).toHaveURL(/\/profil\/preferences$/)
  })

  test('a revoked session sends the user back to the login form', async ({ page }) => {
    const { user, main } = await openUnits(page, unique('Session révoquée'))
    // Signed out elsewhere (another device, « log out everywhere »): the refresh token is dead,
    // the access token in the page is still good — until the API refuses it. The browser's own
    // session, not the test's: signIn() gives it one of its own.
    const browserSession = await sessionCookie(page.context())
    await withApi(undefined, async (api) =>
      expectOk(
        await api.post('/api/auth/logout', { headers: { 'X-Refresh-Token': browserSession! } })
      )
    )
    const refreshes = watchRefreshes(page)
    await refuseOnce(page, '**/api/users/me', 'PUT')

    await main.getByText('Impérial (mi, ft)', { exact: true }).click()
    await expect(main.getByRole('heading', { name: /^Bienvenue sur / })).toBeVisible()
    // Sent to the form with the page it was on, to come back to it once signed in again.
    await expect(page).toHaveURL(/\/(login|connexion)\?next=%2Fprofil%2Fpreferences$/)
    expect(refreshes.map((r) => r.status)).toEqual([403])
    // A protected page stays closed to the dead session, and nothing was saved.
    await page.goto('/profil')
    await expect(main.getByRole('heading', { name: /^Bienvenue sur / })).toBeVisible()
    const again = await loginWithPassword(user.user.email, user.password)
    expect((await apiGet<UserDto>(again, '/api/users/me')).unitSystem ?? 'METRIC').toBe('METRIC')
  })

  test('two calls refused together share one refresh, and both are replayed', async ({ page }) => {
    const user = await newUser(unique('Deux refus'))
    await signIn(page.context(), user)
    await page.goto('/')
    const main = page.getByRole('main')

    // The personal calendar loads two things at once, client-side: its events and its feed URL.
    const events = '**/api/calendar/events?*'
    const token = '**/api/calendar/token'
    const held: { route: Route; url: string }[] = []
    const seen: { url: string; authorization: string | undefined }[] = []
    let refused = 0
    /** Holds the first call of each until both have arrived, then refuses them together. */
    const handler = async (route: Route) => {
      const request = route.request()
      seen.push({
        url: request.url(),
        authorization: (await request.headerValue('authorization')) ?? undefined,
      })
      if (refused >= 2) return route.fallback()
      refused++
      held.push({ route, url: request.url() })
      if (held.length === 2)
        await Promise.all(
          held.map(({ route }) =>
            route.fulfill({ status: 401, contentType: 'application/json', body: '{}' })
          )
        )
    }
    await page.route(events, handler)
    await page.route(token, handler)
    const refreshes = watchRefreshes(page)
    const shown = await watchToasts(page)

    const calendar = await mainNavLink(page, 'Calendrier')
    await calendar.click()
    await expect(page).toHaveURL(/\/calendrier$/)
    const field = main.getByRole('textbox', { name: 'URL du flux global' })
    await expect(field).toHaveValue(/\/api\/calendar\/ics\?token=/)

    expect(refreshes, 'one refresh for both').toHaveLength(1)
    expect(seen.filter((s) => s.url.includes('/api/calendar/events'))).toHaveLength(2)
    expect(seen.filter((s) => s.url.endsWith('/api/calendar/token'))).toHaveLength(2)
    const replays = [seen[2], seen[3]]
    for (const replay of replays)
      expect(replay.authorization).toBe(`Bearer ${refreshes[0].accessToken}`)
    expect(await shown()).toEqual([])
  })
})
