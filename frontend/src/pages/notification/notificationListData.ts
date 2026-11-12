import { useCallback, useMemo } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import {
  getListMyNotificationsQueryKey,
  listMyNotifications,
  prefetchListMyNotificationsQuery,
  useListMyNotifications,
} from '@/api/endpoints/notifications/notifications'
import { prefetchPageWindow } from '@/config/prefetchHelpers'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { readUrlFilters, useUrlFilters } from '@/hooks/useUrlFilters'
import {
  notificationApiParams,
  notificationFiltersAlias,
  notificationFiltersSchema,
} from '@/hooks/filters/notificationFilters'
import { useAuthStore } from '@/store/authStore'

/**
 * What the notifications page reads: the filtered page the URL asks for, plus the neighbouring
 * pages `usePaginatedQuery` warms — and {@link prefetchNotificationList}, the same window
 * server-side. The inbox is per-user, which the SSR handles since it renders a signed-in visitor's
 * documents with their session.
 */
export const notificationListFilterOptions = {
  schema: notificationFiltersSchema,
  alias: notificationFiltersAlias,
} as const

export function useNotificationListData() {
  const { filters, setFilters } = useUrlFilters(notificationListFilterOptions)

  const apiParams = useMemo(() => notificationApiParams(filters), [filters])

  const notifications = useListMyNotifications(apiParams, {
    query: LIST_QUERY,
    request: LIST_REQUEST,
  })

  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getListMyNotificationsQueryKey({ ...apiParams, page }),
      queryFn: () => listMyNotifications({ ...apiParams, page }, LIST_REQUEST),
    }),
    [apiParams]
  )

  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filters.size,
    totalItems: notifications.data?.total ?? 0,
    prefetchPage,
  })

  return { filters, setFilters, notifications, totalPages }
}

/** Server-side counterpart of {@link useNotificationListData}: the page the URL asks for, and its neighbours. */
export async function prefetchNotificationList(queryClient: QueryClient, url: URL) {
  if (!useAuthStore.getState().isAuthenticated) return
  const filters = readUrlFilters(url.searchParams, notificationListFilterOptions)
  await prefetchPageWindow(notificationApiParams(filters), (p) =>
    prefetchListMyNotificationsQuery(queryClient, p, { request: LIST_REQUEST })
  )
}
