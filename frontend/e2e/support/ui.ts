import { expect, test, type Browser, type Locator, type Page } from '@playwright/test'
import type { AuthResponse } from './api'
import { signIn } from './data'

/**
 * Browser-side helpers shared by the journeys: waiting for hydration, recording what the page
 * showed or threw away while a retrying assertion was not looking, a second browser for another
 * user, and the locators every screen shares.
 */

/**
 * Waits until React has hydrated `locator`'s element — i.e. a click on it reaches its handler. The
 * pages are server-rendered, so a control is on screen (and clickable for Playwright) before that,
 * and a click or keystroke in that window is lost.
 *
 * Two signals, both needed. React marks every node it adopts with a `__reactProps$…` key — but
 * while the hydration render is still in progress, before its commit, and a click in between is
 * dropped, not replayed (docs/LEDGER_*.md WEB-35: 3 lost clicks in 40 on a loaded stack, all on a
 * not yet committed fiber). `<html data-hydrated>` is set by HydrationMarker (entry-client.tsx) once that commit is
 * done. The key still matters for an element rendered later, in a lazy part of the page.
 */
export async function hydrated(locator: Locator) {
  await expect
    .poll(
      () =>
        locator.evaluate(
          (element) =>
            document.documentElement.dataset.hydrated === 'true' &&
            Object.keys(element).some((key) => key.startsWith('__reactProps'))
        ),
      { timeout: 15_000 }
    )
    .toBe(true)
}

/**
 * Waits until the app has taken over the server markup (its first render committed) and settled
 * its first fetches.
 */
export async function pageHydrated(page: Page) {
  // The container key is set as soon as hydrateRoot is called, long before the markup is React's:
  // the commit marker (HydrationMarker, WEB-35) is what says the app has taken over.
  await page.waitForFunction(() => document.documentElement.dataset.hydrated === 'true')
  await page.waitForLoadState('networkidle')
}

/**
 * Records, from before the first byte is parsed, every console `[hydration]` error (first line),
 * every uncaught page error, and every DOM removal of a node holding one of `markers` — a mismatch
 * makes React throw the server subtree away and client-render it, which is exactly the flicker to
 * rule out. Call it before `goto`.
 */
export async function watchHydration(page: Page, markers: string[] = []) {
  const hydrationErrors: string[] = []
  const pageErrors: string[] = []
  page.on('pageerror', (error) => pageErrors.push(error.message))
  page.on('console', (message) => {
    if (message.type() === 'error' && message.text().includes('[hydration]'))
      hydrationErrors.push(message.text().split('\n')[0])
  })
  await page.addInitScript((watched: string[]) => {
    const removed: string[] = []
    ;(window as unknown as { __e2eRemoved: string[] }).__e2eRemoved = removed
    new MutationObserver((records) => {
      for (const record of records)
        for (const node of record.removedNodes)
          for (const marker of watched) if (node.textContent?.includes(marker)) removed.push(marker)
    }).observe(document, { childList: true, subtree: true })
  }, markers)
  return {
    hydrationErrors,
    pageErrors,
    removed: () =>
      page.evaluate(() => (window as unknown as { __e2eRemoved: string[] }).__e2eRemoved),
  }
}

/**
 * What the prefetch audit (src/lib/prefetchAudit.ts) said about the first load: `covered` when the
 * SSR cache held every query the page fetched, `gaps` when it did not, `discarded` when the route
 * changed before it settled — a redirect, which measured nothing.
 */
export interface PrefetchAudit {
  verdict: 'covered' | 'gaps' | 'discarded'
  /** The audit's own console line: for `gaps`, the query keys the route's `prefetch` missed. */
  text: string
}

/**
 * Records the prefetch audit's verdict on the next page load. Call it before `goto`; `result()`
 * then waits for the verdict, which the audit logs 5 s after the client router started. Needs a frontend built with FRONTEND_PREFETCH_AUDIT=true, which `.env.e2e` sets.
 */
export function watchPrefetchAudit(page: Page) {
  let audit: PrefetchAudit | undefined
  page.on('console', (message) => {
    const text = message.text()
    if (audit || !text.startsWith('[prefetch-audit] route')) return
    if (text.includes('changed before settling')) audit = { verdict: 'discarded', text }
    else if (text.includes('not covered by route prefetch')) audit = { verdict: 'gaps', text }
    else if (text.includes('all queries were covered')) audit = { verdict: 'covered', text }
  })
  return {
    async result(): Promise<PrefetchAudit> {
      await expect
        .poll(() => audit !== undefined, {
          message:
            'no [prefetch-audit] verdict — was the frontend image built with ' +
            'FRONTEND_PREFETCH_AUDIT=true (scripts/e2e.sh build frontend)?',
          timeout: 20_000,
        })
        .toBe(true)
      return audit!
    },
  }
}

/** The global toasts (Mantine Notifications) — apiClient shows one for every coded API error. */
export const toasts = (page: Page) => page.locator('.mantine-Notification-root')

/**
 * Records the text of every global toast mounted from now on, on the current document; returns a
 * reader. Use it to prove *no* toast was shown: a retrying `toHaveCount(0)` passes vacuously, since
 * it simply waits for the toast to auto-close (4 s) within its own 5 s timeout.
 */
export async function watchToasts(page: Page): Promise<() => Promise<string[]>> {
  await page.evaluate(() => {
    const w = window as unknown as { __toastTexts: string[] }
    w.__toastTexts = []
    const record = (node: Node) => {
      if (!(node instanceof HTMLElement)) return
      const found = node.matches('.mantine-Notification-root')
        ? [node]
        : Array.from(node.querySelectorAll<HTMLElement>('.mantine-Notification-root'))
      for (const toast of found) w.__toastTexts.push(toast.textContent ?? '')
    }
    new MutationObserver((mutations) => {
      for (const m of mutations) m.addedNodes.forEach(record)
    }).observe(document.body, { childList: true, subtree: true })
  })
  return () => page.evaluate(() => (window as unknown as { __toastTexts: string[] }).__toastTexts)
}

/** `text` with every RegExp metacharacter escaped, to match it literally. */
export const escapeRegExp = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

/** A RegExp matching `text` literally at the start of a name. */
export const startsWith = (text: string) => new RegExp(`^${escapeRegExp(text)}`)

/**
 * The card of an entity in a list or a feed (a ride, a post, a route, a team, an ad): every one is a
 * link holding the entity's name. Names are unique per test, so a second match is a strict-mode
 * error, not a guess.
 */
export const entityCard = (scope: Locator, name: string) =>
  scope.getByRole('link').filter({ hasText: name })

/**
 * The publications feed of the home page — its own region, named by its heading (« Dernières
 * publications », « Dernières publications publiques » for a visitor). The member home's « Cette
 * semaine » rows link to the same rides, so a ride's feed card is looked for in here, not in the
 * whole `main`.
 */
export const homeFeed = (page: Page) =>
  page.getByRole('main').getByRole('region', { name: 'Dernières publications' })

/**
 * The chevron that opens a detail page's other actions (publish, cancel, delete…), next to
 * « Modifier »: « Options de gestion ». Not to be confused with the moderation menu (report, block),
 * « Plus d'actions », shown when the page's or a comment's author is someone else.
 */
export const actionsMenu = (page: Page) =>
  page.getByRole('main').getByRole('button', { name: 'Options de gestion', exact: true })

/** Opens the actions menu of a detail page, once hydrated; returns the menu. */
export async function openActionsMenu(page: Page) {
  const chevron = actionsMenu(page)
  await hydrated(chevron)
  await chevron.click()
  return page.getByRole('menu')
}

/**
 * A second browser, signed in as `auth` (anonymous when undefined), with the device, locale and
 * time zone of the running test's project — a bare `browser.newContext()` would fall back to a
 * desktop viewport on the mobile project. Close its `context` when done.
 */
export async function pageAs(browser: Browser, auth: AuthResponse | undefined) {
  const { viewport, userAgent, deviceScaleFactor, isMobile, hasTouch, locale, timezoneId } =
    test.info().project.use
  const context = await browser.newContext({
    viewport,
    userAgent,
    deviceScaleFactor,
    isMobile,
    hasTouch,
    locale,
    timezoneId,
  })
  if (auth) await signIn(context, auth)
  return { context, page: await context.newPage() }
}

/**
 * A link of the site's main navigation (Fil, Équipes, Calendrier, Explorer, Fonctionnalités —
 * MainNav.tsx), hydrated and ready to click: the header's on desktop, the burger's drawer on mobile,
 * which this opens. On desktop the collapsed drawer holds a second copy, hence the scoping.
 */
export async function mainNavLink(page: Page, name: string): Promise<Locator> {
  if (!test.info().project.use.isMobile) {
    const link = page
      .getByRole('navigation', { name: 'Navigation principale' })
      .getByRole('link', { name, exact: true })
    await hydrated(link)
    return link
  }
  const burger = page.getByRole('banner').getByRole('button', { name: 'Ouvrir le menu' })
  await hydrated(burger)
  await burger.click()
  const link = page
    .getByRole('navigation')
    .filter({ has: page.getByRole('combobox') })
    .getByRole('link', { name, exact: true })
  await expect(link).toBeInViewport()
  await hydrated(link)
  return link
}
