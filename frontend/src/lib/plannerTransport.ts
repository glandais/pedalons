import { importGpx, lineElevation, route, routerEngines } from '@/api/endpoints/router/router'
import type {
  GpxImportResponse,
  ImportGpxBody,
  LineElevationRequest,
  LineElevationResponse,
  RouterEnginesResponse,
  RouterRequest,
  RouterResponse,
} from '@/api/dto'

/**
 * The planner's four network calls, behind one interface (docs/LEDGER_*.md WEB-183): the site
 * sends them with the generated client, the planner embedded in the mobile app hands them to the
 * app over its bridge (`src/embed/mobile-planner`), which holds the session.
 *
 * Whatever the implementation, a refusal is thrown in the shapes `lib/apiError.ts` reads
 * (`ApiClientError` when the body carries a code, an axios error otherwise): the planner words its
 * failures by code (`plannerErrors.ts`, `plannerQuota.ts`) and by status (`plannerElevation.ts`).
 */
export interface PlannerTransport {
  /** `POST /api/router`. */
  route(request: RouterRequest, signal?: AbortSignal): Promise<RouterResponse>
  /** `POST /api/router/elevation`. */
  lineElevation(request: LineElevationRequest, signal?: AbortSignal): Promise<LineElevationResponse>
  /** `POST /api/router/import-gpx` (multipart). */
  importGpx(body: ImportGpxBody, signal?: AbortSignal): Promise<GpxImportResponse>
  /** `GET /api/router/engines`, with the planner's team when it has one. */
  engines(teamSlug?: string, signal?: AbortSignal): Promise<RouterEnginesResponse>
}

// The planner renders its failures itself, by code (plannerErrorMessage): no global toast on top.
const SILENT = { skipErrorToast: true }

/** The site's: the generated client, with the session and the 401 refresh of `axiosInstance`. */
const siteTransport: PlannerTransport = {
  route: (request, signal) => route(request, SILENT, signal),
  lineElevation: (request, signal) => lineElevation(request, SILENT, signal),
  importGpx: (body, signal) => importGpx(body, SILENT, signal),
  engines: (teamSlug, signal) => routerEngines(teamSlug ? { teamSlug } : undefined, SILENT, signal),
}

let current: PlannerTransport = siteTransport

/** The transport the planner sends its calls through. */
export function plannerTransport(): PlannerTransport {
  return current
}

/**
 * Replaces the transport for the whole page. Only an entry point that is not the site calls it,
 * once, before anything renders: it is a property of the bundle, never of a request or a visitor.
 */
export function setPlannerTransport(transport: PlannerTransport): void {
  current = transport
}
