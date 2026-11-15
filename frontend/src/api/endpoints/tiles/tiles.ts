import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type { ErrorResponse, TileTokenDto } from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * Short-lived token authorizing the caller's own vector tile requests, to be passed as the 't' query parameter of the .mvt endpoints. Meant for clients whose map renderer has its own HTTP stack and can carry neither an Authorization header nor a session cookie. It grants nothing but tiles: no other endpoint accepts it.
 * @summary Mint a tile token
 */
export const mint = (options?: SecondParameter<typeof axiosMutator>, signal?: AbortSignal) => {
  return axiosMutator<TileTokenDto>({ url: `/api/tiles/token`, method: 'POST', signal }, options)
}

export const getMintMutationKey = () => ['mint'] as const

export const getMintMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<Awaited<ReturnType<typeof mint>>, TError, void, TContext>
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<Awaited<ReturnType<typeof mint>>, TError, void, TContext> => {
  const mutationKey = getMintMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof mint>>, void> = () => {
    return mint(requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type MintMutationResult = NonNullable<Awaited<ReturnType<typeof mint>>>

export type MintMutationError = ErrorType<ErrorResponse | void>

/**
 * Short-lived token authorizing the caller's own vector tile requests, to be passed as the 't' query parameter of the .mvt endpoints. Meant for clients whose map renderer has its own HTTP stack and can carry neither an Authorization header nor a session cookie. It grants nothing but tiles: no other endpoint accepts it.
 * @summary Mint a tile token
 */
export const useMint = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<Awaited<ReturnType<typeof mint>>, TError, void, TContext>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<Awaited<ReturnType<typeof mint>>, TError, void, TContext> => {
  return useMutation(getMintMutationOptions(options), queryClient)
}
