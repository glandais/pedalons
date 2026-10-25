import Axios from 'axios'
import type { ClientErrorDto } from '@/api/dto'
import { reportClientError } from '@/api/endpoints/feedback/feedback'
import { ApiClientError } from '@/lib/apiError'
import { isStaleChunkError, reloadForStaleChunk } from '@/lib/staleChunk'
import { useAuthStore } from '@/store/authStore'
import { buildClientContext } from './clientContext'
import { getLogEntries, logEntry } from './clientLog'

/**
 * Sends the browser's unhandled errors to the server, which groups them into one GitHub issue per
 * distinct error (see FeedbackService on the backend).
 *
 * Members only — the endpoint needs a session — and only while the member leaves the preference
 * on. At most {@link MAX_PER_SESSION} reports per page load, each distinct error once: an error in
 * a render loop must not become a request loop. Failures are swallowed, never logged to the console
 * (which would feed the buffer, and so on).
 */

export const MAX_PER_SESSION = 5
/** Entries of the log sent with an automatic report — the contract allows 50. */
const LOG_ENTRIES = 50
const PREFERENCE_KEY = 'pedalons-error-reports'

/** Noise that says nothing about Pédalons: extensions, a benign browser warning, opaque errors. */
const IGNORED = [/ResizeObserver loop/, /^Script error\.?$/, /-extension:\/\//]

const sent = new Set<string>()
let lastError: ClientErrorDto | undefined

export function isErrorReportingEnabled(): boolean {
  try {
    return localStorage.getItem(PREFERENCE_KEY) !== 'off'
  } catch {
    return true
  }
}

export function setErrorReportingEnabled(enabled: boolean): void {
  try {
    if (enabled) localStorage.removeItem(PREFERENCE_KEY)
    else localStorage.setItem(PREFERENCE_KEY, 'off')
  } catch {
    // Private mode: the preference lasts for the page only.
  }
}

/** The last unhandled error of this page load, for a report opened right after it. */
export function getLastError(): ClientErrorDto | undefined {
  return lastError
}

export function toClientError(error: unknown, componentStack?: string): ClientErrorDto {
  const err = error instanceof Error ? error : undefined
  const type = (err?.name || typeof error).slice(0, 200) || 'Error'
  const message = (err ? err.message : String(error)).slice(0, 2000)
  const stack = [err?.stack, componentStack].filter(Boolean).join('\n').slice(0, 16000)
  return { type, message, stack: stack || undefined }
}

/** Errors the UI already shows (a failed API call) or that are not errors at all (a cancel). */
function isHandled(error: unknown): boolean {
  return error instanceof ApiClientError || Axios.isAxiosError(error) || Axios.isCancel(error)
}

export function reportError(error: unknown, componentStack?: string): void {
  if (typeof window === 'undefined' || isHandled(error)) return
  // A chunk of a build replaced by a deploy, outside any ErrorBoundary: the reload is the fix.
  if (isStaleChunkError(error) && reloadForStaleChunk()) return
  const dto = toClientError(error, componentStack)
  const text = `${dto.type}: ${dto.message}`
  if (IGNORED.some((pattern) => pattern.test(dto.message) || pattern.test(dto.stack ?? ''))) {
    return
  }
  logEntry('ERROR', 'error', text)
  lastError = dto

  if (!useAuthStore.getState().isAuthenticated || !isErrorReportingEnabled()) return
  if (sent.has(text) || sent.size >= MAX_PER_SESSION) return
  sent.add(text)

  void (async () => {
    try {
      await reportClientError(
        { context: await buildClientContext(), error: dto, logs: getLogEntries(LOG_ENTRIES) },
        { skipErrorToast: true }
      )
    } catch {
      // Deliberately silent: see the module comment.
    }
  })()
}

let installed = false

export function installErrorCapture(): void {
  if (installed || typeof window === 'undefined') return
  installed = true
  window.addEventListener('error', (event) => reportError(event.error ?? event.message))
  window.addEventListener('unhandledrejection', (event) => reportError(event.reason))
}

/** For the tests. */
export function resetErrorReporter(): void {
  sent.clear()
  lastError = undefined
}
