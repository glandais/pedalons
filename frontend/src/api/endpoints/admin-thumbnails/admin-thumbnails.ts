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
  AdminGetThumbnailCatchUpParams,
  AdminRegenerateThumbnailsParams,
  ErrorResponse,
  ThumbnailCatchUpStatus,
  ThumbnailRegenerationRequest,
  ThumbnailRegenerationResponse,
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
 * How many routes, rides and trips of the domain have thumbnails drawn before the current basemap, how many of those wait for a new attempt, and how many the catch-up gave up on.
 * @summary State of the automatic thumbnail catch-up
 */
export const adminGetThumbnailCatchUp = (
  params?: AdminGetThumbnailCatchUpParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<ThumbnailCatchUpStatus>(
    { url: `/api/admin/thumbnails/catch-up`, method: 'GET', params, signal },
    options
  )
}

export const getAdminGetThumbnailCatchUpQueryKey = (params?: AdminGetThumbnailCatchUpParams) => {
  return [`/api/admin/thumbnails/catch-up`, ...(params ? [params] : [])] as const
}

export const getAdminGetThumbnailCatchUpQueryOptions = <
  TData = Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: AdminGetThumbnailCatchUpParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getAdminGetThumbnailCatchUpQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>> = ({
    signal,
  }) => adminGetThumbnailCatchUp(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type AdminGetThumbnailCatchUpQueryResult = NonNullable<
  Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>
>
export type AdminGetThumbnailCatchUpQueryError = ErrorType<void | ErrorResponse>

/**
 * How many routes, rides and trips of the domain have thumbnails drawn before the current basemap, how many of those wait for a new attempt, and how many the catch-up gave up on.
 * @summary State of the automatic thumbnail catch-up
 */
export function useAdminGetThumbnailCatchUp<
  TData = Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: undefined | AdminGetThumbnailCatchUpParams,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
          TError,
          Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many routes, rides and trips of the domain have thumbnails drawn before the current basemap, how many of those wait for a new attempt, and how many the catch-up gave up on.
 * @summary State of the automatic thumbnail catch-up
 */
export function useAdminGetThumbnailCatchUp<
  TData = Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: AdminGetThumbnailCatchUpParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
          TError,
          Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many routes, rides and trips of the domain have thumbnails drawn before the current basemap, how many of those wait for a new attempt, and how many the catch-up gave up on.
 * @summary State of the automatic thumbnail catch-up
 */
export function useAdminGetThumbnailCatchUp<
  TData = Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: AdminGetThumbnailCatchUpParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many routes, rides and trips of the domain have thumbnails drawn before the current basemap, how many of those wait for a new attempt, and how many the catch-up gave up on.
 * @summary State of the automatic thumbnail catch-up
 */
export function useAdminGetThumbnailCatchUp<
  TData = Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: AdminGetThumbnailCatchUpParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getAdminGetThumbnailCatchUpQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * How many routes, rides and trips of the domain have thumbnails drawn before the current basemap, how many of those wait for a new attempt, and how many the catch-up gave up on.
 * @summary State of the automatic thumbnail catch-up
 */
export const prefetchAdminGetThumbnailCatchUpQuery = async <
  TData = Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: AdminGetThumbnailCatchUpParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof adminGetThumbnailCatchUp>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getAdminGetThumbnailCatchUpQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

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
