import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type { AssetDto, ErrorResponse, UploadAssetBody, UploadAssetParams } from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * @summary Create asset
 */
export const uploadAsset = (
  teamSlug: string,
  uploadAssetBody: BodyType<UploadAssetBody>,
  params: UploadAssetParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (uploadAssetBody.file !== undefined) {
    formData.append(`file`, uploadAssetBody.file)
  }

  return axiosMutator<AssetDto>(
    {
      url: `/api/teams/${teamSlug}/assets`,
      method: 'POST',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      params,
      signal,
    },
    options
  )
}

export const getUploadAssetMutationKey = () => ['uploadAsset'] as const

export const getUploadAssetMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof uploadAsset>>,
    TError,
    UploadAssetMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof uploadAsset>>,
  TError,
  UploadAssetMutationVariables,
  TContext
> => {
  const mutationKey = getUploadAssetMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof uploadAsset>>,
    UploadAssetMutationVariables
  > = (props) => {
    const { teamSlug, data, params } = props ?? {}

    return uploadAsset(teamSlug, data, params, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UploadAssetMutationResult = NonNullable<Awaited<ReturnType<typeof uploadAsset>>>
export type UploadAssetMutationBody = BodyType<UploadAssetBody>
export type UploadAssetMutationError = ErrorType<ErrorResponse>
export type UploadAssetMutationVariables = {
  teamSlug: string
  data: BodyType<UploadAssetBody>
  params: UploadAssetParams
}

/** @summary Create asset */
export const useUploadAsset = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof uploadAsset>>,
      TError,
      UploadAssetMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof uploadAsset>>,
  TError,
  UploadAssetMutationVariables,
  TContext
> => {
  return useMutation(getUploadAssetMutationOptions(options), queryClient)
}
