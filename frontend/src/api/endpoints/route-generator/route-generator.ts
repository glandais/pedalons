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
  RouteGeneratorRequest,
  RouteGeneratorResponse,
  RouteRetouchOfferDto,
  RouteRetouchRequest,
  RouteRetouchResponse,
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
 * Proposes one to three routes, loops or one-way, from the roads a route of the team already rides (prepared every night for the generator) and the rest of the map: the cursor `discovery` goes from the team's roads only (0) to no preference (1), default 0.25. The engine is osm-route-details and covers one region for now (GENERATOR_OUT_OF_COVERAGE elsewhere); each route was checked by an independent checker of the engine and by a geometric sanity check here. Ascent and descent are computed from the fast elevation profile and are absent when it was not ready in time. Same rights as the route planner: the caller must be allowed to create routes in the team and the team must have its route planner on (ROUTE_PLANNER_DISABLED otherwise). Nothing is stored, no routing provider is called and no quota is drawn. Failures have their own codes, all 400: GENERATOR_START_TOO_FAR and GENERATOR_END_TOO_FAR (no suitable road near), GENERATOR_DISTANCE_TOO_SHORT, GENERATOR_NETWORK_TOO_SMALL, GENERATOR_OUT_OF_COVERAGE, GENERATOR_NETWORK_NOT_READY (the team's roads are not prepared yet; discovery needs no preparation) and GENERATOR_NO_ROUTE. At most 30 requests per user in 15 minutes (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503) when the engine has no free slot or took too long, GENERATOR_UNAVAILABLE (503) when it is off or unreachable.
 * @summary Propose routes that favour the team's own roads
 */
export const generateRoutes = (
  teamSlug: string,
  routeGeneratorRequest: BodyType<RouteGeneratorRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteGeneratorResponse>(
    {
      url: `/api/teams/${teamSlug}/route-generator`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: routeGeneratorRequest,
      signal,
    },
    options
  )
}

export const getGenerateRoutesMutationKey = () => ['generateRoutes'] as const

export const getGenerateRoutesMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof generateRoutes>>,
    TError,
    GenerateRoutesMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof generateRoutes>>,
  TError,
  GenerateRoutesMutationVariables,
  TContext
> => {
  const mutationKey = getGenerateRoutesMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof generateRoutes>>,
    GenerateRoutesMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return generateRoutes(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type GenerateRoutesMutationResult = NonNullable<Awaited<ReturnType<typeof generateRoutes>>>
export type GenerateRoutesMutationBody = BodyType<RouteGeneratorRequest>
export type GenerateRoutesMutationError = ErrorType<ErrorResponse>
export type GenerateRoutesMutationVariables = {
  teamSlug: string
  data: BodyType<RouteGeneratorRequest>
}

/**
 * Proposes one to three routes, loops or one-way, from the roads a route of the team already rides (prepared every night for the generator) and the rest of the map: the cursor `discovery` goes from the team's roads only (0) to no preference (1), default 0.25. The engine is osm-route-details and covers one region for now (GENERATOR_OUT_OF_COVERAGE elsewhere); each route was checked by an independent checker of the engine and by a geometric sanity check here. Ascent and descent are computed from the fast elevation profile and are absent when it was not ready in time. Same rights as the route planner: the caller must be allowed to create routes in the team and the team must have its route planner on (ROUTE_PLANNER_DISABLED otherwise). Nothing is stored, no routing provider is called and no quota is drawn. Failures have their own codes, all 400: GENERATOR_START_TOO_FAR and GENERATOR_END_TOO_FAR (no suitable road near), GENERATOR_DISTANCE_TOO_SHORT, GENERATOR_NETWORK_TOO_SMALL, GENERATOR_OUT_OF_COVERAGE, GENERATOR_NETWORK_NOT_READY (the team's roads are not prepared yet; discovery needs no preparation) and GENERATOR_NO_ROUTE. At most 30 requests per user in 15 minutes (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503) when the engine has no free slot or took too long, GENERATOR_UNAVAILABLE (503) when it is off or unreachable.
 * @summary Propose routes that favour the team's own roads
 */
export const useGenerateRoutes = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof generateRoutes>>,
      TError,
      GenerateRoutesMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof generateRoutes>>,
  TError,
  GenerateRoutesMutationVariables,
  TContext
> => {
  return useMutation(getGenerateRoutesMutationOptions(options), queryClient)
}
/**
 * Proposes one to three routes that change ONE stretch of the saved route and keep the rest as it was drawn, by asking the route generator's engine (osm-route-details): `targetDistanceKm` aims at a total distance (within the offer's bounds, 30 percent of the route at most), `end` moves the finish (a point, or a place of the team); exactly one of the two. Each proposal carries the whole polyline and the indices of the stretch that changed. Ascent and descent come from the same profile for the original (`originalAscentM`) and the proposals. Nothing is stored, no quota is drawn: the proposal is opened in the planner as a new route. Same rights as the route planner plus reading the route; the route's street edges must be computed for its current track (ROUTE_RETOUCH_NOT_READY otherwise: nothing is computed on the fly). Refusals are answers, all 400: ROUTE_RETOUCH_NO_SHORTER (shortening fails about four times in ten, a normal case), ROUTE_RETOUCH_NO_PROPOSAL, ROUTE_RETOUCH_ORDER_ANOMALY (about one track in twenty), ROUTE_RETOUCH_CHANGE_TOO_SMALL, ROUTE_RETOUCH_CHANGE_TOO_LARGE, ROUTE_RETOUCH_END_UNREACHABLE, ROUTE_RETOUCH_UNSUPPORTED, ROUTE_RETOUCH_NOT_READY, GENERATOR_END_TOO_FAR, GENERATOR_OUT_OF_COVERAGE. The 30 requests per 15 minutes of the route generator are shared (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503), GENERATOR_UNAVAILABLE (503, also when the engine does not announce route edits: nothing is sent to it).
 * @summary Propose changes to a saved route: a total distance, or a new finish
 */
export const retouchRoute = (
  teamSlug: string,
  routeSlug: string,
  routeRetouchRequest: BodyType<RouteRetouchRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteRetouchResponse>(
    {
      url: `/api/teams/${teamSlug}/routes/${routeSlug}/retouch`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: routeRetouchRequest,
      signal,
    },
    options
  )
}

export const getRetouchRouteMutationKey = () => ['retouchRoute'] as const

export const getRetouchRouteMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof retouchRoute>>,
    TError,
    RetouchRouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof retouchRoute>>,
  TError,
  RetouchRouteMutationVariables,
  TContext
> => {
  const mutationKey = getRetouchRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof retouchRoute>>,
    RetouchRouteMutationVariables
  > = (props) => {
    const { teamSlug, routeSlug, data } = props ?? {}

    return retouchRoute(teamSlug, routeSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RetouchRouteMutationResult = NonNullable<Awaited<ReturnType<typeof retouchRoute>>>
export type RetouchRouteMutationBody = BodyType<RouteRetouchRequest>
export type RetouchRouteMutationError = ErrorType<ErrorResponse>
export type RetouchRouteMutationVariables = {
  teamSlug: string
  routeSlug: string
  data: BodyType<RouteRetouchRequest>
}

/**
 * Proposes one to three routes that change ONE stretch of the saved route and keep the rest as it was drawn, by asking the route generator's engine (osm-route-details): `targetDistanceKm` aims at a total distance (within the offer's bounds, 30 percent of the route at most), `end` moves the finish (a point, or a place of the team); exactly one of the two. Each proposal carries the whole polyline and the indices of the stretch that changed. Ascent and descent come from the same profile for the original (`originalAscentM`) and the proposals. Nothing is stored, no quota is drawn: the proposal is opened in the planner as a new route. Same rights as the route planner plus reading the route; the route's street edges must be computed for its current track (ROUTE_RETOUCH_NOT_READY otherwise: nothing is computed on the fly). Refusals are answers, all 400: ROUTE_RETOUCH_NO_SHORTER (shortening fails about four times in ten, a normal case), ROUTE_RETOUCH_NO_PROPOSAL, ROUTE_RETOUCH_ORDER_ANOMALY (about one track in twenty), ROUTE_RETOUCH_CHANGE_TOO_SMALL, ROUTE_RETOUCH_CHANGE_TOO_LARGE, ROUTE_RETOUCH_END_UNREACHABLE, ROUTE_RETOUCH_UNSUPPORTED, ROUTE_RETOUCH_NOT_READY, GENERATOR_END_TOO_FAR, GENERATOR_OUT_OF_COVERAGE. The 30 requests per 15 minutes of the route generator are shared (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503), GENERATOR_UNAVAILABLE (503, also when the engine does not announce route edits: nothing is sent to it).
 * @summary Propose changes to a saved route: a total distance, or a new finish
 */
export const useRetouchRoute = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof retouchRoute>>,
      TError,
      RetouchRouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof retouchRoute>>,
  TError,
  RetouchRouteMutationVariables,
  TContext
> => {
  return useMutation(getRetouchRouteMutationOptions(options), queryClient)
}
/**
 * Answers 200 whatever the outcome: `available` and, when not, `unavailableReason` (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the route's analysis is not finished, show the action disabled). The offer comes from the engine's capabilities (a generator engine that cannot edit offers nothing) and from the head of the route's stored documents: nothing is computed, the engine is not called and no request is counted. The route must be readable by the caller (404 otherwise).
 * @summary Whether a route can be retouched by the caller, and within which bounds
 */
export const getRouteRetouchOffer = (
  teamSlug: string,
  routeSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteRetouchOfferDto>(
    { url: `/api/teams/${teamSlug}/routes/${routeSlug}/retouch`, method: 'GET', signal },
    options
  )
}

export const getGetRouteRetouchOfferQueryKey = (teamSlug: string, routeSlug: string) => {
  return [`/api/teams/${teamSlug}/routes/${routeSlug}/retouch`] as const
}

export const getGetRouteRetouchOfferQueryOptions = <
  TData = Awaited<ReturnType<typeof getRouteRetouchOffer>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRouteRetouchOffer>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRouteRetouchOfferQueryKey(teamSlug, routeSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRouteRetouchOffer>>> = ({ signal }) =>
    getRouteRetouchOffer(teamSlug, routeSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && routeSlug !== null && routeSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRouteRetouchOffer>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRouteRetouchOfferQueryResult = NonNullable<
  Awaited<ReturnType<typeof getRouteRetouchOffer>>
>
export type GetRouteRetouchOfferQueryError = ErrorType<ErrorResponse | void>

/**
 * Answers 200 whatever the outcome: `available` and, when not, `unavailableReason` (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the route's analysis is not finished, show the action disabled). The offer comes from the engine's capabilities (a generator engine that cannot edit offers nothing) and from the head of the route's stored documents: nothing is computed, the engine is not called and no request is counted. The route must be readable by the caller (404 otherwise).
 * @summary Whether a route can be retouched by the caller, and within which bounds
 */
export function useGetRouteRetouchOffer<
  TData = Awaited<ReturnType<typeof getRouteRetouchOffer>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  teamSlug: string,
  routeSlug: string,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRouteRetouchOffer>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRouteRetouchOffer>>,
          TError,
          Awaited<ReturnType<typeof getRouteRetouchOffer>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Answers 200 whatever the outcome: `available` and, when not, `unavailableReason` (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the route's analysis is not finished, show the action disabled). The offer comes from the engine's capabilities (a generator engine that cannot edit offers nothing) and from the head of the route's stored documents: nothing is computed, the engine is not called and no request is counted. The route must be readable by the caller (404 otherwise).
 * @summary Whether a route can be retouched by the caller, and within which bounds
 */
export function useGetRouteRetouchOffer<
  TData = Awaited<ReturnType<typeof getRouteRetouchOffer>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRouteRetouchOffer>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRouteRetouchOffer>>,
          TError,
          Awaited<ReturnType<typeof getRouteRetouchOffer>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Answers 200 whatever the outcome: `available` and, when not, `unavailableReason` (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the route's analysis is not finished, show the action disabled). The offer comes from the engine's capabilities (a generator engine that cannot edit offers nothing) and from the head of the route's stored documents: nothing is computed, the engine is not called and no request is counted. The route must be readable by the caller (404 otherwise).
 * @summary Whether a route can be retouched by the caller, and within which bounds
 */
export function useGetRouteRetouchOffer<
  TData = Awaited<ReturnType<typeof getRouteRetouchOffer>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRouteRetouchOffer>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Answers 200 whatever the outcome: `available` and, when not, `unavailableReason` (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the route's analysis is not finished, show the action disabled). The offer comes from the engine's capabilities (a generator engine that cannot edit offers nothing) and from the head of the route's stored documents: nothing is computed, the engine is not called and no request is counted. The route must be readable by the caller (404 otherwise).
 * @summary Whether a route can be retouched by the caller, and within which bounds
 */
export function useGetRouteRetouchOffer<
  TData = Awaited<ReturnType<typeof getRouteRetouchOffer>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRouteRetouchOffer>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRouteRetouchOfferQueryOptions(teamSlug, routeSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Answers 200 whatever the outcome: `available` and, when not, `unavailableReason` (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the route's analysis is not finished, show the action disabled). The offer comes from the engine's capabilities (a generator engine that cannot edit offers nothing) and from the head of the route's stored documents: nothing is computed, the engine is not called and no request is counted. The route must be readable by the caller (404 otherwise).
 * @summary Whether a route can be retouched by the caller, and within which bounds
 */
export const prefetchGetRouteRetouchOfferQuery = async <
  TData = Awaited<ReturnType<typeof getRouteRetouchOffer>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRouteRetouchOffer>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRouteRetouchOfferQueryOptions(teamSlug, routeSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
