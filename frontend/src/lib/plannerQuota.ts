import type { QueryClient } from '@tanstack/react-query'
import { ErrorCode } from '@/api/dto'
import type { PlannerQuotaDetails, PlannerQuotaDto } from '@/api/dto'
import { getGetTeamQueryKey } from '@/api/endpoints/teams/teams'
import { getGetMeQueryKey } from '@/api/endpoints/users/users'
import { ApiClientError } from '@/lib/apiError'
import { formatInTimeZone } from 'date-fns-tz'
import { fr } from 'date-fns/locale/fr'
import { enUS } from 'date-fns/locale/en-US'

/**
 * Whether the monthly saves of a drawn track are already all used (docs/LEDGER_*.md BILL-10): the
 * team's quota (`TeamDetailDto.plannerQuota`) or the personal one of the GPX tools
 * (`UserDto.plannerQuota`). A null `limit` is an unlimited plan, an absent quota is someone the
 * server gave none to (not allowed to create routes there). The platform admin is exempt on the
 * server, whose figures do not know it: never spent for them.
 *
 * Only the obvious case is spared: the server stays the authority, and refuses a save that went
 * past the quota in the meantime with PLANNER_QUOTA_REACHED (the dialog of PlannerQuotaModal).
 */
export function isPlannerQuotaSpent(
  quota: PlannerQuotaDto | null | undefined,
  isPlatformAdmin = false
): boolean {
  if (isPlatformAdmin || !quota || quota.limit == null) return false
  return quota.used >= quota.limit
}

/** The details of a PLANNER_QUOTA_REACHED refusal, or undefined for any other failure. */
export function plannerQuotaRefusalOf(error: unknown): PlannerQuotaDetails | undefined {
  if (!(error instanceof ApiClientError)) return undefined
  if (error.error.code !== ErrorCode.PLANNER_QUOTA_REACHED) return undefined
  const details = error.error.errorDetails as Partial<PlannerQuotaDetails> | undefined
  if (!details?.scope || details.limit == null || !details.resetsOn) return undefined
  return {
    type: 'PLANNER_QUOTA_REACHED',
    scope: details.scope,
    limit: details.limit,
    current: details.current ?? details.limit,
    resetsOn: details.resetsOn,
    teamName: details.teamName,
  }
}

/**
 * The month the count starts again, spelled out (« décembre », "December"). `resetsOn` is always
 * the first day of a month (a `YYYY-MM-DD` local date): the copy says « le 1er » around it, which a
 * formatted day would not spell right in French. A date with no time of day: read at midnight UTC
 * and formatted in UTC, so neither the server's zone nor the reader's can move it to the eve (the
 * same date-fns call as `formatPattern` of utils/dateFormat, which a reader's zone would shift).
 */
export function resetMonthName(resetsOn: string, language: string): string {
  const date = new Date(`${resetsOn}T00:00:00Z`)
  if (Number.isNaN(date.getTime())) return resetsOn
  return formatInTimeZone(date, 'UTC', 'LLLL', { locale: language.startsWith('en') ? enUS : fr })
}

/**
 * After a save that may have counted (or a refusal saying it is all used): the quota the entry
 * points read is refreshed — the team's for a team route, the user's own for the GPX tools.
 */
export function invalidatePlannerQuota(queryClient: QueryClient, teamSlug?: string): void {
  queryClient.invalidateQueries({
    queryKey: teamSlug ? getGetTeamQueryKey(teamSlug) : getGetMeQueryKey(),
  })
}
