import { useMutation, useQuery } from '@tanstack/react-query'
import type {
  DataTag,
  DefinedInitialDataOptions,
  DefinedUseQueryResult,
  MutationFunction,
  QueryClient,
  QueryFunction,
  QueryKey,
  UndefinedInitialDataOptions,
  UseMutationOptions,
  UseMutationResult,
  UseQueryOptions,
  UseQueryResult,
} from '@tanstack/react-query'

import type {
  DeviceListRoutesParams,
  DeviceRoutesResponse,
  DeviceSyncRouteParams,
  ErrorResponse,
  RouteUploadResponse,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

const withQueryKey = <T extends object, K>(query: T, queryKey: K): T & { queryKey: K } => {
  const result = { queryKey } as T & { queryKey: K }
  for (const key of Object.keys(query)) {
    // The explicit queryKey always wins, matching the previous
    // `{ ...query, queryKey }` spread where it was set last.
    if (key === 'queryKey') continue
    Object.defineProperty(result, key, {
      enumerable: true,
      configurable: true,
      get: () => (query as Record<string, unknown>)[key],
    })
  }
  return result
}

/**
 * Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest routes from user's teams.
 * @summary List routes for user
 */
export const deviceListRoutes = (
  params?: DeviceListRoutesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<DeviceRoutesResponse>(
    { url: `/api/device/routes`, method: 'GET', params, signal },
    options
  )
}

export const getDeviceListRoutesQueryKey = (params?: DeviceListRoutesParams) => {
  return [`/api/device/routes`, ...(params ? [params] : [])] as const
}

export const getDeviceListRoutesQueryOptions = <
  TData = Awaited<ReturnType<typeof deviceListRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: DeviceListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceListRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDeviceListRoutesQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof deviceListRoutes>>> = ({ signal }) =>
    deviceListRoutes(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof deviceListRoutes>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type DeviceListRoutesQueryResult = NonNullable<Awaited<ReturnType<typeof deviceListRoutes>>>
export type DeviceListRoutesQueryError = ErrorType<ErrorResponse>

/**
 * Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest routes from user's teams.
 * @summary List routes for user
 */
export function useDeviceListRoutes<
  TData = Awaited<ReturnType<typeof deviceListRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  params: undefined | DeviceListRoutesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceListRoutes>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof deviceListRoutes>>,
          TError,
          Awaited<ReturnType<typeof deviceListRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest routes from user's teams.
 * @summary List routes for user
 */
export function useDeviceListRoutes<
  TData = Awaited<ReturnType<typeof deviceListRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: DeviceListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceListRoutes>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof deviceListRoutes>>,
          TError,
          Awaited<ReturnType<typeof deviceListRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest routes from user's teams.
 * @summary List routes for user
 */
export function useDeviceListRoutes<
  TData = Awaited<ReturnType<typeof deviceListRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: DeviceListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceListRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest routes from user's teams.
 * @summary List routes for user
 */
export function useDeviceListRoutes<
  TData = Awaited<ReturnType<typeof deviceListRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: DeviceListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceListRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDeviceListRoutesQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest routes from user's teams.
 * @summary List routes for user
 */
export const prefetchDeviceListRoutesQuery = async <
  TData = Awaited<ReturnType<typeof deviceListRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: DeviceListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceListRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDeviceListRoutesQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Download route as FIT file for GPS devices
 * @summary Download FIT file
 */
export const deviceDownloadFit = (
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>(
    { url: `/api/device/routes/${teamSlug}/${routeSlug}/fit`, method: 'GET', signal },
    options
  )
}

export const getDeviceDownloadFitQueryKey = (teamSlug: string, routeSlug: string) => {
  return [`/api/device/routes/${teamSlug}/${routeSlug}/fit`] as const
}

export const getDeviceDownloadFitQueryOptions = <
  TData = Awaited<ReturnType<typeof deviceDownloadFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadFit>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDeviceDownloadFitQueryKey(teamSlug, routeSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof deviceDownloadFit>>> = ({ signal }) =>
    deviceDownloadFit(teamSlug, routeSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && routeSlug !== null && routeSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadFit>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DeviceDownloadFitQueryResult = NonNullable<
  Awaited<ReturnType<typeof deviceDownloadFit>>
>
export type DeviceDownloadFitQueryError = ErrorType<ErrorResponse>

/**
 * Download route as FIT file for GPS devices
 * @summary Download FIT file
 */
export function useDeviceDownloadFit<
  TData = Awaited<ReturnType<typeof deviceDownloadFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadFit>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof deviceDownloadFit>>,
          TError,
          Awaited<ReturnType<typeof deviceDownloadFit>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download route as FIT file for GPS devices
 * @summary Download FIT file
 */
export function useDeviceDownloadFit<
  TData = Awaited<ReturnType<typeof deviceDownloadFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadFit>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof deviceDownloadFit>>,
          TError,
          Awaited<ReturnType<typeof deviceDownloadFit>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download route as FIT file for GPS devices
 * @summary Download FIT file
 */
export function useDeviceDownloadFit<
  TData = Awaited<ReturnType<typeof deviceDownloadFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadFit>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download route as FIT file for GPS devices
 * @summary Download FIT file
 */
export function useDeviceDownloadFit<
  TData = Awaited<ReturnType<typeof deviceDownloadFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadFit>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDeviceDownloadFitQueryOptions(teamSlug, routeSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Download route as FIT file for GPS devices
 * @summary Download FIT file
 */
export const prefetchDeviceDownloadFitQuery = async <
  TData = Awaited<ReturnType<typeof deviceDownloadFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadFit>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDeviceDownloadFitQueryOptions(teamSlug, routeSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Download route as GPX file for GPS devices
 * @summary Download GPX file
 */
export const deviceDownloadGpx = (
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>(
    { url: `/api/device/routes/${teamSlug}/${routeSlug}/gpx`, method: 'GET', signal },
    options
  )
}

export const getDeviceDownloadGpxQueryKey = (teamSlug: string, routeSlug: string) => {
  return [`/api/device/routes/${teamSlug}/${routeSlug}/gpx`] as const
}

export const getDeviceDownloadGpxQueryOptions = <
  TData = Awaited<ReturnType<typeof deviceDownloadGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadGpx>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDeviceDownloadGpxQueryKey(teamSlug, routeSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof deviceDownloadGpx>>> = ({ signal }) =>
    deviceDownloadGpx(teamSlug, routeSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && routeSlug !== null && routeSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadGpx>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DeviceDownloadGpxQueryResult = NonNullable<
  Awaited<ReturnType<typeof deviceDownloadGpx>>
>
export type DeviceDownloadGpxQueryError = ErrorType<ErrorResponse>

/**
 * Download route as GPX file for GPS devices
 * @summary Download GPX file
 */
export function useDeviceDownloadGpx<
  TData = Awaited<ReturnType<typeof deviceDownloadGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadGpx>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof deviceDownloadGpx>>,
          TError,
          Awaited<ReturnType<typeof deviceDownloadGpx>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download route as GPX file for GPS devices
 * @summary Download GPX file
 */
export function useDeviceDownloadGpx<
  TData = Awaited<ReturnType<typeof deviceDownloadGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadGpx>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof deviceDownloadGpx>>,
          TError,
          Awaited<ReturnType<typeof deviceDownloadGpx>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download route as GPX file for GPS devices
 * @summary Download GPX file
 */
export function useDeviceDownloadGpx<
  TData = Awaited<ReturnType<typeof deviceDownloadGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadGpx>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download route as GPX file for GPS devices
 * @summary Download GPX file
 */
export function useDeviceDownloadGpx<
  TData = Awaited<ReturnType<typeof deviceDownloadGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadGpx>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDeviceDownloadGpxQueryOptions(teamSlug, routeSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Download route as GPX file for GPS devices
 * @summary Download GPX file
 */
export const prefetchDeviceDownloadGpxQuery = async <
  TData = Awaited<ReturnType<typeof deviceDownloadGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceDownloadGpx>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDeviceDownloadGpxQueryOptions(teamSlug, routeSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Upload route to a cloud GPS service (e.g., Hammerhead, Garmin Connect, Wahoo)
 * @summary Sync route to cloud service
 */
export const deviceSyncRoute = (
  teamSlug: string,
  routeSlug: string,
  params: DeviceSyncRouteParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteUploadResponse>(
    { url: `/api/device/routes/${teamSlug}/${routeSlug}/sync`, method: 'POST', params, signal },
    options
  )
}

export const getDeviceSyncRouteMutationKey = () => ['deviceSyncRoute'] as const

export const getDeviceSyncRouteMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deviceSyncRoute>>,
    TError,
    DeviceSyncRouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deviceSyncRoute>>,
  TError,
  DeviceSyncRouteMutationVariables,
  TContext
> => {
  const mutationKey = getDeviceSyncRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deviceSyncRoute>>,
    DeviceSyncRouteMutationVariables
  > = (props) => {
    const { teamSlug, routeSlug, params } = props ?? {}

    return deviceSyncRoute(teamSlug, routeSlug, params, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeviceSyncRouteMutationResult = NonNullable<Awaited<ReturnType<typeof deviceSyncRoute>>>

export type DeviceSyncRouteMutationError = ErrorType<ErrorResponse>
export type DeviceSyncRouteMutationVariables = {
  teamSlug: string
  routeSlug: string
  params: DeviceSyncRouteParams
}

/**
 * Upload route to a cloud GPS service (e.g., Hammerhead, Garmin Connect, Wahoo)
 * @summary Sync route to cloud service
 */
export const useDeviceSyncRoute = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deviceSyncRoute>>,
      TError,
      DeviceSyncRouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deviceSyncRoute>>,
  TError,
  DeviceSyncRouteMutationVariables,
  TContext
> => {
  return useMutation(getDeviceSyncRouteMutationOptions(options), queryClient)
}
