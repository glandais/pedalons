import { LIST_REQUEST } from '@/lib/listQuery'
import type { QueryClient } from '@tanstack/react-query'
import {
  prefetchGetLatestExportQuery,
  prefetchGetMyProfileSummaryQuery,
  prefetchListPairedDevicesQuery,
} from '@/api/endpoints/users/users'
import { prefetchGetMyNotificationPreferencesQuery } from '@/api/endpoints/notifications/notifications'
import { prefetchListPasskeysQuery } from '@/api/endpoints/passkeys/passkeys'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import { prefetchListMyBlockedUsersQuery } from '@/api/endpoints/moderation/moderation'
import { useAuthStore } from '@/store/authStore'

/**
 * Server-side counterparts of what each profile page puts on the screen at first paint. Every page
 * of the profile also reads `GET /api/users/me`, which the server seeds itself when it resolves the
 * session (entry-server.tsx), and the preferences, account and help pages read nothing else — the
 * version on the help page is the footer's, prefetched for every document.
 *
 * Prefetch-only, like the pages themselves own no query: they mount the section components that do
 * (frontend/docs/SSR-data-loading.md, « Prefetch-only »). The generated `prefetchXxxQuery` of each
 * one is all it takes, none of these queries has a parameter.
 *
 * Its own module, never an export of a page: `routes.config.ts` is eagerly imported and must not
 * pull the pages out of their lazy chunks.
 */
function signedIn(): boolean {
  return useAuthStore.getState().isAuthenticated
}

/** The overview: `/me` plus the summary, its two calls (the state lines). */
export async function prefetchProfileOverview(queryClient: QueryClient): Promise<void> {
  if (!signedIn()) return
  await prefetchGetMyProfileSummaryQuery(queryClient)
}

/** `NotificationPreferences`'s `useGetMyNotificationPreferences()`. */
export async function prefetchProfileNotifications(queryClient: QueryClient): Promise<void> {
  if (!signedIn()) return
  await prefetchGetMyNotificationPreferencesQuery(queryClient)
}

/**
 * `GpsConnectionsManager`'s `useGetAvailableServices()` (the connections themselves are in `/me`)
 * and `PairedDevicesManager`'s `useListPairedDevices()`.
 */
export async function prefetchProfileDevices(queryClient: QueryClient): Promise<void> {
  if (!signedIn()) return
  await Promise.all([
    prefetchGetAvailableServicesQuery(queryClient),
    prefetchListPairedDevicesQuery(queryClient),
  ])
}

/** `PasskeyManager`'s `useListPasskeys()`. */
export async function prefetchProfileSecurity(queryClient: QueryClient): Promise<void> {
  if (!signedIn()) return
  await prefetchListPasskeysQuery(queryClient)
}

/**
 * `DataExportManager`'s `useGetLatestExport()` (via `useDataExport`) and the blocked users the row
 * leading to their page counts — the same list that page shows, so it opens from the cache.
 */
export async function prefetchProfilePrivacy(queryClient: QueryClient): Promise<void> {
  if (!signedIn()) return
  await Promise.all([
    prefetchGetLatestExportQuery(queryClient),
    prefetchListMyBlockedUsersQuery(queryClient),
  ])
}

/** `BlockedUsers`'s `useListMyBlockedUsers()`. */
export async function prefetchBlockedUsers(queryClient: QueryClient): Promise<void> {
  if (!signedIn()) return
  await prefetchListMyBlockedUsersQuery(queryClient, { request: LIST_REQUEST })
}
