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

import type { ConfigDto, GetStyle200 } from '../../dto'

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
 * Get frontend configuration including auth and app settings
 * @summary Get application configuration
 */
export const getConfig = (options?: SecondParameter<typeof axiosMutator>, signal?: AbortSignal) => {
  return axiosMutator<ConfigDto>({ url: `/api/config`, method: 'GET', signal }, options)
}

export const getGetConfigQueryKey = () => {
  return [`/api/config`] as const
}

export const getGetConfigQueryOptions = <
  TData = Awaited<ReturnType<typeof getConfig>>,
  TError = ErrorType<unknown>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConfig>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetConfigQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getConfig>>> = ({ signal }) =>
    getConfig(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getConfig>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetConfigQueryResult = NonNullable<Awaited<ReturnType<typeof getConfig>>>
export type GetConfigQueryError = ErrorType<unknown>

/**
 * Get frontend configuration including auth and app settings
 * @summary Get application configuration
 */
export function useGetConfig<
  TData = Awaited<ReturnType<typeof getConfig>>,
  TError = ErrorType<unknown>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConfig>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getConfig>>,
          TError,
          Awaited<ReturnType<typeof getConfig>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get frontend configuration including auth and app settings
 * @summary Get application configuration
 */
export function useGetConfig<
  TData = Awaited<ReturnType<typeof getConfig>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConfig>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getConfig>>,
          TError,
          Awaited<ReturnType<typeof getConfig>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get frontend configuration including auth and app settings
 * @summary Get application configuration
 */
export function useGetConfig<
  TData = Awaited<ReturnType<typeof getConfig>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConfig>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get frontend configuration including auth and app settings
 * @summary Get application configuration
 */
export function useGetConfig<
  TData = Awaited<ReturnType<typeof getConfig>>,
  TError = ErrorType<unknown>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConfig>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetConfigQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get frontend configuration including auth and app settings
 * @summary Get application configuration
 */
export const prefetchGetConfigQuery = async <
  TData = Awaited<ReturnType<typeof getConfig>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getConfig>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetConfigQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Returns the MapLibre style document for a raster basemap whose provider serves tiles only. The URL is the one already carried by MapStyleDto.url — clients hand it to the map engine rather than building it themselves.
 * @summary Get a generated map style
 */
export const getStyle = (
  id: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GetStyle200>(
    { url: `/api/map/styles/${id}.json`, method: 'GET', signal },
    options
  )
}

export const getGetStyleQueryKey = (id: string) => {
  return [`/api/map/styles/${id}.json`] as const
}

export const getGetStyleQueryOptions = <
  TData = Awaited<ReturnType<typeof getStyle>>,
  TError = ErrorType<void>,
>(
  id: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStyle>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetStyleQueryKey(id)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getStyle>>> = ({ signal }) =>
    getStyle(id, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: id !== null && id !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getStyle>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetStyleQueryResult = NonNullable<Awaited<ReturnType<typeof getStyle>>>
export type GetStyleQueryError = ErrorType<void>

/**
 * Returns the MapLibre style document for a raster basemap whose provider serves tiles only. The URL is the one already carried by MapStyleDto.url — clients hand it to the map engine rather than building it themselves.
 * @summary Get a generated map style
 */
export function useGetStyle<TData = Awaited<ReturnType<typeof getStyle>>, TError = ErrorType<void>>(
  id: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStyle>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getStyle>>,
          TError,
          Awaited<ReturnType<typeof getStyle>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Returns the MapLibre style document for a raster basemap whose provider serves tiles only. The URL is the one already carried by MapStyleDto.url — clients hand it to the map engine rather than building it themselves.
 * @summary Get a generated map style
 */
export function useGetStyle<TData = Awaited<ReturnType<typeof getStyle>>, TError = ErrorType<void>>(
  id: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStyle>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getStyle>>,
          TError,
          Awaited<ReturnType<typeof getStyle>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Returns the MapLibre style document for a raster basemap whose provider serves tiles only. The URL is the one already carried by MapStyleDto.url — clients hand it to the map engine rather than building it themselves.
 * @summary Get a generated map style
 */
export function useGetStyle<TData = Awaited<ReturnType<typeof getStyle>>, TError = ErrorType<void>>(
  id: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStyle>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Returns the MapLibre style document for a raster basemap whose provider serves tiles only. The URL is the one already carried by MapStyleDto.url — clients hand it to the map engine rather than building it themselves.
 * @summary Get a generated map style
 */
export function useGetStyle<TData = Awaited<ReturnType<typeof getStyle>>, TError = ErrorType<void>>(
  id: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStyle>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetStyleQueryOptions(id, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Returns the MapLibre style document for a raster basemap whose provider serves tiles only. The URL is the one already carried by MapStyleDto.url — clients hand it to the map engine rather than building it themselves.
 * @summary Get a generated map style
 */
export const prefetchGetStyleQuery = async <
  TData = Awaited<ReturnType<typeof getStyle>>,
  TError = ErrorType<void>,
>(
  queryClient: QueryClient,
  id: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStyle>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetStyleQueryOptions(id, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
