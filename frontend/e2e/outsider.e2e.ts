import { randomBytes } from 'node:crypto'
import type { Page } from '@playwright/test'
import type {
  AdDto,
  CommentDto,
  CommentRequest,
  PostDto,
  RideDto,
  TeamPageDto,
  TripDto,
} from '../src/api/dto'
import { newAd } from './support/ads'
import { ApiError, apiGet, apiPost, type AuthResponse } from './support/api'
import {
  addMember,
  markdownMedia,
  newTeam,
  newTeamPage,
  newUser,
  roleSession,
} from './support/data'
import { expect, test, unique } from './support/fixtures'
import { commentOnPost, newPost, postPath } from './support/posts'
import { joinGroup, newRide, postComments, ridePath } from './support/rides'
import { newTrip, stagePath, tripPath } from './support/routes'
import {
  authState,
  rawDocument,
  reactQueryState,
  sessionCookie,
  ssrOutlet,
  type RawDocument,
} from './support/ssr'
import { pageAs, pageHydrated } from './support/ui'

/**
 * A public team's content as someone outside the team meets it: an anonymous visitor, and a
 * signed-in user who belongs to no team of the scene (the « outsider »).
 *
 * The team is PUBLIC, and so are its ride, trip and post: anyone may read them. What stays the
 * members' is taking part and the conversation — no « Rejoindre », no comments, neither on screen
 * nor in the server document (its markup, its dehydrated query cache), nor in what the browser
 * fetches. The rides and trips say why and point the way: « Connectez-vous… » to an anonymous
 * visitor, « Voir l'équipe » to an outsider (RideDetailPage, TripDetailPage); a post says nothing,
 * it just has no comment section (PostDetailPage).
 *
 * Next to them, the same kinds left at TEAM visibility stay out of reach: « introuvable », and
 * nothing of them in the document. And ads are the members' only — no list, no detail — whatever
 * the team's visibility (AdAccessChecker needs a team role).
 *
 * Which page each (route, role) pair lands on is routes-render.e2e.ts; this spec is about what
 * those pages do and do not carry.
 */

/** A text found nowhere else: a random token, no markdown in it for a renderer to eat. */
const secretText = (label: string) => `${label}${randomBytes(8).toString('hex')}`

type Kind = 'ride' | 'trip' | 'post'

/**
 * What carries a thread: the three kinds, and a trip's stage (docs/LEDGER_*.md API-11), whose own
 * thread is the members' just the same.
 */
type Commented = Kind | 'stage'

interface Entity {
  kind: Commented
  name: string
  path: string
  /** The comments endpoint of the entity. */
  commentsApi: string
}

interface Scene {
  teamSlug: string
  teamName: string
  member: AuthResponse
  outsider: AuthResponse
  /** PUBLIC entities, each with a member's comment on it. */
  open: Record<Commented, Entity>
  /** The text of the member's comment on each open entity. */
  comments: Record<Commented, string>
  /** The same kinds left at TEAM visibility, and their texts. */
  closed: Record<Kind, Entity & { text: string }>
  ad: AdDto
  /** Everything of the ad a non-member must never get. */
  adSecrets: Record<string, string>
  /** A PUBLIC team page, and a TEAM one with its text: the latter is the members'. */
  teamPages: { open: TeamPageDto; closed: TeamPageDto & { text: string } }
}

let scene: Scene

test.beforeAll(async () => {
  const admin = await roleSession('admin')
  const [owner, member, outsider] = await Promise.all([
    newUser('outsider-owner'),
    newUser('outsider-member'),
    newUser('outsider-passerby'),
  ])
  const teamName = unique('Club ouvert')
  const team = await newTeam(owner, teamName, { visibility: 'PUBLIC' })
  await addMember(admin, team.slug, member)
  const slug = team.slug

  const [ride, trip, post] = await Promise.all([
    newRide(owner, slug, unique('Sortie ouverte'), { visibility: 'PUBLIC' }),
    newTrip(owner, slug, unique('Voyage ouvert'), [{ name: unique('Étape ouverte') }], {
      visibility: 'PUBLIC',
    }),
    newPost(owner, slug, unique('Article ouvert'), { visibility: 'PUBLIC' }),
  ])
  const comments: Record<Commented, string> = {
    ride: secretText('CommentaireSortie'),
    trip: secretText('CommentaireVoyage'),
    post: secretText('CommentaireArticle'),
    stage: secretText('CommentaireEtape'),
  }
  const stage = trip.stages[0]
  await Promise.all([
    postComments(member, slug, ride.slug, [comments.ride]),
    // The member takes part: their name is what a non-member must never get (API-144).
    joinGroup(member, slug, ride, 'Groupe A'),
    apiPost<CommentDto>(member, `/api/teams/${slug}/trips/${trip.slug}/comments`, {
      content: comments.trip,
    } satisfies CommentRequest),
    commentOnPost(member, slug, post.slug, comments.post),
    apiPost<CommentDto>(member, `/api/teams/${slug}/stages/${stage.slug}/comments`, {
      content: comments.stage,
    } satisfies CommentRequest),
  ])

  const closedText = {
    ride: secretText('SortieInterne'),
    trip: secretText('VoyageInterne'),
    post: secretText('ArticleInterne'),
  }
  const [closedRide, closedTrip, closedPost] = await Promise.all([
    newRide(owner, slug, unique('Sortie interne'), { media: markdownMedia(closedText.ride) }),
    newTrip(owner, slug, unique('Voyage interne'), [{ name: unique('Étape interne') }], {
      media: markdownMedia(closedText.trip),
    }),
    newPost(owner, slug, unique('Article interne'), { media: markdownMedia(closedText.post) }),
  ])

  const adSecrets = {
    'ad name': unique('Vélo à vendre'),
    'ad text': secretText('Annonce'),
    'ad place': secretText('Lieu'),
  }
  const ad = await newAd(member, slug, {
    name: adSecrets['ad name'],
    body: adSecrets['ad text'],
    price: 250,
    locationDescription: adSecrets['ad place'],
    locationGeometry: { type: 'Point', coordinates: [-1.68, 48.11] },
  })

  const closedPageText = secretText('PageInterne')
  const [openPage, closedPage] = await Promise.all([
    newTeamPage(owner, slug, unique('Page ouverte'), 'Page publique.', { visibility: 'PUBLIC' }),
    newTeamPage(owner, slug, unique('Page interne'), closedPageText),
  ])

  const entity = (kind: Kind, e: RideDto | TripDto | PostDto): Entity => {
    const plural = { ride: 'rides', trip: 'trips', post: 'posts' }[kind]
    const path = { ride: ridePath, trip: tripPath, post: postPath }[kind](slug, e.slug)
    return {
      kind,
      name: e.name,
      path,
      commentsApi: `/api/teams/${slug}/${plural}/${e.slug}/comments`,
    }
  }
  scene = {
    teamSlug: slug,
    teamName,
    member,
    outsider,
    open: {
      ride: entity('ride', ride),
      trip: entity('trip', trip),
      post: entity('post', post),
      stage: {
        kind: 'stage',
        name: stage.name,
        path: stagePath(slug, trip.slug, stage.slug),
        commentsApi: `/api/teams/${slug}/stages/${stage.slug}/comments`,
      },
    },
    comments,
    closed: {
      ride: { ...entity('ride', closedRide), text: closedText.ride },
      trip: { ...entity('trip', closedTrip), text: closedText.trip },
      post: { ...entity('post', closedPost), text: closedText.post },
    },
    ad,
    adSecrets,
    teamPages: { open: openPage, closed: { ...closedPage, text: closedPageText } },
  }
})

/** Who meets the team's content from outside: nobody, or a signed-in non-member. */
const VISITORS = [
  { visitor: 'anonymous', session: (): AuthResponse | undefined => undefined },
  { visitor: 'outsider', session: (): AuthResponse | undefined => scene.outsider },
] as const

const KINDS: readonly Kind[] = ['ride', 'trip', 'post']

const COMMENTED: readonly Commented[] = [...KINDS, 'stage']

/** The server document of `path`, as `auth` (or nobody) gets it, checked to be a real render. */
async function documentAs(path: string, auth: AuthResponse | undefined): Promise<RawDocument> {
  const document = await rawDocument(path, { cookie: auth ? sessionCookie(auth) : undefined })
  expect(document.status, `${path}: status`).toBe(200)
  expect(authState(document.html)?.user?.id ?? null, `${path}: rendered as`).toBe(
    auth?.user.id ?? null
  )
  return document
}

/** The dehydrated queries of a comments endpoint that carry data. */
const commentQueries = (html: string) =>
  reactQueryState(html)
    .queries.filter(
      (query) => String(query.queryKey[0]).endsWith('/comments') && query.state.data !== undefined
    )
    .map((query) => JSON.stringify(query.queryKey))

/**
 * Records the body of every API response the page receives from now on; returns a reader. Call it
 * before `goto`.
 */
function recordApi(page: Page) {
  const bodies: Promise<{ url: string; status: number; body: string }>[] = []
  page.on('response', (response) => {
    if (!new URL(response.url()).pathname.startsWith('/api/')) return
    bodies.push(
      response
        .text()
        .catch(() => '')
        .then((body) => ({ url: response.url(), status: response.status(), body }))
    )
  })
  return () => Promise.all(bodies)
}

/** The status of what `call` threw, or 'ok' when it went through. */
async function statusOf(call: Promise<unknown>): Promise<number | 'ok'> {
  try {
    await call
    return 'ok'
  } catch (error) {
    if (error instanceof ApiError) return error.status
    throw error
  }
}

test.describe('public content, seen from outside the team', () => {
  test('a member still sees who takes part in a public ride (positive control, API-144)', async () => {
    const { commentsApi } = scene.open.ride
    const rideApi = commentsApi.replace(/\/comments$/, '')
    const name = scene.member.user.displayName
    const ride = await apiGet<RideDto>(scene.member, rideApi)
    expect(ride.topParticipants.map((p) => p.displayName)).toContain(name)
  })

  test('a member gets each entity with its comments, server document included (positive control)', async () => {
    for (const kind of COMMENTED) {
      const { path, name } = scene.open[kind]
      const document = await documentAs(path, scene.member)
      const markup = ssrOutlet(document.html)
      expect.soft(markup.includes(name), `${kind}: the name in the markup`).toBe(true)
      expect
        .soft(markup.includes(scene.comments[kind]), `${kind}: the comment in the markup`)
        .toBe(true)
      expect.soft(commentQueries(document.html), `${kind}: comments handed over`).not.toEqual([])
    }
  })

  for (const { visitor, session } of VISITORS) {
    for (const kind of COMMENTED) {
      test(`${visitor} on a public ${kind}: no comment in the server document, nor through the API`, async () => {
        const auth = session()
        const { path, name, commentsApi } = scene.open[kind]
        const document = await documentAs(path, auth)
        const markup = ssrOutlet(document.html)
        // The entity itself is public: the page did render it.
        expect(markup, 'the name in the markup').toContain(name)
        expect
          .soft(document.html.includes(scene.comments[kind]), 'the comment anywhere')
          .toBe(false)
        expect.soft(markup, 'no comment section').not.toContain('Commentaires (')
        expect.soft(commentQueries(document.html), 'comments handed over').toEqual([])

        const refused = await statusOf(apiGet(auth, commentsApi))
        expect(refused, 'the comments endpoint refuses').not.toBe('ok')
      })
    }

    test(`${visitor} on a public ride: the count of participants, never a name (API-144)`, async () => {
      const auth = session()
      const { path, commentsApi } = scene.open.ride
      const rideApi = commentsApi.replace(/\/comments$/, '')
      const name = scene.member.user.displayName

      const document = await documentAs(path, auth)
      expect.soft(document.html.includes(name), 'the member name in the document').toBe(false)
      expect.soft(document.html.includes(scene.member.user.id), 'the member id').toBe(false)

      const ride = await apiGet<RideDto>(auth, rideApi)
      expect.soft(ride.participantCount, 'the count stays').toBeGreaterThan(0)
      expect.soft(ride.topParticipants, 'no preview').toEqual([])
      expect.soft(JSON.stringify(ride).includes(name), 'the name anywhere in the ride').toBe(false)
      for (const group of ride.groups) {
        expect.soft(group.participants, 'no group preview').toEqual([])
        expect.soft(group.leader ?? null, 'no leader').toBeNull()
      }
      expect(await statusOf(apiGet(auth, `${rideApi}/participants`)), 'the list is refused').toBe(
        auth ? 403 : 401
      )
    })

    test(`${visitor} on a public ride and trip: taking part is the members', no join, no comments`, async ({
      browser,
    }) => {
      const auth = session()
      const { context, page } = await pageAs(browser, auth)
      try {
        for (const kind of ['ride', 'trip'] as const) {
          const { path, name } = scene.open[kind]
          const noun = kind === 'ride' ? 'sorties' : 'voyages'
          const responses = recordApi(page)
          await page.goto(path)
          const main = page.getByRole('main')
          await expect(main.getByRole('heading', { level: 2, name })).toBeVisible()
          await pageHydrated(page)

          if (auth) {
            const alert = main.getByRole('alert').filter({
              hasText: `Rejoignez cette équipe pour participer aux ${noun}.`,
            })
            await expect(alert).toBeVisible()
            await expect(alert.getByRole('link', { name: "Voir l'équipe" })).toHaveAttribute(
              'href',
              `/equipes/${scene.teamSlug}`
            )
            await expect(main.getByText(/^Connectez-vous/)).toHaveCount(0)
          } else {
            const alert = main.getByRole('alert').filter({
              hasText: `Connectez-vous et rejoignez cette équipe pour participer aux ${noun}.`,
            })
            await expect(alert).toBeVisible()
            await expect(alert.getByRole('link', { name: 'Se connecter' })).toBeVisible()
            await expect(main.getByRole('link', { name: "Voir l'équipe" })).toHaveCount(0)
          }
          // Neither a group's « Rejoindre » nor « Rejoindre le voyage ».
          await expect(main.getByRole('button', { name: /^Rejoindre/ })).toHaveCount(0)
          await expect(main.getByRole('heading', { name: /^Commentaires/ })).toHaveCount(0)
          await expect(
            main.getByRole('textbox', { name: 'Écrivez un commentaire...' })
          ).toHaveCount(0)
          await expect(page.getByText(scene.comments[kind])).toHaveCount(0)

          // Nor did the page fetch them.
          for (const response of await responses()) {
            expect
              .soft(response.body.includes(scene.comments[kind]), `${kind}: ${response.url}`)
              .toBe(false)
          }
        }
      } finally {
        await context.close()
      }
    })

    test(`${visitor} on a public post: it reads, without a comment section`, async ({
      browser,
    }) => {
      const auth = session()
      const { context, page } = await pageAs(browser, auth)
      try {
        const { path, name } = scene.open.post
        const responses = recordApi(page)
        await page.goto(path)
        const main = page.getByRole('main')
        await expect(main.getByRole('heading', { level: 2, name })).toBeVisible()
        await pageHydrated(page)
        await expect(main.getByRole('heading', { name: /^Commentaires/ })).toHaveCount(0)
        await expect(main.getByRole('textbox', { name: 'Écrivez un commentaire...' })).toHaveCount(
          0
        )
        await expect(page.getByText(scene.comments.post)).toHaveCount(0)
        for (const response of await responses())
          expect.soft(response.body.includes(scene.comments.post), response.url).toBe(false)
      } finally {
        await context.close()
      }
    })

    test(`${visitor}: a TEAM ride, trip and post of the public team stay not found`, async ({
      browser,
    }) => {
      const auth = session()
      const notFound: Record<Kind, string> = {
        ride: 'Sortie non trouvée',
        trip: 'Voyage introuvable',
        post: 'Publication introuvable',
      }
      for (const kind of KINDS) {
        const { path, name, text } = scene.closed[kind]
        const document = await documentAs(path, auth)
        for (const [label, secret] of Object.entries({ name, text }))
          expect
            .soft(document.html.includes(secret), `${kind}: its ${label} in the document`)
            .toBe(false)
      }

      const { context, page } = await pageAs(browser, auth)
      try {
        for (const kind of KINDS) {
          const { path, name, text } = scene.closed[kind]
          const responses = recordApi(page)
          await page.goto(path)
          // The pages retry a 404 three times before saying so (pinned in flow-trips.e2e.ts).
          await expect(
            page.getByRole('main').getByRole('heading', { name: notFound[kind] })
          ).toBeVisible({ timeout: 15_000 })
          await expect(page.getByText(name)).toHaveCount(0)
          for (const response of await responses())
            for (const secret of [name, text])
              expect.soft(response.body.includes(secret), `${kind}: ${response.url}`).toBe(false)
        }
      } finally {
        await context.close()
      }
    })

    test(`${visitor}: nothing of an ad, neither the list nor the detail`, async ({ browser }) => {
      const auth = session()
      const { ad, adSecrets, teamSlug } = scene
      const listPath = `/equipes/${teamSlug}/annonces`
      const adPath = `${listPath}/${ad.slug}`

      // The API: no list, no ad.
      expect(await statusOf(apiGet(auth, `/api/teams/${teamSlug}/classifieds`))).not.toBe('ok')
      expect(
        await statusOf(apiGet(auth, `/api/teams/${teamSlug}/classifieds/${ad.slug}`))
      ).not.toBe('ok')

      // The server documents: an anonymous visitor is sent to sign in, an outsider gets the
      // team's tab — neither carries the ad.
      for (const path of [listPath, adPath]) {
        const document = await rawDocument(path, {
          cookie: auth ? sessionCookie(auth) : undefined,
        })
        for (const [label, secret] of Object.entries(adSecrets))
          expect.soft(document.html.includes(secret), `${path}: the ${label}`).toBe(false)
        expect
          .soft(
            reactQueryState(document.html)
              .queries.filter(
                (query) =>
                  String(query.queryKey[0]).includes('/classifieds') &&
                  query.state.data !== undefined
              )
              .map((query) => JSON.stringify(query.queryKey)),
            `${path}: ad queries handed over`
          )
          .toEqual([])
      }

      // With JavaScript: whatever the pages fetch, nothing of the ad.
      const { context, page } = await pageAs(browser, auth)
      try {
        for (const path of [listPath, adPath]) {
          const responses = recordApi(page)
          await page.goto(path)
          await pageHydrated(page)
          if (auth) {
            // Settled on the tab's empty state — so the absence below is not vacuous. Its wording
            // is not the point: « Aucune annonce » today, a members-only « Réservées aux membres »
            // once AdListPage tells a non-member why (a fix under way).
            await expect(
              page
                .getByRole('main')
                .getByText(/^(Aucune annonce|Réservées aux membres)/)
                .first()
            ).toBeVisible()
          } else {
            await expect(page).toHaveURL(/\/connexion/)
          }
          const text = await page.locator('body').innerText()
          const all = await responses()
          for (const [label, secret] of Object.entries(adSecrets)) {
            expect.soft(text.includes(secret), `${path}: the ${label} on screen`).toBe(false)
            for (const response of all)
              expect.soft(response.body.includes(secret), `${path}: ${response.url}`).toBe(false)
          }
        }
      } finally {
        await context.close()
      }
    })
  }
})

/**
 * A custom page left at TEAM visibility, in a PUBLIC team: the members' own. Seen from outside, the
 * team shows its PUBLIC page as a tab — the positive control that tabs are rendered at all — and
 * nothing of the TEAM one: no tab, no page, not its title, its slug or its text.
 */
test.describe("a public team's members-only custom page, seen from outside", () => {
  const teamPath = () => `/equipes/${scene.teamSlug}`
  const pagePath = (page: TeamPageDto) => `${teamPath()}/pages/${page.slug}`
  /** Everything that names or holds the TEAM page. */
  const pageSecrets = () => {
    const { closed } = scene.teamPages
    return { 'page title': closed.title, 'page slug': closed.slug, 'page text': closed.text }
  }

  test('a member gets both pages as tabs, and the members-only one (positive control)', async () => {
    const { open, closed } = scene.teamPages
    const team = ssrOutlet((await documentAs(teamPath(), scene.member)).html)
    expect.soft(team.includes(`href="${pagePath(open)}"`), 'the public tab').toBe(true)
    expect.soft(team.includes(`href="${pagePath(closed)}"`), 'the members-only tab').toBe(true)
    const page = ssrOutlet((await documentAs(pagePath(closed), scene.member)).html)
    expect.soft(page.includes(closed.title), 'the page title').toBe(true)
    expect.soft(page.includes(closed.text), 'the page text').toBe(true)
  })

  for (const { visitor, session } of VISITORS) {
    test(`${visitor}: the members-only page is neither a tab nor a page`, async ({ browser }) => {
      const auth = session()
      const { open, closed } = scene.teamPages
      // The API refuses the page itself.
      expect(
        await statusOf(apiGet(auth, `/api/teams/${scene.teamSlug}/pages/${closed.slug}`))
      ).not.toBe('ok')

      const { context, page } = await pageAs(browser, auth)
      try {
        await page.goto(teamPath())
        const main = page.getByRole('main')
        await expect(main.getByRole('heading', { level: 1, name: scene.teamName })).toBeVisible()
        await pageHydrated(page)
        // The public page is a tab (a link, in the menu on a phone): tabs are there.
        await expect(page.locator(`a[href="${pagePath(open)}"]`).first()).toBeAttached()
        await expect(page.locator(`a[href="${pagePath(closed)}"]`)).toHaveCount(0)
        expect(await page.locator('body').innerText()).not.toContain(closed.title)

        // Its address leads back to the team, without showing it.
        await page.goto(pagePath(closed))
        await expect(page).toHaveURL(teamPath(), { timeout: 15_000 })
        await expect(main.getByRole('heading', { level: 1, name: scene.teamName })).toBeVisible()
        const text = await page.locator('body').innerText()
        for (const [label, secret] of Object.entries(pageSecrets()))
          expect.soft(text.includes(secret), `the ${label} on screen`).toBe(false)
      } finally {
        await context.close()
      }
    })

    test(`${visitor}: nothing of the members-only page in the server documents nor the API`, async () => {
      // Regression (fe40f8f7): TeamDetailDto.from lists a TEAM page to its members only — before,
      // GET /api/teams/{slug} (and the SSR's #ssr-query-state block) handed its title and slug to
      // anyone who may read a PUBLIC team; the web hid them on screen only.
      const auth = session()
      const closedPath = pagePath(scene.teamPages.closed)
      for (const path of [teamPath(), `${teamPath()}/a-propos`, closedPath]) {
        const document = await rawDocument(path, {
          cookie: auth ? sessionCookie(auth) : undefined,
        })
        expect(authState(document.html)?.user?.id ?? null, `${path}: rendered as`).toBe(
          auth?.user.id ?? null
        )
        for (const [label, secret] of Object.entries(pageSecrets())) {
          // The page's own address carries its slug: an echo of the URL typed, not a leak.
          if (path === closedPath && label === 'page slug') continue
          expect.soft(document.html.includes(secret), `${path}: the ${label}`).toBe(false)
        }
      }
      // What the team's own read hands to anyone who may read the team.
      const team = await apiGet<unknown>(auth, `/api/teams/${scene.teamSlug}`)
      for (const [label, secret] of Object.entries(pageSecrets()))
        expect
          .soft(JSON.stringify(team).includes(secret), `GET /api/teams/{slug}: the ${label}`)
          .toBe(false)
    })
  }
})
