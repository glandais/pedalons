import type { QueryClient } from '@tanstack/react-query'
import {
  prefetchGetActivationQuery,
  prefetchGetStatsQuery,
} from '@/api/endpoints/admin-domains/admin-domains'
import { useAuthStore } from '@/store/authStore'

/**
 * « Activation des nouveaux comptes » (docs/LEDGER_*.md API-213): the last twelve sign-up weeks,
 * read by `AdminDashboardPage` and prefetched here with the same params, so they share one key.
 */
export const ACTIVATION_PARAMS = { weeks: 12 } as const

/**
 * Server-side counterpart of `AdminDashboardPage`, which reads `useGetStats()` and
 * `useGetActivation(ACTIVATION_PARAMS)` unconditionally (no gate in the hooks themselves).
 * Prefetch-only — the page owns exactly these queries, so a hook here would just re-export them
 * for no reader.
 *
 * Gated on `isAuthenticated` only: the route (`admin`) is `auth: 'authenticated'` and the store
 * carries no platform-admin flag to check server-side. A signed-in non-admin still gets a
 * prefetch that resolves to a 403 from `GET /admin/…` — wasted requests, same cost the client
 * would have paid after hydration, and cheaper than adding a call just to find out.
 */
export async function prefetchAdminDashboard(queryClient: QueryClient): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated) return
  await Promise.all([
    prefetchGetStatsQuery(queryClient),
    prefetchGetActivationQuery(queryClient, ACTIVATION_PARAMS),
  ])
}
