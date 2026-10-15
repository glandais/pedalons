/**
 * What a page view sends to the audience counter — and, above all, what it never sends
 * (docs/plans/2026-10-15-web-analytics.md §4.2, docs/LEDGER_*.md WEB-90).
 *
 * Built from the router's matched route only: the host, the route's canonical French template and
 * the one `:teamSlug` it may carry. Never from `location.pathname`/`search`/`hash`,
 * `window.location` or `document.title`: those hold object slugs, ids of capability URLs
 * (`/outils-gpx/{previewId}`), tokens in the query string, and the names of private content. Never
 * the visitor's session either — the route's static `auth` answers « public or members-only ».
 *
 * Pure, and touches no browser global, so it is imported by the SSR bundle without effect.
 */
import { routeById } from '@/config/routeUtils'

/** `handle.routeId` of the router's `*` catch-all (RouteGenerator.tsx), counted as `/<host>/404`. */
export const NOT_FOUND_ROUTE_ID = 'not-found'

/** The backend's slug rule (SlugService.PATTERN_VALID_SLUG and MAX_SLUG_LENGTH). */
const SLUG_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/
const MAX_SLUG_LENGTH = 200

const TEAM_SLUG_SEGMENT = ':teamSlug'

/** The part of a router state this module reads — a data router's `state` satisfies it. */
export interface CountableState {
  matches: ReadonlyArray<{
    params: Readonly<Record<string, string | undefined>>
    route: { handle?: unknown }
  }>
}

/** A page view, before the sender adds the screen width and the cache buster. */
export interface CountHit {
  /** `/<host>` + the route template, `:teamSlug` filled in when well formed. */
  p: string
  /** `<routeId> · <auth of the route>`. */
  t: string
  /** The external referrer's origin, on the first page view of a load only. */
  r?: string
}

/** The route id a match carries, or undefined for a match without one (a gated route). */
export function leafRouteId(state: CountableState): string | undefined {
  const handle = state.matches.at(-1)?.route.handle as { routeId?: unknown } | undefined
  return typeof handle?.routeId === 'string' ? handle.routeId : undefined
}

/** A team slug the router resolved, kept only when it has the form of a slug. */
function validTeamSlug(value: string | undefined): string | undefined {
  if (!value || value.length > MAX_SLUG_LENGTH || !SLUG_PATTERN.test(value)) return undefined
  return value
}

/** Replace the one segment equal to `:teamSlug`, once; every other parameter stays a marker. */
function fillTeamSlug(template: string, teamSlug: string | undefined): string {
  if (!teamSlug) return template
  const segments = template.split('/')
  const index = segments.indexOf(TEAM_SLUG_SEGMENT)
  if (index < 0) return template
  segments[index] = teamSlug
  return segments.join('/')
}

/** The origin of an external referrer; nothing for an internal, empty or unreadable one. */
function externalOrigin(referrer: string, host: string): string | undefined {
  if (!referrer) return undefined
  let url: URL
  try {
    url = new URL(referrer)
  } catch {
    return undefined
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return undefined
  if (url.host === host) return undefined
  return url.origin
}

/**
 * The hit for the router's current state, or null when the matched route carries no `routeId`
 * (a route gated on a single-team site renders a redirect, not a page) or an unknown one.
 *
 * @param host the host the browser shows (`location.host`): one per club domain and alias
 * @param referrer `document.referrer`, read only when `isFirst`
 * @param isFirst true for the first page view of the load: a client-side navigation keeps the
 *   same `document.referrer`, which must not be sent again
 */
export function toCountHit(
  state: CountableState,
  host: string,
  referrer: string,
  isFirst: boolean
): CountHit | null {
  const routeId = leafRouteId(state)
  if (!routeId) return null

  let template: string
  let auth: string
  if (routeId === NOT_FOUND_ROUTE_ID) {
    template = '/404'
    auth = 'public'
  } else {
    const config = routeById.get(routeId)
    if (!config) return null
    const teamSlug = validTeamSlug(state.matches.at(-1)?.params.teamSlug)
    template = fillTeamSlug(config.paths.fr, teamSlug)
    auth = config.auth
  }

  // GoatCounter drops a trailing slash itself; dropping it here keeps the sent value the stored one.
  const p = template === '/' ? `/${host}` : `/${host}${template}`
  const hit: CountHit = { p, t: `${routeId} · ${auth}` }
  const r = isFirst ? externalOrigin(referrer, host) : undefined
  if (r) hit.r = r
  return hit
}
