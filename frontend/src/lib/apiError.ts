import Axios from 'axios'
import type { ErrorCode, ErrorResponse } from '@/api/dto'

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
