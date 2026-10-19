import type { Locator, Page, Response } from '@playwright/test'
import type {
  LineElevationRequest,
  LineElevationResponse,
  RouterRequest,
  RouterResponse,
  RouteDetailDto,
  RouteDto,
  RouteRequest,
  RoutesBulkResponse,
  SurfaceSpanDto,
  TrackDto,
  TrackSurfaceState,
  StageRequest,
  TripDto,
  TripRequest,
} from '../../src/api/dto'
import { apiGet, apiGetOrNull, apiPost, expectOk, withApi, type AuthResponse } from './api'
import { markdownMedia } from './data'
import { wallTimeOf } from './dates'
import { encode1, encode2 } from '../../src/lib/polyline'

/**
 * Routes, trips and stages seeded through the REST API, and what a page read of a route's
 * geometry looks like from the browser: the requests it sent, the queries the SSR server handed it,
 * and the pixels its map drew.
 */

/** A GPX point: latitude, longitude (degrees), elevation (metres). */
export type GpxPoint = [lat: number, lon: number, ele: number]

/**
 * A winding track of `count` points through the Beauce, east of Chartres: a line heading east,
 * swinging ±300 m north and south every 1.5 km, about 50 m between two points. The bends keep the
 * backend's own simplification (10 m resampling, then Douglas-Peucker at 3 m) from collapsing it to a
 * handful of vertices — so a geometry that lost points on the way cannot pass for the full one.
 */
export function windingTrack(count = 300): GpxPoint[] {
  const [lat0, lon0] = [48.4469, 1.4875]
  const metresPerDegLat = 111_320
  const metresPerDegLon = metresPerDegLat * Math.cos((lat0 * Math.PI) / 180)
  return Array.from({ length: count }, (_, i) => {
    const east = i * 50
    const north = 300 * Math.sin((2 * Math.PI * east) / 1500)
    const ele = 150 + 20 * Math.sin((2 * Math.PI * east) / 4000)
    return [
      Number((lat0 + north / metresPerDegLat).toFixed(7)),
      Number((lon0 + east / metresPerDegLon).toFixed(7)),
      Number(ele.toFixed(1)),
    ]
  })
}

export function gpxOf(name: string, points: GpxPoint[]): string {
  const trkpts = points
    .map(([lat, lon, ele]) => `<trkpt lat="${lat}" lon="${lon}"><ele>${ele}</ele></trkpt>`)
    .join('\n      ')
  return `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="pedalons-e2e" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>${name}</name>
    <trkseg>
      ${trkpts}
    </trkseg>
  </trk>
</gpx>
`
}

/** Creates a route from a GPX upload, as the « Nouveau parcours » form does (multipart). */
export async function newRoute(
  by: AuthResponse,
  teamSlug: string,
  name: string,
  points: GpxPoint[],
  overrides: Partial<RouteRequest> = {}
): Promise<RouteDto> {
  const request: RouteRequest = {
    name,
    media: markdownMedia(),
    surfaceType: 'ROAD',
    visibility: 'TEAM',
    ...overrides,
  }
  return withApi(by, async (api) =>
    expectOk<RouteDto>(
      await api.post(`/api/teams/${teamSlug}/routes`, {
        multipart: {
          route: {
            name: 'route.json',
            mimeType: 'application/json',
            buffer: Buffer.from(JSON.stringify(request)),
          },
          gpxFile: {
            name: 'trace.gpx',
            mimeType: 'application/gpx+xml',
            buffer: Buffer.from(gpxOf(name, points)),
          },
        },
      })
    )
  )
}

/** The route as the single-route endpoint serves it: the stored geometry, untouched. */
export const getRoute = (by: AuthResponse, teamSlug: string, routeSlug: string) =>
  apiGet<RouteDetailDto>(by, `/api/teams/${teamSlug}/routes/${routeSlug}`)

/**
 * A published, members-only trip two days ahead, with the given stages (one day apart), unless
 * `overrides` say otherwise.
 */
export async function newTrip(
  by: AuthResponse,
  teamSlug: string,
  name: string,
  stages: Omit<StageRequest, 'dateTime' | 'media'>[],
  overrides: Partial<Omit<TripRequest, 'stages'>> = {}
): Promise<TripDto> {
  const start = Date.now() + 2 * 24 * 3600 * 1000
  const request: TripRequest = {
    name,
    media: markdownMedia(),
    dateTime: wallTimeOf(start),
    status: 'PUBLISHED',
    visibility: 'TEAM',
    ...overrides,
    stages: stages.map((stage, i) => ({
      ...stage,
      dateTime: wallTimeOf(start + i * 24 * 3600 * 1000),
      media: markdownMedia(),
    })),
  }
  return apiPost<TripDto>(by, `/api/teams/${teamSlug}/trips`, request)
}

/** The trip as `who` reads it, or null when the API answers 404 (deleted, or never there). */
export const fetchTrip = (who: AuthResponse, teamSlug: string, tripSlug: string) =>
  apiGetOrNull<TripDto>(who, `/api/teams/${teamSlug}/trips/${tripSlug}`)

export const routePath = (teamSlug: string, routeSlug: string) =>
  `/equipes/${teamSlug}/parcours/${routeSlug}`
export const routeMapPath = (teamSlug: string, routeSlug: string) =>
  `${routePath(teamSlug, routeSlug)}/carte`
export const tripPath = (teamSlug: string, tripSlug: string) =>
  `/equipes/${teamSlug}/voyages/${tripSlug}`
export const tripNewPath = (teamSlug: string) => `/equipes/${teamSlug}/voyages/nouveau`
export const stagePath = (teamSlug: string, tripSlug: string, stageSlug: string) =>
  `${tripPath(teamSlug, tripSlug)}/etapes/${stageSlug}`
export const stageMapPath = (teamSlug: string, tripSlug: string, stageSlug: string) =>
  `${stagePath(teamSlug, tripSlug, stageSlug)}/carte`

/** Every [lon, lat, …] vertex of a route, tracks concatenated. */
export function coordinatesOf(route: Pick<RouteDetailDto, 'tracks'>): number[][] {
  return route.tracks.flatMap((track) => track.line.coordinates)
}

/**
 * How far, in metres, the farthest of `points` lies from the polyline `line` ([lon, lat] vertices)
 * — a local equirectangular projection, exact enough over a few kilometres.
 */
export function farthestFrom(line: number[][], points: GpxPoint[]): number {
  const lat0 = (points[0][0] * Math.PI) / 180
  const project = (lon: number, lat: number) => [lon * 111_320 * Math.cos(lat0), lat * 111_320]
  const vertices = line.map(([lon, lat]) => project(lon, lat))
  let worst = 0
  for (const [lat, lon] of points) {
    const [px, py] = project(lon, lat)
    let best = Infinity
    for (let i = 0; i + 1 < vertices.length; i++) {
      const [ax, ay] = vertices[i]
      const [bx, by] = vertices[i + 1]
      const [dx, dy] = [bx - ax, by - ay]
      const length2 = dx * dx + dy * dy
      const t =
        length2 === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / length2))
      best = Math.min(best, Math.hypot(px - (ax + t * dx), py - (ay + t * dy)))
    }
    worst = Math.max(worst, best)
  }
  return worst
}

/** One read of a route's detail by a page — sent by the browser, or prefetched by the SSR server. */
export interface RouteRead {
  source: 'browser' | 'ssr'
  /** Endpoint path, e.g. `/api/teams/t/routes/bulk`. */
  endpoint: string
  /** The query parameters it was asked with, `slug` excepted. */
  params: Record<string, unknown>
  /** The route as that read delivered it. */
  route: RouteDetailDto
}

/**
 * Records every read of route `routeSlug` the page makes, whichever way it reaches the page. Call
 * it before `goto`, then `reads()` once the page has drawn.
 *
 * Both ways matter: a page is server-rendered, and the SSR server prefetches its queries and hands
 * them over in the `#ssr-query-state` data block — the browser then sends no request at all for them.
 * A query the client asks with other parameters than the prefetch has a different key, so it *is*
 * sent from the browser, and caught here.
 */
export function watchRouteReads(page: Page, teamSlug: string, routeSlug: string) {
  const single = `/api/teams/${teamSlug}/routes/${routeSlug}`
  const bulk = `/api/teams/${teamSlug}/routes/bulk`
  const pending: Promise<RouteRead | null>[] = []

  const fromBrowser = async (response: Response): Promise<RouteRead | null> => {
    const url = new URL(response.url())
    const params: Record<string, unknown> = {}
    for (const [key, value] of url.searchParams) if (key !== 'slug') params[key] = value
    if (url.pathname === single) {
      return {
        source: 'browser',
        endpoint: single,
        params,
        route: (await response.json()) as RouteDetailDto,
      }
    }
    if (url.pathname === bulk && url.searchParams.getAll('slug').includes(routeSlug)) {
      const body = (await response.json()) as RoutesBulkResponse
      const route = body.routes.find((r) => r.slug === routeSlug)
      return route ? { source: 'browser', endpoint: bulk, params, route } : null
    }
    return null
  }
  page.on('response', (response) => {
    if (response.request().method() === 'GET' && response.ok()) pending.push(fromBrowser(response))
  })

  return {
    async reads(): Promise<RouteRead[]> {
      const browser = (await Promise.all(pending)).filter((read): read is RouteRead => !!read)
      const ssr = await page.evaluate(
        ({ single, bulk, routeSlug }) => {
          const state = JSON.parse(
            document.getElementById('ssr-query-state')?.textContent || 'null'
          ) as { queries: { queryKey: unknown[]; state: { data?: unknown } }[] } | null
          const out: { endpoint: string; params: Record<string, unknown>; route: unknown }[] = []
          for (const { queryKey, state: query } of state?.queries ?? []) {
            const [endpoint, rawParams] = queryKey as [string, Record<string, unknown>?]
            const { slug, ...params } = rawParams ?? {}
            if (endpoint === single && query.data) out.push({ endpoint, params, route: query.data })
            if (endpoint === bulk && ([] as unknown[]).concat(slug).includes(routeSlug)) {
              const data = query.data as { routes: { slug: string }[] } | undefined
              const route = data?.routes.find((r) => r.slug === routeSlug)
              if (route) out.push({ endpoint, params, route })
            }
          }
          return out
        },
        { single, bulk, routeSlug }
      )
      return [
        ...browser,
        ...ssr.map((read) => ({
          source: 'ssr' as const,
          endpoint: read.endpoint,
          params: read.params,
          route: read.route as RouteDetailDto,
        })),
      ]
    },
  }
}

/**
 * Replaces the basemap with a plain light-grey background. The basemaps are third-party CDNs
 * (tiles.versatiles.org, see GET /api/config — light and dark variants), not part of the stack:
 * their tiles depend on the network and change under us. With a flat background, the only
 * saturated pixels left on the map canvas are the trace's. Call it before `goto`.
 */
export async function stubBasemap(page: Page) {
  await page.route('https://tiles.versatiles.org/**/style.json', (route) =>
    route.fulfill({
      json: {
        version: 8,
        sources: {},
        layers: [
          { id: 'background', type: 'background', paint: { 'background-color': '#f0f0f0' } },
        ],
      },
    })
  )
}

/**
 * How many pixels of the map canvas are drawn in a saturated colour — i.e. belong to a trace, on a
 * stubbed basemap. Every DOM overlay (markers, controls, the elevation chart's own canvas) is hidden
 * for the capture, so what is counted is what MapLibre itself drew from the route source.
 */
export async function traceMapPixels(page: Page, canvas: Locator): Promise<number> {
  const png = (
    await canvas.screenshot({
      animations: 'disabled',
      style:
        '.maplibregl-marker, .maplibregl-control-container, canvas:not(.maplibregl-canvas) { visibility: hidden !important; }',
    })
  ).toString('base64')
  return page.evaluate(async (png) => {
    const img = new Image()
    img.src = `data:image/png;base64,${png}`
    await img.decode()
    const scratch = document.createElement('canvas')
    scratch.width = img.naturalWidth
    scratch.height = img.naturalHeight
    const ctx = scratch.getContext('2d')!
    ctx.drawImage(img, 0, 0)
    const { data } = ctx.getImageData(0, 0, scratch.width, scratch.height)
    let saturated = 0
    for (let i = 0; i < data.length; i += 4) {
      const [r, g, b] = [data[i], data[i + 1], data[i + 2]]
      if (Math.max(r, g, b) - Math.min(r, g, b) > 60) saturated++
    }
    return saturated
  }, png)
}

/** Great-circle distance in metres — the formula the planner measures its own route with. */
function metresBetween(a: [lon: number, lat: number], b: [lon: number, lat: number]): number {
  const rad = Math.PI / 180
  const dLat = (b[1] - a[1]) * rad
  const dLon = (b[0] - a[0]) * rad
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(a[1] * rad) * Math.cos(b[1] * rad) * Math.sin(dLon / 2) ** 2
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h))
}

/**
 * A plausible answer of POST /api/router for `request`: a gently bowed line (up to 3 % of its
 * length off the straight one, so the planner's simplification keeps its points) of 3D points from
 * `from` to `to`, climbing 50 m along the way, a third of it unpaved.
 */
export function routerAnswer({ from, to }: RouterRequest): RouterResponse {
  const steps = 12
  const coordinates = Array.from({ length: steps + 1 }, (_, i) => {
    const t = i / steps
    const bow = 0.03 * Math.sin(Math.PI * t)
    // The offset is perpendicular to the straight line, in degrees: good enough at these scales.
    const dLon = to.lng - from.lng
    const dLat = to.lat - from.lat
    return [from.lng + dLon * t - dLat * bow, from.lat + dLat * t + dLon * bow, 100 + 50 * t]
  })
  let dist = 0
  for (let i = 1; i < coordinates.length; i++) {
    dist += metresBetween(
      [coordinates[i - 1][0], coordinates[i - 1][1]],
      [coordinates[i][0], coordinates[i][1]]
    )
  }
  return {
    route: { type: 'LineString', coordinates },
    dist: Math.round(dist),
    ascend: 50,
    // A run of unpaved edges in the middle of the leg (C1a): a third of it, as the router's own
    // maneuvers would say. Edges are half-open, indexed in `route`.
    unpaved: [{ from: 4, to: 8 }],
  }
}

/**
 * Lets POST /api/router reach the backend (and Stadia Maps, billed per request) while recording each
 * request, so a test can still assert the cost of a gesture.
 */
export async function watchRouter(page: Page): Promise<RouterRequest[]> {
  const requests: RouterRequest[] = []
  await page.route('**/api/router', async (route) => {
    if (route.request().method() !== 'POST') return route.fallback()
    requests.push(route.request().postDataJSON() as RouterRequest)
    await route.continue()
  })
  return requests
}

/**
 * Answers POST /api/router in the browser, so a planner test never reaches the real router (the
 * stack has none in CI, and a real one is billed per request). Returns the requests received, in
 * order: their count is the cost of a gesture.
 */
export async function stubRouter(page: Page): Promise<RouterRequest[]> {
  const requests: RouterRequest[] = []
  await page.route('**/api/router', async (route) => {
    if (route.request().method() !== 'POST') return route.fallback()
    const request = route.request().postDataJSON() as RouterRequest
    requests.push(request)
    await route.fulfill({ json: routerAnswer(request) })
  })
  return requests
}

/**
 * A plausible answer of POST /api/router/elevation for `request`: per line, three points (start,
 * middle, end) at 100 m, 130 m and 110 m, so the line climbs 30 m.
 */
export function elevationAnswer({ lines }: LineElevationRequest): LineElevationResponse {
  return {
    lines: lines.map(({ from, to }) => ({
      line: encode2([
        [from.lng, from.lat],
        [(from.lng + to.lng) / 2, (from.lat + to.lat) / 2],
        [to.lng, to.lat],
      ]),
      ele: encode1([100, 130, 110]),
      climb: encode1([0, 30, 30]),
      dist: Math.round(metresBetween([from.lng, from.lat], [to.lng, to.lat])),
      ascend: 30,
    })),
    elevationFallback: false,
  }
}

/**
 * Answers POST /api/router/elevation (the relief of the straight lines, read in the background)
 * in the browser. Returns the requests received, in order: their count is kept apart from the
 * router's, which is the billed one (the glob of stubRouter does not match this URL).
 */
export async function stubElevation(page: Page): Promise<LineElevationRequest[]> {
  const requests: LineElevationRequest[] = []
  await page.route('**/api/router/elevation', async (route) => {
    if (route.request().method() !== 'POST') return route.fallback()
    const request = route.request().postDataJSON() as LineElevationRequest
    requests.push(request)
    await route.fulfill({ json: elevationAnswer(request) })
  })
  return requests
}

/**
 * Lets POST /api/router/elevation reach the backend (the FAST elevations, read from the terrain
 * model; nothing is billed) while recording each request.
 */
export async function watchElevation(page: Page): Promise<LineElevationRequest[]> {
  const requests: LineElevationRequest[] = []
  await page.route('**/api/router/elevation', async (route) => {
    if (route.request().method() !== 'POST') return route.fallback()
    requests.push(route.request().postDataJSON() as LineElevationRequest)
    await route.continue()
  })
  return requests
}

/**
 * Answers the GET of `apiPath` with the real response whose tracks carry the surface `surfaceOf`
 * says (WEB-100 C1b). The e2e stack runs with the surface computation off (no call to Stadia Maps,
 * `.env.e2e`), so a track never has one: the browser is handed what the worker would have stored.
 * Only a read the browser sends is touched: the page must be reached by a client-side navigation,
 * the SSR server's own prefetch does not go through the browser.
 */
export async function withTrackSurfaces(
  page: Page,
  apiPath: string,
  surfaceOf: (
    track: TrackDto,
    index: number
  ) => { surfaceState: TrackSurfaceState; surfaces?: SurfaceSpanDto[] }
) {
  await page.route(
    (url) => url.pathname === apiPath,
    async (route) => {
      if (route.request().method() !== 'GET') return route.continue()
      const response = await route.fetch()
      const body = (await response.json()) as { tracks: TrackDto[] }
      body.tracks = body.tracks.map((track, i) => ({ ...track, ...surfaceOf(track, i) }))
      return route.fulfill({ response, json: body })
    }
  )
}

/** The length of a track: the measure (4th ordinate) of its last point. */
export const trackLength = (track: TrackDto) => track.line.coordinates.at(-1)?.[3] ?? 0
