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
  AllRoutesTileParams,
  CountAllRoutesParams,
  CountResponse,
  CountRoutesParams,
  CreateRouteBody,
  ErrorResponse,
  GetAllRoutesBoundsParams,
  GetRoutesBoundsParams,
  GetRoutesBulkParams,
  ListAllRoutesParams,
  ListRoutesParams,
  PlannerStateResponse,
  RouteBoundsResponse,
  RouteDetailDto,
  RouteDto,
  RouteListResponse,
  RouteUsagesResponse,
  RoutesBulkResponse,
  RoutesTileParams,
  SlugChangeRequest,
  UpdateRouteBody,
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
 * Get paginated list of routes from all accessible teams (user's teams + public teams)
 * @summary List all routes
 */
export const listAllRoutes = (
  params?: ListAllRoutesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteListResponse>(
    { url: `/api/routes`, method: 'GET', params, signal },
    options
  )
}

export const getListAllRoutesQueryKey = (params?: ListAllRoutesParams) => {
  return [`/api/routes`, ...(params ? [params] : [])] as const
}

export const getListAllRoutesQueryOptions = <
  TData = Awaited<ReturnType<typeof listAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params?: ListAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListAllRoutesQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listAllRoutes>>> = ({ signal }) =>
    listAllRoutes(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listAllRoutes>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListAllRoutesQueryResult = NonNullable<Awaited<ReturnType<typeof listAllRoutes>>>
export type ListAllRoutesQueryError = ErrorType<unknown>

export function useListAllRoutes<
  TData = Awaited<ReturnType<typeof listAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params: undefined | ListAllRoutesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllRoutes>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listAllRoutes>>,
          TError,
          Awaited<ReturnType<typeof listAllRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useListAllRoutes<
  TData = Awaited<ReturnType<typeof listAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params?: ListAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllRoutes>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listAllRoutes>>,
          TError,
          Awaited<ReturnType<typeof listAllRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useListAllRoutes<
  TData = Awaited<ReturnType<typeof listAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params?: ListAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary List all routes
 */

export function useListAllRoutes<
  TData = Awaited<ReturnType<typeof listAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params?: ListAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListAllRoutesQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary List all routes
 */
export const prefetchListAllRoutesQuery = async <
  TData = Awaited<ReturnType<typeof listAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  params?: ListAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAllRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListAllRoutesQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Extent enclosing the routes of all accessible teams, so a map can open framed on them. Accepts the same filters as the route list, minus sorting and pagination. Yields a null box when no route matches.
 * @summary All routes bounding box
 */
export const getAllRoutesBounds = (
  params?: GetAllRoutesBoundsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteBoundsResponse>(
    { url: `/api/routes/bounds`, method: 'GET', params, signal },
    options
  )
}

export const getGetAllRoutesBoundsQueryKey = (params?: GetAllRoutesBoundsParams) => {
  return [`/api/routes/bounds`, ...(params ? [params] : [])] as const
}

export const getGetAllRoutesBoundsQueryOptions = <
  TData = Awaited<ReturnType<typeof getAllRoutesBounds>>,
  TError = ErrorType<unknown>,
>(
  params?: GetAllRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAllRoutesBounds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetAllRoutesBoundsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getAllRoutesBounds>>> = ({ signal }) =>
    getAllRoutesBounds(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getAllRoutesBounds>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetAllRoutesBoundsQueryResult = NonNullable<
  Awaited<ReturnType<typeof getAllRoutesBounds>>
>
export type GetAllRoutesBoundsQueryError = ErrorType<unknown>

export function useGetAllRoutesBounds<
  TData = Awaited<ReturnType<typeof getAllRoutesBounds>>,
  TError = ErrorType<unknown>,
>(
  params: undefined | GetAllRoutesBoundsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAllRoutesBounds>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAllRoutesBounds>>,
          TError,
          Awaited<ReturnType<typeof getAllRoutesBounds>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetAllRoutesBounds<
  TData = Awaited<ReturnType<typeof getAllRoutesBounds>>,
  TError = ErrorType<unknown>,
>(
  params?: GetAllRoutesBoundsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getAllRoutesBounds>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAllRoutesBounds>>,
          TError,
          Awaited<ReturnType<typeof getAllRoutesBounds>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetAllRoutesBounds<
  TData = Awaited<ReturnType<typeof getAllRoutesBounds>>,
  TError = ErrorType<unknown>,
>(
  params?: GetAllRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAllRoutesBounds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary All routes bounding box
 */

export function useGetAllRoutesBounds<
  TData = Awaited<ReturnType<typeof getAllRoutesBounds>>,
  TError = ErrorType<unknown>,
>(
  params?: GetAllRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAllRoutesBounds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetAllRoutesBoundsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary All routes bounding box
 */
export const prefetchGetAllRoutesBoundsQuery = async <
  TData = Awaited<ReturnType<typeof getAllRoutesBounds>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  params?: GetAllRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAllRoutesBounds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetAllRoutesBoundsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * How many routes of all accessible teams match the filters, with none of them read. Accepts exactly the same filters as the route list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count all routes
 */
export const countAllRoutes = (
  params?: CountAllRoutesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CountResponse>(
    { url: `/api/routes/count`, method: 'GET', params, signal },
    options
  )
}

export const getCountAllRoutesQueryKey = (params?: CountAllRoutesParams) => {
  return [`/api/routes/count`, ...(params ? [params] : [])] as const
}

export const getCountAllRoutesQueryOptions = <
  TData = Awaited<ReturnType<typeof countAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params?: CountAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAllRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getCountAllRoutesQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof countAllRoutes>>> = ({ signal }) =>
    countAllRoutes(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof countAllRoutes>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type CountAllRoutesQueryResult = NonNullable<Awaited<ReturnType<typeof countAllRoutes>>>
export type CountAllRoutesQueryError = ErrorType<unknown>

export function useCountAllRoutes<
  TData = Awaited<ReturnType<typeof countAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params: undefined | CountAllRoutesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAllRoutes>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof countAllRoutes>>,
          TError,
          Awaited<ReturnType<typeof countAllRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useCountAllRoutes<
  TData = Awaited<ReturnType<typeof countAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params?: CountAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAllRoutes>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof countAllRoutes>>,
          TError,
          Awaited<ReturnType<typeof countAllRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useCountAllRoutes<
  TData = Awaited<ReturnType<typeof countAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params?: CountAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAllRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Count all routes
 */

export function useCountAllRoutes<
  TData = Awaited<ReturnType<typeof countAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  params?: CountAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAllRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getCountAllRoutesQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Count all routes
 */
export const prefetchCountAllRoutesQuery = async <
  TData = Awaited<ReturnType<typeof countAllRoutes>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  params?: CountAllRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAllRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getCountAllRoutesQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Mapbox vector tile holding the routes of all accessible teams, layer 'routes'. Accepts the same filters as the route list, minus sorting and pagination, which a tile has no use for. Fetched directly by the map renderer, outside the authenticated HTTP stack: a browser authenticates with its session cookie, any other client with the 't' tile token.
 * @summary All routes vector tile
 */
export const allRoutesTile = (
  z: number,
  x: number,
  y: number,
  params?: AllRoutesTileParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>(
    { url: `/api/routes/tiles/${z}/${x}/${y}.mvt`, method: 'GET', params, signal },
    options
  )
}

export const getAllRoutesTileQueryKey = (
  z: number,
  x: number,
  y: number,
  params?: AllRoutesTileParams
) => {
  return [`/api/routes/tiles/${z}/${x}/${y}.mvt`, ...(params ? [params] : [])] as const
}

export const getAllRoutesTileQueryOptions = <
  TData = Awaited<ReturnType<typeof allRoutesTile>>,
  TError = ErrorType<void>,
>(
  z: number,
  x: number,
  y: number,
  params?: AllRoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof allRoutesTile>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getAllRoutesTileQueryKey(z, x, y, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof allRoutesTile>>> = ({ signal }) =>
    allRoutesTile(z, x, y, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      z !== null &&
      z !== undefined &&
      x !== null &&
      x !== undefined &&
      y !== null &&
      y !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof allRoutesTile>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type AllRoutesTileQueryResult = NonNullable<Awaited<ReturnType<typeof allRoutesTile>>>
export type AllRoutesTileQueryError = ErrorType<void>

export function useAllRoutesTile<
  TData = Awaited<ReturnType<typeof allRoutesTile>>,
  TError = ErrorType<void>,
>(
  z: number,
  x: number,
  y: number,
  params: undefined | AllRoutesTileParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof allRoutesTile>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof allRoutesTile>>,
          TError,
          Awaited<ReturnType<typeof allRoutesTile>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useAllRoutesTile<
  TData = Awaited<ReturnType<typeof allRoutesTile>>,
  TError = ErrorType<void>,
>(
  z: number,
  x: number,
  y: number,
  params?: AllRoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof allRoutesTile>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof allRoutesTile>>,
          TError,
          Awaited<ReturnType<typeof allRoutesTile>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useAllRoutesTile<
  TData = Awaited<ReturnType<typeof allRoutesTile>>,
  TError = ErrorType<void>,
>(
  z: number,
  x: number,
  y: number,
  params?: AllRoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof allRoutesTile>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary All routes vector tile
 */

export function useAllRoutesTile<
  TData = Awaited<ReturnType<typeof allRoutesTile>>,
  TError = ErrorType<void>,
>(
  z: number,
  x: number,
  y: number,
  params?: AllRoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof allRoutesTile>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getAllRoutesTileQueryOptions(z, x, y, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary All routes vector tile
 */
export const prefetchAllRoutesTileQuery = async <
  TData = Awaited<ReturnType<typeof allRoutesTile>>,
  TError = ErrorType<void>,
>(
  queryClient: QueryClient,
  z: number,
  x: number,
  y: number,
  params?: AllRoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof allRoutesTile>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getAllRoutesTileQueryOptions(z, x, y, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get paginated list of routes for a team with optional filters and sorting
 * @summary List routes
 */
export const listRoutes = (
  teamSlug: string,
  params?: ListRoutesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteListResponse>(
    { url: `/api/teams/${teamSlug}/routes`, method: 'GET', params, signal },
    options
  )
}

export const getListRoutesQueryKey = (teamSlug: string, params?: ListRoutesParams) => {
  return [`/api/teams/${teamSlug}/routes`, ...(params ? [params] : [])] as const
}

export const getListRoutesQueryOptions = <
  TData = Awaited<ReturnType<typeof listRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListRoutesQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listRoutes>>> = ({ signal }) =>
    listRoutes(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listRoutes>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListRoutesQueryResult = NonNullable<Awaited<ReturnType<typeof listRoutes>>>
export type ListRoutesQueryError = ErrorType<ErrorResponse>

export function useListRoutes<
  TData = Awaited<ReturnType<typeof listRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | ListRoutesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRoutes>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listRoutes>>,
          TError,
          Awaited<ReturnType<typeof listRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useListRoutes<
  TData = Awaited<ReturnType<typeof listRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRoutes>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listRoutes>>,
          TError,
          Awaited<ReturnType<typeof listRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useListRoutes<
  TData = Awaited<ReturnType<typeof listRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary List routes
 */

export function useListRoutes<
  TData = Awaited<ReturnType<typeof listRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListRoutesQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary List routes
 */
export const prefetchListRoutesQuery = async <
  TData = Awaited<ReturnType<typeof listRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: ListRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListRoutesQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a new route by uploading a GPX file
 * @summary Create route
 */
export const createRoute = (
  teamSlug: string,
  createRouteBody: BodyType<CreateRouteBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (createRouteBody.route !== undefined) {
    formData.append(`route`, JSON.stringify(createRouteBody.route))
  }
  if (createRouteBody.gpxFile !== undefined) {
    formData.append(`gpxFile`, createRouteBody.gpxFile)
  }

  return axiosMutator<RouteDto>(
    {
      url: `/api/teams/${teamSlug}/routes`,
      method: 'POST',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      signal,
    },
    options
  )
}

export const getCreateRouteMutationKey = () => ['createRoute'] as const

export const getCreateRouteMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createRoute>>,
    TError,
    CreateRouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createRoute>>,
  TError,
  CreateRouteMutationVariables,
  TContext
> => {
  const mutationKey = getCreateRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createRoute>>,
    CreateRouteMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createRoute(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateRouteMutationResult = NonNullable<Awaited<ReturnType<typeof createRoute>>>
export type CreateRouteMutationBody = BodyType<CreateRouteBody>
export type CreateRouteMutationError = ErrorType<ErrorResponse>
export type CreateRouteMutationVariables = { teamSlug: string; data: BodyType<CreateRouteBody> }

/**
 * @summary Create route
 */
export const useCreateRoute = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createRoute>>,
      TError,
      CreateRouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createRoute>>,
  TError,
  CreateRouteMutationVariables,
  TContext
> => {
  return useMutation(getCreateRouteMutationOptions(options), queryClient)
}
/**
 * Extent enclosing the team's routes, so a map can open framed on them. Accepts the same filters as the route list, minus sorting and pagination. Yields a null box when no route matches.
 * @summary Team routes bounding box
 */
export const getRoutesBounds = (
  teamSlug: string,
  params?: GetRoutesBoundsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteBoundsResponse>(
    { url: `/api/teams/${teamSlug}/routes/bounds`, method: 'GET', params, signal },
    options
  )
}

export const getGetRoutesBoundsQueryKey = (teamSlug: string, params?: GetRoutesBoundsParams) => {
  return [`/api/teams/${teamSlug}/routes/bounds`, ...(params ? [params] : [])] as const
}

export const getGetRoutesBoundsQueryOptions = <
  TData = Awaited<ReturnType<typeof getRoutesBounds>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBounds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRoutesBoundsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRoutesBounds>>> = ({ signal }) =>
    getRoutesBounds(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRoutesBounds>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRoutesBoundsQueryResult = NonNullable<Awaited<ReturnType<typeof getRoutesBounds>>>
export type GetRoutesBoundsQueryError = ErrorType<ErrorResponse>

export function useGetRoutesBounds<
  TData = Awaited<ReturnType<typeof getRoutesBounds>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | GetRoutesBoundsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBounds>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRoutesBounds>>,
          TError,
          Awaited<ReturnType<typeof getRoutesBounds>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRoutesBounds<
  TData = Awaited<ReturnType<typeof getRoutesBounds>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBounds>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRoutesBounds>>,
          TError,
          Awaited<ReturnType<typeof getRoutesBounds>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRoutesBounds<
  TData = Awaited<ReturnType<typeof getRoutesBounds>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBounds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Team routes bounding box
 */

export function useGetRoutesBounds<
  TData = Awaited<ReturnType<typeof getRoutesBounds>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBounds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRoutesBoundsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Team routes bounding box
 */
export const prefetchGetRoutesBoundsQuery = async <
  TData = Awaited<ReturnType<typeof getRoutesBounds>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: GetRoutesBoundsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBounds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRoutesBoundsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * The detail of every requested 'slug' that exists and the caller may read, in one round-trip — built for the screens that load several routes together (a ride's stages, a comparison view), which would otherwise cost one request per route. Each row is exactly what the single-route endpoint returns, geometry included. Unknown slugs and slugs the caller may not read are silently left out of the answer rather than failing the whole batch. Set 'geometry' to false for the screens that only need each route's name and figures. The response also carries the bounding box of the track geometry actually sent back (waypoints are excluded, so an imported meeting-point or car-park waypoint far off the track cannot widen it), so a map can frame the batch without a second request.
 * @summary Get several routes' details at once
 */
export const getRoutesBulk = (
  teamSlug: string,
  params?: GetRoutesBulkParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RoutesBulkResponse>(
    { url: `/api/teams/${teamSlug}/routes/bulk`, method: 'GET', params, signal },
    options
  )
}

export const getGetRoutesBulkQueryKey = (teamSlug: string, params?: GetRoutesBulkParams) => {
  return [`/api/teams/${teamSlug}/routes/bulk`, ...(params ? [params] : [])] as const
}

export const getGetRoutesBulkQueryOptions = <
  TData = Awaited<ReturnType<typeof getRoutesBulk>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetRoutesBulkParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBulk>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRoutesBulkQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRoutesBulk>>> = ({ signal }) =>
    getRoutesBulk(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRoutesBulk>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRoutesBulkQueryResult = NonNullable<Awaited<ReturnType<typeof getRoutesBulk>>>
export type GetRoutesBulkQueryError = ErrorType<ErrorResponse>

export function useGetRoutesBulk<
  TData = Awaited<ReturnType<typeof getRoutesBulk>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | GetRoutesBulkParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBulk>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRoutesBulk>>,
          TError,
          Awaited<ReturnType<typeof getRoutesBulk>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRoutesBulk<
  TData = Awaited<ReturnType<typeof getRoutesBulk>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetRoutesBulkParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBulk>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRoutesBulk>>,
          TError,
          Awaited<ReturnType<typeof getRoutesBulk>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRoutesBulk<
  TData = Awaited<ReturnType<typeof getRoutesBulk>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetRoutesBulkParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBulk>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get several routes' details at once
 */

export function useGetRoutesBulk<
  TData = Awaited<ReturnType<typeof getRoutesBulk>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetRoutesBulkParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBulk>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRoutesBulkQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get several routes' details at once
 */
export const prefetchGetRoutesBulkQuery = async <
  TData = Awaited<ReturnType<typeof getRoutesBulk>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: GetRoutesBulkParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoutesBulk>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRoutesBulkQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * How many of the team's routes match the filters, with none of them read. Accepts exactly the same filters as the route list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count routes
 */
export const countRoutes = (
  teamSlug: string,
  params?: CountRoutesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CountResponse>(
    { url: `/api/teams/${teamSlug}/routes/count`, method: 'GET', params, signal },
    options
  )
}

export const getCountRoutesQueryKey = (teamSlug: string, params?: CountRoutesParams) => {
  return [`/api/teams/${teamSlug}/routes/count`, ...(params ? [params] : [])] as const
}

export const getCountRoutesQueryOptions = <
  TData = Awaited<ReturnType<typeof countRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: CountRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getCountRoutesQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof countRoutes>>> = ({ signal }) =>
    countRoutes(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof countRoutes>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type CountRoutesQueryResult = NonNullable<Awaited<ReturnType<typeof countRoutes>>>
export type CountRoutesQueryError = ErrorType<ErrorResponse>

export function useCountRoutes<
  TData = Awaited<ReturnType<typeof countRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | CountRoutesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof countRoutes>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof countRoutes>>,
          TError,
          Awaited<ReturnType<typeof countRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useCountRoutes<
  TData = Awaited<ReturnType<typeof countRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: CountRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countRoutes>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof countRoutes>>,
          TError,
          Awaited<ReturnType<typeof countRoutes>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useCountRoutes<
  TData = Awaited<ReturnType<typeof countRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: CountRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Count routes
 */

export function useCountRoutes<
  TData = Awaited<ReturnType<typeof countRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: CountRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getCountRoutesQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Count routes
 */
export const prefetchCountRoutesQuery = async <
  TData = Awaited<ReturnType<typeof countRoutes>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: CountRoutesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countRoutes>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getCountRoutesQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Mapbox vector tile holding the team's routes, layer 'routes'. Accepts the same filters as the route list, minus sorting and pagination, which a tile has no use for. Fetched directly by the map renderer, outside the authenticated HTTP stack: a browser authenticates with its session cookie, any other client with the 't' tile token.
 * @summary Team routes vector tile
 */
export const routesTile = (
  teamSlug: string,
  z: number,
  x: number,
  y: number,
  params?: RoutesTileParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>(
    {
      url: `/api/teams/${teamSlug}/routes/tiles/${z}/${x}/${y}.mvt`,
      method: 'GET',
      params,
      signal,
    },
    options
  )
}

export const getRoutesTileQueryKey = (
  teamSlug: string,
  z: number,
  x: number,
  y: number,
  params?: RoutesTileParams
) => {
  return [
    `/api/teams/${teamSlug}/routes/tiles/${z}/${x}/${y}.mvt`,
    ...(params ? [params] : []),
  ] as const
}

export const getRoutesTileQueryOptions = <
  TData = Awaited<ReturnType<typeof routesTile>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  z: number,
  x: number,
  y: number,
  params?: RoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routesTile>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getRoutesTileQueryKey(teamSlug, z, x, y, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof routesTile>>> = ({ signal }) =>
    routesTile(teamSlug, z, x, y, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      z !== null &&
      z !== undefined &&
      x !== null &&
      x !== undefined &&
      y !== null &&
      y !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof routesTile>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type RoutesTileQueryResult = NonNullable<Awaited<ReturnType<typeof routesTile>>>
export type RoutesTileQueryError = ErrorType<void | ErrorResponse>

export function useRoutesTile<
  TData = Awaited<ReturnType<typeof routesTile>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  z: number,
  x: number,
  y: number,
  params: undefined | RoutesTileParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof routesTile>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof routesTile>>,
          TError,
          Awaited<ReturnType<typeof routesTile>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useRoutesTile<
  TData = Awaited<ReturnType<typeof routesTile>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  z: number,
  x: number,
  y: number,
  params?: RoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routesTile>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof routesTile>>,
          TError,
          Awaited<ReturnType<typeof routesTile>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useRoutesTile<
  TData = Awaited<ReturnType<typeof routesTile>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  z: number,
  x: number,
  y: number,
  params?: RoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routesTile>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Team routes vector tile
 */

export function useRoutesTile<
  TData = Awaited<ReturnType<typeof routesTile>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  z: number,
  x: number,
  y: number,
  params?: RoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routesTile>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getRoutesTileQueryOptions(teamSlug, z, x, y, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Team routes vector tile
 */
export const prefetchRoutesTileQuery = async <
  TData = Awaited<ReturnType<typeof routesTile>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  z: number,
  x: number,
  y: number,
  params?: RoutesTileParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routesTile>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getRoutesTileQueryOptions(teamSlug, z, x, y, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Update route metadata (name, markdown, etc.) and optionally replace the GPX file. If a new GPX file is provided, the old track data and climbs will be replaced.
 * @summary Update route
 */
export const updateRoute = (
  teamSlug: string,
  routeSlug: string,
  updateRouteBody: BodyType<UpdateRouteBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (updateRouteBody.route !== undefined) {
    formData.append(`route`, JSON.stringify(updateRouteBody.route))
  }
  if (updateRouteBody.gpxFile !== undefined) {
    formData.append(`gpxFile`, updateRouteBody.gpxFile)
  }

  return axiosMutator<RouteDto>(
    {
      url: `/api/teams/${teamSlug}/routes/${routeSlug}`,
      method: 'PUT',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      signal,
    },
    options
  )
}

export const getUpdateRouteMutationKey = () => ['updateRoute'] as const

export const getUpdateRouteMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateRoute>>,
    TError,
    UpdateRouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateRoute>>,
  TError,
  UpdateRouteMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateRoute>>,
    UpdateRouteMutationVariables
  > = (props) => {
    const { teamSlug, routeSlug, data } = props ?? {}

    return updateRoute(teamSlug, routeSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateRouteMutationResult = NonNullable<Awaited<ReturnType<typeof updateRoute>>>
export type UpdateRouteMutationBody = BodyType<UpdateRouteBody>
export type UpdateRouteMutationError = ErrorType<ErrorResponse>
export type UpdateRouteMutationVariables = {
  teamSlug: string
  routeSlug: string
  data: BodyType<UpdateRouteBody>
}

/**
 * @summary Update route
 */
export const useUpdateRoute = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateRoute>>,
      TError,
      UpdateRouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateRoute>>,
  TError,
  UpdateRouteMutationVariables,
  TContext
> => {
  return useMutation(getUpdateRouteMutationOptions(options), queryClient)
}
/**
 * Get detailed route information including GPS coordinates and statistics. The track is returned exactly as stored — already resampled and Douglas-Peucker-filtered at import, which lands it at roughly one point every 90 m. Every coordinate carries longitude, latitude, elevation and cumulative distance in meters, so a client can draw both the line and its elevation profile from this one payload.
 * @summary Get route details
 */
export const getRoute = (
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteDetailDto>(
    { url: `/api/teams/${teamSlug}/routes/${routeSlug}`, method: 'GET', signal },
    options
  )
}

export const getGetRouteQueryKey = (teamSlug: string, routeSlug: string) => {
  return [`/api/teams/${teamSlug}/routes/${routeSlug}`] as const
}

export const getGetRouteQueryOptions = <
  TData = Awaited<ReturnType<typeof getRoute>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoute>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRouteQueryKey(teamSlug, routeSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRoute>>> = ({ signal }) =>
    getRoute(teamSlug, routeSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && routeSlug !== null && routeSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRoute>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRouteQueryResult = NonNullable<Awaited<ReturnType<typeof getRoute>>>
export type GetRouteQueryError = ErrorType<ErrorResponse>

export function useGetRoute<
  TData = Awaited<ReturnType<typeof getRoute>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoute>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRoute>>,
          TError,
          Awaited<ReturnType<typeof getRoute>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRoute<
  TData = Awaited<ReturnType<typeof getRoute>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoute>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRoute>>,
          TError,
          Awaited<ReturnType<typeof getRoute>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRoute<
  TData = Awaited<ReturnType<typeof getRoute>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoute>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get route details
 */

export function useGetRoute<
  TData = Awaited<ReturnType<typeof getRoute>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoute>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRouteQueryOptions(teamSlug, routeSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get route details
 */
export const prefetchGetRouteQuery = async <
  TData = Awaited<ReturnType<typeof getRoute>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRoute>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRouteQueryOptions(teamSlug, routeSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Soft delete a route. Requires route creator or team admin permissions.
 * @summary Delete route
 */
export const deleteRoute = (
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/routes/${routeSlug}`, method: 'DELETE', signal },
    options
  )
}

export const getDeleteRouteMutationKey = () => ['deleteRoute'] as const

export const getDeleteRouteMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteRoute>>,
    TError,
    DeleteRouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteRoute>>,
  TError,
  DeleteRouteMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteRoute>>,
    DeleteRouteMutationVariables
  > = (props) => {
    const { teamSlug, routeSlug } = props ?? {}

    return deleteRoute(teamSlug, routeSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteRouteMutationResult = NonNullable<Awaited<ReturnType<typeof deleteRoute>>>

export type DeleteRouteMutationError = ErrorType<ErrorResponse>
export type DeleteRouteMutationVariables = { teamSlug: string; routeSlug: string }

/**
 * @summary Delete route
 */
export const useDeleteRoute = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteRoute>>,
      TError,
      DeleteRouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteRoute>>,
  TError,
  DeleteRouteMutationVariables,
  TContext
> => {
  return useMutation(getDeleteRouteMutationOptions(options), queryClient)
}
/**
 * The control points, routed pieces and imported ranges the route was last saved with, for its edit page. Reserved to those who may edit the route. 'state' is absent when there is none to read back (never saved with one, track replaced since by a path that does not carry it, several tracks): the editor then opens the saved track as an import.
 * @summary Get the planner state of a route
 */
export const getRoutePlannerState = (
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PlannerStateResponse>(
    { url: `/api/teams/${teamSlug}/routes/${routeSlug}/planner-state`, method: 'GET', signal },
    options
  )
}

export const getGetRoutePlannerStateQueryKey = (teamSlug: string, routeSlug: string) => {
  return [`/api/teams/${teamSlug}/routes/${routeSlug}/planner-state`] as const
}

export const getGetRoutePlannerStateQueryOptions = <
  TData = Awaited<ReturnType<typeof getRoutePlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRoutePlannerState>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRoutePlannerStateQueryKey(teamSlug, routeSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRoutePlannerState>>> = ({ signal }) =>
    getRoutePlannerState(teamSlug, routeSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && routeSlug !== null && routeSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRoutePlannerState>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRoutePlannerStateQueryResult = NonNullable<
  Awaited<ReturnType<typeof getRoutePlannerState>>
>
export type GetRoutePlannerStateQueryError = ErrorType<ErrorResponse>

export function useGetRoutePlannerState<
  TData = Awaited<ReturnType<typeof getRoutePlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRoutePlannerState>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRoutePlannerState>>,
          TError,
          Awaited<ReturnType<typeof getRoutePlannerState>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRoutePlannerState<
  TData = Awaited<ReturnType<typeof getRoutePlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRoutePlannerState>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRoutePlannerState>>,
          TError,
          Awaited<ReturnType<typeof getRoutePlannerState>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRoutePlannerState<
  TData = Awaited<ReturnType<typeof getRoutePlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRoutePlannerState>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get the planner state of a route
 */

export function useGetRoutePlannerState<
  TData = Awaited<ReturnType<typeof getRoutePlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRoutePlannerState>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRoutePlannerStateQueryOptions(teamSlug, routeSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get the planner state of a route
 */
export const prefetchGetRoutePlannerStateQuery = async <
  TData = Awaited<ReturnType<typeof getRoutePlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRoutePlannerState>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRoutePlannerStateQueryOptions(teamSlug, routeSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Change route URL slug. Requires organizer permissions.
 * @summary Change route slug
 */
export const changeRouteSlug = (
  teamSlug: string,
  routeSlug: string,
  slugChangeRequest: BodyType<SlugChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteDetailDto>(
    {
      url: `/api/teams/${teamSlug}/routes/${routeSlug}/slug`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: slugChangeRequest,
      signal,
    },
    options
  )
}

export const getChangeRouteSlugMutationKey = () => ['changeRouteSlug'] as const

export const getChangeRouteSlugMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changeRouteSlug>>,
    TError,
    ChangeRouteSlugMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changeRouteSlug>>,
  TError,
  ChangeRouteSlugMutationVariables,
  TContext
> => {
  const mutationKey = getChangeRouteSlugMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changeRouteSlug>>,
    ChangeRouteSlugMutationVariables
  > = (props) => {
    const { teamSlug, routeSlug, data } = props ?? {}

    return changeRouteSlug(teamSlug, routeSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangeRouteSlugMutationResult = NonNullable<Awaited<ReturnType<typeof changeRouteSlug>>>
export type ChangeRouteSlugMutationBody = BodyType<SlugChangeRequest>
export type ChangeRouteSlugMutationError = ErrorType<ErrorResponse>
export type ChangeRouteSlugMutationVariables = {
  teamSlug: string
  routeSlug: string
  data: BodyType<SlugChangeRequest>
}

/**
 * @summary Change route slug
 */
export const useChangeRouteSlug = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changeRouteSlug>>,
      TError,
      ChangeRouteSlugMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changeRouteSlug>>,
  TError,
  ChangeRouteSlugMutationVariables,
  TContext
> => {
  return useMutation(getChangeRouteSlugMutationOptions(options), queryClient)
}
/**
 * Restore a soft-deleted route. Requires route creator or team admin permissions.
 * @summary Restore route
 */
export const undeleteRoute = (
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteDetailDto>(
    { url: `/api/teams/${teamSlug}/routes/${routeSlug}/undelete`, method: 'POST', signal },
    options
  )
}

export const getUndeleteRouteMutationKey = () => ['undeleteRoute'] as const

export const getUndeleteRouteMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof undeleteRoute>>,
    TError,
    UndeleteRouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof undeleteRoute>>,
  TError,
  UndeleteRouteMutationVariables,
  TContext
> => {
  const mutationKey = getUndeleteRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof undeleteRoute>>,
    UndeleteRouteMutationVariables
  > = (props) => {
    const { teamSlug, routeSlug } = props ?? {}

    return undeleteRoute(teamSlug, routeSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UndeleteRouteMutationResult = NonNullable<Awaited<ReturnType<typeof undeleteRoute>>>

export type UndeleteRouteMutationError = ErrorType<ErrorResponse>
export type UndeleteRouteMutationVariables = { teamSlug: string; routeSlug: string }

/**
 * @summary Restore route
 */
export const useUndeleteRoute = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof undeleteRoute>>,
      TError,
      UndeleteRouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof undeleteRoute>>,
  TError,
  UndeleteRouteMutationVariables,
  TContext
> => {
  return useMutation(getUndeleteRouteMutationOptions(options), queryClient)
}
/**
 * Rides and trips that reference this route, directly or via a group/stage. Results are visibility filtered for the caller.
 * @summary List route usages
 */
export const getRouteUsages = (
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteUsagesResponse>(
    { url: `/api/teams/${teamSlug}/routes/${routeSlug}/usages`, method: 'GET', signal },
    options
  )
}

export const getGetRouteUsagesQueryKey = (teamSlug: string, routeSlug: string) => {
  return [`/api/teams/${teamSlug}/routes/${routeSlug}/usages`] as const
}

export const getGetRouteUsagesQueryOptions = <
  TData = Awaited<ReturnType<typeof getRouteUsages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRouteUsages>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRouteUsagesQueryKey(teamSlug, routeSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRouteUsages>>> = ({ signal }) =>
    getRouteUsages(teamSlug, routeSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && routeSlug !== null && routeSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRouteUsages>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRouteUsagesQueryResult = NonNullable<Awaited<ReturnType<typeof getRouteUsages>>>
export type GetRouteUsagesQueryError = ErrorType<ErrorResponse>

export function useGetRouteUsages<
  TData = Awaited<ReturnType<typeof getRouteUsages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRouteUsages>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRouteUsages>>,
          TError,
          Awaited<ReturnType<typeof getRouteUsages>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRouteUsages<
  TData = Awaited<ReturnType<typeof getRouteUsages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRouteUsages>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRouteUsages>>,
          TError,
          Awaited<ReturnType<typeof getRouteUsages>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRouteUsages<
  TData = Awaited<ReturnType<typeof getRouteUsages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRouteUsages>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary List route usages
 */

export function useGetRouteUsages<
  TData = Awaited<ReturnType<typeof getRouteUsages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRouteUsages>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRouteUsagesQueryOptions(teamSlug, routeSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary List route usages
 */
export const prefetchGetRouteUsagesQuery = async <
  TData = Awaited<ReturnType<typeof getRouteUsages>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRouteUsages>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRouteUsagesQueryOptions(teamSlug, routeSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
