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
  CreatePreviewBody,
  ErrorResponse,
  GpsServiceType,
  GpxPreviewCopyRequest,
  GpxPreviewDto,
  GpxPreviewFromPointsRequest,
  GpxPreviewListResponse,
  ListMyPreviewsParams,
  MergePreviewsBody,
  PlannerStateResponse,
  RideWeatherDto,
  RouteDto,
  RouteRequest,
  RouteUploadResponse,
  UpdatePreviewBody,
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
 * Returns the current user's previews still within the 30-day retention window, most recent first
 * @summary List the current user's analysed GPX files
 */
export const listMyPreviews = (
  params?: ListMyPreviewsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GpxPreviewListResponse>(
    { url: `/api/gpx-previews`, method: 'GET', params, signal },
    options
  )
}

export const getListMyPreviewsQueryKey = (params?: ListMyPreviewsParams) => {
  return [`/api/gpx-previews`, ...(params ? [params] : [])] as const
}

export const getListMyPreviewsQueryOptions = <
  TData = Awaited<ReturnType<typeof listMyPreviews>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: ListMyPreviewsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyPreviews>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListMyPreviewsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listMyPreviews>>> = ({ signal }) =>
    listMyPreviews(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listMyPreviews>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListMyPreviewsQueryResult = NonNullable<Awaited<ReturnType<typeof listMyPreviews>>>
export type ListMyPreviewsQueryError = ErrorType<ErrorResponse | void>

export function useListMyPreviews<
  TData = Awaited<ReturnType<typeof listMyPreviews>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params: undefined | ListMyPreviewsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyPreviews>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listMyPreviews>>,
          TError,
          Awaited<ReturnType<typeof listMyPreviews>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useListMyPreviews<
  TData = Awaited<ReturnType<typeof listMyPreviews>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: ListMyPreviewsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyPreviews>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listMyPreviews>>,
          TError,
          Awaited<ReturnType<typeof listMyPreviews>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useListMyPreviews<
  TData = Awaited<ReturnType<typeof listMyPreviews>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: ListMyPreviewsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyPreviews>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary List the current user's analysed GPX files
 */

export function useListMyPreviews<
  TData = Awaited<ReturnType<typeof listMyPreviews>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: ListMyPreviewsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyPreviews>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListMyPreviewsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary List the current user's analysed GPX files
 */
export const prefetchListMyPreviewsQuery = async <
  TData = Awaited<ReturnType<typeof listMyPreviews>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  params?: ListMyPreviewsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyPreviews>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListMyPreviewsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Uploads a GPX file, runs the elevation and climb pipeline, and stores the result under an unguessable identifier for 30 days
 * @summary Analyse a GPX file
 */
export const createPreview = (
  createPreviewBody: BodyType<CreatePreviewBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (createPreviewBody.gpxFile !== undefined) {
    formData.append(`gpxFile`, createPreviewBody.gpxFile)
  }
  if (createPreviewBody.departure !== undefined) {
    formData.append(`departure`, createPreviewBody.departure)
  }
  if (createPreviewBody.averageSpeed !== undefined) {
    formData.append(`averageSpeed`, createPreviewBody.averageSpeed)
  }

  return axiosMutator<GpxPreviewDto>(
    {
      url: `/api/gpx-previews`,
      method: 'POST',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      signal,
    },
    options
  )
}

export const getCreatePreviewMutationKey = () => ['createPreview'] as const

export const getCreatePreviewMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createPreview>>,
    TError,
    CreatePreviewMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createPreview>>,
  TError,
  CreatePreviewMutationVariables,
  TContext
> => {
  const mutationKey = getCreatePreviewMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createPreview>>,
    CreatePreviewMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return createPreview(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreatePreviewMutationResult = NonNullable<Awaited<ReturnType<typeof createPreview>>>
export type CreatePreviewMutationBody = BodyType<CreatePreviewBody>
export type CreatePreviewMutationError = ErrorType<ErrorResponse | void>
export type CreatePreviewMutationVariables = { data: BodyType<CreatePreviewBody> }

/**
 * @summary Analyse a GPX file
 */
export const useCreatePreview = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createPreview>>,
      TError,
      CreatePreviewMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createPreview>>,
  TError,
  CreatePreviewMutationVariables,
  TContext
> => {
  return useMutation(getCreatePreviewMutationOptions(options), queryClient)
}
/**
 * Builds a preview from a route drawn with the planner (no GPX file; drawn = true), runs the elevation and climb pipeline, and stores the result under an unguessable identifier for 30 days
 * @summary Create an analysed GPX file from planner points
 */
export const createPreviewFromPoints = (
  gpxPreviewFromPointsRequest: BodyType<GpxPreviewFromPointsRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GpxPreviewDto>(
    {
      url: `/api/gpx-previews/from-points`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: gpxPreviewFromPointsRequest,
      signal,
    },
    options
  )
}

export const getCreatePreviewFromPointsMutationKey = () => ['createPreviewFromPoints'] as const

export const getCreatePreviewFromPointsMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createPreviewFromPoints>>,
    TError,
    CreatePreviewFromPointsMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createPreviewFromPoints>>,
  TError,
  CreatePreviewFromPointsMutationVariables,
  TContext
> => {
  const mutationKey = getCreatePreviewFromPointsMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createPreviewFromPoints>>,
    CreatePreviewFromPointsMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return createPreviewFromPoints(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreatePreviewFromPointsMutationResult = NonNullable<
  Awaited<ReturnType<typeof createPreviewFromPoints>>
>
export type CreatePreviewFromPointsMutationBody = BodyType<GpxPreviewFromPointsRequest>
export type CreatePreviewFromPointsMutationError = ErrorType<ErrorResponse>
export type CreatePreviewFromPointsMutationVariables = {
  data: BodyType<GpxPreviewFromPointsRequest>
}

/**
 * @summary Create an analysed GPX file from planner points
 */
export const useCreatePreviewFromPoints = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createPreviewFromPoints>>,
      TError,
      CreatePreviewFromPointsMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createPreviewFromPoints>>,
  TError,
  CreatePreviewFromPointsMutationVariables,
  TContext
> => {
  return useMutation(getCreatePreviewFromPointsMutationOptions(options), queryClient)
}
/**
 * Uploads 2 to 10 GPX files (10 MB together at most) and merges all their tracks into a single track, choosing the order of the tracks and the direction each one is ridden in so that the summed straight-line gaps between them are as short as possible. The result then runs the same pipeline as a single upload and is stored the same way, for 30 days
 * @summary Merge several GPX files into one analysed GPX file
 */
export const mergePreviews = (
  mergePreviewsBody: BodyType<MergePreviewsBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (mergePreviewsBody.gpxFiles !== undefined) {
    mergePreviewsBody.gpxFiles.forEach((value) => formData.append(`gpxFiles`, value))
  }
  if (mergePreviewsBody.departure !== undefined) {
    formData.append(`departure`, mergePreviewsBody.departure)
  }
  if (mergePreviewsBody.averageSpeed !== undefined) {
    formData.append(`averageSpeed`, mergePreviewsBody.averageSpeed)
  }

  return axiosMutator<GpxPreviewDto>(
    {
      url: `/api/gpx-previews/merge`,
      method: 'POST',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      signal,
    },
    options
  )
}

export const getMergePreviewsMutationKey = () => ['mergePreviews'] as const

export const getMergePreviewsMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof mergePreviews>>,
    TError,
    MergePreviewsMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof mergePreviews>>,
  TError,
  MergePreviewsMutationVariables,
  TContext
> => {
  const mutationKey = getMergePreviewsMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof mergePreviews>>,
    MergePreviewsMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return mergePreviews(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type MergePreviewsMutationResult = NonNullable<Awaited<ReturnType<typeof mergePreviews>>>
export type MergePreviewsMutationBody = BodyType<MergePreviewsBody>
export type MergePreviewsMutationError = ErrorType<ErrorResponse | void>
export type MergePreviewsMutationVariables = { data: BodyType<MergePreviewsBody> }

/**
 * @summary Merge several GPX files into one analysed GPX file
 */
export const useMergePreviews = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof mergePreviews>>,
      TError,
      MergePreviewsMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof mergePreviews>>,
  TError,
  MergePreviewsMutationVariables,
  TContext
> => {
  return useMutation(getMergePreviewsMutationOptions(options), queryClient)
}
/**
 * Rename the preview and, when a new GPX file or planner points are provided, replay the pipeline to replace its track. Only the creator may edit.
 * @summary Update an analysed GPX file
 */
export const updatePreview = (
  previewId: string,
  updatePreviewBody: BodyType<UpdatePreviewBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (updatePreviewBody.preview !== undefined) {
    formData.append(`preview`, JSON.stringify(updatePreviewBody.preview))
  }
  if (updatePreviewBody.gpxFile !== undefined) {
    formData.append(`gpxFile`, updatePreviewBody.gpxFile)
  }

  return axiosMutator<GpxPreviewDto>(
    {
      url: `/api/gpx-previews/${previewId}`,
      method: 'PUT',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      signal,
    },
    options
  )
}

export const getUpdatePreviewMutationKey = () => ['updatePreview'] as const

export const getUpdatePreviewMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updatePreview>>,
    TError,
    UpdatePreviewMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updatePreview>>,
  TError,
  UpdatePreviewMutationVariables,
  TContext
> => {
  const mutationKey = getUpdatePreviewMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updatePreview>>,
    UpdatePreviewMutationVariables
  > = (props) => {
    const { previewId, data } = props ?? {}

    return updatePreview(previewId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdatePreviewMutationResult = NonNullable<Awaited<ReturnType<typeof updatePreview>>>
export type UpdatePreviewMutationBody = BodyType<UpdatePreviewBody>
export type UpdatePreviewMutationError = ErrorType<ErrorResponse>
export type UpdatePreviewMutationVariables = {
  previewId: string
  data: BodyType<UpdatePreviewBody>
}

/**
 * @summary Update an analysed GPX file
 */
export const useUpdatePreview = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updatePreview>>,
      TError,
      UpdatePreviewMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updatePreview>>,
  TError,
  UpdatePreviewMutationVariables,
  TContext
> => {
  return useMutation(getUpdatePreviewMutationOptions(options), queryClient)
}
/**
 * Anyone holding the link may read the preview: the unguessable identifier is what grants access. Creating and deleting require an account.
 * @summary Get an analysed GPX file
 */
export const getPreview = (
  previewId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GpxPreviewDto>(
    { url: `/api/gpx-previews/${previewId}`, method: 'GET', signal },
    options
  )
}

export const getGetPreviewQueryKey = (previewId: string) => {
  return [`/api/gpx-previews/${previewId}`] as const
}

export const getGetPreviewQueryOptions = <
  TData = Awaited<ReturnType<typeof getPreview>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreview>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetPreviewQueryKey(previewId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getPreview>>> = ({ signal }) =>
    getPreview(previewId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: previewId !== null && previewId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getPreview>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetPreviewQueryResult = NonNullable<Awaited<ReturnType<typeof getPreview>>>
export type GetPreviewQueryError = ErrorType<ErrorResponse>

export function useGetPreview<
  TData = Awaited<ReturnType<typeof getPreview>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreview>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPreview>>,
          TError,
          Awaited<ReturnType<typeof getPreview>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetPreview<
  TData = Awaited<ReturnType<typeof getPreview>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreview>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPreview>>,
          TError,
          Awaited<ReturnType<typeof getPreview>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetPreview<
  TData = Awaited<ReturnType<typeof getPreview>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreview>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get an analysed GPX file
 */

export function useGetPreview<
  TData = Awaited<ReturnType<typeof getPreview>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreview>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetPreviewQueryOptions(previewId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get an analysed GPX file
 */
export const prefetchGetPreviewQuery = async <
  TData = Awaited<ReturnType<typeof getPreview>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreview>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetPreviewQueryOptions(previewId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Only the creator may delete
 * @summary Delete an analysed GPX file
 */
export const deletePreview = (
  previewId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/gpx-previews/${previewId}`, method: 'DELETE', signal },
    options
  )
}

export const getDeletePreviewMutationKey = () => ['deletePreview'] as const

export const getDeletePreviewMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deletePreview>>,
    TError,
    DeletePreviewMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deletePreview>>,
  TError,
  DeletePreviewMutationVariables,
  TContext
> => {
  const mutationKey = getDeletePreviewMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deletePreview>>,
    DeletePreviewMutationVariables
  > = (props) => {
    const { previewId } = props ?? {}

    return deletePreview(previewId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeletePreviewMutationResult = NonNullable<Awaited<ReturnType<typeof deletePreview>>>

export type DeletePreviewMutationError = ErrorType<ErrorResponse>
export type DeletePreviewMutationVariables = { previewId: string }

/**
 * @summary Delete an analysed GPX file
 */
export const useDeletePreview = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deletePreview>>,
      TError,
      DeletePreviewMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deletePreview>>,
  TError,
  DeletePreviewMutationVariables,
  TContext
> => {
  return useMutation(getDeletePreviewMutationOptions(options), queryClient)
}
/**
 * Creates a new preview owned by the caller from any preview they have the link of, under the given name: same track, surface and waypoints, and the average speed and departure date when still to come. The planner state is private to the creator: only a copy by the creator keeps it. A copy counts no planner save, whatever the personal quota. Kept 30 days from its creation; the source is left as it is.
 * @summary Copy an analysed GPX file
 */
export const copyGpxPreview = (
  previewId: string,
  gpxPreviewCopyRequest: BodyType<GpxPreviewCopyRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<GpxPreviewDto>(
    {
      url: `/api/gpx-previews/${previewId}/copy`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: gpxPreviewCopyRequest,
      signal,
    },
    options
  )
}

export const getCopyGpxPreviewMutationKey = () => ['copyGpxPreview'] as const

export const getCopyGpxPreviewMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof copyGpxPreview>>,
    TError,
    CopyGpxPreviewMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof copyGpxPreview>>,
  TError,
  CopyGpxPreviewMutationVariables,
  TContext
> => {
  const mutationKey = getCopyGpxPreviewMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof copyGpxPreview>>,
    CopyGpxPreviewMutationVariables
  > = (props) => {
    const { previewId, data } = props ?? {}

    return copyGpxPreview(previewId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CopyGpxPreviewMutationResult = NonNullable<Awaited<ReturnType<typeof copyGpxPreview>>>
export type CopyGpxPreviewMutationBody = BodyType<GpxPreviewCopyRequest>
export type CopyGpxPreviewMutationError = ErrorType<ErrorResponse | void>
export type CopyGpxPreviewMutationVariables = {
  previewId: string
  data: BodyType<GpxPreviewCopyRequest>
}

/**
 * @summary Copy an analysed GPX file
 */
export const useCopyGpxPreview = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof copyGpxPreview>>,
      TError,
      CopyGpxPreviewMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof copyGpxPreview>>,
  TError,
  CopyGpxPreviewMutationVariables,
  TContext
> => {
  return useMutation(getCopyGpxPreviewMutationOptions(options), queryClient)
}
/**
 * Whoever holds the preview identifier may download it.
 * @summary Download an analysed GPX file as FIT
 */
export const downloadGpxPreviewFit = (
  previewId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    { url: `/api/gpx-previews/${previewId}/fit`, method: 'GET', responseType: 'blob', signal },
    options
  )
}

export const getDownloadGpxPreviewFitQueryKey = (previewId: string) => {
  return [`/api/gpx-previews/${previewId}/fit`] as const
}

export const getDownloadGpxPreviewFitQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadGpxPreviewFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewFit>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDownloadGpxPreviewFitQueryKey(previewId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadGpxPreviewFit>>> = ({ signal }) =>
    downloadGpxPreviewFit(previewId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: previewId !== null && previewId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewFit>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadGpxPreviewFitQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadGpxPreviewFit>>
>
export type DownloadGpxPreviewFitQueryError = ErrorType<ErrorResponse>

export function useDownloadGpxPreviewFit<
  TData = Awaited<ReturnType<typeof downloadGpxPreviewFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewFit>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadGpxPreviewFit>>,
          TError,
          Awaited<ReturnType<typeof downloadGpxPreviewFit>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadGpxPreviewFit<
  TData = Awaited<ReturnType<typeof downloadGpxPreviewFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewFit>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadGpxPreviewFit>>,
          TError,
          Awaited<ReturnType<typeof downloadGpxPreviewFit>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadGpxPreviewFit<
  TData = Awaited<ReturnType<typeof downloadGpxPreviewFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewFit>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download an analysed GPX file as FIT
 */

export function useDownloadGpxPreviewFit<
  TData = Awaited<ReturnType<typeof downloadGpxPreviewFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewFit>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadGpxPreviewFitQueryOptions(previewId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download an analysed GPX file as FIT
 */
export const prefetchDownloadGpxPreviewFitQuery = async <
  TData = Awaited<ReturnType<typeof downloadGpxPreviewFit>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewFit>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadGpxPreviewFitQueryOptions(previewId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Uploads the preview to the current user's connected Garmin, Hammerhead or Wahoo
 * @summary Send an analysed GPX file to a GPS service
 */
export const uploadToGpsService = (
  previewId: string,
  serviceType: GpsServiceType,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteUploadResponse>(
    { url: `/api/gpx-previews/${previewId}/gps/${serviceType}`, method: 'POST', signal },
    options
  )
}

export const getUploadToGpsServiceMutationKey = () => ['uploadToGpsService'] as const

export const getUploadToGpsServiceMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof uploadToGpsService>>,
    TError,
    UploadToGpsServiceMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof uploadToGpsService>>,
  TError,
  UploadToGpsServiceMutationVariables,
  TContext
> => {
  const mutationKey = getUploadToGpsServiceMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof uploadToGpsService>>,
    UploadToGpsServiceMutationVariables
  > = (props) => {
    const { previewId, serviceType } = props ?? {}

    return uploadToGpsService(previewId, serviceType, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UploadToGpsServiceMutationResult = NonNullable<
  Awaited<ReturnType<typeof uploadToGpsService>>
>

export type UploadToGpsServiceMutationError = ErrorType<ErrorResponse | void>
export type UploadToGpsServiceMutationVariables = { previewId: string; serviceType: GpsServiceType }

/**
 * @summary Send an analysed GPX file to a GPS service
 */
export const useUploadToGpsService = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof uploadToGpsService>>,
      TError,
      UploadToGpsServiceMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof uploadToGpsService>>,
  TError,
  UploadToGpsServiceMutationVariables,
  TContext
> => {
  return useMutation(getUploadToGpsServiceMutationOptions(options), queryClient)
}
/**
 * Whoever holds the preview identifier may download it.
 * @summary Download an analysed GPX file as GPX
 */
export const downloadGpxPreviewGpx = (
  previewId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    { url: `/api/gpx-previews/${previewId}/gpx`, method: 'GET', responseType: 'blob', signal },
    options
  )
}

export const getDownloadGpxPreviewGpxQueryKey = (previewId: string) => {
  return [`/api/gpx-previews/${previewId}/gpx`] as const
}

export const getDownloadGpxPreviewGpxQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadGpxPreviewGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewGpx>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDownloadGpxPreviewGpxQueryKey(previewId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadGpxPreviewGpx>>> = ({ signal }) =>
    downloadGpxPreviewGpx(previewId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: previewId !== null && previewId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewGpx>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadGpxPreviewGpxQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadGpxPreviewGpx>>
>
export type DownloadGpxPreviewGpxQueryError = ErrorType<ErrorResponse>

export function useDownloadGpxPreviewGpx<
  TData = Awaited<ReturnType<typeof downloadGpxPreviewGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewGpx>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadGpxPreviewGpx>>,
          TError,
          Awaited<ReturnType<typeof downloadGpxPreviewGpx>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadGpxPreviewGpx<
  TData = Awaited<ReturnType<typeof downloadGpxPreviewGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewGpx>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadGpxPreviewGpx>>,
          TError,
          Awaited<ReturnType<typeof downloadGpxPreviewGpx>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadGpxPreviewGpx<
  TData = Awaited<ReturnType<typeof downloadGpxPreviewGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewGpx>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download an analysed GPX file as GPX
 */

export function useDownloadGpxPreviewGpx<
  TData = Awaited<ReturnType<typeof downloadGpxPreviewGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewGpx>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadGpxPreviewGpxQueryOptions(previewId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download an analysed GPX file as GPX
 */
export const prefetchDownloadGpxPreviewGpxQuery = async <
  TData = Awaited<ReturnType<typeof downloadGpxPreviewGpx>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadGpxPreviewGpx>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadGpxPreviewGpxQueryOptions(previewId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * The control points, routed pieces and imported ranges the preview was last saved with, for its edit page. Only the creator may read it. 'state' is absent when there is none to read back.
 * @summary Get the planner state of an analysed GPX file
 */
export const getPreviewPlannerState = (
  previewId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PlannerStateResponse>(
    { url: `/api/gpx-previews/${previewId}/planner-state`, method: 'GET', signal },
    options
  )
}

export const getGetPreviewPlannerStateQueryKey = (previewId: string) => {
  return [`/api/gpx-previews/${previewId}/planner-state`] as const
}

export const getGetPreviewPlannerStateQueryOptions = <
  TData = Awaited<ReturnType<typeof getPreviewPlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getPreviewPlannerState>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetPreviewPlannerStateQueryKey(previewId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getPreviewPlannerState>>> = ({ signal }) =>
    getPreviewPlannerState(previewId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: previewId !== null && previewId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getPreviewPlannerState>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetPreviewPlannerStateQueryResult = NonNullable<
  Awaited<ReturnType<typeof getPreviewPlannerState>>
>
export type GetPreviewPlannerStateQueryError = ErrorType<ErrorResponse>

export function useGetPreviewPlannerState<
  TData = Awaited<ReturnType<typeof getPreviewPlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getPreviewPlannerState>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPreviewPlannerState>>,
          TError,
          Awaited<ReturnType<typeof getPreviewPlannerState>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetPreviewPlannerState<
  TData = Awaited<ReturnType<typeof getPreviewPlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getPreviewPlannerState>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPreviewPlannerState>>,
          TError,
          Awaited<ReturnType<typeof getPreviewPlannerState>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetPreviewPlannerState<
  TData = Awaited<ReturnType<typeof getPreviewPlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getPreviewPlannerState>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get the planner state of an analysed GPX file
 */

export function useGetPreviewPlannerState<
  TData = Awaited<ReturnType<typeof getPreviewPlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getPreviewPlannerState>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetPreviewPlannerStateQueryOptions(previewId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get the planner state of an analysed GPX file
 */
export const prefetchGetPreviewPlannerStateQuery = async <
  TData = Awaited<ReturnType<typeof getPreviewPlannerState>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  previewId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getPreviewPlannerState>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetPreviewPlannerStateQueryOptions(previewId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Creates a team route from the preview's original upload. A preview that was drawn in the route planner (drawn = true) is refused with ROUTE_PLANNER_DISABLED when the team has no route planner; an imported GPX file can become a route of any team.
 * @summary Save an analysed GPX file as a route
 */
export const createRouteFromPreview = (
  previewId: string,
  teamSlug: string,
  routeRequest: BodyType<RouteRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouteDto>(
    {
      url: `/api/gpx-previews/${previewId}/routes/${teamSlug}`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: routeRequest,
      signal,
    },
    options
  )
}

export const getCreateRouteFromPreviewMutationKey = () => ['createRouteFromPreview'] as const

export const getCreateRouteFromPreviewMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createRouteFromPreview>>,
    TError,
    CreateRouteFromPreviewMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createRouteFromPreview>>,
  TError,
  CreateRouteFromPreviewMutationVariables,
  TContext
> => {
  const mutationKey = getCreateRouteFromPreviewMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createRouteFromPreview>>,
    CreateRouteFromPreviewMutationVariables
  > = (props) => {
    const { previewId, teamSlug, data } = props ?? {}

    return createRouteFromPreview(previewId, teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateRouteFromPreviewMutationResult = NonNullable<
  Awaited<ReturnType<typeof createRouteFromPreview>>
>
export type CreateRouteFromPreviewMutationBody = BodyType<RouteRequest>
export type CreateRouteFromPreviewMutationError = ErrorType<ErrorResponse>
export type CreateRouteFromPreviewMutationVariables = {
  previewId: string
  teamSlug: string
  data: BodyType<RouteRequest>
}

/**
 * @summary Save an analysed GPX file as a route
 */
export const useCreateRouteFromPreview = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createRouteFromPreview>>,
      TError,
      CreateRouteFromPreviewMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createRouteFromPreview>>,
  TError,
  CreateRouteFromPreviewMutationVariables,
  TContext
> => {
  return useMutation(getCreateRouteFromPreviewMutationOptions(options), queryClient)
}
/**
 * The preview's map thumbnail, resized to the requested size and encoded in the best format the Accept header allows. Whoever holds the preview identifier may read it.
 * @summary Download the map thumbnail of an analysed GPX file
 */
export const getGpxPreviewThumbnail = (
  previewId: string,
  size: number,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    {
      url: `/api/gpx-previews/${previewId}/thumbnail/${size}`,
      method: 'GET',
      responseType: 'blob',
      signal,
    },
    options
  )
}

export const getGetGpxPreviewThumbnailQueryKey = (previewId: string, size: number) => {
  return [`/api/gpx-previews/${previewId}/thumbnail/${size}`] as const
}

export const getGetGpxPreviewThumbnailQueryOptions = <
  TData = Awaited<ReturnType<typeof getGpxPreviewThumbnail>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getGpxPreviewThumbnail>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetGpxPreviewThumbnailQueryKey(previewId, size)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getGpxPreviewThumbnail>>> = ({ signal }) =>
    getGpxPreviewThumbnail(previewId, size, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: previewId !== null && previewId !== undefined && size !== null && size !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getGpxPreviewThumbnail>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetGpxPreviewThumbnailQueryResult = NonNullable<
  Awaited<ReturnType<typeof getGpxPreviewThumbnail>>
>
export type GetGpxPreviewThumbnailQueryError = ErrorType<ErrorResponse>

export function useGetGpxPreviewThumbnail<
  TData = Awaited<ReturnType<typeof getGpxPreviewThumbnail>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  size: number,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getGpxPreviewThumbnail>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getGpxPreviewThumbnail>>,
          TError,
          Awaited<ReturnType<typeof getGpxPreviewThumbnail>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetGpxPreviewThumbnail<
  TData = Awaited<ReturnType<typeof getGpxPreviewThumbnail>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getGpxPreviewThumbnail>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getGpxPreviewThumbnail>>,
          TError,
          Awaited<ReturnType<typeof getGpxPreviewThumbnail>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetGpxPreviewThumbnail<
  TData = Awaited<ReturnType<typeof getGpxPreviewThumbnail>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getGpxPreviewThumbnail>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download the map thumbnail of an analysed GPX file
 */

export function useGetGpxPreviewThumbnail<
  TData = Awaited<ReturnType<typeof getGpxPreviewThumbnail>>,
  TError = ErrorType<ErrorResponse>,
>(
  previewId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getGpxPreviewThumbnail>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetGpxPreviewThumbnailQueryOptions(previewId, size, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download the map thumbnail of an analysed GPX file
 */
export const prefetchGetGpxPreviewThumbnailQuery = async <
  TData = Awaited<ReturnType<typeof getGpxPreviewThumbnail>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  previewId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getGpxPreviewThumbnail>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetGpxPreviewThumbnailQueryOptions(previewId, size, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * The forecast along the track when the preview has a departure date: at the start, then at each estimated passage (the average speed given, else 25 km/h). Anyone holding the link may read it. Read from the server's cache only — the forecast is refreshed in the background, never on request — and always 200: the state is in status (OUT_OF_RANGE without a date or once it is past). Cache-Control: private, no-cache with an ETag (revalidate with If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.
 * @summary Get the weather of an analysed GPX file
 */
export const getPreviewWeather = (
  previewId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideWeatherDto>(
    { url: `/api/gpx-previews/${previewId}/weather`, method: 'GET', signal },
    options
  )
}

export const getGetPreviewWeatherQueryKey = (previewId: string) => {
  return [`/api/gpx-previews/${previewId}/weather`] as const
}

export const getGetPreviewWeatherQueryOptions = <
  TData = Awaited<ReturnType<typeof getPreviewWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreviewWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetPreviewWeatherQueryKey(previewId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getPreviewWeather>>> = ({ signal }) =>
    getPreviewWeather(previewId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: previewId !== null && previewId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getPreviewWeather>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetPreviewWeatherQueryResult = NonNullable<
  Awaited<ReturnType<typeof getPreviewWeather>>
>
export type GetPreviewWeatherQueryError = ErrorType<void | ErrorResponse>

export function useGetPreviewWeather<
  TData = Awaited<ReturnType<typeof getPreviewWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  previewId: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreviewWeather>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPreviewWeather>>,
          TError,
          Awaited<ReturnType<typeof getPreviewWeather>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetPreviewWeather<
  TData = Awaited<ReturnType<typeof getPreviewWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreviewWeather>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPreviewWeather>>,
          TError,
          Awaited<ReturnType<typeof getPreviewWeather>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetPreviewWeather<
  TData = Awaited<ReturnType<typeof getPreviewWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreviewWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get the weather of an analysed GPX file
 */

export function useGetPreviewWeather<
  TData = Awaited<ReturnType<typeof getPreviewWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreviewWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetPreviewWeatherQueryOptions(previewId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get the weather of an analysed GPX file
 */
export const prefetchGetPreviewWeatherQuery = async <
  TData = Awaited<ReturnType<typeof getPreviewWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  previewId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPreviewWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetPreviewWeatherQueryOptions(previewId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
