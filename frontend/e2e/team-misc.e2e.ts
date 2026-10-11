import type { Page } from '@playwright/test'
import type { UserPreferencesRequest } from '../src/api/dto'
import { apiPatch } from './support/api'
import { getTeam, newTeam, newUser, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { stack } from './support/stack'
import { hydrated, pageHydrated, watchHydration } from './support/ui'

/**
 * Three loose items of the ledger: the team page's vertical budget (docs/LEDGER_*.md WEB-18), and two notes of
 * its former « A classifier » section (entries closed on 2026-09-25) — the team settings page loaded directly through SSR, and a saved language
 * preference winning over the browser's.
 */

test.describe('team page at 1440×900', () => {
  test.use({ viewport: { width: 1440, height: 900 } })

  // The criterion is a desktop one (T3.6 of docs/plans/archive/2026-07-26-web-portage-mobile-v2.md);
  // the mobile project would emulate a phone behind the 1440 px viewport.
  test.skip(({ isMobile }) => isMobile, 'desktop criterion')

  // T3.6 aimed at 220 px; the page settled at ~283 px (from ~300 before the port): header (60) +
  // breadcrumb + team header (avatar lg, h1) + NavButtons (40 px square *plus* a label line, ~78 px
  // — NavButtons.tsx) + the Stack gaps of TeamLayout.tsx. Reaching 220 would mean redesigning the
  // team nav, which was judged out of scope (2026-09-25): this pins today's budget so it doesn't grow.
  test('the first content element starts less than 300 px from the top', async ({
    context,
    page,
  }) => {
    const owner = await newUser('team-misc layout owner')
    // Not `unique()`: its worker index and counter vary the name's length, and at ~40 characters the
    // h1, badge and buttons no longer fit on one line — the header wraps and the budget gains 32 px.
    // The base-36 timestamp keeps it unique at a fixed length (8 characters until 2059).
    const team = await newTeam(owner, `Budget vertical ${Date.now().toString(36)}`)
    await signIn(context, owner)

    await page.goto(`/equipes/${team.slug}/agenda`)
    await expect(
      page.getByRole('heading', { level: 1, name: team.name }),
      'precondition: the team page is rendered'
    ).toBeVisible()
    // The team's own tabs, then the page content: TeamLayout renders the content right after them.
    const tabs = page.getByRole('navigation', { name: "Navigation de l'équipe" })
    const content = tabs.locator('xpath=following-sibling::div[1]')
    await expect(
      content.getByRole('heading', { level: 2, name: 'Agenda' }),
      'precondition: the block measured is the page content, right after the team tabs'
    ).toBeVisible()

    const box = await content.boundingBox()
    expect(box, 'precondition: the content block is laid out').not.toBeNull()
    expect(box!.y).toBeLessThan(300)
  })
})

test.describe('team settings loaded directly', () => {
  test('the owner gets a working settings form from a document request', async ({
    context,
    page,
  }) => {
    const owner = await newUser('team-misc settings owner')
    const team = await newTeam(owner, unique('Réglages directs'), {
      media: {
        markdown: 'Nous roulons **le dimanche** matin.',
        assets: { images: [], attachments: [] },
      },
    })
    await signIn(context, owner)
    const { hydrationErrors, pageErrors } = await watchHydration(page)

    const response = await page.goto(`/equipes/${team.slug}/admin/parametres`)
    expect(response?.status()).toBe(200)
    // Rendered by the server, for the owner: the form itself, not a spinner or a redirect.
    const html = await response!.text()
    expect(html).toContain('Gérer le profil et les paramètres de votre équipe')
    expect(html).toContain('le dimanche')
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/admin/parametres$`))
    await expect(
      page.getByRole('heading', { level: 2, name: "Paramètres de l'équipe" })
    ).toBeVisible()
    const name = page.getByRole('textbox', { name: "Nom de l'équipe" })
    await expect(name).toHaveValue(team.name)
    await expect(page.getByText('le dimanche', { exact: false })).toBeVisible()

    // And it works once hydrated: a rename is saved and lands on the renamed team.
    await hydrated(name)
    const renamed = unique('Renommée')
    await name.fill(renamed)
    const form = page.locator('form').filter({ has: name })
    await form.getByRole('button', { name: 'Enregistrer' }).click()
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}$`))
    await expect(page.getByRole('heading', { level: 1, name: renamed })).toBeVisible()

    expect((await getTeam(owner, team.slug)).name).toBe(renamed)
    expect(pageErrors).toEqual([])
    expect(hydrationErrors).toEqual([])
  })
})

test.describe('saved language preference', () => {
  test.describe('in a French browser that picked French before', () => {
    // The `lang` cookie a previous anonymous choice of French leaves (LanguageSwitcher). The
    // server resolves the signed-in user's preference first, the cookie second, Accept-Language
    // last — so the saved preference must win over both.
    test.use({
      locale: 'fr-FR',
      storageState: {
        cookies: [
          {
            name: 'lang',
            value: 'fr',
            domain: new URL(stack.baseURL).hostname,
            path: '/',
            expires: -1,
            httpOnly: false,
            secure: false,
            sameSite: 'Lax',
          },
        ],
        origins: [],
      },
    })

    test('a signed-in user who saved English gets English', async ({ context, page }) => {
      const user = await newUser('team-misc english')
      const preferences: UserPreferencesRequest = { language: 'en' }
      await apiPatch(user, '/api/users/me/preferences', preferences)
      await signIn(context, user)

      const response = await page.goto('/')
      expect(response?.status()).toBe(200)
      // The server already renders in the saved language…
      expect(await response!.text()).toMatch(/<html[^>]*\slang="en"/)
      // …and the hydrated app keeps it.
      await pageHydrated(page)
      await expect(page.locator('html')).toHaveAttribute('lang', 'en')
      await expect(languageSelect(page, 'Language')).toHaveValue('en')
      // The member home's greeting.
      await expect(page.getByRole('heading', { level: 1, name: /^Hello\b/ })).toBeVisible()
    })
  })

  // An anonymous visitor has no backend preference: the choice lives in the `lang` cookie, which
  // the SSR server reads before Accept-Language (it used to sit in localStorage, overwritten by
  // the detected language on every load — formerly an open ledger note, « A classifier », fixed 2026-09-25).
  test('an anonymous visitor who picked English keeps it on the next visit', async ({
    context,
    page,
  }) => {
    await page.goto('/')
    await pageHydrated(page)
    await expect(
      languageSelect(page, 'Langue'),
      'precondition: the page starts in French'
    ).toHaveValue('fr')
    await languageSelect(page, 'Langue').selectOption('en')
    await expect(
      languageSelect(page, 'Language'),
      'precondition: picking English switched the page'
    ).toHaveValue('en')
    await expect
      .poll(async () => (await context.cookies()).find((c) => c.name === 'lang')?.value, {
        message: 'precondition: the choice is saved in the lang cookie',
      })
      .toBe('en')

    await page.reload()
    await pageHydrated(page)
    // The page is back, whatever its language…
    await expect(
      // The visitor home's headline.
      page.getByRole('heading', { level: 1, name: /^(Organisez vos sorties|Organize your rides)/ }),
      'precondition: the home page is back after the reload'
    ).toBeVisible()
    // …and it is still English, already in the server's HTML.
    await expect(page.locator('html')).toHaveAttribute('lang', 'en')
    await expect(languageSelect(page, 'Language')).toHaveValue('en')
  })
})

/**
 * The header's language select. The layout renders two (header on desktop, drawer on mobile); the
 * one the current breakpoint hides is display:none, so the first *accessible* one is the live one.
 */
function languageSelect(page: Page, name: 'Langue' | 'Language') {
  return page.getByRole('combobox', { name }).first()
}
