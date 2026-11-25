/**
 * The bridge between the planner's page and the mobile app that embeds it (README.md has the
 * protocol). The page holds no token and no URL: every request is a `request` message the app
 * sends itself, answered through `window.pedalonsPlanner.response`.
 */
import { AxiosError, CanceledError } from 'axios'
import type {
  ErrorResponse,
  GeocodeResultDto,
  PlannerQuotaDto,
  PlannerQuotaScope,
  PlannerState,
  WaypointDto,
  WaypointRequest,
  GeoPoint,
  MapCenterDto,
  MapStyleDto,
  MapTerrainDto,
  UnitSystem,
} from '@/api/dto'
import { ApiClientError, parseRetryAfter } from '@/lib/apiError'
import type { PlannerTransport } from '@/lib/plannerTransport'

// ── Messages ────────────────────────────────────────────────────────────────────────────────────

/** A basemap as the app hands it over: the served entry, with the documents the page cannot fetch. */
export interface BridgeMapStyle extends Omit<MapStyleDto, 'url'> {
  /** A style document on a host that answers the page (a public CDN). */
  url?: string
  /** The style document itself, for one served by our API (no CORS header for origin `null`). */
  style?: unknown
  /** Same choice for the dark counterpart: a URL (`darkVariant`) or the document. */
  darkStyle?: unknown
}

/** What `window.pedalonsPlanner.load` takes. */
export interface PlannerLoad {
  /** The saved editing state of the route: wins over `track`. */
  state?: PlannerState
  /** `[lng, lat, ele, dist][]` of the route being edited. */
  track?: number[][]
  /** D+ (m) stored for `track`. */
  ascend?: number
  waypoints?: WaypointDto[]
  /** Length (m) stored with `waypoints`. */
  waypointsTotal?: number
  /** Shown in the toolbar. */
  routeName?: string
  /**
   * The team the route belongs to, sent with every routing call. Absent for a GPX preview of the GPX
   * tools, which belongs to no team (docs/LEDGER_*.md MOB-178): the server then applies the personal
   * quota, as the site's `RoutePlannerField` without a team does.
   */
  teamSlug?: string
  /** `[lng, lat]`: where the map opens when there is no track. */
  teamLocation?: [number, number]
  /** Accepted for the app's convenience; the page does not read it (the app disables its entry). */
  quota?: PlannerQuotaDto
  styles: BridgeMapStyle[]
  /** The elevation source of the relief switches (`ConfigDto.terrain`); absent, they are hidden. */
  terrain?: MapTerrainDto
  /** Where the map opens with neither track nor team location (`ConfigDto.defaultCenter`). */
  defaultCenter?: MapCenterDto
  theme: 'light' | 'dark'
  locale: string
  units: UnitSystem
  /**
   * True when the route does not exist yet: the whole drawing is sent. False (an existing route):
   * an untouched track sends nothing. Default: true when neither `state` nor `track` is given.
   */
  create?: boolean
  /**
   * True shows « Me localiser », which asks the app for the device's position (`locate`). Absent or
   * false, the button is not drawn: the app's stores declare what it reads the position for, and
   * the planner is not in that declaration (ledger MOB-170).
   */
  locate?: boolean
  /**
   * A proposal of the route generator to open (docs/LEDGER_*.md MOB-154): imported on load as the
   * site imports one (WEB-179), a replacing import that keeps no file and whose sources are marked
   * `generated`, so « Terminer » sends the planner state. With `create: true`.
   */
  generated?: GeneratedImport
  /**
   * Test only (the app's Patrol suite): true makes `window.pedalonsPlanner.test` act. Absent or
   * false, that call does nothing.
   */
  testCommands?: boolean
}

/** A generated route as `load.generated` carries it. */
export interface GeneratedImport {
  /** Polyline of precision 6 (latitude then longitude): `GeneratedRouteDto.polyline`. */
  polyline: string
  /** The name of the import: « Parcours généré de 82 km ». */
  name: string
}

/** The request fragment of `lib/plannerSubmit.ts`, as it crosses the bridge. */
export interface DonePayload {
  points?: GeoPoint[]
  plannerState?: PlannerState
  /** The route is, untouched, the file the app picked last: the app uploads that file. */
  file?: true
  /** The `id` the app gave that file in `gpx`, when it gave one: which of the files it kept. */
  fileId?: string
  waypoints?: WaypointRequest[]
}

export interface DoneStats {
  /** Metres. */
  distance: number
  /** Metres of climb. */
  ascend: number
  /** Control points placed. */
  pointCount: number
  /** The drawn line, as a polyline of precision 6 (latitude then longitude): the app's preview. */
  line: string
}

/** A multipart body, since a `FormData` cannot cross the bridge. */
export interface MultipartBody {
  multipart: {
    fields: Record<string, string>
    file: { name: string; base64: string; contentType: string }
  }
}

export type Outgoing =
  | { type: 'ready' }
  | { type: 'request'; id: string; method: 'GET' | 'POST'; path: string; body?: unknown }
  | { type: 'cancel'; id: string }
  | { type: 'pickGpx' }
  | { type: 'locate' }
  | { type: 'busy'; busy: boolean }
  /**
   * `dirty`: anything changed since `load`. `pending`: anything changed since the last « Terminer »
   * (since `load` before the first) — what the form does not have.
   */
  | { type: 'dirty'; dirty: boolean; pending: boolean }
  | {
      type: 'quotaRefused'
      scope: PlannerQuotaScope
      limit: number
      current: number
      resetsOn: string
      teamName?: string
    }
  | {
      type: 'done'
      payload: DonePayload
      stats: DoneStats
      /** Whether anything changed since `load`. */
      dirty: boolean
      /** Name of the last file imported, for a name field still empty. */
      nameSuggestion?: string
      /** `tooLarge`: the points are sent, the saved track loses its control points. */
      notice?: 'tooLarge'
    }
  | { type: 'close'; dirty: boolean; pending: boolean }
  | { type: 'error'; message: string }

/** What the app answers a `request` with. */
export interface BridgeResponse {
  id: string
  /** HTTP status; 0 when no answer came (network down, request refused by the app). */
  status: number
  /** The decoded JSON body, or its text. */
  body?: unknown
  /** Seconds, from the `Retry-After` header, when the server sent one. */
  retryAfter?: number
}

declare global {
  interface Window {
    PedalonsBridge?: { postMessage(message: string): void }
  }
}

export function post(message: Outgoing): void {
  window.PedalonsBridge?.postMessage(JSON.stringify(message))
}

// ── What the app sends without being asked through a request ─────────────────────────────────────

type Listener<T> = (value: T) => void

function channel<T>() {
  const listeners = new Set<Listener<T>>()
  return {
    emit: (value: T) => listeners.forEach((listener) => listener(value)),
    subscribe: (listener: Listener<T>) => {
      listeners.add(listener)
      return () => {
        listeners.delete(listener)
      }
    },
  }
}

/**
 * A test-only command (`PlannerLoad.testCommands`): control points placed as straight lines, in
 * order, without a touch on the map and without a routing request, then « Terminer ».
 */
export interface TestCommand {
  place?: { lng: number; lat: number }[]
  done?: boolean
}

const gpxChannel = channel<File | null>()
const positionChannel = channel<{ lng: number; lat: number } | null>()
const testChannel = channel<TestCommand>()

/** The answer to `pickGpx`: the file chosen in the app's picker, null when the picker was left. */
export const onGpx = gpxChannel.subscribe
export const emitGpx = gpxChannel.emit
/** The answer to `locate`: the app's position, null when it has none to give. */
export const onPosition = positionChannel.subscribe
export const emitPosition = positionChannel.emit
/** A test-only command, when `load` enabled them. */
export const onTest = testChannel.subscribe
export const emitTest = testChannel.emit

// ── Requests ────────────────────────────────────────────────────────────────────────────────────

interface Pending {
  resolve: (body: unknown) => void
  reject: (error: unknown) => void
  cleanup: () => void
}

const pending = new Map<string, Pending>()
let nextId = 0

/**
 * Sends a request through the app. Fails in the shapes the site's client fails in, so the
 * planner's wording by code and by status holds (`lib/apiError.ts`): an `ApiClientError` when the
 * body carries a code, an axios error otherwise, a `CanceledError` when `signal` aborts.
 */
export function bridgeRequest<T>(
  method: 'GET' | 'POST',
  path: string,
  body?: unknown,
  signal?: AbortSignal
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    if (signal?.aborted) {
      reject(new CanceledError())
      return
    }
    const id = String(++nextId)
    const onAbort = () => {
      if (!pending.delete(id)) return
      post({ type: 'cancel', id })
      reject(new CanceledError())
    }
    signal?.addEventListener('abort', onAbort, { once: true })
    pending.set(id, {
      resolve: resolve as (body: unknown) => void,
      reject,
      cleanup: () => signal?.removeEventListener('abort', onAbort),
    })
    post({ type: 'request', id, method, path, ...(body !== undefined && { body }) })
  })
}

function decodeBody(body: unknown): unknown {
  if (typeof body !== 'string') return body
  try {
    return JSON.parse(body)
  } catch {
    return body
  }
}

/** The app's answer to a `request`. An answer to a request already cancelled is dropped. */
export function settleResponse(response: BridgeResponse): void {
  const entry = pending.get(response.id)
  if (!entry) return
  pending.delete(response.id)
  entry.cleanup()
  const status = Number(response.status) || 0
  const body = decodeBody(response.body)
  if (status >= 200 && status < 300) {
    entry.resolve(body)
    return
  }
  if (status === 0) {
    entry.reject(new AxiosError('Network Error', AxiosError.ERR_NETWORK))
    return
  }
  const code = (body as Partial<ErrorResponse> | null | undefined)?.code
  if (body && typeof body === 'object' && code) {
    entry.reject(
      new ApiClientError(status, body as ErrorResponse, parseRetryAfter(response.retryAfter))
    )
    return
  }
  // No business code (a bare 404 of an older backend, a proxy's 502): the status alone, as axios
  // reports it (`apiErrorStatus`).
  const error = new AxiosError(
    `Request failed with status code ${status}`,
    AxiosError.ERR_BAD_RESPONSE
  )
  error.status = status
  error.response = {
    status,
    data: body,
    statusText: '',
    headers: {},
    config: {} as never,
  }
  entry.reject(error)
}

/** For tests: forgets the requests in flight. */
export function resetBridgeRequests(): void {
  pending.clear()
  nextId = 0
}

// ── Files ───────────────────────────────────────────────────────────────────────────────────────

/** The bytes of a file, in base64 (no data URL prefix). */
export function fileToBase64(file: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onerror = () => reject(reader.error ?? new Error('unreadable file'))
    reader.onload = () => {
      const url = String(reader.result)
      resolve(url.slice(url.indexOf(',') + 1))
    }
    reader.readAsDataURL(file)
  })
}

// The app keeps every file it hands over, under an id: `done` names the one the route still is,
// which is not always the last one picked (a later file refused by the server, or turned down in
// the replace-or-append question, leaves the earlier one in place).
const fileIds = new WeakMap<Blob, string>()

/** The id the app gave `file` in `gpx`, if it gave one. */
export function fileIdOf(file: Blob): string | undefined {
  return fileIds.get(file)
}

/** The file the app picked, rebuilt from its base64 bytes; `id` is the app's name for it. */
export function fileFromBase64(name: string, base64: string, id?: string): File {
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  const file = new File([bytes], name, { type: 'application/gpx+xml' })
  if (id) fileIds.set(file, id)
  return file
}

// ── The planner's calls ─────────────────────────────────────────────────────────────────────────

/** The planner's transport over the bridge (`lib/plannerTransport.ts`). */
export const bridgeTransport: PlannerTransport = {
  route: (request, signal) => bridgeRequest('POST', '/api/router', request, signal),
  lineElevation: (request, signal) =>
    bridgeRequest('POST', '/api/router/elevation', request, signal),
  importGpx: async (body, signal) => {
    const file = body.gpxFile
    const multipart: MultipartBody = {
      multipart: {
        fields: body.teamSlug !== undefined ? { teamSlug: body.teamSlug } : {},
        file: {
          name: file instanceof File ? file.name : 'import.gpx',
          base64: file ? await fileToBase64(file) : '',
          contentType: file?.type || 'application/gpx+xml',
        },
      },
    }
    return bridgeRequest('POST', '/api/router/import-gpx', multipart, signal)
  },
  engines: (teamSlug, signal) =>
    bridgeRequest(
      'GET',
      teamSlug
        ? `/api/router/engines?teamSlug=${encodeURIComponent(teamSlug)}`
        : '/api/router/engines',
      undefined,
      signal
    ),
}

/** `GET /api/geocode/search`: at most five suggestions, usually without a position. */
export function searchPlaces(query: string, signal?: AbortSignal): Promise<GeocodeResultDto[]> {
  return bridgeRequest(
    'GET',
    `/api/geocode/search?q=${encodeURIComponent(query)}`,
    undefined,
    signal
  )
}

/** `GET /api/geocode/place`: the position of the suggestion picked (billed: never for a list). */
export function resolvePlace(id: string, signal?: AbortSignal): Promise<GeocodeResultDto> {
  return bridgeRequest('GET', `/api/geocode/place?id=${encodeURIComponent(id)}`, undefined, signal)
}
