import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type { ErrorResponse, RouterRequest, RouterResponse } from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * Calculate a route between two points using the Stadia Maps routing API
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
