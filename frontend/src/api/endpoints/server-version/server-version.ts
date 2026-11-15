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

import type { VersionDto } from '../../dto'

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
 * Get the API contract version the server implements, plus the git commit and build time it was built from
 * @summary Get server version
 */
export const getVersion = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<VersionDto>({ url: `/api/version`, method: 'GET', signal }, options)
}

export const getGetVersionQueryKey = () => {
  return [`/api/version`] as const
}

export const getGetVersionQueryOptions = <
  TData = Awaited<ReturnType<typeof getVersion>>,
  TError = ErrorType<unknown>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getVersion>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetVersionQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getVersion>>> = ({ signal }) =>
    getVersion(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getVersion>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetVersionQueryResult = NonNullable<Awaited<ReturnType<typeof getVersion>>>
export type GetVersionQueryError = ErrorType<unknown>

/**
 * Get the API contract version the server implements, plus the git commit and build time it was built from
 * @summary Get server version
 */
export function useGetVersion<
  TData = Awaited<ReturnType<typeof getVersion>>,
  TError = ErrorType<unknown>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getVersion>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getVersion>>,
          TError,
          Awaited<ReturnType<typeof getVersion>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get the API contract version the server implements, plus the git commit and build time it was built from
 * @summary Get server version
 */
export function useGetVersion<
  TData = Awaited<ReturnType<typeof getVersion>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getVersion>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getVersion>>,
          TError,
          Awaited<ReturnType<typeof getVersion>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get the API contract version the server implements, plus the git commit and build time it was built from
 * @summary Get server version
 */
export function useGetVersion<
  TData = Awaited<ReturnType<typeof getVersion>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getVersion>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get the API contract version the server implements, plus the git commit and build time it was built from
 * @summary Get server version
 */
export function useGetVersion<
  TData = Awaited<ReturnType<typeof getVersion>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getVersion>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetVersionQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get the API contract version the server implements, plus the git commit and build time it was built from
 * @summary Get server version
 */
export const prefetchGetVersionQuery = async <
  TData = Awaited<ReturnType<typeof getVersion>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getVersion>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetVersionQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
