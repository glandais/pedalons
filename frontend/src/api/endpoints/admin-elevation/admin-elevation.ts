import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type {
  AdminRetryElevationRefreshParams,
  ElevationRefreshRetryRequest,
  ElevationRefreshRetryResponse,
  ErrorResponse,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * Start again the HD recomputation of the routes and GPX-tool previews whose request used up its attempts (they stay on the fast profile, state FAST). Their attempts are reset and their due times spread one minute apart, oldest first, so the worker is not flooded; the targets go back to PENDING. Idempotent: a second call finds nothing. Run it with dryRun first.
 * @summary Retry abandoned HD elevation recomputations
 */
export const adminRetryElevationRefresh = (
  elevationRefreshRetryRequest: BodyType<ElevationRefreshRetryRequest>,
  params?: AdminRetryElevationRefreshParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<ElevationRefreshRetryResponse>(
    {
      url: `/api/admin/elevation-refresh/retry`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: elevationRefreshRetryRequest,
      params,
      signal,
    },
    options
  )
}

export const getAdminRetryElevationRefreshMutationKey = () =>
  ['adminRetryElevationRefresh'] as const

export const getAdminRetryElevationRefreshMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof adminRetryElevationRefresh>>,
    TError,
    AdminRetryElevationRefreshMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof adminRetryElevationRefresh>>,
  TError,
  AdminRetryElevationRefreshMutationVariables,
  TContext
> => {
  const mutationKey = getAdminRetryElevationRefreshMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof adminRetryElevationRefresh>>,
    AdminRetryElevationRefreshMutationVariables
  > = (props) => {
    const { data, params } = props ?? {}

    return adminRetryElevationRefresh(data, params, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AdminRetryElevationRefreshMutationResult = NonNullable<
  Awaited<ReturnType<typeof adminRetryElevationRefresh>>
>
export type AdminRetryElevationRefreshMutationBody = BodyType<ElevationRefreshRetryRequest>
export type AdminRetryElevationRefreshMutationError = ErrorType<void | ErrorResponse>
export type AdminRetryElevationRefreshMutationVariables = {
  data: BodyType<ElevationRefreshRetryRequest>
  params?: AdminRetryElevationRefreshParams
}

/**
 * @summary Retry abandoned HD elevation recomputations
 */
export const useAdminRetryElevationRefresh = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof adminRetryElevationRefresh>>,
      TError,
      AdminRetryElevationRefreshMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof adminRetryElevationRefresh>>,
  TError,
  AdminRetryElevationRefreshMutationVariables,
  TContext
> => {
  return useMutation(getAdminRetryElevationRefreshMutationOptions(options), queryClient)
}
