import type { Locator, Page } from '@playwright/test'
import type { CalendarTokenDto, SlugChangeRequest, TeamDetailDto } from '../../src/api/dto'
import { apiGet, apiPatch, withApi, type AuthResponse } from './api'
import { newAd } from './ads'
import { addMember, newTeam, newUser } from './data'
import { unique } from './fixtures'
import { newRide, ridePath } from './rides'
import { newRoute, routePath, windingTrack } from './routes'

/**
 * The slug journey (slug-change.e2e.ts): renaming the URL of a team, a ride, a route or an ad with
 * the edit form's `SlugEditor`, and the redirects the backend keeps from every old slug
 * (`TeamSlugRedirect`, `TeamEntitySlugRedirect`) — which the server turns into a 301 for an old
 * team slug, and the pages into the new URL on the client (`useCanonicalPath`) for an old entity
 * slug.
 */

/** What renaming one kind of entity involves: its URLs, its API path, its pages' landmarks. */
export interface SlugTarget {
  kind: 'team' | 'ride' | 'route' | 'ad'
  /** The edit page holding the slug editor (the settings, for a team). */
  editPath: (teamSlug: string, slug: string) => string
  /** The page a shared link points to. */
  detailPath: (teamSlug: string, slug: string) => string
  /** The API resource, whose `/slug` sub-resource the editor PATCHes. */
  apiPath: (teamSlug: string, slug: string) => string
  /** The edit page's title. */
  editTitle: string
  /** The detail page's heading, which names the entity. */
  detailHeading: (page: Page, name: string) => Locator
  /** The toast the edit form's own « Enregistrer » shows. */
  savedToast: string
}

const heading = (level: number) => (page: Page, name: string) =>
  page.getByRole('main').getByRole('heading', { level, name, exact: true })

export const teamTarget: SlugTarget = {
  kind: 'team',
  editPath: (teamSlug) => `/equipes/${teamSlug}/admin/parametres`,
  detailPath: (teamSlug) => `/equipes/${teamSlug}`,
  apiPath: (teamSlug) => `/api/teams/${teamSlug}`,
  editTitle: 'Paramètres',
  detailHeading: heading(1),
  savedToast: 'Équipe mise à jour avec succès',
}

export const entityTargets: SlugTarget[] = [
  {
    kind: 'ride',
    editPath: (teamSlug, slug) => `${ridePath(teamSlug, slug)}/modifier`,
    detailPath: ridePath,
    apiPath: (teamSlug, slug) => `/api/teams/${teamSlug}/rides/${slug}`,
    editTitle: 'Modifier la sortie',
    detailHeading: heading(1),
    savedToast: 'Sortie mise à jour avec succès',
  },
  {
    kind: 'route',
    editPath: (teamSlug, slug) => `${routePath(teamSlug, slug)}/modifier`,
    detailPath: routePath,
    apiPath: (teamSlug, slug) => `/api/teams/${teamSlug}/routes/${slug}`,
    editTitle: 'Modifier le parcours',
    detailHeading: heading(1),
    savedToast: 'Parcours mis à jour avec succès',
  },
  {
    kind: 'ad',
    editPath: (teamSlug, slug) => `/equipes/${teamSlug}/annonces/${slug}/modifier`,
    detailPath: (teamSlug, slug) => `/equipes/${teamSlug}/annonces/${slug}`,
    apiPath: (teamSlug, slug) => `/api/teams/${teamSlug}/classifieds/${slug}`,
    editTitle: "Modifier l'annonce",
    detailHeading: heading(1),
    savedToast: 'Annonce mise à jour avec succès',
  },
]

export const rideTarget = entityTargets[0]
export const routeTarget = entityTargets[1]
export const adTarget = entityTargets[2]

/** A slug no other test — nor another run — will produce, from `unique(label)`. */
export function freshSlug(label: string): string {
  return unique(label)
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
}

/**
 * A members-only team of its own, owned by a fresh user (its ADMIN — never a platform admin, whose
 * rights short-circuit the checks), and a plain member, added by the platform admin: the member is
 * the one who follows the old links.
 */
export async function slugScene(label: string) {
  const [owner, member] = await Promise.all([
    newUser(`Slug ${label} bureau`),
    newUser(`Slug ${label} membre`),
  ])
  const team = await newTeam(owner, unique(`Slug ${label}`))
  await addMember(team.slug, member)
  return { owner, member, team }
}

/** A ride, a route or an ad of the team, created as `owner`: its slug and name. */
export async function newEntity(
  kind: Exclude<SlugTarget['kind'], 'team'>,
  owner: AuthResponse,
  teamSlug: string,
  label: string
): Promise<{ id: string; slug: string; name: string }> {
  const name = unique(label)
  switch (kind) {
    case 'ride':
      return newRide(owner, teamSlug, name)
    case 'route':
      return newRoute(owner, teamSlug, name, windingTrack(60))
    case 'ad':
      return newAd(owner, teamSlug, { name, price: 50 })
  }
}

/** PATCH {apiPath}/slug as `who` — what the editor sends, for a rename the test does not watch. */
export const renameThroughApi = (
  who: AuthResponse,
  target: SlugTarget,
  teamSlug: string,
  slug: string,
  newSlug: string
) =>
  apiPatch<{ slug: string }>(who, `${target.apiPath(teamSlug, slug)}/slug`, {
    slug: newSlug,
  } satisfies SlugChangeRequest)

/** The entity as `who` reads it at `slug` — an old slug resolves through its redirect. */
export const readAt = (who: AuthResponse, target: SlugTarget, teamSlug: string, slug: string) =>
  apiGet<{ id: string; slug: string }>(who, target.apiPath(teamSlug, slug))

export const readTeamAt = (who: AuthResponse, slug: string) =>
  apiGet<TeamDetailDto>(who, `/api/teams/${slug}`)

/** Whether `url` is a slug PATCH (`…/slug`, the only sub-resource of that name). */
export const isSlugPatch = (method: string, url: string) =>
  method === 'PATCH' && new URL(url).pathname.endsWith('/slug')

/** The hint the slug editor shows while open — the parent of its input, its buttons, its error. */
const SLUG_HINT = "L'ancienne URL redirigera vers la nouvelle."

/**
 * The `SlugEditor` of an edit form. Closed, it reads « URL: {baseUrl}{slug} » with a pencil
 * (« Modifier l'URL »); open, an unlabelled input between two icon buttons (« Enregistrer »,
 * « Annuler ») above the hint.
 */
export function slugEditor(page: Page) {
  const main = page.getByRole('main')
  const open = main.getByText(SLUG_HINT, { exact: true }).locator('xpath=..')
  return {
    pencil: main.getByRole('button', { name: "Modifier l'URL", exact: true }),
    open,
    input: open.getByRole('textbox'),
    save: open.getByRole('button', { name: 'Enregistrer', exact: true }),
    cancel: open.getByRole('button', { name: 'Annuler', exact: true }),
    /** The closed editor's line, which ends with the current slug. */
    shown: (slug: string) => main.getByText(new RegExp(`/${slug}$`)),
  }
}

/**
 * The team's ICS feed as a calendar app subscribed to it for `who` fetches it: the URL the profile
 * hands out (`teamFeedUrlTemplate`), with `teamSlug` in it — an old one, for a subscription made
 * before a rename. Only its path is kept: the template carries the domain's public base URL.
 */
export async function teamFeed(who: AuthResponse, teamSlug: string) {
  const { teamFeedUrlTemplate } = await apiGet<CalendarTokenDto>(who, '/api/calendar/token')
  const url = new URL(teamFeedUrlTemplate.replace('{teamSlug}', teamSlug))
  return withApi(undefined, async (api) => {
    const response = await api.get(url.pathname + url.search)
    return { status: response.status(), body: await response.text() }
  })
}
