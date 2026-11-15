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
  ErrorResponse,
  ListPlacesParams,
  PlaceDetailDto,
  PlaceListResponse,
  PlaceRequest,
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
 * Get all places for a team
 * @summary List places
 */
export const listPlaces = (
  teamSlug: string,
  params?: ListPlacesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PlaceListResponse>(
    { url: `/api/teams/${teamSlug}/places`, method: 'GET', params, signal },
    options
  )
}

export const getListPlacesQueryKey = (teamSlug: string, params?: ListPlacesParams) => {
  return [`/api/teams/${teamSlug}/places`, ...(params ? [params] : [])] as const
}

export const getListPlacesQueryOptions = <
  TData = Awaited<ReturnType<typeof listPlaces>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: ListPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPlaces>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListPlacesQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listPlaces>>> = ({ signal }) =>
    listPlaces(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listPlaces>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListPlacesQueryResult = NonNullable<Awaited<ReturnType<typeof listPlaces>>>
export type ListPlacesQueryError = ErrorType<void | ErrorResponse>

/**
 * Get all places for a team
 * @summary List places
 */
export function useListPlaces<
  TData = Awaited<ReturnType<typeof listPlaces>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | ListPlacesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPlaces>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPlaces>>,
          TError,
          Awaited<ReturnType<typeof listPlaces>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all places for a team
 * @summary List places
 */
export function useListPlaces<
  TData = Awaited<ReturnType<typeof listPlaces>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: ListPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPlaces>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPlaces>>,
          TError,
          Awaited<ReturnType<typeof listPlaces>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all places for a team
 * @summary List places
 */
export function useListPlaces<
  TData = Awaited<ReturnType<typeof listPlaces>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: ListPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPlaces>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all places for a team
 * @summary List places
 */
export function useListPlaces<
  TData = Awaited<ReturnType<typeof listPlaces>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: ListPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPlaces>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListPlacesQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get all places for a team
 * @summary List places
 */
export const prefetchListPlacesQuery = async <
  TData = Awaited<ReturnType<typeof listPlaces>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: ListPlacesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPlaces>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListPlacesQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a new place for the team
 * @summary Create place
 */
export const createPlace = (
  teamSlug: string,
  placeRequest: BodyType<PlaceRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PlaceDetailDto>(
    {
      url: `/api/teams/${teamSlug}/places`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: placeRequest,
      signal,
    },
    options
  )
}

export const getCreatePlaceMutationKey = () => ['createPlace'] as const

export const getCreatePlaceMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createPlace>>,
    TError,
    CreatePlaceMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createPlace>>,
  TError,
  CreatePlaceMutationVariables,
  TContext
> => {
  const mutationKey = getCreatePlaceMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createPlace>>,
    CreatePlaceMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createPlace(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreatePlaceMutationResult = NonNullable<Awaited<ReturnType<typeof createPlace>>>
export type CreatePlaceMutationBody = BodyType<PlaceRequest>
export type CreatePlaceMutationError = ErrorType<ErrorResponse>
export type CreatePlaceMutationVariables = { teamSlug: string; data: BodyType<PlaceRequest> }

/**
 * Create a new place for the team
 * @summary Create place
 */
export const useCreatePlace = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createPlace>>,
      TError,
      CreatePlaceMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createPlace>>,
  TError,
  CreatePlaceMutationVariables,
  TContext
> => {
  return useMutation(getCreatePlaceMutationOptions(options), queryClient)
}
/**
 * Update an existing place
 * @summary Update place
 */
export const updatePlace = (
  teamSlug: string,
  placeId: string,
  placeRequest: BodyType<PlaceRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PlaceDetailDto>(
    {
      url: `/api/teams/${teamSlug}/places/${placeId}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: placeRequest,
      signal,
    },
    options
  )
}

export const getUpdatePlaceMutationKey = () => ['updatePlace'] as const

export const getUpdatePlaceMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updatePlace>>,
    TError,
    UpdatePlaceMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updatePlace>>,
  TError,
  UpdatePlaceMutationVariables,
  TContext
> => {
  const mutationKey = getUpdatePlaceMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updatePlace>>,
    UpdatePlaceMutationVariables
  > = (props) => {
    const { teamSlug, placeId, data } = props ?? {}

    return updatePlace(teamSlug, placeId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdatePlaceMutationResult = NonNullable<Awaited<ReturnType<typeof updatePlace>>>
export type UpdatePlaceMutationBody = BodyType<PlaceRequest>
export type UpdatePlaceMutationError = ErrorType<ErrorResponse>
export type UpdatePlaceMutationVariables = {
  teamSlug: string
  placeId: string
  data: BodyType<PlaceRequest>
}

/**
 * Update an existing place
 * @summary Update place
 */
export const useUpdatePlace = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updatePlace>>,
      TError,
      UpdatePlaceMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updatePlace>>,
  TError,
  UpdatePlaceMutationVariables,
  TContext
> => {
  return useMutation(getUpdatePlaceMutationOptions(options), queryClient)
}
/**
 * Get a specific place by ID
 * @summary Get place details
 */
export const getPlace = (
  teamSlug: string,
  placeId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PlaceDetailDto>(
    { url: `/api/teams/${teamSlug}/places/${placeId}`, method: 'GET', signal },
    options
  )
}

export const getGetPlaceQueryKey = (teamSlug: string, placeId: string) => {
  return [`/api/teams/${teamSlug}/places/${placeId}`] as const
}

export const getGetPlaceQueryOptions = <
  TData = Awaited<ReturnType<typeof getPlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  placeId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPlace>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetPlaceQueryKey(teamSlug, placeId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getPlace>>> = ({ signal }) =>
    getPlace(teamSlug, placeId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && placeId !== null && placeId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getPlace>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetPlaceQueryResult = NonNullable<Awaited<ReturnType<typeof getPlace>>>
export type GetPlaceQueryError = ErrorType<void | ErrorResponse>

/**
 * Get a specific place by ID
 * @summary Get place details
 */
export function useGetPlace<
  TData = Awaited<ReturnType<typeof getPlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  placeId: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPlace>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPlace>>,
          TError,
          Awaited<ReturnType<typeof getPlace>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a specific place by ID
 * @summary Get place details
 */
export function useGetPlace<
  TData = Awaited<ReturnType<typeof getPlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  placeId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPlace>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPlace>>,
          TError,
          Awaited<ReturnType<typeof getPlace>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a specific place by ID
 * @summary Get place details
 */
export function useGetPlace<
  TData = Awaited<ReturnType<typeof getPlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  placeId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPlace>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a specific place by ID
 * @summary Get place details
 */
export function useGetPlace<
  TData = Awaited<ReturnType<typeof getPlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  placeId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPlace>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetPlaceQueryOptions(teamSlug, placeId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get a specific place by ID
 * @summary Get place details
 */
export const prefetchGetPlaceQuery = async <
  TData = Awaited<ReturnType<typeof getPlace>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  placeId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPlace>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetPlaceQueryOptions(teamSlug, placeId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Soft delete a place
 * @summary Delete place
 */
export const deletePlace = (
  teamSlug: string,
  placeId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/places/${placeId}`, method: 'DELETE', signal },
    options
  )
}

export const getDeletePlaceMutationKey = () => ['deletePlace'] as const

export const getDeletePlaceMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deletePlace>>,
    TError,
    DeletePlaceMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deletePlace>>,
  TError,
  DeletePlaceMutationVariables,
  TContext
> => {
  const mutationKey = getDeletePlaceMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deletePlace>>,
    DeletePlaceMutationVariables
  > = (props) => {
    const { teamSlug, placeId } = props ?? {}

    return deletePlace(teamSlug, placeId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeletePlaceMutationResult = NonNullable<Awaited<ReturnType<typeof deletePlace>>>

export type DeletePlaceMutationError = ErrorType<ErrorResponse>
export type DeletePlaceMutationVariables = { teamSlug: string; placeId: string }

/**
 * Soft delete a place
 * @summary Delete place
 */
export const useDeletePlace = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deletePlace>>,
      TError,
      DeletePlaceMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deletePlace>>,
  TError,
  DeletePlaceMutationVariables,
  TContext
> => {
  return useMutation(getDeletePlaceMutationOptions(options), queryClient)
}
