import type { TFunction } from 'i18next'
import { ErrorCode } from '@/api/dto'
import { apiErrorCode } from '@/lib/apiError'
import { isApplePlatform } from '@/lib/platform'
import { PlannerRefusedError } from '@/lib/planner'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'

/** The router's own failures (no-route aside: it carries the shortcut), each with the advice that unblocks the user. Anything else falls back on the generic message. */
const PLANNER_ERROR_KEYS: Partial<Record<ErrorCode, TranslationKey>> = {
  [ErrorCode.ROUTING_QUOTA_EXCEEDED]: tRegister('planner.error.quota'),
  [ErrorCode.ROUTING_SEGMENT_TOO_LONG]: tRegister('planner.error.segmentTooLong'),
  [ErrorCode.ROUTING_UNAVAILABLE]: tRegister('planner.error.unavailable'),
  // Refusals of the team named in the call (rights or team changed meanwhile): retrying changes nothing.
  [ErrorCode.FORBIDDEN]: tRegister('planner.error.forbidden'),
  [ErrorCode.NOT_FOUND]: tRegister('planner.error.forbidden'),
  [ErrorCode.TEAM_NOT_FOUND]: tRegister('planner.error.forbidden'),
  // Refusals of a file sent to the editor's import (the API's own wording).
  [ErrorCode.FILE_REQUIRED]: tRegister('errors.api.FILE_REQUIRED'),
  [ErrorCode.FILE_TOO_LARGE]: tRegister('errors.api.FILE_TOO_LARGE'),
  [ErrorCode.GPX_EMPTY]: tRegister('errors.api.GPX_EMPTY'),
  [ErrorCode.GPX_FAILURE]: tRegister('errors.api.GPX_FAILURE'),
  [ErrorCode.GPX_TOO_LONG]: tRegister('errors.api.GPX_TOO_LONG'),
  [ErrorCode.PLANNER_IMPORT_TOO_LARGE]: tRegister('errors.api.PLANNER_IMPORT_TOO_LARGE'),
}

/** The straight-line gesture, spelled for the platform (the same as the help panel's). */
export function directShortcut(t: TFunction): string {
  // No modifier key on a finger: the bar's toggle is the way
  if (window.matchMedia?.('(pointer: coarse)')?.matches) return t('planner.help.direct.touch')
  return isApplePlatform()
    ? t('planner.help.direct.apple', { alt: '⌥' })
    : t('planner.help.direct.mouse', { alt: 'Alt' })
}

/**
 * The message shown under the planner for a failed routing call. `teamSlug` tells whose flag
 * refused a ROUTE_PLANNER_DISABLED: the team's with one, the site's (GPX tools) without.
 * `fallbackKey` words a failure with no message of its own (default: the routing one).
 */
export function plannerErrorMessage(
  error: unknown,
  t: TFunction,
  teamSlug?: string,
  fallbackKey: TranslationKey = 'planner.error.routing'
): string {
  if (error instanceof PlannerRefusedError) return t(error.messageKey)
  const code = apiErrorCode(error)
  if (code === ErrorCode.ROUTE_PLANNER_DISABLED)
    return t(teamSlug ? 'planner.error.disabled' : 'planner.error.disabledSite')
  if (code === ErrorCode.ROUTING_NO_ROUTE)
    return t('planner.error.noRoute', { shortcut: directShortcut(t) })
  const key = code ? PLANNER_ERROR_KEYS[code] : undefined
  return key ? t(key) : t(fallbackKey)
}
