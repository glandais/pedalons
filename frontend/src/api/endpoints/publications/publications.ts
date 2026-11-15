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

import type {
  CountAllPublicationsParams,
  CountPublicationsParams,
  CountResponse,
  ErrorResponse,
  ListAllPublicationsParams,
  ListPublicationsParams,
  PublicationListResponse,
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
 * Get publications from all accessible teams (user's teams + public teams)
 * @summary List all publications
 */
export const listAllPublications = (
  params?: ListAllPublicationsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PublicationListResponse>(
    { url: `/api/publications`, method: 'GET', params, signal },
    options
  )
}

export const getListAllPublicationsQueryKey = (params?: ListAllPublicationsParams) => {
  return [`/api/publications`, ...(params ? [params] : [])] as const
}

export const getListAllPublicationsQueryOptions = <
  TData = Awaited<ReturnType<typeof listAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params?: ListAllPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListAllPublicationsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listAllPublications>>> = ({ signal }) =>
    listAllPublications(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listAllPublications>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListAllPublicationsQueryResult = NonNullable<
  Awaited<ReturnType<typeof listAllPublications>>
>
export type ListAllPublicationsQueryError = ErrorType<unknown>

/**
 * Get publications from all accessible teams (user's teams + public teams)
 * @summary List all publications
 */
export function useListAllPublications<
  TData = Awaited<ReturnType<typeof listAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params: undefined | ListAllPublicationsParams,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listAllPublications>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listAllPublications>>,
          TError,
          Awaited<ReturnType<typeof listAllPublications>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get publications from all accessible teams (user's teams + public teams)
 * @summary List all publications
 */
export function useListAllPublications<
  TData = Awaited<ReturnType<typeof listAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params?: ListAllPublicationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listAllPublications>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listAllPublications>>,
          TError,
          Awaited<ReturnType<typeof listAllPublications>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get publications from all accessible teams (user's teams + public teams)
 * @summary List all publications
 */
export function useListAllPublications<
  TData = Awaited<ReturnType<typeof listAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params?: ListAllPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get publications from all accessible teams (user's teams + public teams)
 * @summary List all publications
 */
export function useListAllPublications<
  TData = Awaited<ReturnType<typeof listAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params?: ListAllPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListAllPublicationsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get publications from all accessible teams (user's teams + public teams)
 * @summary List all publications
 */
export const prefetchListAllPublicationsQuery = async <
  TData = Awaited<ReturnType<typeof listAllPublications>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  params?: ListAllPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListAllPublicationsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * How many publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count all publications
 */
export const countAllPublications = (
  params?: CountAllPublicationsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CountResponse>(
    { url: `/api/publications/count`, method: 'GET', params, signal },
    options
  )
}

export const getCountAllPublicationsQueryKey = (params?: CountAllPublicationsParams) => {
  return [`/api/publications/count`, ...(params ? [params] : [])] as const
}

export const getCountAllPublicationsQueryOptions = <
  TData = Awaited<ReturnType<typeof countAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params?: CountAllPublicationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof countAllPublications>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getCountAllPublicationsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof countAllPublications>>> = ({ signal }) =>
    countAllPublications(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof countAllPublications>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type CountAllPublicationsQueryResult = NonNullable<
  Awaited<ReturnType<typeof countAllPublications>>
>
export type CountAllPublicationsQueryError = ErrorType<unknown>

/**
 * How many publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count all publications
 */
export function useCountAllPublications<
  TData = Awaited<ReturnType<typeof countAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params: undefined | CountAllPublicationsParams,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof countAllPublications>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof countAllPublications>>,
          TError,
          Awaited<ReturnType<typeof countAllPublications>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count all publications
 */
export function useCountAllPublications<
  TData = Awaited<ReturnType<typeof countAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params?: CountAllPublicationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof countAllPublications>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof countAllPublications>>,
          TError,
          Awaited<ReturnType<typeof countAllPublications>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count all publications
 */
export function useCountAllPublications<
  TData = Awaited<ReturnType<typeof countAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params?: CountAllPublicationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof countAllPublications>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count all publications
 */
export function useCountAllPublications<
  TData = Awaited<ReturnType<typeof countAllPublications>>,
  TError = ErrorType<unknown>,
>(
  params?: CountAllPublicationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof countAllPublications>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getCountAllPublicationsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * How many publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count all publications
 */
export const prefetchCountAllPublicationsQuery = async <
  TData = Awaited<ReturnType<typeof countAllPublications>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  params?: CountAllPublicationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof countAllPublications>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getCountAllPublicationsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get paginated list of publications for a team with optional filtering
 * @summary List publications
 */
export const listPublications = (
  teamSlug: string,
  params?: ListPublicationsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PublicationListResponse>(
    { url: `/api/teams/${teamSlug}/publications`, method: 'GET', params, signal },
    options
  )
}

export const getListPublicationsQueryKey = (teamSlug: string, params?: ListPublicationsParams) => {
  return [`/api/teams/${teamSlug}/publications`, ...(params ? [params] : [])] as const
}

export const getListPublicationsQueryOptions = <
  TData = Awaited<ReturnType<typeof listPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListPublicationsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listPublications>>> = ({ signal }) =>
    listPublications(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listPublications>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListPublicationsQueryResult = NonNullable<Awaited<ReturnType<typeof listPublications>>>
export type ListPublicationsQueryError = ErrorType<ErrorResponse>

/**
 * Get paginated list of publications for a team with optional filtering
 * @summary List publications
 */
export function useListPublications<
  TData = Awaited<ReturnType<typeof listPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | ListPublicationsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPublications>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPublications>>,
          TError,
          Awaited<ReturnType<typeof listPublications>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of publications for a team with optional filtering
 * @summary List publications
 */
export function useListPublications<
  TData = Awaited<ReturnType<typeof listPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPublications>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPublications>>,
          TError,
          Awaited<ReturnType<typeof listPublications>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of publications for a team with optional filtering
 * @summary List publications
 */
export function useListPublications<
  TData = Awaited<ReturnType<typeof listPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of publications for a team with optional filtering
 * @summary List publications
 */
export function useListPublications<
  TData = Awaited<ReturnType<typeof listPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListPublicationsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get paginated list of publications for a team with optional filtering
 * @summary List publications
 */
export const prefetchListPublicationsQuery = async <
  TData = Awaited<ReturnType<typeof listPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: ListPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListPublicationsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * How many of the team's publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count publications
 */
export const countPublications = (
  teamSlug: string,
  params?: CountPublicationsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CountResponse>(
    { url: `/api/teams/${teamSlug}/publications/count`, method: 'GET', params, signal },
    options
  )
}

export const getCountPublicationsQueryKey = (
  teamSlug: string,
  params?: CountPublicationsParams
) => {
  return [`/api/teams/${teamSlug}/publications/count`, ...(params ? [params] : [])] as const
}

export const getCountPublicationsQueryOptions = <
  TData = Awaited<ReturnType<typeof countPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: CountPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getCountPublicationsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof countPublications>>> = ({ signal }) =>
    countPublications(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof countPublications>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type CountPublicationsQueryResult = NonNullable<
  Awaited<ReturnType<typeof countPublications>>
>
export type CountPublicationsQueryError = ErrorType<ErrorResponse>

/**
 * How many of the team's publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count publications
 */
export function useCountPublications<
  TData = Awaited<ReturnType<typeof countPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | CountPublicationsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof countPublications>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof countPublications>>,
          TError,
          Awaited<ReturnType<typeof countPublications>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many of the team's publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count publications
 */
export function useCountPublications<
  TData = Awaited<ReturnType<typeof countPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: CountPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countPublications>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof countPublications>>,
          TError,
          Awaited<ReturnType<typeof countPublications>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many of the team's publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count publications
 */
export function useCountPublications<
  TData = Awaited<ReturnType<typeof countPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: CountPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many of the team's publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count publications
 */
export function useCountPublications<
  TData = Awaited<ReturnType<typeof countPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: CountPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getCountPublicationsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * How many of the team's publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
 * @summary Count publications
 */
export const prefetchCountPublicationsQuery = async <
  TData = Awaited<ReturnType<typeof countPublications>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: CountPublicationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countPublications>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getCountPublicationsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
