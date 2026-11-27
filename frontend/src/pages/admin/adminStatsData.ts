import type { QueryClient } from '@tanstack/react-query'
import {
  prefetchGetPlatformStatsQuery,
  prefetchListDomainsQuery,
} from '@/api/endpoints/admin-domains/admin-domains'
import { useAuthStore } from '@/store/authStore'
import { ADMIN_DOMAIN_FILTER_PARAMS } from './adminTeamsData'

/** Params of the first render: all domains (`domainId` left out), the page's initial state. */
export const ADMIN_STATS_DEFAULT_PARAMS = undefined

/**
 * Server-side counterpart of `AdminStatsPage`: the statistics over all domains and the domain
 * dropdown. Gated on `isAuthenticated` only — see `adminDashboardData.ts` for why.
 */
export async function prefetchAdminStats(queryClient: QueryClient): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated) return
  await Promise.all([
    prefetchGetPlatformStatsQuery(queryClient, ADMIN_STATS_DEFAULT_PARAMS),
    prefetchListDomainsQuery(queryClient, ADMIN_DOMAIN_FILTER_PARAMS),
  ])
}
