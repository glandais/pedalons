/**
 * The list gallery's API: an axios adapter on the shared instance (`AXIOS_INSTANCE`, the one every
 * generated hook goes through), answering from the fixtures — nothing leaves the page. Every
 * endpoint a list page reads has a name and an answer at rest; a case replaces some of them
 * ({@link setScenario}): another page of data, an empty page, a server error, a wait that never
 * ends. The page itself — its filters, counter, pagination, empty and error states — runs as in
 * production on top of these answers.
 *
 * A request no endpoint matches is recorded in {@link unservedRequests} and answered 404, so a
 * page that grew a new call shows up in the gallery's test instead of silently reaching a server.
 */
import type { AxiosAdapter, AxiosResponse, InternalAxiosRequestConfig } from 'axios'
import { AxiosError } from 'axios'
import { AXIOS_INSTANCE } from '@/lib/axiosInstance'
import { APP_CONFIG, READER, ride, routeDetails, weatherLeg } from '../cardGallery/fixtures'
import {
  ADS,
  ADS_TOTAL,
  AGENDA,
  AGENDA_PAST,
  ALL_ROUTES,
  GROUP_B_PEOPLE,
  MEMBERS,
  MONTH_EVENTS,
  MY_TEAMS,
  NOTIFICATIONS,
  POSTS,
  ROUTES,
  TEMPLATES,
  VCM_ORGANIZER,
  teamTags,
} from './listFixtures'

type Params = Record<string, unknown>

/** What an endpoint answers: data, a server error, or nothing ever. */
export type Reply = { data: unknown } | { status: 500 } | 'pending'

export const ok = (data: unknown): Reply => ({ data })
export const SERVER_ERROR: Reply = { status: 500 }
export const PENDING: Reply = 'pending'

/**
 * A page of a list response, its items under `key`. `upcomingTotal`: what a `when=UPCOMING_FIRST`
 * list says of its first section, « À venir » (RL15).
 */
export function page(
  key: string,
  items: unknown[],
  total = items.length,
  size = 12,
  upcomingTotal?: number
): Reply {
  return { data: { [key]: items, total, page: 0, size, upcomingTotal } }
}

/** Every endpoint the gallery's pages read, with its answer at rest. */
const AT_REST = {
  config: ok(APP_CONFIG),
  me: ok(READER),
  version: ok({ apiVersion: '14.7.0' }),
  unreadCount: ok({ count: 2 }),
  gpsAvailable: ok([]),
  myInvitations: ok({ invitations: [] }),
  /** « Ma prochaine sortie »: nothing booked, so the feed comes right after. */
  myParticipations: page('publications', []),
  /** « À venir » holds 12 of the 47: the first page is all ahead. */
  feed: page('publications', AGENDA, 47, 12, 12),
  /** The member home's week and the calendars. */
  calendar: ok({ events: MONTH_EVENTS }),
  teamCalendar: ok({ events: MONTH_EVENTS }),
  calendarToken: ok({
    token: 'galerie',
    globalFeedUrl: 'https://example.org/api/calendar/ics?token=galerie',
    teamFeedUrlTemplate: 'https://example.org/api/teams/{teamSlug}/calendar/ics?token=galerie',
  }),
  /** The membership probe, « Mes équipes » and the team switcher (every `size` but the page's). */
  myTeams: page('teams', MY_TEAMS, MY_TEAMS.length, 20),
  /** The teams page (`size` 12). */
  teamList: page('teams', MY_TEAMS, MY_TEAMS.length),
  team: ok(VCM_ORGANIZER),
  tags: ok(teamTags('ROUTE')),
  posts: page('publications', POSTS, 47),
  /**
   * The agenda's « À venir » (`when=UPCOMING`, and `UPCOMING_FIRST` with a kind) and its « Plus
   * tôt » (`when=PAST`): « Tout » over « Toutes les dates » is read from both (RL15).
   */
  agenda: page('publications', AGENDA, 18, 12, 18),
  agendaPast: page('publications', AGENDA_PAST, 29),
  routes: page('routes', ROUTES, 47),
  routesBounds: ok({ minLat: 48.3, minLon: -4.0, maxLat: 48.5, maxLon: -3.7 }),
  allRoutes: page('routes', ALL_ROUTES, 47),
  /** The dead end's « without this criterion » counts (`RouteDeadEnd`). */
  routesCount: ok({ total: 4 }),
  ads: page('ads', ADS, ADS_TOTAL),
  members: page('members', MEMBERS, 24, 50),
  invitations: ok({ invitations: [] }),
  ride: ok(ride({ registered: true })),
  rideWeather: ok({ legs: ride().groups.map((g) => weatherLeg(g)) }),
  participants: page('participants', GROUP_B_PEOPLE, GROUP_B_PEOPLE.length, 50),
  routesBulk: ok({ routes: [...routeDetails().values()] }),
  notifications: ok({ items: NOTIFICATIONS, total: 47, unreadCount: 2, page: 0, size: 20 }),
  templates: page('templates', TEMPLATES, 47, 20),
} satisfies Record<string, Reply>

export type Endpoint = keyof typeof AT_REST
export type Scenario = Partial<Record<Endpoint, Reply>>

const routes: Array<[method: string, path: RegExp, endpoint: (params: Params) => Endpoint]> = [
  ['get', /^\/api\/config$/, () => 'config'],
  ['get', /^\/api\/users\/me$/, () => 'me'],
  ['get', /^\/api\/version$/, () => 'version'],
  ['get', /^\/api\/notifications\/unread-count$/, () => 'unreadCount'],
  ['get', /^\/api\/notifications$/, () => 'notifications'],
  ['get', /^\/api\/gps\/available$/, () => 'gpsAvailable'],
  ['get', /^\/api\/users\/me\/invitations$/, () => 'myInvitations'],
  ['get', /^\/api\/users\/me\/participations$/, () => 'myParticipations'],
  ['get', /^\/api\/publications$/, () => 'feed'],
  ['get', /^\/api\/calendar\/events$/, () => 'calendar'],
  ['get', /^\/api\/calendar\/token$/, () => 'calendarToken'],
  ['get', /^\/api\/routes$/, () => 'allRoutes'],
  ['get', /^\/api\/routes\/count$/, () => 'routesCount'],
  ['get', /^\/api\/teams\/[^/]+\/routes\/count$/, () => 'routesCount'],
  ['get', /^\/api\/teams$/, (params) => (Number(params.size) === 12 ? 'teamList' : 'myTeams')],
  ['get', /^\/api\/teams\/[^/]+\/tags$/, () => 'tags'],
  [
    'get',
    /^\/api\/teams\/[^/]+\/publications$/,
    (params) =>
      params.type === 'POST' ? 'posts' : params.when === 'PAST' ? 'agendaPast' : 'agenda',
  ],
  ['get', /^\/api\/teams\/[^/]+\/calendar\/events$/, () => 'teamCalendar'],
  ['get', /^\/api\/teams\/[^/]+\/routes\/bounds$/, () => 'routesBounds'],
  ['get', /^\/api\/teams\/[^/]+\/routes\/bulk$/, () => 'routesBulk'],
  ['get', /^\/api\/teams\/[^/]+\/routes$/, () => 'routes'],
  ['get', /^\/api\/teams\/[^/]+\/classifieds$/, () => 'ads'],
  ['get', /^\/api\/teams\/[^/]+\/members$/, () => 'members'],
  ['get', /^\/api\/teams\/[^/]+\/invitations$/, () => 'invitations'],
  ['get', /^\/api\/teams\/[^/]+\/ride-templates$/, () => 'templates'],
  ['get', /^\/api\/teams\/[^/]+\/rides\/[^/]+\/participants$/, () => 'participants'],
  ['get', /^\/api\/teams\/[^/]+\/rides\/[^/]+\/weather$/, () => 'rideWeather'],
  ['get', /^\/api\/teams\/[^/]+\/rides\/[^/]+$/, () => 'ride'],
  ['get', /^\/api\/teams\/[^/]+$/, () => 'team'],
]

let scenario: Scenario = {}

/** The answers of the case on screen, over the answers at rest. */
export function setScenario(next: Scenario): void {
  scenario = next
}

export const unservedRequests: string[] = []

function response(config: InternalAxiosRequestConfig, status: number, data: unknown) {
  const res: AxiosResponse = {
    data,
    status,
    statusText: status === 200 ? 'OK' : 'Error',
    headers: {},
    config,
  }
  return res
}

const galleryAdapter: AxiosAdapter = async (config) => {
  const method = (config.method ?? 'get').toLowerCase()
  const path = (config.url ?? '').split('?')[0]
  for (const [verb, pattern, endpointOf] of routes) {
    if (verb !== method || !pattern.test(path)) continue
    const endpoint = endpointOf((config.params ?? {}) as Params)
    const reply = scenario[endpoint] ?? AT_REST[endpoint]
    if (reply === 'pending') return new Promise<AxiosResponse>(() => {})
    if ('status' in reply) {
      const res = response(config, 500, { code: 'INTERNAL_ERROR', message: 'galerie' })
      throw new AxiosError('galerie', AxiosError.ERR_BAD_RESPONSE, config, null, res)
    }
    return response(config, 200, reply.data)
  }
  const label = `${method.toUpperCase()} ${config.url}`
  unservedRequests.push(label)
  console.warn(`[galerie] requête non servie : ${label}`)
  const notFound = response(config, 404, { code: 'NOT_FOUND', message: 'galerie' })
  throw new AxiosError('galerie', AxiosError.ERR_BAD_REQUEST, config, null, notFound)
}

let installed = false

/** Routes every API call of the page to the fixtures. Idempotent. */
export function installListFakeApi(): void {
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
