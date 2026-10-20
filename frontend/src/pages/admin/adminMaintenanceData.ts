import type { QueryClient } from '@tanstack/react-query'
import { prefetchListDomainsQuery } from '@/api/endpoints/admin-domains/admin-domains'
import { useAuthStore } from '@/store/authStore'
import { ADMIN_DOMAIN_FILTER_PARAMS } from './adminTeamsData'

/**
 * Server-side counterpart of `AdminMaintenancePage`: its only query is the domain dropdown, the
 * same `/admin/domains` entry `AdminTeamsPage` and `AdminUsersPage` read. The two maintenance
 * actions are mutations, run on demand.
 *
 * Gated on `isAuthenticated` only — see `adminDashboardData.ts` for why.
 */
export async function prefetchAdminMaintenance(queryClient: QueryClient): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated) return
  await prefetchListDomainsQuery(queryClient, ADMIN_DOMAIN_FILTER_PARAMS)
}
