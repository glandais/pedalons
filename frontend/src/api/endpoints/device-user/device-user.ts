import { useQuery } from '@tanstack/react-query'
import type {
  DataTag,
  DefinedInitialDataOptions,
  DefinedUseQueryResult,
  QueryClient,
  QueryFunction,
  QueryKey,
  UndefinedInitialDataOptions,
  UseQueryOptions,
  UseQueryResult,
} from '@tanstack/react-query'

import type { DeviceUserStatusResponse, ErrorResponse } from '../../dto'

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
 * Get authenticated user's status including connected GPS services
 * @summary Get current user status
 */
export const deviceGetMe = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<DeviceUserStatusResponse>(
    { url: `/api/device/me`, method: 'GET', signal },
    options
  )
}

export const getDeviceGetMeQueryKey = () => {
  return [`/api/device/me`] as const
}

export const getDeviceGetMeQueryOptions = <
  TData = Awaited<ReturnType<typeof deviceGetMe>>,
  TError = ErrorType<ErrorResponse>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceGetMe>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDeviceGetMeQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof deviceGetMe>>> = ({ signal }) =>
    deviceGetMe(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof deviceGetMe>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type DeviceGetMeQueryResult = NonNullable<Awaited<ReturnType<typeof deviceGetMe>>>
export type DeviceGetMeQueryError = ErrorType<ErrorResponse>

/**
 * Get authenticated user's status including connected GPS services
 * @summary Get current user status
 */
export function useDeviceGetMe<
  TData = Awaited<ReturnType<typeof deviceGetMe>>,
  TError = ErrorType<ErrorResponse>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceGetMe>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof deviceGetMe>>,
          TError,
          Awaited<ReturnType<typeof deviceGetMe>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get authenticated user's status including connected GPS services
 * @summary Get current user status
 */
export function useDeviceGetMe<
  TData = Awaited<ReturnType<typeof deviceGetMe>>,
  TError = ErrorType<ErrorResponse>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceGetMe>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof deviceGetMe>>,
          TError,
          Awaited<ReturnType<typeof deviceGetMe>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get authenticated user's status including connected GPS services
 * @summary Get current user status
 */
export function useDeviceGetMe<
  TData = Awaited<ReturnType<typeof deviceGetMe>>,
  TError = ErrorType<ErrorResponse>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceGetMe>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get authenticated user's status including connected GPS services
 * @summary Get current user status
 */
export function useDeviceGetMe<
  TData = Awaited<ReturnType<typeof deviceGetMe>>,
  TError = ErrorType<ErrorResponse>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceGetMe>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDeviceGetMeQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get authenticated user's status including connected GPS services
 * @summary Get current user status
 */
export const prefetchDeviceGetMeQuery = async <
  TData = Awaited<ReturnType<typeof deviceGetMe>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof deviceGetMe>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDeviceGetMeQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
