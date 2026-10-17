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
  ErrorResponse,
  GeocodeResultDto,
  ResolvePlaceParams,
  SearchPlacesParams,
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
 * Returns the place whose id a search result carried, with lat and lon always set. Call it only for the result the user picked, never for every suggestion: each call is billed by the provider. The id is a query parameter because it contains ':'. An id that is not shaped like a provider id, or that the provider does not know, is a 404 (NOT_FOUND); a provider failure or spent quota is a 503 (GEOCODING_UNAVAILABLE) — the client should then let the user search and pick again, or leave the position empty.
 * @summary Resolve the position of a picked place
 */
export const resolvePlace = (
  params: ResolvePlaceParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GeocodeResultDto>(
    { url: `/api/geocode/place`, method: 'GET', params, signal },
    options
  )
}

export const getResolvePlaceQueryKey = (params?: ResolvePlaceParams) => {
  return [`/api/geocode/place`, ...(params ? [params] : [])] as const
}

export const getResolvePlaceQueryOptions = <
  TData = Awaited<ReturnType<typeof resolvePlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: ResolvePlaceParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof resolvePlace>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getResolvePlaceQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof resolvePlace>>> = ({ signal }) =>
    resolvePlace(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof resolvePlace>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ResolvePlaceQueryResult = NonNullable<Awaited<ReturnType<typeof resolvePlace>>>
export type ResolvePlaceQueryError = ErrorType<void | ErrorResponse>

export function useResolvePlace<
  TData = Awaited<ReturnType<typeof resolvePlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: ResolvePlaceParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof resolvePlace>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof resolvePlace>>,
          TError,
          Awaited<ReturnType<typeof resolvePlace>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useResolvePlace<
  TData = Awaited<ReturnType<typeof resolvePlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: ResolvePlaceParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof resolvePlace>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof resolvePlace>>,
          TError,
          Awaited<ReturnType<typeof resolvePlace>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useResolvePlace<
  TData = Awaited<ReturnType<typeof resolvePlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: ResolvePlaceParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof resolvePlace>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Resolve the position of a picked place
 */

export function useResolvePlace<
  TData = Awaited<ReturnType<typeof resolvePlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: ResolvePlaceParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof resolvePlace>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getResolvePlaceQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Resolve the position of a picked place
 */
export const prefetchResolvePlaceQuery = async <
  TData = Awaited<ReturnType<typeof resolvePlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  params: ResolvePlaceParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof resolvePlace>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getResolvePlaceQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Returns at most 5 places matching the query, or an empty list when the query is shorter than 3 characters or the provider is unreachable. A result's lat and lon are null when the provider gave no position for it (the usual case): once the user picks it, resolve its position with GET /api/geocode/place?id=. Never resolve every suggestion: each resolution is billed. Results come from the Stadia Maps geocoder: a client displaying them must credit 'Stadia Maps, © OpenStreetMap contributors & others'.
 * @summary Search places by name
 */
export const searchPlaces = (
  params?: SearchPlacesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GeocodeResultDto[]>(
    { url: `/api/geocode/search`, method: 'GET', params, signal },
    options
  )
}

export const getSearchPlacesQueryKey = (params?: SearchPlacesParams) => {
  return [`/api/geocode/search`, ...(params ? [params] : [])] as const
}

export const getSearchPlacesQueryOptions = <
  TData = Awaited<ReturnType<typeof searchPlaces>>,
  TError = ErrorType<void>,
>(
  params?: SearchPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof searchPlaces>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getSearchPlacesQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof searchPlaces>>> = ({ signal }) =>
    searchPlaces(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof searchPlaces>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type SearchPlacesQueryResult = NonNullable<Awaited<ReturnType<typeof searchPlaces>>>
export type SearchPlacesQueryError = ErrorType<void>

export function useSearchPlaces<
  TData = Awaited<ReturnType<typeof searchPlaces>>,
  TError = ErrorType<void>,
>(
  params: undefined | SearchPlacesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof searchPlaces>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof searchPlaces>>,
          TError,
          Awaited<ReturnType<typeof searchPlaces>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useSearchPlaces<
  TData = Awaited<ReturnType<typeof searchPlaces>>,
  TError = ErrorType<void>,
>(
  params?: SearchPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof searchPlaces>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof searchPlaces>>,
          TError,
          Awaited<ReturnType<typeof searchPlaces>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useSearchPlaces<
  TData = Awaited<ReturnType<typeof searchPlaces>>,
  TError = ErrorType<void>,
>(
  params?: SearchPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof searchPlaces>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Search places by name
 */

export function useSearchPlaces<
  TData = Awaited<ReturnType<typeof searchPlaces>>,
  TError = ErrorType<void>,
>(
  params?: SearchPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof searchPlaces>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getSearchPlacesQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Search places by name
 */
export const prefetchSearchPlacesQuery = async <
  TData = Awaited<ReturnType<typeof searchPlaces>>,
  TError = ErrorType<void>,
>(
  queryClient: QueryClient,
  params?: SearchPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof searchPlaces>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getSearchPlacesQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
