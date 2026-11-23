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
  GpxImportResponse,
  ImportGpxBody,
  LineElevationRequest,
  LineElevationResponse,
  RouterEnginesParams,
  RouterEnginesResponse,
  RouterRequest,
  RouterResponse,
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
 * Calculate a route between two points using the Stadia Maps routing API, or, with engine PEDALONS on a bicycle profile, the engine of osm-route-details, which falls back silently on Stadia Maps when it cannot answer. Each call is billed against a monthly quota, so the checks come first: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Otherwise ROUTE_PLANNER_DISABLED. Once the planner quota the save would draw on is spent — the team's with teamSlug, the caller's own without — the calculation is refused with PLANNER_QUOTA_REACHED (403); past the caller's calculations of the UTC day, whatever the plan, with ROUTING_DAILY_LIMIT_REACHED (429, Retry-After). Routing failures have their own codes: ROUTING_SEGMENT_TOO_LONG and ROUTING_NO_ROUTE (400), ROUTING_QUOTA_EXCEEDED and ROUTING_UNAVAILABLE (503).
 * @summary Calculate route
 */
export const route = (
  routerRequest: BodyType<RouterRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouterResponse>(
    {
      url: `/api/router`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: routerRequest,
      signal,
    },
    options
  )
}

export const getRouteMutationKey = () => ['route'] as const

export const getRouteMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof route>>,
    TError,
    RouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof route>>,
  TError,
  RouteMutationVariables,
  TContext
> => {
  const mutationKey = getRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof route>>, RouteMutationVariables> = (
    props
  ) => {
    const { data } = props ?? {}

    return route(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RouteMutationResult = NonNullable<Awaited<ReturnType<typeof route>>>
export type RouteMutationBody = BodyType<RouterRequest>
export type RouteMutationError = ErrorType<ErrorResponse | void>
export type RouteMutationVariables = { data: BodyType<RouterRequest> }

/**
 * Calculate a route between two points using the Stadia Maps routing API, or, with engine PEDALONS on a bicycle profile, the engine of osm-route-details, which falls back silently on Stadia Maps when it cannot answer. Each call is billed against a monthly quota, so the checks come first: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Otherwise ROUTE_PLANNER_DISABLED. Once the planner quota the save would draw on is spent — the team's with teamSlug, the caller's own without — the calculation is refused with PLANNER_QUOTA_REACHED (403); past the caller's calculations of the UTC day, whatever the plan, with ROUTING_DAILY_LIMIT_REACHED (429, Retry-After). Routing failures have their own codes: ROUTING_SEGMENT_TOO_LONG and ROUTING_NO_ROUTE (400), ROUTING_QUOTA_EXCEEDED and ROUTING_UNAVAILABLE (503).
 * @summary Calculate route
 */
export const useRoute = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof route>>,
      TError,
      RouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof route>>,
  TError,
  RouteMutationVariables,
  TContext
> => {
  return useMutation(getRouteMutationOptions(options), queryClient)
}
/**
 * Processes each straight line with the FAST elevations, as a routed leg, and returns its densified track with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
 * @summary Read the relief of straight lines
 */
export const lineElevation = (
  lineElevationRequest: BodyType<LineElevationRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<LineElevationResponse>(
    {
      url: `/api/router/elevation`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: lineElevationRequest,
      signal,
    },
    options
  )
}

export const getLineElevationMutationKey = () => ['lineElevation'] as const

export const getLineElevationMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof lineElevation>>,
    TError,
    LineElevationMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof lineElevation>>,
  TError,
  LineElevationMutationVariables,
  TContext
> => {
  const mutationKey = getLineElevationMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof lineElevation>>,
    LineElevationMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return lineElevation(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type LineElevationMutationResult = NonNullable<Awaited<ReturnType<typeof lineElevation>>>
export type LineElevationMutationBody = BodyType<LineElevationRequest>
export type LineElevationMutationError = ErrorType<ErrorResponse>
export type LineElevationMutationVariables = { data: BodyType<LineElevationRequest> }

/**
 * Processes each straight line with the FAST elevations, as a routed leg, and returns its densified track with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
 * @summary Read the relief of straight lines
 */
export const useLineElevation = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof lineElevation>>,
      TError,
      LineElevationMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof lineElevation>>,
  TError,
  LineElevationMutationVariables,
  TContext
> => {
  return useMutation(getLineElevationMutationOptions(options), queryClient)
}
/**
 * The engines the planner can ask for a leg and the profiles each calculates. STADIA is always there with every profile; PEDALONS (BIKE, FASTBIKE, GRAVEL and MTB) only when the service behind it is configured and announces itself ready, read on its cached capabilities. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Calls no engine and counts for nothing in the daily calculations.
 * @summary List the routing engines on offer
 */
export const routerEngines = (
  params?: RouterEnginesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouterEnginesResponse>(
    { url: `/api/router/engines`, method: 'GET', params, signal },
    options
  )
}

export const getRouterEnginesQueryKey = (params?: RouterEnginesParams) => {
  return [`/api/router/engines`, ...(params ? [params] : [])] as const
}

export const getRouterEnginesQueryOptions = <
  TData = Awaited<ReturnType<typeof routerEngines>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: RouterEnginesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routerEngines>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getRouterEnginesQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof routerEngines>>> = ({ signal }) =>
    routerEngines(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof routerEngines>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type RouterEnginesQueryResult = NonNullable<Awaited<ReturnType<typeof routerEngines>>>
export type RouterEnginesQueryError = ErrorType<ErrorResponse>

/**
 * The engines the planner can ask for a leg and the profiles each calculates. STADIA is always there with every profile; PEDALONS (BIKE, FASTBIKE, GRAVEL and MTB) only when the service behind it is configured and announces itself ready, read on its cached capabilities. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Calls no engine and counts for nothing in the daily calculations.
 * @summary List the routing engines on offer
 */
export function useRouterEngines<
  TData = Awaited<ReturnType<typeof routerEngines>>,
  TError = ErrorType<ErrorResponse>,
>(
  params: undefined | RouterEnginesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof routerEngines>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof routerEngines>>,
          TError,
          Awaited<ReturnType<typeof routerEngines>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The engines the planner can ask for a leg and the profiles each calculates. STADIA is always there with every profile; PEDALONS (BIKE, FASTBIKE, GRAVEL and MTB) only when the service behind it is configured and announces itself ready, read on its cached capabilities. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Calls no engine and counts for nothing in the daily calculations.
 * @summary List the routing engines on offer
 */
export function useRouterEngines<
  TData = Awaited<ReturnType<typeof routerEngines>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: RouterEnginesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routerEngines>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof routerEngines>>,
          TError,
          Awaited<ReturnType<typeof routerEngines>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The engines the planner can ask for a leg and the profiles each calculates. STADIA is always there with every profile; PEDALONS (BIKE, FASTBIKE, GRAVEL and MTB) only when the service behind it is configured and announces itself ready, read on its cached capabilities. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Calls no engine and counts for nothing in the daily calculations.
 * @summary List the routing engines on offer
 */
export function useRouterEngines<
  TData = Awaited<ReturnType<typeof routerEngines>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: RouterEnginesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routerEngines>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The engines the planner can ask for a leg and the profiles each calculates. STADIA is always there with every profile; PEDALONS (BIKE, FASTBIKE, GRAVEL and MTB) only when the service behind it is configured and announces itself ready, read on its cached capabilities. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Calls no engine and counts for nothing in the daily calculations.
 * @summary List the routing engines on offer
 */
export function useRouterEngines<
  TData = Awaited<ReturnType<typeof routerEngines>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: RouterEnginesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routerEngines>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getRouterEnginesQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * The engines the planner can ask for a leg and the profiles each calculates. STADIA is always there with every profile; PEDALONS (BIKE, FASTBIKE, GRAVEL and MTB) only when the service behind it is configured and announces itself ready, read on its cached capabilities. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Calls no engine and counts for nothing in the daily calculations.
 * @summary List the routing engines on offer
 */
export const prefetchRouterEnginesQuery = async <
  TData = Awaited<ReturnType<typeof routerEngines>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: RouterEnginesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof routerEngines>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getRouterEnginesQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Processes a GPX file with the FAST elevations and returns its tracks as polylines, with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
 * @summary Load a GPX file into the route editor
 */
export const importGpx = (
  importGpxBody: BodyType<ImportGpxBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (importGpxBody.gpxFile !== undefined) {
    formData.append(`gpxFile`, importGpxBody.gpxFile)
  }
  if (importGpxBody.teamSlug !== undefined) {
    formData.append(`teamSlug`, importGpxBody.teamSlug)
  }

  return axiosMutator<GpxImportResponse>(
    {
      url: `/api/router/import-gpx`,
      method: 'POST',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      signal,
    },
    options
  )
}

export const getImportGpxMutationKey = () => ['importGpx'] as const

export const getImportGpxMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof importGpx>>,
    TError,
    ImportGpxMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof importGpx>>,
  TError,
  ImportGpxMutationVariables,
  TContext
> => {
  const mutationKey = getImportGpxMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof importGpx>>,
    ImportGpxMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return importGpx(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ImportGpxMutationResult = NonNullable<Awaited<ReturnType<typeof importGpx>>>
export type ImportGpxMutationBody = BodyType<ImportGpxBody>
export type ImportGpxMutationError = ErrorType<ErrorResponse>
export type ImportGpxMutationVariables = { data: BodyType<ImportGpxBody> }

/**
 * Processes a GPX file with the FAST elevations and returns its tracks as polylines, with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
 * @summary Load a GPX file into the route editor
 */
export const useImportGpx = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof importGpx>>,
      TError,
      ImportGpxMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof importGpx>>,
  TError,
  ImportGpxMutationVariables,
  TContext
> => {
  return useMutation(getImportGpxMutationOptions(options), queryClient)
}
