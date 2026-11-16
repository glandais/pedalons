import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type { ErrorResponse, RouteGeneratorRequest, RouteGeneratorResponse } from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

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
