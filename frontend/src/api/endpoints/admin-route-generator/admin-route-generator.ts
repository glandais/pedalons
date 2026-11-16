import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type {
  ErrorResponse,
  RouteGeneratorOverlayRefreshRequest,
  RouteGeneratorOverlayRefreshResponse,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * The nightly pass, by hand: for each team (or the one given), compares the digest of its tracks with the one the engine holds and deposits it again when it differs, is absent, stale or about to expire (or always with force); deletes the overlay of a deleted team, or one whose planner is off. Idempotent. With dryRun the answer (200) lists what would be done; otherwise the pass runs in the background (202, started=false if one already runs on this instance). Run it with dryRun first; use force after a key rotation or a new graph.
 * @summary Prepare the teams' roads for the route generator now
 */
export const adminRefreshRouteGeneratorOverlays = (
  routeGeneratorOverlayRefreshRequest: BodyType<RouteGeneratorOverlayRefreshRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteGeneratorOverlayRefreshResponse>(
    {
      url: `/api/admin/route-generator/overlays/refresh`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: routeGeneratorOverlayRefreshRequest,
      signal,
    },
    options
  )
}

export const getAdminRefreshRouteGeneratorOverlaysMutationKey = () =>
  ['adminRefreshRouteGeneratorOverlays'] as const

export const getAdminRefreshRouteGeneratorOverlaysMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof adminRefreshRouteGeneratorOverlays>>,
    TError,
    AdminRefreshRouteGeneratorOverlaysMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof adminRefreshRouteGeneratorOverlays>>,
  TError,
  AdminRefreshRouteGeneratorOverlaysMutationVariables,
  TContext
> => {
  const mutationKey = getAdminRefreshRouteGeneratorOverlaysMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof adminRefreshRouteGeneratorOverlays>>,
    AdminRefreshRouteGeneratorOverlaysMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return adminRefreshRouteGeneratorOverlays(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AdminRefreshRouteGeneratorOverlaysMutationResult = NonNullable<
  Awaited<ReturnType<typeof adminRefreshRouteGeneratorOverlays>>
>
export type AdminRefreshRouteGeneratorOverlaysMutationBody =
  BodyType<RouteGeneratorOverlayRefreshRequest>
export type AdminRefreshRouteGeneratorOverlaysMutationError = ErrorType<void | ErrorResponse>
export type AdminRefreshRouteGeneratorOverlaysMutationVariables = {
  data: BodyType<RouteGeneratorOverlayRefreshRequest>
}

/**
 * The nightly pass, by hand: for each team (or the one given), compares the digest of its tracks with the one the engine holds and deposits it again when it differs, is absent, stale or about to expire (or always with force); deletes the overlay of a deleted team, or one whose planner is off. Idempotent. With dryRun the answer (200) lists what would be done; otherwise the pass runs in the background (202, started=false if one already runs on this instance). Run it with dryRun first; use force after a key rotation or a new graph.
 * @summary Prepare the teams' roads for the route generator now
 */
export const useAdminRefreshRouteGeneratorOverlays = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof adminRefreshRouteGeneratorOverlays>>,
      TError,
      AdminRefreshRouteGeneratorOverlaysMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof adminRefreshRouteGeneratorOverlays>>,
  TError,
  AdminRefreshRouteGeneratorOverlaysMutationVariables,
  TContext
> => {
  return useMutation(getAdminRefreshRouteGeneratorOverlaysMutationOptions(options), queryClient)
}
