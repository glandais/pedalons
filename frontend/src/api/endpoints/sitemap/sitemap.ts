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

import type { SitemapDto } from '../../dto'

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
 * Public teams and their public content, as an anonymous visitor sees it, for the site the request arrived on (a pinned host lists its one team). Classified ads and routes are never listed. Anonymous by construction: the caller's session does not widen it.
 * @summary Get the indexable pages of this site
 */
export const getSitemap = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<SitemapDto>({ url: `/api/sitemap`, method: 'GET', signal }, options)
}

export const getGetSitemapQueryKey = () => {
  return [`/api/sitemap`] as const
}

export const getGetSitemapQueryOptions = <
  TData = Awaited<ReturnType<typeof getSitemap>>,
  TError = ErrorType<unknown>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getSitemap>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetSitemapQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getSitemap>>> = ({ signal }) =>
    getSitemap(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getSitemap>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetSitemapQueryResult = NonNullable<Awaited<ReturnType<typeof getSitemap>>>
export type GetSitemapQueryError = ErrorType<unknown>

/**
 * Public teams and their public content, as an anonymous visitor sees it, for the site the request arrived on (a pinned host lists its one team). Classified ads and routes are never listed. Anonymous by construction: the caller's session does not widen it.
 * @summary Get the indexable pages of this site
 */
export function useGetSitemap<
  TData = Awaited<ReturnType<typeof getSitemap>>,
  TError = ErrorType<unknown>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getSitemap>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getSitemap>>,
          TError,
          Awaited<ReturnType<typeof getSitemap>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Public teams and their public content, as an anonymous visitor sees it, for the site the request arrived on (a pinned host lists its one team). Classified ads and routes are never listed. Anonymous by construction: the caller's session does not widen it.
 * @summary Get the indexable pages of this site
 */
export function useGetSitemap<
  TData = Awaited<ReturnType<typeof getSitemap>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getSitemap>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getSitemap>>,
          TError,
          Awaited<ReturnType<typeof getSitemap>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Public teams and their public content, as an anonymous visitor sees it, for the site the request arrived on (a pinned host lists its one team). Classified ads and routes are never listed. Anonymous by construction: the caller's session does not widen it.
 * @summary Get the indexable pages of this site
 */
export function useGetSitemap<
  TData = Awaited<ReturnType<typeof getSitemap>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getSitemap>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Public teams and their public content, as an anonymous visitor sees it, for the site the request arrived on (a pinned host lists its one team). Classified ads and routes are never listed. Anonymous by construction: the caller's session does not widen it.
 * @summary Get the indexable pages of this site
 */
export function useGetSitemap<
  TData = Awaited<ReturnType<typeof getSitemap>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getSitemap>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetSitemapQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Public teams and their public content, as an anonymous visitor sees it, for the site the request arrived on (a pinned host lists its one team). Classified ads and routes are never listed. Anonymous by construction: the caller's session does not widen it.
 * @summary Get the indexable pages of this site
 */
export const prefetchGetSitemapQuery = async <
  TData = Awaited<ReturnType<typeof getSitemap>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getSitemap>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetSitemapQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
