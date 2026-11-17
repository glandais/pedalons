import type { Page } from '@playwright/test'
import type {
  AdListResponse,
  GpxPreviewDto,
  GpxPreviewListResponse,
  PublicationListResponse,
  TeamListResponse,
} from '../src/api/dto'
import { newAd } from './support/ads'
import { apiGet, expectOk, withApi, type AuthResponse } from './support/api'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import {
  expectCurrentPage,
  expectInMarkup,
  expectQuery,
  nextPage,
  openServerRendered,
  queryOf,
  readsOf,
} from './support/list-pages'
import { newPost } from './support/posts'
import { gpxOf, windingTrack } from './support/routes'
import { entityCard, hydrated } from './support/ui'
import { wallTimeOf } from './support/dates'

/**
 * docs/plans/archive/2026-09-27-e2e-coverage-audit.md, P1 « Pagination » — the page lives in the query string (`p`, zero-based)
 * on every list, the same way on the server and in the browser (frontend/docs/URL_FILTERS.md):
 *
 * - `?p=1` is server-rendered as the second page, and the browser reads no list again after
 *   hydration (the route prefetched the page window under the page's own key);
 * - paging, opening an entry and going back lands on the same page again;
 * - `?p=abc` is the first page, not an error;
 * - `?p=99` says the page does not exist — not the list's empty state — and leads back to page 1.
 *
 * Every list pages by 12 (PUBLICATION_PAGE_SIZE, TEAM_PAGE_SIZE, AD_PAGE_SIZE,
 * GPX_PREVIEW_PAGE_SIZE), so each test seeds 13 entries — two pages — in a scope nothing else in the
 * parallel suite writes to: a team of its own, a fresh user's own teams or files. Which entry lands
 * on which page is asked of the API, not assumed from the sort.
 */

const PAGE_SIZE = 12
const OUT_OF_RANGE = "Cette page n'existe pas"
const FIRST_PAGE = 'Revenir à la première page'
const COUNT = PAGE_SIZE + 1

interface Journey {
  /** The list, with the query string it needs whatever the page (the team feed's `tab`), if any. */
  path: string
  /** The list endpoint the page reads (a pathname). */
  endpoint: string
  /** What the page writes to its URL besides `p` (the home feed and the team list spell out `role`). */
  query?: Record<string, string>
  /** The first entry of page 1, and the one entry of page 2. */
  first: string
  second: string
  /**
   * The heading of the list's absolute empty state, which `?p=99` must not show: the list is not
   * empty, the page is past its end.
   */
  empty: string
  /** Opens the entry `name` from the list, and waits for its own page. */
  open: (page: Page, name: string) => Promise<void>
}

/** Opens an entry through its card (a link holding its name) and waits for the entry's own page. */
async function openCard(page: Page, name: string) {
  await entityCard(page.getByRole('main'), name).click()
  await expect(page.getByRole('main').getByRole('heading', { name }).first()).toBeVisible()
}

async function paginate(page: Page, journey: Journey) {
  const { path, endpoint, first, second, empty, query = {} } = journey
  const main = page.getByRole('main')
  /** The list with `param` added to its query string. */
  const withParam = (param: string) => `${path}${path.includes('?') ? '&' : '?'}${param}`

  await test.step('?p=1 is server-rendered as page 2, and not read again once hydrated', async () => {
    const { markup, reads } = await openServerRendered(page, withParam('p=1'), endpoint)
    expectInMarkup(markup, [second], [first])
    expect(readsOf(reads), 'list reads sent by the browser after the server render').toEqual([])
    await expect(entry(page, second)).toBeVisible()
    await expect(main.getByText(first, { exact: true })).toHaveCount(0)
    await expectCurrentPage(page, 2, 2)
  })

  await test.step('paging, opening an entry and going back lands on page 2 again', async () => {
    await page.goto(path)
    await expect(entry(page, first)).toBeVisible()
    await expectCurrentPage(page, 1, 2)
    await nextPage(page)
    await expectQuery(page, { ...query, p: '1' })
    await expect(entry(page, second)).toBeVisible()

    const listUrl = page.url()
    await journey.open(page, second)
    // The entry's page is on its way only once the URL has left the list: the card on the list
    // carries the very heading the entry's page shows, and the router pushes the entry's URL only
    // once its loader is done. A goBack before that push skips the list's own history entry.
    await expect(page).not.toHaveURL(listUrl)
    await page.goBack()
    // The pagination first: the URL changes before the list replaces the entry's page.
    await expectCurrentPage(page, 2, 2)
    expect(queryOf(page)).toEqual({ ...query, p: '1' })
    await expect(entry(page, second)).toBeVisible()
    await expect(main.getByText(first, { exact: true })).toHaveCount(0)
  })

  await test.step('?p=abc is the first page', async () => {
    const { markup, reads } = await openServerRendered(page, withParam('p=abc'), endpoint)
    expectInMarkup(markup, [first], [second])
    expect(readsOf(reads), 'list reads sent by the browser after the server render').toEqual([])
    await expect(entry(page, first)).toBeVisible()
    await expectCurrentPage(page, 1, 2)
  })

  // Regression (b08d3f90): OutOfRangeState — before, `?p=99` showed the absolute empty state
  // (« Aucune équipe n'a encore été créée… »), wrong and with no way out.
  await test.step('?p=99 says the page does not exist, and leads back to page 1', async () => {
    const { markup, reads } = await openServerRendered(page, withParam('p=99'), endpoint)
    // The markup as React escapes it: an apostrophe is `&#x27;`.
    const escaped = (text: string) => text.replaceAll("'", '&#x27;')
    expectInMarkup(markup, [escaped(OUT_OF_RANGE), FIRST_PAGE], [first, second, escaped(empty)])
    expect(readsOf(reads), 'list reads sent by the browser after the server render').toEqual([])
    await expect(main.getByText(OUT_OF_RANGE, { exact: true })).toBeVisible()
    await expect(main.getByText(empty, { exact: true })).toHaveCount(0)

    const back = main.getByRole('button', { name: FIRST_PAGE, exact: true })
    await hydrated(back)
    await back.click()
    await expectQuery(page, query)
    await expect(entry(page, first)).toBeVisible()
    await expectCurrentPage(page, 1, 2)
    await expect(main.getByText(OUT_OF_RANGE, { exact: true })).toHaveCount(0)
  })
}

/** An entry of the list by its name: every list here shows it as the exact text of one element. */
const entry = (page: Page, name: string) => page.getByRole('main').getByText(name, { exact: true })

/** The first entry of page 1 and of page 2, as the API orders them (page size 12). */
async function pageHeads<T>(
  read: (page: number) => Promise<T[]>,
  name: (entry: T) => string
): Promise<{ first: string; second: string }> {
  const [one, two] = await Promise.all([read(0), read(1)])
  expect(one, 'precondition: a full first page').toHaveLength(PAGE_SIZE)
  expect(two, 'precondition: one entry on the second page').toHaveLength(1)
  return { first: name(one[0]), second: name(two[0]) }
}

/** A fresh owner, a team of theirs, and 13 posts one day apart — all in the past. */
async function teamWithPosts(label: string) {
  const owner = await newUser(label)
  const team = await newTeam(owner, unique(label))
  const day = 24 * 3600 * 1000
  for (let i = 0; i < COUNT; i++) {
    await newPost(owner, team.slug, unique(`Article ${String(i + 1).padStart(2, '0')}`), {
      dateTime: wallTimeOf(Date.now() - (i + 1) * day),
    })
  }
  return { owner, team }
}

const publicationNames = (response: PublicationListResponse) =>
  response.publications.map((publication) => publication.name)

test('team posts: page 2 from the server, back to it, p=abc, p=99', async ({ page, context }) => {
  const { owner, team } = await teamWithPosts('pagination-team-posts')
  const endpoint = `/api/teams/${team.slug}/publications`
  const heads = await pageHeads(
    async (p) =>
      publicationNames(
        await apiGet<PublicationListResponse>(owner, endpoint, {
          type: 'POST',
          page: p,
          size: PAGE_SIZE,
        })
      ),
    (name) => name
  )

  await signIn(context, owner)
  // The team's « Publications » (WEB-68): the posts alone, newest first.
  await paginate(page, {
    path: `/equipes/${team.slug}/articles`,
    endpoint,
    ...heads,
    empty: 'Aucune publication pour le moment',
    open: openCard,
  })
})

test('home feed: page 2 from the server, back to it, p=abc, p=99', async ({ page, context }) => {
  // A fresh user with one team: the home feed defaults to their teams (role=member), so it holds
  // exactly the 13 posts, whatever the rest of the suite publishes.
  const { owner } = await teamWithPosts('pagination-home')
  const heads = await pageHeads(
    async (p) =>
      publicationNames(
        await apiGet<PublicationListResponse>(owner, '/api/publications', {
          minRole: 'MEMBER',
          page: p,
          size: PAGE_SIZE,
        })
      ),
    (name) => name
  )

  await signIn(context, owner)
  await paginate(page, {
    path: '/',
    endpoint: '/api/publications',
    query: { role: 'member' },
    ...heads,
    empty: 'Aucune publication pour le moment',
    open: openCard,
  })
})

test('team list: page 2 from the server, back to it, p=abc, p=99', async ({ page, context }) => {
  // A user may own a single team, so the platform admin creates the 13 and adds a fresh user to
  // each: that user's /equipes defaults to their own teams (role=member) — exactly these.
  const admin = await roleSession('admin')
  const member = await newUser('pagination-teams')
  for (let i = 0; i < COUNT; i++) {
    const team = await newTeam(admin, unique(`Équipe paginée ${String(i + 1).padStart(2, '0')}`))
    await addMember(team.slug, member)
  }
  const heads = await pageHeads(
    async (p) =>
      (
        await apiGet<TeamListResponse>(member, '/api/teams', {
          minRole: 'MEMBER',
          page: p,
          size: PAGE_SIZE,
        })
      ).teams,
    (team) => team.name
  )

  await signIn(context, member)
  await paginate(page, {
    path: '/equipes',
    endpoint: '/api/teams',
    query: { role: 'member' },
    ...heads,
    empty: 'Aucune équipe',
    open: openCard,
  })
})

test('ads: page 2 from the server, back to it, p=abc, p=99', async ({ page, context }) => {
  const owner = await newUser('pagination-ads')
  const team = await newTeam(owner, unique('pagination-ads'))
  for (let i = 0; i < COUNT; i++)
    await newAd(owner, team.slug, { name: unique(`Annonce ${String(i + 1).padStart(2, '0')}`) })
  const endpoint = `/api/teams/${team.slug}/classifieds`
  const heads = await pageHeads(
    async (p) => (await apiGet<AdListResponse>(owner, endpoint, { page: p, size: PAGE_SIZE })).ads,
    (ad) => ad.name
  )

  await signIn(context, owner)
  await paginate(page, {
    path: `/equipes/${team.slug}/annonces`,
    endpoint,
    ...heads,
    empty: 'Aucune annonce',
    open: openCard,
  })
})

/** A GPX file uploaded to « Outils GPX » by `owner`, named `name`. */
const uploadPreview = (owner: AuthResponse, name: string) =>
  withApi(owner, async (api) =>
    expectOk<GpxPreviewDto>(
      await api.post('/api/gpx-previews', {
        multipart: {
          gpxFile: {
            name: 'trace.gpx',
            mimeType: 'application/gpx+xml',
            buffer: Buffer.from(gpxOf(name, windingTrack(20))),
          },
        },
      })
    )
  )

test('my GPX files: page 2 from the server, back to it, p=abc, p=99', async ({ page, context }) => {
  // Each file is a GPX parsed and stored by the server: under load, the uploads alone can take
  // half of the default 30 s.
  test.slow()
  const owner = await newUser('pagination-gpx')
  for (let i = 0; i < COUNT; i++)
    await uploadPreview(owner, unique(`Fichier ${String(i + 1).padStart(2, '0')}`))
  const endpoint = '/api/gpx-previews'
  const heads = await pageHeads(
    async (p) =>
      (await apiGet<GpxPreviewListResponse>(owner, endpoint, { page: p, size: PAGE_SIZE }))
        .previews,
    (preview) => preview.name
  )

  await signIn(context, owner)
  await paginate(page, {
    path: '/outils-gpx/mes-fichiers',
    endpoint,
    ...heads,
    empty: "Vous n'avez aucun fichier disponible pour le moment.",
    // A row is not a link: its « Voir » button is.
    open: async (page, name) => {
      const row = page.locator('.mantine-Card-root').filter({ hasText: name })
      await row.getByRole('link', { name: 'Voir' }).click()
      await expect(page.getByRole('main').getByRole('heading', { level: 1, name })).toBeVisible()
    },
  })
})
