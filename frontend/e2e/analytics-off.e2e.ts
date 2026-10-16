import { expect, test } from './support/fixtures'
import { hydrated, pageHydrated } from './support/ui'

/**
 * The e2e stack has neither the flag nor the service: `.env.e2e` leaves
 * PEDALONS_ANALYTICS_COUNT_PATH unset, so /api/config answers `analytics: null`, and
 * docker-compose.e2e.yml keeps goatcounter behind a profile e2e.sh never starts
 * (docs/plans/2026-10-15-web-analytics.md §3.7, docs/LEDGER_*.md WEB-90). Browsing must then send
 * no page view at all.
 *
 * What this proves is the stack's configuration end to end — no flag, nothing on the wire — not the
 * flag's own effect: two other guards of the sender also hold here and would keep /count silent on
 * their own, `navigator.webdriver` (true in a driven browser) and the loopback host (the stack is
 * `localhost`, its other sites `*.localhost`). Hiding `webdriver` would leave the second, and no
 * host of this stack escapes it. That the counter installs nothing without the flag is
 * pageViewCounter.test.ts's « without the analytics config ».
 */
test('no page view leaves when the deployment configures no counter', async ({ page, seed }) => {
  const counted: string[] = []
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === '/count') counted.push(request.url())
  })

  // The flag is off on this stack; if it ever is not, the absence below proves nothing.
  const config = await page.request.get('/api/config')
  expect(config.ok()).toBe(true)
  expect((await config.json()).analytics ?? null).toBeNull()

  await page.goto(`/equipes/${seed.team.slug}`)
  await pageHydrated(page)

  // A few client-side navigations, then a full load of another page and a back.
  // The footer link: a client-side navigation, not a document load.
  const privacy = page
    .getByRole('link', { name: 'Politique de confidentialité', exact: true })
    .last()
  await hydrated(privacy)
  await privacy.click()
  await expect(page).toHaveURL(/\/confidentialite$/)
  await expect(page.getByRole('heading', { name: "Mesure d'audience", exact: true })).toBeVisible()
  await page.goBack()
  await expect(page).toHaveURL(new RegExp(`/equipes/${seed.team.slug}$`))
  await page.goto('/outils-gpx')
  await pageHydrated(page)
  await page.goto('/une-adresse-inconnue')
  await pageHydrated(page)

  expect(counted).toEqual([])
})
