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
  ErrorResponse,
  GetConnectUrlParams,
  GpsAutoSyncRequest,
  GpsOAuthUrlResponse,
  GpsServiceConnectionDto,
  GpsServiceType,
  HandleCallbackParams,
  RouteUploadResponse,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

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
 * Get list of GPS service types configured for this domain
 * @summary Get available GPS services
 */
export const getAvailableServices = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GpsServiceType[]>(
    { url: `/api/gps/available`, method: 'GET', signal },
    options
  )
}

export const getGetAvailableServicesQueryKey = () => {
  return [`/api/gps/available`] as const
}

export const getGetAvailableServicesQueryOptions = <
  TData = Awaited<ReturnType<typeof getAvailableServices>>,
  TError = ErrorType<void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAvailableServices>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetAvailableServicesQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getAvailableServices>>> = ({ signal }) =>
    getAvailableServices(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getAvailableServices>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetAvailableServicesQueryResult = NonNullable<
  Awaited<ReturnType<typeof getAvailableServices>>
>
export type GetAvailableServicesQueryError = ErrorType<void>

export function useGetAvailableServices<
  TData = Awaited<ReturnType<typeof getAvailableServices>>,
  TError = ErrorType<void>,
>(
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getAvailableServices>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAvailableServices>>,
          TError,
          Awaited<ReturnType<typeof getAvailableServices>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetAvailableServices<
  TData = Awaited<ReturnType<typeof getAvailableServices>>,
  TError = ErrorType<void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getAvailableServices>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAvailableServices>>,
          TError,
          Awaited<ReturnType<typeof getAvailableServices>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetAvailableServices<
  TData = Awaited<ReturnType<typeof getAvailableServices>>,
  TError = ErrorType<void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getAvailableServices>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get available GPS services
 */

export function useGetAvailableServices<
  TData = Awaited<ReturnType<typeof getAvailableServices>>,
  TError = ErrorType<void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getAvailableServices>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetAvailableServicesQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get available GPS services
 */
export const prefetchGetAvailableServicesQuery = async <
  TData = Awaited<ReturnType<typeof getAvailableServices>>,
  TError = ErrorType<void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getAvailableServices>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetAvailableServicesQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Handles OAuth callback from GPS service and redirects to the frontend page chosen by the returnTo of the connect call (the profile by default). OAuth 2.0 brings code and state; OAuth 1.0a (Garmin, when the domain's credential says so) brings oauth_token and oauth_verifier.
 * @summary OAuth callback
 */
export const handleCallback = (
  serviceType: GpsServiceType,
  params?: HandleCallbackParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>(
    { url: `/api/gps/callback/${serviceType}`, method: 'GET', params, signal },
    options
  )
}

export const getHandleCallbackQueryKey = (
  serviceType: GpsServiceType,
  params?: HandleCallbackParams
) => {
  return [`/api/gps/callback/${serviceType}`, ...(params ? [params] : [])] as const
}

export const getHandleCallbackQueryOptions = <
  TData = Awaited<ReturnType<typeof handleCallback>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  serviceType: GpsServiceType,
  params?: HandleCallbackParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof handleCallback>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getHandleCallbackQueryKey(serviceType, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof handleCallback>>> = ({ signal }) =>
    handleCallback(serviceType, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: serviceType !== null && serviceType !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof handleCallback>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type HandleCallbackQueryResult = NonNullable<Awaited<ReturnType<typeof handleCallback>>>
export type HandleCallbackQueryError = ErrorType<void | ErrorResponse>

export function useHandleCallback<
  TData = Awaited<ReturnType<typeof handleCallback>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  serviceType: GpsServiceType,
  params: undefined | HandleCallbackParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof handleCallback>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof handleCallback>>,
          TError,
          Awaited<ReturnType<typeof handleCallback>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useHandleCallback<
  TData = Awaited<ReturnType<typeof handleCallback>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  serviceType: GpsServiceType,
  params?: HandleCallbackParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof handleCallback>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof handleCallback>>,
          TError,
          Awaited<ReturnType<typeof handleCallback>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useHandleCallback<
  TData = Awaited<ReturnType<typeof handleCallback>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  serviceType: GpsServiceType,
  params?: HandleCallbackParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof handleCallback>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary OAuth callback
 */

export function useHandleCallback<
  TData = Awaited<ReturnType<typeof handleCallback>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  serviceType: GpsServiceType,
  params?: HandleCallbackParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof handleCallback>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getHandleCallbackQueryOptions(serviceType, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary OAuth callback
 */
export const prefetchHandleCallbackQuery = async <
  TData = Awaited<ReturnType<typeof handleCallback>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  serviceType: GpsServiceType,
  params?: HandleCallbackParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof handleCallback>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getHandleCallbackQueryOptions(serviceType, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get the OAuth authorization URL to connect a GPS service
 * @summary Get OAuth authorization URL
 */
export const getConnectUrl = (
  serviceType: GpsServiceType,
  params?: GetConnectUrlParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GpsOAuthUrlResponse>(
    { url: `/api/gps/connect/${serviceType}`, method: 'GET', params, signal },
    options
  )
}

export const getGetConnectUrlQueryKey = (
  serviceType: GpsServiceType,
  params?: GetConnectUrlParams
) => {
  return [`/api/gps/connect/${serviceType}`, ...(params ? [params] : [])] as const
}

export const getGetConnectUrlQueryOptions = <
  TData = Awaited<ReturnType<typeof getConnectUrl>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  serviceType: GpsServiceType,
  params?: GetConnectUrlParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConnectUrl>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetConnectUrlQueryKey(serviceType, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getConnectUrl>>> = ({ signal }) =>
    getConnectUrl(serviceType, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: serviceType !== null && serviceType !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getConnectUrl>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetConnectUrlQueryResult = NonNullable<Awaited<ReturnType<typeof getConnectUrl>>>
export type GetConnectUrlQueryError = ErrorType<ErrorResponse | void>

export function useGetConnectUrl<
  TData = Awaited<ReturnType<typeof getConnectUrl>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  serviceType: GpsServiceType,
  params: undefined | GetConnectUrlParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConnectUrl>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getConnectUrl>>,
          TError,
          Awaited<ReturnType<typeof getConnectUrl>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetConnectUrl<
  TData = Awaited<ReturnType<typeof getConnectUrl>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  serviceType: GpsServiceType,
  params?: GetConnectUrlParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConnectUrl>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getConnectUrl>>,
          TError,
          Awaited<ReturnType<typeof getConnectUrl>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetConnectUrl<
  TData = Awaited<ReturnType<typeof getConnectUrl>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  serviceType: GpsServiceType,
  params?: GetConnectUrlParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConnectUrl>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get OAuth authorization URL
 */

export function useGetConnectUrl<
  TData = Awaited<ReturnType<typeof getConnectUrl>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  serviceType: GpsServiceType,
  params?: GetConnectUrlParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConnectUrl>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetConnectUrlQueryOptions(serviceType, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get OAuth authorization URL
 */
export const prefetchGetConnectUrlQuery = async <
  TData = Awaited<ReturnType<typeof getConnectUrl>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  serviceType: GpsServiceType,
  params?: GetConnectUrlParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConnectUrl>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetConnectUrlQueryOptions(serviceType, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Turns on or off, for one connected service, the automatic sending of the routes of the rides the user is registered in (from 7 days before the departure until a day after it), kept in sync with their changes. Turning it off removes from the service the upcoming routes it sent. A RECONNECT_REQUIRED state is only cleared by connecting the service again.
 * @summary Turn the automatic route sync on or off
 */
export const setGpsAutoSync = (
  serviceType: GpsServiceType,
  gpsAutoSyncRequest: BodyType<GpsAutoSyncRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GpsServiceConnectionDto>(
    {
      url: `/api/gps/connections/${serviceType}/auto-sync`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: gpsAutoSyncRequest,
      signal,
    },
    options
  )
}

export const getSetGpsAutoSyncMutationKey = () => ['setGpsAutoSync'] as const

export const getSetGpsAutoSyncMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof setGpsAutoSync>>,
    TError,
    SetGpsAutoSyncMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof setGpsAutoSync>>,
  TError,
  SetGpsAutoSyncMutationVariables,
  TContext
> => {
  const mutationKey = getSetGpsAutoSyncMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof setGpsAutoSync>>,
    SetGpsAutoSyncMutationVariables
  > = (props) => {
    const { serviceType, data } = props ?? {}

    return setGpsAutoSync(serviceType, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type SetGpsAutoSyncMutationResult = NonNullable<Awaited<ReturnType<typeof setGpsAutoSync>>>
export type SetGpsAutoSyncMutationBody = BodyType<GpsAutoSyncRequest>
export type SetGpsAutoSyncMutationError = ErrorType<ErrorResponse | void>
export type SetGpsAutoSyncMutationVariables = {
  serviceType: GpsServiceType
  data: BodyType<GpsAutoSyncRequest>
}

/**
 * @summary Turn the automatic route sync on or off
 */
export const useSetGpsAutoSync = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof setGpsAutoSync>>,
      TError,
      SetGpsAutoSyncMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof setGpsAutoSync>>,
  TError,
  SetGpsAutoSyncMutationVariables,
  TContext
> => {
  return useMutation(getSetGpsAutoSyncMutationOptions(options), queryClient)
}
/**
 * Disconnect a connected GPS service
 * @summary Disconnect GPS service
 */
export const disconnect = (
  serviceType: GpsServiceType,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/gps/disconnect/${serviceType}`, method: 'DELETE', signal },
    options
  )
}

export const getDisconnectMutationKey = () => ['disconnect'] as const

export const getDisconnectMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof disconnect>>,
    TError,
    DisconnectMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof disconnect>>,
  TError,
  DisconnectMutationVariables,
  TContext
> => {
  const mutationKey = getDisconnectMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof disconnect>>,
    DisconnectMutationVariables
  > = (props) => {
    const { serviceType } = props ?? {}

    return disconnect(serviceType, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DisconnectMutationResult = NonNullable<Awaited<ReturnType<typeof disconnect>>>

export type DisconnectMutationError = ErrorType<ErrorResponse | void>
export type DisconnectMutationVariables = { serviceType: GpsServiceType }

/**
 * @summary Disconnect GPS service
 */
export const useDisconnect = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof disconnect>>,
      TError,
      DisconnectMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof disconnect>>,
  TError,
  DisconnectMutationVariables,
  TContext
> => {
  return useMutation(getDisconnectMutationOptions(options), queryClient)
}
/**
 * Upload a route to a connected GPS service
 * @summary Upload route to GPS service
 */
export const uploadRoute = (
  serviceType: GpsServiceType,
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteUploadResponse>(
    { url: `/api/gps/upload/${serviceType}/${teamSlug}/${routeSlug}`, method: 'POST', signal },
    options
  )
}

export const getUploadRouteMutationKey = () => ['uploadRoute'] as const

export const getUploadRouteMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof uploadRoute>>,
    TError,
    UploadRouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof uploadRoute>>,
  TError,
  UploadRouteMutationVariables,
  TContext
> => {
  const mutationKey = getUploadRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof uploadRoute>>,
    UploadRouteMutationVariables
  > = (props) => {
    const { serviceType, teamSlug, routeSlug } = props ?? {}

    return uploadRoute(serviceType, teamSlug, routeSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UploadRouteMutationResult = NonNullable<Awaited<ReturnType<typeof uploadRoute>>>

export type UploadRouteMutationError = ErrorType<ErrorResponse | void>
export type UploadRouteMutationVariables = {
  serviceType: GpsServiceType
  teamSlug: string
  routeSlug: string
}

/**
 * @summary Upload route to GPS service
 */
export const useUploadRoute = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof uploadRoute>>,
      TError,
      UploadRouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof uploadRoute>>,
  TError,
  UploadRouteMutationVariables,
  TContext
> => {
  return useMutation(getUploadRouteMutationOptions(options), queryClient)
}
