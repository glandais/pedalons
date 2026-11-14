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
 * Proposes one to three routes, loops or one-way, whose every metre lies on a road that a route of the team already rides. Same rights as the route planner: the caller must be allowed to create routes in the team and the team must have its route planner on (ROUTE_PLANNER_DISABLED otherwise). Nothing is stored, no routing provider is called and no quota is drawn. Failures have their own codes, all 400: GENERATOR_START_TOO_FAR and GENERATOR_END_TOO_FAR (no road of the team within 2 km), GENERATOR_DISTANCE_TOO_SHORT, GENERATOR_NETWORK_TOO_SMALL (with RouteGeneratorNetworkDetails: also sent while the team's routes are still being analysed), GENERATOR_NETWORK_TOO_LARGE (the team's routes are more than the generator can hold in memory; no request succeeds until the limit is raised) and GENERATOR_NO_ROUTE. At most 30 requests per user in 15 minutes (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503) when the server has no free slot or the run took too long.
 * @summary Propose routes made of the team's own roads
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
 * @summary Propose routes made of the team's own roads
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
