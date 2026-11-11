import { ErrorCode } from '@/api/dto'
import type { IncompatibleVisibilityDetails } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'

/**
 * The details of an `INCOMPATIBLE_VISIBILITY` refusal (plan §4.4), or undefined for any other
 * failure. Both lists are always there; the one that does not apply is empty.
 */
export function incompatibleVisibilityOf(
  error: unknown
): IncompatibleVisibilityDetails | undefined {
  if (!(error instanceof ApiClientError)) return undefined
  if (error.error.code !== ErrorCode.INCOMPATIBLE_VISIBILITY) return undefined
  const details = error.error.errorDetails as Partial<IncompatibleVisibilityDetails> | undefined
  return {
    type: 'INCOMPATIBLE_VISIBILITY',
    routes: details?.routes ?? [],
    usages: details?.usages ?? [],
  }
}
