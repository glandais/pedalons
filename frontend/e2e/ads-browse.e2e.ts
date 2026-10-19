import type { Locator, Page } from '@playwright/test'
import type { AdDto, AdEditDto, AssetDto } from '../src/api/dto'
import { getAd, newAd, solidPng, uploadImage } from './support/ads'
import { apiGet } from './support/api'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { stubBasemap } from './support/routes'
import { rawDocument, sessionCookie, ssrOutlet } from './support/ssr'
import { escapeRegExp, hydrated, pageAs, pageHydrated } from './support/ui'

/**
 * Ads, browsing — docs/LEDGER_*.md WEB-16 and WEB-17 (web): the detail page (gallery, approximate location, no
 * empty section) and the list's sort and price bounds living in the URL.
 *
 * Every test works in a team of its own, owned by a user of its own: the ads are team-visible, so
 * the owner is the one reader who needs no extra setup.
 */

async function ownTeam(label: string) {
  const owner = await newUser(label)
  const team = await newTeam(owner, unique(label))
  return { owner, team }
}

const adPath = (teamSlug: string, ad: AdDto) => `/equipes/${teamSlug}/annonces/${ad.slug}`

test.describe('ad detail', () => {
  test('the gallery steps with the arrows and the thumbnails, full screen asks for 1920 px', async ({
    page,
    context,
  }) => {
    const { owner, team } = await ownTeam('gallery')
    const colours: [number, number, number][] = [
      [220, 40, 40],
      [40, 160, 60],
      [40, 60, 200],
    ]
    const images: AssetDto[] = []
    for (const [i, colour] of colours.entries()) {
      images.push(
        await uploadImage(owner, team.slug, `photo-${i + 1}.png`, solidPng(400, 300, colour))
      )
    }
    const ad = await newAd(owner, team.slug, {
      name: unique('Vélo en photos'),
      body: 'Trois photos.',
      price: 300,
      images,
    })
    expect(ad.images).toHaveLength(3)

    await signIn(context, owner)
    await page.goto(adPath(team.slug, ad))
    await expect(page.getByRole('heading', { level: 2, name: ad.name })).toBeVisible()

    const photoButtons = page.getByRole('button', { name: /^Ouvrir la photo \d sur 3$/ })
    // The thumbnails carry aria-current (true or false); the main frame does not.
    const thumbnails = photoButtons.and(page.locator('[aria-current]'))
    const mainFrame = photoButtons.and(page.locator(':not([aria-current])'))
    const mainImage = mainFrame.getByRole('img', { name: ad.name })

    await expect(thumbnails).toHaveCount(3)
    // The strip keeps the order the images were added in — the backend used to drop it and serve
    // them in hash order, the first (the list thumbnail) included (fixed 2026-09-25).
    const order = await thumbnails
      .getByRole('img')
      .evaluateAll((imgs) => imgs.map((img) => img.getAttribute('src')!.split('/').at(-2)!))
    expect(order).toEqual(images.map((image) => image.id))
    const shows = async (index: number) => {
      await expect(mainFrame).toHaveAccessibleName(`Ouvrir la photo ${index + 1} sur 3`)
      await expect(mainImage).toHaveAttribute(
        'src',
        new RegExp(`/${order[index]}/\\d+(\\?v=\\w+)?$`)
      )
      await expect(thumbnails.nth(index)).toHaveAttribute('aria-current', 'true')
    }

    await shows(0)
    await hydrated(page.getByRole('button', { name: 'Photo suivante' }))
    await page.getByRole('button', { name: 'Photo suivante' }).click()
    await shows(1)
    await page.getByRole('button', { name: 'Photo suivante' }).click()
    await shows(2)
    // Past the last picture, the arrows wrap around.
    await page.getByRole('button', { name: 'Photo suivante' }).click()
    await shows(0)
    await page.getByRole('button', { name: 'Photo précédente' }).click()
    await shows(2)

    await thumbnails.nth(1).click()
    await shows(1)
    await thumbnails.nth(0).click()
    await shows(0)
    await thumbnails.nth(2).click()
    await shows(2)

    // Full screen: the picture on display, at the 1920 variant, actually served.
    const served = page.waitForResponse((response) =>
      new URL(response.url()).pathname.endsWith(`/${order[2]}/1920`)
    )
    await mainFrame.click()
    const dialog = page.getByRole('dialog', { name: "Photos de l'annonce" })
    await expect(dialog).toBeVisible()
    const fullImage = dialog.getByRole('img', { name: ad.name })
    await expect(fullImage).toHaveAttribute('src', new RegExp(`/${order[2]}/1920(\\?v=\\w+)?$`))
    expect((await served).status()).toBe(200)
    await expect
      .poll(() => fullImage.evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth))
      .toBeGreaterThan(0)
  })

  test.describe('location map', () => {
    // The basemap is a third-party CDN (tiles.versatiles.org, see GET /api/config), not part of the
    // stack: its tiles depend on the network and change under us. It is replaced by a plain
    // background so what is measured below is the ad's sector alone — the overlay is untouched.
    test.beforeEach(async ({ page }) => {
      await stubBasemap(page)
    })

    test('renders a disc without a pin, framed on its extent, captioned « à environ 1 km près »', async ({
      page,
      context,
    }) => {
      const { owner, team } = await ownTeam('sector')
      const ad = await newAd(owner, team.slug, {
        name: unique('Roue avant'),
        body: 'Une roue.',
        price: 80,
        locationDescription: 'Près de Chartres',
        locationGeometry: { type: 'Point', coordinates: [1.4875, 48.4469] },
      })

      await signIn(context, owner)
      await page.goto(adPath(team.slug, ad))
      await expect(page.getByRole('heading', { level: 4, name: 'Localisation' })).toBeVisible()
      await expect(page.getByText('Près de Chartres')).toBeVisible()
      await expect(page.getByText(/à environ 1 km près/)).toBeVisible()

      const map = page.getByRole('img', { name: /Localisation approximative, à environ 1 km près/ })
      await expect(map).toBeVisible()
      await expect(map.locator('canvas')).toHaveCount(1)
      // No pin: neither a MapLibre marker nor any other DOM overlay on the map.
      await expect(map.locator('.maplibregl-marker, .maplibregl-popup')).toHaveCount(0)

      // Framing and shape, read from the rendered pixels: the sector tints the plain background
      // blue. Along the vertical axis through the centre, it must reach close to the top and
      // bottom edges (fitBounds with 24 px of padding on a 200 px frame) without covering them;
      // the corners, outside a disc, stay untinted.
      const box = (await map.boundingBox())!
      const cx = Math.round(box.width / 2)
      const cy = Math.round(box.height / 2)
      const probes = {
        centre: [cx, cy],
        nearTop: [cx, 34],
        nearBottom: [cx, Math.round(box.height) - 34],
        aboveTop: [cx, 8],
        belowBottom: [cx, Math.round(box.height) - 8],
        topLeft: [8, 8],
        topRight: [Math.round(box.width) - 8, 8],
        bottomLeft: [8, Math.round(box.height) - 8],
        bottomRight: [Math.round(box.width) - 8, Math.round(box.height) - 8],
      } satisfies Record<string, [number, number]>

      // Wait for the style and the sector to be drawn, rather than for a fixed delay.
      await expect
        .poll(async () => (await tintAt(page, map, probes)).centre, { timeout: 15_000 })
        .toBeGreaterThan(20)
      const tint = await tintAt(page, map, probes)
      expect(tint.nearTop, 'the disc reaches near the top edge').toBeGreaterThan(20)
      expect(tint.nearBottom, 'the disc reaches near the bottom edge').toBeGreaterThan(20)
      for (const outside of [
        'aboveTop',
        'belowBottom',
        'topLeft',
        'topRight',
        'bottomLeft',
        'bottomRight',
      ] as const) {
        expect(tint[outside], `${outside} is outside the disc`).toBeLessThan(8)
      }
      // No centre mark either: the middle of the disc is the same flat tint as the rest of it.
      expect(Math.abs(tint.centre - tint.nearTop)).toBeLessThan(8)
    })
  })

  test('no empty section: neither Description without a body nor Localisation without a place', async ({
    page,
    context,
  }) => {
    const { owner, team } = await ownTeam('bare')
    const bare = await newAd(owner, team.slug, { name: unique('Annonce nue'), price: 10 })
    const placeOnly = await newAd(owner, team.slug, {
      name: unique('Annonce avec lieu'),
      price: 20,
      locationDescription: 'Gare de Lyon',
    })

    await signIn(context, owner)

    await page.goto(adPath(team.slug, bare))
    await expect(page.getByRole('heading', { level: 2, name: bare.name })).toBeVisible()
    // The page is complete: the always-present seller section rendered.
    await expect(page.getByRole('heading', { level: 4, name: 'Annonceur' })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Description' })).toHaveCount(0)
    await expect(page.getByRole('heading', { name: 'Localisation' })).toHaveCount(0)
    await expect(page.getByRole('img', { name: /à environ 1 km près/ })).toHaveCount(0)
    // No picture, no gallery frame.
    await expect(page.getByRole('button', { name: /^Ouvrir la photo/ })).toHaveCount(0)

    // A written place with no geometry: the section, the place, and no map pretending to a spot.
    await page.goto(adPath(team.slug, placeOnly))
    await expect(page.getByRole('heading', { level: 2, name: placeOnly.name })).toBeVisible()
    await expect(page.getByRole('heading', { level: 4, name: 'Localisation' })).toBeVisible()
    await expect(page.getByText('Gare de Lyon')).toBeVisible()
    await expect(page.getByRole('img', { name: /à environ 1 km près/ })).toHaveCount(0)
    await expect(page.getByText(/à environ 1 km près/)).toHaveCount(0)
    await expect(page.getByRole('heading', { name: 'Description' })).toHaveCount(0)
  })
})

/**
 * How much bluer than red `element` is at each probe point (CSS pixels): 0 on the plain #f0f0f0
 * background, ~+37 under the sector's 22 % #4c6ef5 fill. The screenshot is
 * decoded in the page (a 2D canvas) so the suite needs no PNG decoder.
 */
async function tintAt<K extends string>(
  page: Page,
  element: Locator,
  probes: Record<K, [number, number]>
): Promise<Record<K, number>> {
  const png = (await element.screenshot({ animations: 'disabled' })).toString('base64')
  const box = (await element.boundingBox())!
  const points: Record<string, [number, number]> = probes
  const tints = await page.evaluate(
    async ({ png, points, width }) => {
      const img = new Image()
      img.src = `data:image/png;base64,${png}`
      await img.decode()
      // The screenshot is in device pixels; the probes are in CSS pixels.
      const scale = img.naturalWidth / width
      const canvas = document.createElement('canvas')
      canvas.width = img.naturalWidth
      canvas.height = img.naturalHeight
      const ctx = canvas.getContext('2d')!
      ctx.drawImage(img, 0, 0)
      const out: Record<string, number> = {}
      for (const [name, [x, y]] of Object.entries(points)) {
        const [r, , b] = ctx.getImageData(Math.round(x * scale), Math.round(y * scale), 1, 1).data
        out[name] = b - r
      }
      return out
    },
    { png, points, width: box.width }
  )
  return tints as Record<K, number>
}

test.describe('ad list', () => {
  /** Three priced ads and one "à négocier", in a team of their own. */
  async function pricedAds(label: string) {
    const { owner, team } = await ownTeam(label)
    const tag = unique(label)
    const ads = {
      cheap: await newAd(owner, team.slug, { name: `C cheap ${tag}`, price: 100 }),
      mid: await newAd(owner, team.slug, { name: `A mid ${tag}`, price: 500 }),
      dear: await newAd(owner, team.slug, { name: `B dear ${tag}`, price: 900 }),
      negotiable: await newAd(owner, team.slug, { name: `D negotiable ${tag}` }),
    }
    return { owner, team, tag, ads }
  }

  const listPath = (teamSlug: string) => `/equipes/${teamSlug}/annonces`
  const cardTitles = (page: Page, tag: string) =>
    page.getByRole('heading', {
      level: 4,
      name: new RegExp(escapeRegExp(tag)),
    })
  const query = (page: Page) => Object.fromEntries(new URL(page.url()).searchParams)
  /** The filters the page wrote to its URL — waited for, since the write follows the loader. */
  const expectQuery = (page: Page, expected: Record<string, string>) =>
    expect.poll(() => query(page)).toEqual(expected)

  const sortControl = (page: Page) => page.getByRole('combobox', { name: 'Trier par' })
  const minPrice = (page: Page) => page.getByRole('textbox', { name: 'Prix min.' })
  const maxPrice = (page: Page) => page.getByRole('textbox', { name: 'Prix max.' })

  async function pickSort(page: Page, label: string) {
    await hydrated(sortControl(page))
    await sortControl(page).click()
    await page.getByRole('option', { name: label }).click()
  }

  async function expectControls(
    page: Page,
    { sort, min, max }: { sort: string; min: string; max: string }
  ) {
    await expect(sortControl(page)).toHaveValue(sort)
    await expect(minPrice(page)).toHaveValue(min)
    await expect(maxPrice(page)).toHaveValue(max)
  }

  const filtered = { sort: 'PRICE', dir: 'ASC', pmin: '200', pmax: '1000' }

  test('sort and price bounds survive going back and a shared link', async ({
    page,
    context,
    browser,
  }) => {
    const { owner, team, tag, ads } = await pricedAds('list-url')
    await signIn(context, owner)

    await page.goto(listPath(team.slug))
    const titles = cardTitles(page, tag)
    // Default order: newest first, and nothing in the query string.
    await expect(titles).toHaveText([
      ads.negotiable.name,
      ads.dear.name,
      ads.mid.name,
      ads.cheap.name,
    ])
    expect(query(page)).toEqual({})

    // One control at a time, each change rendered — the list reordered or narrowed — before the
    // next: the URL alone is not enough (see the quick-succession test below).
    await pickSort(page, 'Prix croissant')
    await expect(titles).toHaveText([
      ads.cheap.name,
      ads.mid.name,
      ads.dear.name,
      ads.negotiable.name,
    ])
    await expectQuery(page, { sort: 'PRICE', dir: 'ASC' })
    await minPrice(page).fill('200')
    await expect(titles).toHaveText([ads.mid.name, ads.dear.name])
    await expectQuery(page, { sort: 'PRICE', dir: 'ASC', pmin: '200' })
    await maxPrice(page).fill('1000')
    await expectQuery(page, filtered)
    await expect(titles).toHaveText([ads.mid.name, ads.dear.name])
    const shared = page.url()

    // Into an ad, and back.
    await titles.first().click()
    await expect(page.getByRole('heading', { level: 2, name: ads.mid.name })).toBeVisible()
    await page.goBack()
    await expect(titles).toHaveText([ads.mid.name, ads.dear.name])
    expect(query(page)).toEqual(filtered)
    await expectControls(page, { sort: 'Prix croissant', min: '200 €', max: '1000 €' })

    // The same link, opened in another browser (server-rendered first, then hydrated).
    const other = await browser.newContext({ locale: 'fr-FR' })
    try {
      await signIn(other, owner)
      const otherPage = await other.newPage()
      await otherPage.goto(shared)
      await expect(cardTitles(otherPage, tag)).toHaveText([ads.mid.name, ads.dear.name])
      await expectControls(otherPage, { sort: 'Prix croissant', min: '200 €', max: '1000 €' })
      expect(query(otherPage)).toEqual(filtered)
    } finally {
      await other.close()
    }
  })

  test('« Effacer les filtres » drops the price bounds and keeps the sort', async ({
    page,
    context,
  }) => {
    const { owner, team, tag, ads } = await pricedAds('list-clear')
    await signIn(context, owner)

    // Nothing costs more than 5000: the filtered dead end, whose way out is the clear button.
    await page.goto(`${listPath(team.slug)}?sort=PRICE&dir=ASC&pmin=5000`)
    await expect(page.getByRole('heading', { name: 'Aucune annonce trouvée' })).toBeVisible()
    await expectControls(page, { sort: 'Prix croissant', min: '5000 €', max: '' })

    const clear = page.getByRole('button', { name: 'Effacer les filtres' })
    await hydrated(clear)
    await clear.click()

    // Every ad is back — the negotiable one too, last — cheapest first.
    await expect(cardTitles(page, tag)).toHaveText([
      ads.cheap.name,
      ads.mid.name,
      ads.dear.name,
      ads.negotiable.name,
    ])
    await expectQuery(page, { sort: 'PRICE', dir: 'ASC' })
    await expectControls(page, { sort: 'Prix croissant', min: '', max: '' })
  })

  // Every filter change is a navigation of the data router, whose `ads` loader awaits the list
  // prefetch before the location commits (config/RouteGenerator.tsx). Until then `useSearchParams`
  // still returns the old query string: useUrlFilters.setFilters used to rebuild from it, so a
  // second change made while the first was loading dropped the first (fixed 2026-09-25).
  test('changes made in quick succession all land in the URL', async ({ page, context }) => {
    const { owner, team, tag, ads } = await pricedAds('list-race')
    await signIn(context, owner)
    await page.goto(listPath(team.slug))
    await expect(cardTitles(page, tag), 'precondition: the four ads are listed').toHaveCount(4)

    // A slower network, so that the window in which the defect bites is wide enough to be hit
    // every run — the local stack answers too fast to make that deterministic by itself. The
    // responses are the real ones, only delayed.
    await page.route(`**/api/teams/${team.slug}/classifieds?**`, async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 800))
      await route.continue()
    })
    const sent: URLSearchParams[] = []
    page.on('request', (request) => {
      if (request.url().includes(`/api/teams/${team.slug}/classifieds?`))
        sent.push(new URL(request.url()).searchParams)
    })

    await pickSort(page, 'Prix croissant')
    await minPrice(page).fill('200')
    await maxPrice(page).fill('1000')

    // Preconditions: each change reached the app — its list request went out. (Not the controls:
    // they read the URL, so they lose the dropped filter along with it.)
    await expect
      .poll(() => sent.some((q) => q.get('sortBy') === 'PRICE' && q.get('sortDir') === 'ASC'), {
        message: 'precondition: the sort was picked',
      })
      .toBe(true)
    await expect
      .poll(() => sent.some((q) => q.get('minPrice') === '200'), {
        message: 'precondition: the minimum price was applied',
      })
      .toBe(true)
    // None of them lost on the way.
    await expectQuery(page, filtered)
    await expect(cardTitles(page, tag)).toHaveText([ads.mid.name, ads.dear.name])
  })
})

/**
 * An ad's location is, in practice, the seller's home: the API publishes only the centre of the
 * ~1 km cell holding it (CoarseLocation.blur, AdDto.locationGeometry), and every client draws a
 * sector, never a pin. The exact point stays on AdEditDto (`/edit`), the owner's. So a member
 * reading someone else's ad — its page, the team's list — must not receive it anywhere: not in the
 * server document (markup, dehydrated query cache), not in any response the browser fetches.
 */
test('the exact point of an ad is neither in the server documents nor in any API response a member gets', async ({
  browser,
}) => {
  // Two server documents, then three pages in a browser: past 30 s on a loaded stack.
  test.setTimeout(60_000)
  const [admin, owner, member] = await Promise.all([
    roleSession('admin'),
    newUser('exact-point seller'),
    newUser('exact-point buyer'),
  ])
  const team = await newTeam(owner, unique('exact-point'))
  await addMember(admin, team.slug, member)
  // Six decimals, like a geocoded address: its digits are the needles.
  const exact: [number, number] = [1.487531, 48.446927]
  const needles = ['1.48753', '48.44692']
  const ad = await newAd(owner, team.slug, {
    name: unique('Vélo chez moi'),
    body: 'À venir chercher.',
    price: 150,
    locationDescription: 'Près de Chartres',
    locationGeometry: { type: 'Point', coordinates: exact },
  })

  // The owner's edit read keeps the point; a member's read has the cell's centre instead.
  const edited = await apiGet<AdEditDto>(
    owner,
    `/api/teams/${team.slug}/classifieds/${ad.slug}/edit`
  )
  expect(edited.locationGeometry?.coordinates).toEqual(exact)
  const read = await getAd(member, team.slug, ad.slug)
  const [lon, lat] = read.locationGeometry!.coordinates
  expect(Math.abs(lat - exact[1]), 'blurred latitude, within a cell').toBeLessThan(0.01)
  expect(Math.abs(lon - exact[0]), 'blurred longitude, within a cell').toBeLessThan(0.02)
  for (const needle of needles) expect(JSON.stringify(read)).not.toContain(needle)
  const blurredLat = String(lat)

  const pages = [
    { label: 'detail', path: adPath(team.slug, ad) },
    { label: 'list', path: `/equipes/${team.slug}/annonces` },
  ]

  // The server documents: the ad is there (its name, and on the detail its blurred point), the
  // exact point is not.
  for (const { label, path } of pages) {
    const document = await rawDocument(path, { cookie: sessionCookie(member) })
    expect(document.status, `${label}: status`).toBe(200)
    expect(ssrOutlet(document.html), `${label}: the ad in the markup`).toContain(ad.name)
    if (label === 'detail')
      expect(document.html, `${label}: the blurred point handed over`).toContain(blurredLat)
    for (const needle of needles)
      expect.soft(document.html.includes(needle), `${label}: ${needle} in the document`).toBe(false)
  }

  // In the browser: whatever the pages fetch. Opened by their URL they fetch nothing — the server
  // prefetches every query they read (docs/LEDGER_*.md WEB-52) — so the detail is reached from the
  // list, as a member would: that client-side navigation reads the ad from the API.
  const { context, page } = await pageAs(browser, member)
  try {
    await stubBasemap(page)
    const bodies: Promise<{ url: string; body: string }>[] = []
    page.on('response', (response) => {
      if (!new URL(response.url()).pathname.startsWith('/api/')) return
      bodies.push(
        response
          .text()
          .catch(() => '')
          .then((body) => ({ url: response.url(), body }))
      )
    })
    await page.goto(pages[1].path)
    await pageHydrated(page)
    const card = page.getByRole('main').getByRole('link', { name: ad.name }).first()
    await hydrated(card)
    await card.click()
    await expect(page).toHaveURL(new RegExp(`${escapeRegExp(adPath(team.slug, ad))}$`))
    await expect(page.getByRole('heading', { name: ad.name }).first()).toBeVisible()
    // The detail's sector: the page did draw the location it was given.
    await expect(page.getByRole('img', { name: /à environ 1 km près/ })).toBeVisible()
    await pageHydrated(page)

    const responses = await Promise.all(bodies)
    expect(
      responses.some(({ url }) => new URL(url).pathname.endsWith(`/classifieds/${ad.slug}`)),
      'the ad read by the browser'
    ).toBe(true)
    for (const response of responses)
      for (const needle of needles)
        expect.soft(response.body.includes(needle), `${needle} in ${response.url}`).toBe(false)
  } finally {
    await context.close()
  }
})
