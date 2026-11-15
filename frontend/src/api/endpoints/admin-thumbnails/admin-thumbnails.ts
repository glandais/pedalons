import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type {
  AdminRegenerateThumbnailsParams,
  ErrorResponse,
  ThumbnailRegenerationRequest,
  ThumbnailRegenerationResponse,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * Redraw the light and dark map thumbnails of routes, rides and trips from the geometry already stored, selected by drawing date, stored size or absence. Synchronous; run it with dryRun first.
 * @summary Regenerate map thumbnails
 */
export const adminRegenerateThumbnails = (
  thumbnailRegenerationRequest: BodyType<ThumbnailRegenerationRequest>,
  params?: AdminRegenerateThumbnailsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<ThumbnailRegenerationResponse>(
    {
      url: `/api/admin/thumbnails/regenerate`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: thumbnailRegenerationRequest,
      params,
      signal,
    },
    options
  )
}

export const getAdminRegenerateThumbnailsMutationKey = () => ['adminRegenerateThumbnails'] as const

export const getAdminRegenerateThumbnailsMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof adminRegenerateThumbnails>>,
    TError,
    AdminRegenerateThumbnailsMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof adminRegenerateThumbnails>>,
  TError,
  AdminRegenerateThumbnailsMutationVariables,
  TContext
> => {
  const mutationKey = getAdminRegenerateThumbnailsMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof adminRegenerateThumbnails>>,
    AdminRegenerateThumbnailsMutationVariables
  > = (props) => {
    const { data, params } = props ?? {}

    return adminRegenerateThumbnails(data, params, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AdminRegenerateThumbnailsMutationResult = NonNullable<
  Awaited<ReturnType<typeof adminRegenerateThumbnails>>
>
export type AdminRegenerateThumbnailsMutationBody = BodyType<ThumbnailRegenerationRequest>
export type AdminRegenerateThumbnailsMutationError = ErrorType<ErrorResponse | void>
export type AdminRegenerateThumbnailsMutationVariables = {
  data: BodyType<ThumbnailRegenerationRequest>
  params?: AdminRegenerateThumbnailsParams
}

/**
 * Redraw the light and dark map thumbnails of routes, rides and trips from the geometry already stored, selected by drawing date, stored size or absence. Synchronous; run it with dryRun first.
 * @summary Regenerate map thumbnails
 */
export const useAdminRegenerateThumbnails = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof adminRegenerateThumbnails>>,
      TError,
      AdminRegenerateThumbnailsMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof adminRegenerateThumbnails>>,
  TError,
  AdminRegenerateThumbnailsMutationVariables,
  TContext
> => {
  return useMutation(getAdminRegenerateThumbnailsMutationOptions(options), queryClient)
}
