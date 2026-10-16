import { useCallback, useMemo } from 'react'
import { useQueryClient, useMutation } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { useAuth } from './useAuth'
import { AXIOS_INSTANCE } from '@/lib/axiosInstance'
import { getGetMeQueryKey } from '@/api/endpoints/users/users'
import {
  useGetAvailableServices,
  useSetGpsAutoSync,
} from '@/api/endpoints/gps-services/gps-services'
import { uploadToGpsService } from '@/api/endpoints/gpx-previews/gpx-previews'
import type { GpsConnectReturn, GpsServiceType, GpsServiceConnectionDto, UserDto } from '@/api/dto'

interface GpsOAuthUrlResponse {
  authorizationUrl: string
}

interface RouteUploadResponse {
  success: boolean
  message?: string
  externalRouteId?: string
}

/**
 * Hook for managing GPS service connections.
 */
export function useGpsConnections() {
  const queryClient = useQueryClient()
  const { user, refetchUser, isAuthenticated } = useAuth()

  // Fetch available services for this domain
  const { data: availableServices = [], isLoading: isLoadingAvailable } = useGetAvailableServices({
    query: { enabled: isAuthenticated },
  })

  const connectedServices = useMemo(() => user?.connectedServices ?? [], [user?.connectedServices])

  const isConnected = useCallback(
    (serviceType: GpsServiceType) => {
      return connectedServices.some((s) => s.serviceType === serviceType)
    },
    [connectedServices]
  )

  const getConnection = useCallback(
    (serviceType: GpsServiceType): GpsServiceConnectionDto | undefined => {
      return connectedServices.find((s) => s.serviceType === serviceType)
    },
    [connectedServices]
  )

  const isServiceAvailable = useCallback(
    (serviceType: GpsServiceType): boolean => {
      return availableServices.includes(serviceType)
    },
    [availableServices]
  )

  /**
   * Initiate OAuth flow for connecting a GPS service: the page leaves for the provider, whose
   * callback brings the browser back to `returnTo` — the profile unless said otherwise
   * (docs/LEDGER_*.md API-63).
   */
  const initiateConnect = useCallback(
    async (serviceType: GpsServiceType, returnTo?: GpsConnectReturn) => {
      try {
        const response = await AXIOS_INSTANCE.get<GpsOAuthUrlResponse>(
          `/api/gps/connect/${serviceType}`,
          { params: returnTo ? { returnTo } : undefined }
        )
        // Redirect to the authorization URL
        window.location.href = response.data.authorizationUrl
      } catch {
        notifications.show({
          message: i18next.t('gps.notifications.connectFailed'),
          color: 'red',
        })
      }
    },
    []
  )

  /**
   * Disconnect a GPS service.
   */
  const disconnectMutation = useMutation({
    mutationFn: async (serviceType: GpsServiceType) => {
      await AXIOS_INSTANCE.delete(`/api/gps/disconnect/${serviceType}`)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: getGetMeQueryKey() })
      refetchUser()
      notifications.show({
        message: i18next.t('gps.notifications.disconnected'),
        color: 'green',
      })
    },
    onError: () => {
      notifications.show({
        message: i18next.t('gps.notifications.disconnectFailed'),
        color: 'red',
      })
    },
  })

  /**
   * Turn the automatic sending of the member's ride routes on or off for one connected service
   * (docs/LEDGER_*.md API-120, WEB-92). The answer is the connection as it now stands: it replaces
   * the one `/me` carries at once, so the switch does not flick back while `/me` is fetched again.
   */
  const autoSyncMutation = useSetGpsAutoSync({
    mutation: {
      onSuccess: (connection, { data }) => {
        queryClient.setQueryData<UserDto>(getGetMeQueryKey(), (current) =>
          current
            ? {
                ...current,
                connectedServices: (current.connectedServices ?? []).map((service) =>
                  service.serviceType === connection.serviceType ? connection : service
                ),
              }
            : current
        )
        queryClient.invalidateQueries({ queryKey: getGetMeQueryKey() })
        const service = i18next.t(
          `gps.services.${connection.serviceType.toLowerCase() as Lowercase<GpsServiceType>}`
        )
        notifications.show({
          message: data.enabled
            ? i18next.t('gps.autoSync.notifications.enabled', { service })
            : i18next.t('gps.autoSync.notifications.disabled', { service }),
          color: 'green',
        })
      },
      onError: () => {
        notifications.show({
          message: i18next.t('gps.autoSync.notifications.failed'),
          color: 'red',
        })
      },
    },
  })

  const mutateAutoSync = autoSyncMutation.mutate
  const setAutoSync = useCallback(
    (serviceType: GpsServiceType, enabled: boolean) =>
      mutateAutoSync({ serviceType, data: { enabled } }),
    [mutateAutoSync]
  )

  const notifyUploadResult = (data: RouteUploadResponse) => {
    if (data.success) {
      notifications.show({ message: i18next.t('gps.notifications.uploadSuccess'), color: 'green' })
    } else {
      notifications.show({
        message: data.message || i18next.t('gps.notifications.uploadFailed'),
        color: 'red',
      })
    }
  }

  const notifyUploadFailure = () => {
    notifications.show({ message: i18next.t('gps.notifications.uploadFailed'), color: 'red' })
  }

  /**
   * Upload a route to a connected GPS service.
   */
  const uploadRouteMutation = useMutation({
    mutationFn: async ({
      serviceType,
      teamSlug,
      routeSlug,
    }: {
      serviceType: GpsServiceType
      teamSlug: string
      routeSlug: string
    }) => {
      const response = await AXIOS_INSTANCE.post<RouteUploadResponse>(
        `/api/gps/upload/${serviceType}/${teamSlug}/${routeSlug}`
      )
      return response.data
    },
    onSuccess: notifyUploadResult,
    onError: notifyUploadFailure,
  })

  /**
   * Upload an analysed GPX file (from the GPX tools) to a connected GPS service.
   */
  const uploadPreviewMutation = useMutation({
    mutationFn: ({ serviceType, previewId }: { serviceType: GpsServiceType; previewId: string }) =>
      uploadToGpsService(previewId, serviceType),
    onSuccess: notifyUploadResult,
    onError: notifyUploadFailure,
  })

  return {
    availableServices,
    isLoadingAvailable,
    isServiceAvailable,
    connectedServices,
    isConnected,
    getConnection,
    initiateConnect,
    disconnect: disconnectMutation.mutate,
    isDisconnecting: disconnectMutation.isPending,
    setAutoSync,
    /** The change being saved, if any: the switch it concerns shows it and waits. */
    autoSyncPending: autoSyncMutation.isPending
      ? {
          serviceType: autoSyncMutation.variables.serviceType,
          enabled: autoSyncMutation.variables.data.enabled,
        }
      : undefined,
    uploadRoute: uploadRouteMutation.mutate,
    uploadRouteAsync: uploadRouteMutation.mutateAsync,
    isUploading: uploadRouteMutation.isPending,
    uploadPreview: uploadPreviewMutation.mutate,
    isUploadingPreview: uploadPreviewMutation.isPending,
  }
}
