/**
 * The gallery's API: an axios adapter on the shared instance (`AXIOS_INSTANCE`, the one every
 * generated hook goes through), answering from the fixtures — nothing leaves the page. A request it
 * does not know is recorded in {@link unservedRequests} and answered 404, so a card that grew a new
 * call shows up (in the console, and in the gallery's test) instead of silently reaching a server.
 * `fetch` to `/api/…` (the app config, the session refresh) is answered the same way.
 */
import type { AxiosAdapter, AxiosResponse, InternalAxiosRequestConfig } from 'axios'
import { AxiosError } from 'axios'
import { AXIOS_INSTANCE } from '@/lib/axiosInstance'
import {
  APP_CONFIG,
  COMMENTS,
  DEVICES,
  GRAVEL_TEAM,
  INVITATION,
  MARKDOWN_COMMENTS,
  MARKDOWN_COMMENTS_SLUG,
  PEOPLE,
  READER,
  ROUTE_USAGES,
  routeDetails,
  TEMPLATE,
  TEMPLATE_DRAFT,
  VCM_TEAM,
} from './fixtures'

type Params = Record<string, unknown>
type Handler = (match: RegExpMatchArray, params: Params) => unknown

/** Team slugs of the cases that mount a whole page, one per case (see `sections/divers.tsx`). */
export const TEMPLATE_TEAM_SLUGS = {
  modele: 'velo-club-des-monts-modele',
  'modele-brouillon': 'velo-club-des-monts-modele-brouillon',
} as const

const EMPTY_PAGE = { total: 0, page: 0, size: 20 }

const routes: Array<[method: string, path: RegExp, handler: Handler]> = [
  ['get', /^\/api\/config$/, () => APP_CONFIG],
  ['get', /^\/api\/users\/me$/, () => READER],
  ['get', /^\/api\/gps\/available$/, () => []],
  ['get', /^\/api\/users\/me\/invitations$/, () => ({ invitations: [INVITATION] })],
  ['get', /^\/api\/users\/me\/devices$/, () => DEVICES],
  // « Ma prochaine sortie » when nothing is booked: the member home with empty lists.
  ['get', /^\/api\/users\/me\/participations$/, () => ({ publications: [], ...EMPTY_PAGE })],
  ['get', /^\/api\/publications$/, () => ({ publications: [], ...EMPTY_PAGE })],
  ['get', /^\/api\/calendar\/events$/, () => ({ events: [] })],
  [
    'get',
    /^\/api\/teams$/,
    () => ({ teams: [VCM_TEAM, GRAVEL_TEAM], total: 2, page: 0, size: 20 }),
  ],
  ['get', /^\/api\/teams\/[^/]+\/routes\/[^/]+\/usages$/, () => ({ usages: ROUTE_USAGES })],
  // The « GPS » menu of a card without its route (« Ma prochaine sortie »): its GPX and FIT links.
  [
    'get',
    /^\/api\/teams\/[^/]+\/routes\/bulk$/,
    (_match, params) => {
      const slugs = ([] as unknown[]).concat(params.slug ?? [])
      return { routes: [...routeDetails().values()].filter((r) => slugs.includes(r.slug)) }
    },
  ],
  [
    'get',
    /^\/api\/teams\/[^/]+\/rides\/[^/]+\/participants$/,
    () => ({ participants: PEOPLE, total: PEOPLE.length, page: 0, size: 20 }),
  ],
  [
    'get',
    /^\/api\/teams\/[^/]+\/rides\/([^/]+)\/comments$/,
    (match) => {
      const items = match[1] === MARKDOWN_COMMENTS_SLUG ? MARKDOWN_COMMENTS : COMMENTS
      const total = items === COMMENTS ? 3 : items.length
      return { items, total, itemTotal: items.length, page: 0, size: 20 }
    },
  ],
  [
    'get',
    /^\/api\/teams\/([^/]+)\/ride-templates$/,
    (match) => {
      const templates =
        match[1] === TEMPLATE_TEAM_SLUGS['modele-brouillon'] ? [TEMPLATE_DRAFT] : [TEMPLATE]
      return { templates, total: templates.length, page: 0, size: 20 }
    },
  ],
  // The template pages' team: an organizer's view, since only organizers reach that page.
  [
    'get',
    /^\/api\/teams\/([^/]+)$/,
    (match) => ({ ...VCM_TEAM, slug: match[1], role: 'ORGANIZER' }),
  ],
]

export const unservedRequests: string[] = []

function answer(config: InternalAxiosRequestConfig): AxiosResponse | undefined {
  const method = (config.method ?? 'get').toLowerCase()
  const path = (config.url ?? '').split('?')[0]
  for (const [verb, pattern, handler] of routes) {
    if (verb !== method) continue
    const match = path.match(pattern)
    if (match) {
      return {
        data: handler(match, (config.params ?? {}) as Params),
        status: 200,
        statusText: 'OK',
        headers: {},
        config,
      }
    }
  }
  return undefined
}

const galleryAdapter: AxiosAdapter = async (config) => {
  const response = answer(config)
  if (response) return response
  const label = `${(config.method ?? 'get').toUpperCase()} ${config.url}`
  unservedRequests.push(label)
  console.warn(`[galerie] requête non servie : ${label}`)
  const notFound: AxiosResponse = {
    data: { code: 'NOT_FOUND', message: 'galerie' },
    status: 404,
    statusText: 'Not Found',
    headers: {},
    config,
  }
  throw new AxiosError('galerie', AxiosError.ERR_BAD_REQUEST, config, null, notFound)
}

let installed = false

/** Routes every API call of the page to the fixtures. Idempotent. */
export function installFakeApi(): void {
  if (installed) return
  installed = true
  AXIOS_INSTANCE.defaults.adapter = galleryAdapter

  if (typeof window !== 'undefined' && typeof window.fetch === 'function') {
    const realFetch = window.fetch.bind(window)
    window.fetch = (input, init) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url
      const path = new URL(url, window.location.href).pathname
      if (path.startsWith('/api/')) {
        unservedRequests.push(`FETCH ${path}`)
        console.warn(`[galerie] fetch non servi : ${path}`)
        return Promise.resolve(new Response('{}', { status: 404 }))
      }
      return realFetch(input, init)
    }
  }
}
