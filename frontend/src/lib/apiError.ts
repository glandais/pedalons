import Axios from 'axios'
import { ErrorCode } from '@/api/dto'
import type { ErrorResponse } from '@/api/dto'

export class ApiClientError extends Error {
  constructor(
    public status: number,
    public error: ErrorResponse,
    /**
     * Seconds to wait, read from the `Retry-After` response header when the server sent one.
     * Only the quota responses declare it, so treat its absence as normal and fall back on a
     * message without a figure.
     */
    public retryAfterSeconds?: number
  ) {
    super(error.code)
    this.name = 'ApiClientError'
  }
}

/** Parses a `Retry-After` header holding a delta-seconds value. HTTP-date form is not used here. */
export function parseRetryAfter(value: unknown): number | undefined {
  const seconds = Number(value)
  return Number.isFinite(seconds) && seconds >= 0 ? seconds : undefined
}

/**
 * The API error code carried by a failed call, whatever shape it failed in: the mutator turns an
 * error response into an `ApiClientError`, except a 401, which it rethrows as the raw axios error.
 */
export function apiErrorCode(error: unknown): ErrorCode | undefined {
  if (error instanceof ApiClientError) return error.error.code
  if (Axios.isAxiosError(error)) return (error.response?.data as ErrorResponse | undefined)?.code
  return undefined
}

/**
 * The HTTP status of a failed call. `axiosMutator` only wraps an error in `ApiClientError` when
 * the body carries a `code`; a bare 404 or a non-JSON 5xx arrives as the raw axios error.
 * Undefined when there was no response at all (network down).
 */
export function apiErrorStatus(error: unknown): number | undefined {
  if (error instanceof ApiClientError) return error.status
  if (Axios.isAxiosError(error)) return error.response?.status
  return undefined
}

/**
 * The codes whose refusal the screen that made the call renders itself — a dialog that lists what
 * is in the way — so the mutator's generic toast stays quiet for them (`axiosMutator`). Every call
 * that can receive one must handle it: the ride and trip editors and their status actions, the
 * restore of a ride or a trip, the route editor (docs/LEDGER_*.md WEB-166). A spent planner quota
 * opens PlannerQuotaModal from every planner call: the route and GPX preview editors, the promotion
 * of a preview, the route calculation (docs/LEDGER_*.md BILL-10).
 */
export const CALLER_RENDERED_ERROR_CODES: ReadonlySet<ErrorCode> = new Set([
  ErrorCode.INCOMPATIBLE_VISIBILITY,
  ErrorCode.PLANNER_QUOTA_REACHED,
])
