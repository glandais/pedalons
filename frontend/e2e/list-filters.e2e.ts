import type { Locator, Page } from '@playwright/test'
import type { RouteDto } from '../src/api/dto'
import { newAd } from './support/ads'
import { addMember, newTeam, newUser, roleSession, signIn } from './support/data'
import { expect, test, unique } from './support/fixtures'
import { expectInMarkup, expectQuery, openServerRendered, readsOf } from './support/list-pages'
import { newPost } from './support/posts'
import { newRide } from './support/rides'
import { newRoute, windingTrack } from './support/routes'
import { entityCard, escapeRegExp, homeFeed, hydrated } from './support/ui'
import { wallTimeOf } from './support/dates'

/**
 * docs/plans/archive/2026-09-27-e2e-coverage-audit.md, P1 « Filtres portés par l'URL et cohérents avec le SSR » — a list's
 * filters live in its query string (frontend/docs/URL_FILTERS.md), and the route's prefetch reads that
 * query string through the page's own schema (frontend/docs/SSR-data-loading.md). So a filtered link:
 *
 * - is server-rendered already filtered — the document the browser receives lists what the
 *   filters keep, and nothing they drop;
 * - is not read again once hydrated — the browser sends no request to the list endpoint, since the
 *   page builds the very query key the server filled;
 * - reflects the filters in its controls, and a change through those controls lands in the URL.
 *
 * Every test works in a team of its own, owned by a fresh user: the lists involved are that team's,
 * or the home feed of a user whose only team it is (role=member), which nothing else in the
 * parallel suite writes to.
 */

async function ownTeam(label: string) {
  const owner = await newUser(label)
  const team = await newTeam(owner, unique(label))
  return { owner, team }
}

const DAY = 24 * 3600 * 1000

/** A team with an upcoming ride (two days ahead) and a post two days old. */
async function teamWithFeed(label: string) {
  const { owner, team } = await ownTeam(label)
  const ride = await newRide(owner, team.slug, unique('Sortie filtrée'))
  const post = await newPost(owner, team.slug, unique('Article filtré'), {
    dateTime: wallTimeOf(Date.now() - 2 * DAY),
  })
  return { owner, team, ride: ride.name, post: post.name }
}

/** Picks `option` in the Mantine Select `select`, once hydrated. */
async function pick(page: Page, select: Locator, option: string) {
  await hydrated(select)
  await select.click()
  await page.getByRole('option', { name: option, exact: true }).click()
}

/**
 * Picks `label` in a SegmentedControl (the feed's scope, the route list's view). Its radios are
 * visually hidden inputs and the view switch's labels are icons (the name is visually hidden text):
 * a person clicks the segment's `<label>`, and so does the test.
 */
async function segment(page: Page, group: string, label: string) {
  const control = page.getByRole('radiogroup', { name: group })
  await hydrated(control.getByRole('radio', { name: label }))
  await control
    .locator('label')
    .filter({ hasText: new RegExp(`^${escapeRegExp(label)}$`) })
    .click()
}

const noReadsAfterHydration = (reads: URLSearchParams[]) =>
  expect(readsOf(reads), 'list reads sent by the browser after the server render').toEqual([])

test.describe('publication feeds', () => {
  test('team agenda: kind and period from the URL, server-rendered, in two sections, then « Effacer les filtres »', async ({
    page,
    context,
  }) => {
    const { owner, team, ride, post } = await teamWithFeed('filters-team-agenda')
    const past = await newRide(owner, team.slug, unique('Sortie passée filtrée'), {
      dateTime: wallTimeOf(Date.now() - 2 * DAY),
    })
    await signIn(context, owner)
    const main = page.getByRole('main')
    const typeRadio = (label: string) =>
      main
        .getByRole('radiogroup', { name: 'Type', exact: true })
        .getByRole('radio', { name: label })
    const periodRadio = (label: string) =>
      main.getByRole('radiogroup', { name: 'Période' }).getByRole('radio', { name: label })

    // The agenda holds rides and trips, never posts, in two sections (RL15): « À venir », then
    // « Plus tôt ». « Toutes les dates » by default (when=UPCOMING_FIRST).
    const { markup, reads } = await openServerRendered(
      page,
      `/equipes/${team.slug}/agenda?type=ride`,
      `/api/teams/${team.slug}/publications`
    )
    expectInMarkup(markup, [ride, past.name], [post])
    noReadsAfterHydration(reads)
    await expect(entityCard(main.getByRole('region', { name: 'À venir' }), ride)).toBeVisible()
    await expect(
      entityCard(main.getByRole('region', { name: 'Plus tôt' }), past.name)
    ).toBeVisible()
    await expect(typeRadio('Sorties')).toBeChecked()
    await expect(periodRadio('Toutes les dates')).toBeChecked()

    // A former « Passées » link opens « Toutes les dates », the kind kept.
    await page.goto(`/equipes/${team.slug}/agenda?type=ride&w=past`)
    await expect(page).toHaveURL(new RegExp(`/equipes/${team.slug}/agenda\\?type=ride$`))
    await expect(periodRadio('Toutes les dates')).toBeChecked()

    // Nobody registered, no trip: the filtered dead end, « Je participe » among its filters.
    await segment(page, 'Période', 'Je participe')
    await segment(page, 'Type', 'Voyages')
    await expectQuery(page, { type: 'trip', w: 'me' })
    await expect(main.getByRole('heading', { name: 'Aucun voyage pour ces filtres' })).toBeVisible()
    await expect(main.getByText('Rien ne correspond à : Je participe · Voyages.')).toBeVisible()

    await main.getByRole('button', { name: 'Effacer les filtres' }).click()
    await expectQuery(page, {})
    await expect(entityCard(main, ride)).toBeVisible()
    await expect(entityCard(main, past.name)).toBeVisible()
    await expect(entityCard(main, post)).toHaveCount(0)
    await expect(typeRadio('Tout')).toBeChecked()
  })

  test('team posts: the posts alone, server-rendered, with no period', async ({
    page,
    context,
  }) => {
    const { owner, team, ride, post } = await teamWithFeed('filters-team-posts')
    await signIn(context, owner)
    const main = page.getByRole('main')

    const { markup, reads } = await openServerRendered(
      page,
      `/equipes/${team.slug}/articles`,
      `/api/teams/${team.slug}/publications`
    )
    expectInMarkup(markup, [post], [ride])
    noReadsAfterHydration(reads)
    await expect(entityCard(main, post)).toBeVisible()
    await expect(main.getByRole('radiogroup', { name: 'Période' })).toHaveCount(0)
  })

  test('home feed: type and membership from the URL, server-rendered, then « Effacer les filtres »', async ({
    page,
    context,
  }) => {
    const { owner, ride, post } = await teamWithFeed('filters-home')
    await signIn(context, owner)
    const main = page.getByRole('main')
    // The member home's « Cette semaine » also links to the ride: its card is looked for in the feed.
    const feed = homeFeed(page)
    // The home feed's type filter is a segmented control (radios), as everywhere on the site (RL6).
    const typeChip = (label: string) =>
      main
        .getByRole('radiogroup', { name: 'Type', exact: true })
        .getByRole('radio', { name: label })

    const { markup, reads } = await openServerRendered(
      page,
      '/?role=member&type=ride',
      '/api/publications'
    )
    expectInMarkup(markup, [ride], [post])
    noReadsAfterHydration(reads)
    await expect(entityCard(feed, ride)).toBeVisible()
    await expect(entityCard(feed, post)).toHaveCount(0)
    await expect(typeChip('Sorties')).toBeChecked()
    await expect(page.getByRole('combobox', { name: 'Portée', exact: true })).toHaveValue('Membre')

    // Nobody registered for the ride: « Je participe » empties the feed.
    await segment(page, 'Portée du fil', 'Je participe')
    await expectQuery(page, { role: 'member', type: 'ride', w: 'me' })
    await expect(
      main.getByRole('heading', { name: 'Aucune publication pour ces filtres' })
    ).toBeVisible()

    // Back to the defaults — the membership spelled out, as always on this list.
    await main.getByRole('button', { name: 'Effacer les filtres' }).click()
    await expectQuery(page, { role: 'member' })
    await expect(entityCard(feed, ride)).toBeVisible()
    await expect(entityCard(feed, post)).toBeVisible()
  })
})

test('team routes: distance, surface, sort and density from the URL, server-rendered, then « Effacer les filtres »', async ({
  page,
  context,
}) => {
  const { owner, team } = await ownTeam('filters-routes')
  const tag = unique('parcours')
  // Created shortest first, so the default order (newest first) is the longest first.
  const short: RouteDto = await newRoute(owner, team.slug, `Court ${tag}`, windingTrack(40), {
    surfaceType: 'GRAVEL',
  })
  const mid = await newRoute(owner, team.slug, `Moyen ${tag}`, windingTrack(200), {
    surfaceType: 'GRAVEL',
  })
  const long = await newRoute(owner, team.slug, `Long ${tag}`, windingTrack(400), {
    surfaceType: 'GRAVEL',
  })
  const road = await newRoute(owner, team.slug, `Route ${tag}`, windingTrack(300), {
    surfaceType: 'ROAD',
  })
  // A whole number of km between the short route and the others: the bound the URL carries.
  const minKm = Math.ceil(short.distance / 1000)
  expect(minKm * 1000, 'precondition: the bound keeps the middle route').toBeLessThan(mid.distance)
  await signIn(context, owner)
  const main = page.getByRole('main')
  const names = main.getByRole('link').filter({ hasText: new RegExp(escapeRegExp(tag)) })
  const expectNames = (routes: RouteDto[]) =>
    expect(names).toHaveText(routes.map((route) => new RegExp(escapeRegExp(route.name))))

  const filtered = {
    surf: 'GRAVEL',
    dmin: String(minKm * 1000),
    sort: 'DISTANCE',
    dir: 'ASC',
    view: 'row',
  }
  const { markup, reads } = await openServerRendered(
    page,
    `/equipes/${team.slug}/parcours?${new URLSearchParams(filtered)}`,
    `/api/teams/${team.slug}/routes`
  )
  // Gravel, beyond the bound, shortest first — and in rows: the density is in the markup too.
  expectInMarkup(markup, [mid.name, long.name], [short.name, road.name])
  expect(markup, 'the server rendered the dense rows').toMatch(
    /<input[^>]*type="radio"[^>]*checked=""[^>]*value="row"/
  )
  noReadsAfterHydration(reads)
  await expectNames([mid, long])
  await expect(page.getByRole('radio', { name: 'Lignes' })).toBeChecked()

  // The sort is in sight, out of the panel (RL6); the folded panel's button counts the two
  // criteria it hides (RL4).
  await expect(main.getByRole('combobox', { name: 'Trier par', exact: true })).toHaveValue(
    'Distance'
  )
  const toggle = main.getByRole('button', { name: 'Filtres, 2 actifs', exact: true })
  await hydrated(toggle)
  await toggle.click()
  await expect(main.getByRole('textbox', { name: 'Min' }).first()).toHaveValue(String(minKm))
  await expect(main.getByRole('combobox', { name: 'Type de revêtement', exact: true })).toHaveValue(
    'Gravel'
  )

  // Descending is the default direction: it leaves the URL.
  const ascending = main.getByRole('button', { name: 'Croissant', exact: true })
  await hydrated(ascending)
  await ascending.click()
  await expectQuery(page, { surf: 'GRAVEL', dmin: filtered.dmin, sort: 'DISTANCE', view: 'row' })
  await expectNames([long, mid])

  // « Effacer les filtres » drops the filters and keeps the sort and the density (RL4): neither
  // is a filter.
  await main.getByRole('button', { name: 'Effacer les filtres', exact: true }).click()
  await expectQuery(page, { sort: 'DISTANCE', view: 'row' })
  await expectNames([long, road, mid, short])
  await expect(page.getByRole('radio', { name: 'Lignes' })).toBeChecked()
  await expect(main.getByRole('button', { name: 'Filtres', exact: true })).toBeVisible()

  await segment(page, 'Affichage', 'Vignettes')
  await expectQuery(page, { sort: 'DISTANCE', view: 'card' })
  await expectNames([long, road, mid, short])
})

test('ads: search and type from the URL, server-rendered, then changed through the controls', async ({
  page,
  context,
}) => {
  const { owner, team } = await ownTeam('filters-ads')
  const tag = unique('annonce')
  const sale = await newAd(owner, team.slug, { name: `Velo de course ${tag}`, adType: 'SALE' })
  const rental = await newAd(owner, team.slug, {
    name: `Velo en location ${tag}`,
    adType: 'RENTAL',
    rentalPeriod: 'DAY',
  })
  const wanted = await newAd(owner, team.slug, { name: `Casque cherche ${tag}`, adType: 'WANTED' })
  await signIn(context, owner)
  const titles = page.getByRole('heading', { level: 4, name: new RegExp(escapeRegExp(tag)) })
  const search = page.getByRole('searchbox', { name: 'Rechercher des annonces' })
  // The kind is a segmented control (RL6).
  const typeRadio = (label: string) =>
    page.getByRole('radiogroup', { name: 'Filtrer par type' }).getByRole('radio', { name: label })

  const { markup, reads } = await openServerRendered(
    page,
    `/equipes/${team.slug}/annonces?q=Velo&type=RENTAL`,
    `/api/teams/${team.slug}/classifieds`
  )
  expectInMarkup(markup, [rental.name], [sale.name, wanted.name])
  noReadsAfterHydration(reads)
  await expect(titles).toHaveText([rental.name])
  await expect(search).toHaveValue('Velo')
  await expect(typeRadio('Location')).toBeChecked()

  await segment(page, 'Filtrer par type', 'Tous les types')
  await expectQuery(page, { q: 'Velo' })
  await expect(titles).toHaveText([rental.name, sale.name])
  // The watch does see the browser's own reads: a filter nobody prefetched is one.
  expect(
    readsOf(reads).some((read) => read.includes('search=Velo') && !read.includes('adType'))
  ).toBe(true)

  await search.fill('Casque')
  await expectQuery(page, { q: 'Casque' })
  await expect(titles).toHaveText([wanted.name])

  await segment(page, 'Filtrer par type', 'Vente')
  await expectQuery(page, { q: 'Casque', type: 'SALE' })
  await expect(page.getByRole('heading', { name: 'Aucune annonce pour ces filtres' })).toBeVisible()
})

/**
 * The team list (TeamListPage.tsx:34-49): its search (`q`) and membership filter (`role`, always
 * spelled out — two visitors resolve its default differently) live in the URL, and the `teams`
 * route's prefetch reads them through the same schema (teamListData.ts), so a filtered link is
 * server-rendered filtered and not read again once hydrated.
 *
 * The visitor is a fresh user: ADMIN of a team of its own, member of a public team, a stranger to
 * another public team and to a members-only one. Every team of the scene carries one unique tag in
 * its name, but for a public team outside the search.
 */
test('team list: search and membership from the URL, server-rendered, then changed through the controls', async ({
  page,
  context,
}) => {
  const [admin, visitor] = await Promise.all([roleSession('admin'), newUser('filters-teams')])
  const tag = unique('filtre').split(' ').at(-1)!
  // A user may own a single team (TeamService.MAX_ADMIN_TEAMS_PER_USER): the others are the
  // platform admin's, who is exempt.
  const [own, joined, open, closed, elsewhere] = await Promise.all([
    newTeam(visitor, `Equipe admin ${tag}`),
    newTeam(admin, `Equipe membre ${tag}`, { visibility: 'PUBLIC' }),
    newTeam(admin, `Equipe ouverte ${tag}`, { visibility: 'PUBLIC' }),
    newTeam(admin, `Equipe fermee ${tag}`),
    newTeam(admin, unique('Equipe hors recherche'), { visibility: 'PUBLIC' }),
  ])
  await addMember(admin, joined.slug, visitor)
  await signIn(context, visitor)
  const main = page.getByRole('main')
  const search = page.getByRole('searchbox', { name: 'Rechercher des équipes' })
  const membership = page.getByRole('combobox', { name: 'Portée', exact: true })
  /** The scene's team cards on screen: exactly `shown`. */
  const expectCards = async (shown: { name: string }[]) => {
    for (const team of [own, joined, open, closed, elsewhere])
      await expect(entityCard(main, team.name), team.name).toHaveCount(shown.includes(team) ? 1 : 0)
  }

  // Every team the search finds that the visitor may see: its own, and the public ones.
  const all = await openServerRendered(page, `/equipes?q=${tag}&role=all`, '/api/teams')
  for (const team of [own, joined, open]) expectInMarkup(all.markup, [team.name])
  expectInMarkup(all.markup, [], [closed.name, elsewhere.name])
  noReadsAfterHydration(all.reads)
  await expectCards([own, joined, open])
  await expect(search).toHaveValue(tag)
  await expect(membership).toHaveValue('Toutes les équipes')

  // A shared link narrowed to the teams one belongs to.
  const member = await openServerRendered(page, `/equipes?q=${tag}&role=member`, '/api/teams')
  for (const team of [own, joined]) expectInMarkup(member.markup, [team.name])
  expectInMarkup(member.markup, [], [open.name, closed.name, elsewhere.name])
  noReadsAfterHydration(member.reads)
  await expectCards([own, joined])
  await expect(membership).toHaveValue('Membre')

  // Through the controls: the URL follows.
  await pick(page, membership, 'Administrateur')
  await expectQuery(page, { q: tag, role: 'admin' })
  await expectCards([own])

  await pick(page, membership, 'Toutes les équipes')
  await expectQuery(page, { q: tag, role: 'all' })
  await expectCards([own, joined, open])

  await search.fill(`ouverte ${tag}`)
  await expectQuery(page, { q: `ouverte ${tag}`, role: 'all' })
  await expectCards([open])
})
