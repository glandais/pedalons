import { paths } from '@/config/paths'

/**
 * Where the addresses of the former team feed now lead (ledger `WEB-68`, plan 2026-10-06 §5). The
 * feed — `team?tab=publications` for a member, the bare team URL with its filters for a visitor —
 * gave way to the dashboard for everyone, the « Agenda » (rides and trips) and the
 * « Publications » (posts); the « Sorties » and « Voyages » tabs (`teamRides`, `teamTrips`,
 * WEB-64) to the agenda.
 *
 * Pure functions of the URL: the routes' loaders call them (routes.config.ts), so the server
 * answers a redirect and a client navigation replaces its history entry — the old address never
 * stays in the back stack. Each returns `undefined` when there is nothing to redirect.
 *
 * Filters carried over: the search (`q`) everywhere; the tags with a kind; « Je participe »
 * (`w=me`) on the agenda. `w=upcoming`, `w=all` and `w=past` all become « Toutes les dates », the
 * agenda's default (RL15), so they are dropped rather than written.
 */

/** Builds `path?query`, without a dangling `?`. */
function withQuery(path: string, query: URLSearchParams): string {
  const qs = query.toString()
  return qs ? `${path}?${qs}` : path
}

/** The agenda's own params, from a former feed URL: kind, « Je participe », search, tags. */
function agendaQuery(from: URLSearchParams, type: 'ride' | 'trip' | undefined): URLSearchParams {
  const query = new URLSearchParams()
  if (type) query.set('type', type)
  if (from.get('w') === 'me') query.set('w', 'me')
  const search = from.get('q')
  if (search) query.set('q', search)
  const tags = from.get('tags')
  if (type && tags) query.set('tags', tags)
  return query
}

/**
 * The team's own URL (`team`) carrying the former feed's parameters: `?tab=publications`, or a
 * visitor's `?type=…` / `?w=…`.
 */
export function teamHomeRedirect(teamSlug: string, search: URLSearchParams): string | undefined {
  const type = search.get('type')
  const scope = search.get('w')
  const isFeed = search.get('tab') === 'publications' || type !== null || scope !== null
  if (!isFeed) return undefined

  if (type === 'post') {
    const query = new URLSearchParams()
    const q = search.get('q')
    if (q) query.set('q', q)
    const tags = search.get('tags')
    if (tags) query.set('tags', tags)
    return withQuery(paths.teamPosts(teamSlug), query)
  }
  if (type === 'ride' || type === 'trip') {
    return withQuery(paths.teamAgenda(teamSlug), agendaQuery(search, type))
  }
  // A scope with no kind: the agenda as a whole, « Je participe » kept.
  if (scope === 'me' || scope === 'upcoming' || scope === 'all' || scope === 'past') {
    return withQuery(paths.teamAgenda(teamSlug), agendaQuery(search, undefined))
  }
  // `?tab=publications` alone: the feed is gone, the team page is the dashboard.
  return paths.team(teamSlug)
}

/** The former « Sorties » tab (`teamRides`): the agenda. */
export function teamRidesRedirect(teamSlug: string, search: URLSearchParams): string {
  return withQuery(paths.teamAgenda(teamSlug), agendaQuery(search, undefined))
}

/** The former « Voyages » tab (`teamTrips`): the agenda narrowed to trips. */
export function teamTripsRedirect(teamSlug: string, search: URLSearchParams): string {
  return withQuery(paths.teamAgenda(teamSlug), agendaQuery(search, 'trip'))
}

/**
 * The agenda's own address carrying a period it no longer has (RL15): « À venir » (`w=upcoming`)
 * and « Passées » (`w=past`) are the two sections of « Toutes les dates », the default, so the
 * parameter is dropped and everything else kept. « Je participe » (`w=me`) stays.
 */
export function teamAgendaRedirect(teamSlug: string, search: URLSearchParams): string | undefined {
  const query = withoutFormerPeriod(search)
  return query ? withQuery(paths.teamAgenda(teamSlug), query) : undefined
}

/**
 * The home feed's address carrying « À venir » (`w=upcoming`), which RL15 folded into « Tout »:
 * its upcoming rides are the first section. The parameter is dropped, the rest kept.
 */
export function homeFeedRedirect(search: URLSearchParams): string | undefined {
  const query = withoutFormerPeriod(search)
  return query ? withQuery(paths.home(), query) : undefined
}

/** `search` without its `w`, when it holds a period other than « Je participe »; else nothing. */
function withoutFormerPeriod(search: URLSearchParams): URLSearchParams | undefined {
  const scope = search.get('w')
  if (scope === null || scope === 'me') return undefined
  const query = new URLSearchParams(search)
  query.delete('w')
  return query
}
