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
  GetTripParticipantsParams,
  ParticipantListResponse,
  SlugChangeRequest,
  StatusChangeRequest,
  TripDto,
  TripParticipationDto,
  TripRequest,
  TripWeatherDto,
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
 * Create a new trip with optional stages
 * @summary Create trip
 */
export const createTrip = (
  teamSlug: string,
  tripRequest: BodyType<TripRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TripDto>(
    {
      url: `/api/teams/${teamSlug}/trips`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: tripRequest,
      signal,
    },
    options
  )
}

export const getCreateTripMutationKey = () => ['createTrip'] as const

export const getCreateTripMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createTrip>>,
    TError,
    CreateTripMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createTrip>>,
  TError,
  CreateTripMutationVariables,
  TContext
> => {
  const mutationKey = getCreateTripMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createTrip>>,
    CreateTripMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createTrip(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateTripMutationResult = NonNullable<Awaited<ReturnType<typeof createTrip>>>
export type CreateTripMutationBody = BodyType<TripRequest>
export type CreateTripMutationError = ErrorType<ErrorResponse>
export type CreateTripMutationVariables = { teamSlug: string; data: BodyType<TripRequest> }

/**
 * @summary Create trip
 */
export const useCreateTrip = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createTrip>>,
      TError,
      CreateTripMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createTrip>>,
  TError,
  CreateTripMutationVariables,
  TContext
> => {
  return useMutation(getCreateTripMutationOptions(options), queryClient)
}
/**
 * Update trip information. Requires organizer permissions.
 * @summary Update trip
 */
export const updateTrip = (
  teamSlug: string,
  tripSlug: string,
  tripRequest: BodyType<TripRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TripDto>(
    {
      url: `/api/teams/${teamSlug}/trips/${tripSlug}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: tripRequest,
      signal,
    },
    options
  )
}

export const getUpdateTripMutationKey = () => ['updateTrip'] as const

export const getUpdateTripMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateTrip>>,
    TError,
    UpdateTripMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateTrip>>,
  TError,
  UpdateTripMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateTripMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateTrip>>,
    UpdateTripMutationVariables
  > = (props) => {
    const { teamSlug, tripSlug, data } = props ?? {}

    return updateTrip(teamSlug, tripSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateTripMutationResult = NonNullable<Awaited<ReturnType<typeof updateTrip>>>
export type UpdateTripMutationBody = BodyType<TripRequest>
export type UpdateTripMutationError = ErrorType<ErrorResponse>
export type UpdateTripMutationVariables = {
  teamSlug: string
  tripSlug: string
  data: BodyType<TripRequest>
}

/**
 * @summary Update trip
 */
export const useUpdateTrip = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateTrip>>,
      TError,
      UpdateTripMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateTrip>>,
  TError,
  UpdateTripMutationVariables,
  TContext
> => {
  return useMutation(getUpdateTripMutationOptions(options), queryClient)
}
/**
 * Get detailed trip information including stages and participants
 * @summary Get trip details
 */
export const getTrip = (
  teamSlug: string,
  tripSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TripDto>(
    { url: `/api/teams/${teamSlug}/trips/${tripSlug}`, method: 'GET', signal },
    options
  )
}

export const getGetTripQueryKey = (teamSlug: string, tripSlug: string) => {
  return [`/api/teams/${teamSlug}/trips/${tripSlug}`] as const
}

export const getGetTripQueryOptions = <
  TData = Awaited<ReturnType<typeof getTrip>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTrip>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTripQueryKey(teamSlug, tripSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTrip>>> = ({ signal }) =>
    getTrip(teamSlug, tripSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && tripSlug !== null && tripSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTrip>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTripQueryResult = NonNullable<Awaited<ReturnType<typeof getTrip>>>
export type GetTripQueryError = ErrorType<ErrorResponse>

export function useGetTrip<
  TData = Awaited<ReturnType<typeof getTrip>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTrip>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTrip>>,
          TError,
          Awaited<ReturnType<typeof getTrip>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetTrip<
  TData = Awaited<ReturnType<typeof getTrip>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTrip>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTrip>>,
          TError,
          Awaited<ReturnType<typeof getTrip>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetTrip<
  TData = Awaited<ReturnType<typeof getTrip>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTrip>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get trip details
 */

export function useGetTrip<
  TData = Awaited<ReturnType<typeof getTrip>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTrip>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTripQueryOptions(teamSlug, tripSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get trip details
 */
export const prefetchGetTripQuery = async <
  TData = Awaited<ReturnType<typeof getTrip>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTrip>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTripQueryOptions(teamSlug, tripSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Soft delete a trip. Requires organizer permissions.
 * @summary Delete trip
 */
export const deleteTrip = (
  teamSlug: string,
  tripSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/trips/${tripSlug}`, method: 'DELETE', signal },
    options
  )
}

export const getDeleteTripMutationKey = () => ['deleteTrip'] as const

export const getDeleteTripMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteTrip>>,
    TError,
    DeleteTripMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteTrip>>,
  TError,
  DeleteTripMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteTripMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteTrip>>,
    DeleteTripMutationVariables
  > = (props) => {
    const { teamSlug, tripSlug } = props ?? {}

    return deleteTrip(teamSlug, tripSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteTripMutationResult = NonNullable<Awaited<ReturnType<typeof deleteTrip>>>

export type DeleteTripMutationError = ErrorType<ErrorResponse>
export type DeleteTripMutationVariables = { teamSlug: string; tripSlug: string }

/**
 * @summary Delete trip
 */
export const useDeleteTrip = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteTrip>>,
      TError,
      DeleteTripMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteTrip>>,
  TError,
  DeleteTripMutationVariables,
  TContext
> => {
  return useMutation(getDeleteTripMutationOptions(options), queryClient)
}
/**
 * One all-day VEVENT per stage, to add the trip on its own to a calendar. Readable by whoever may read the trip; no calendar token.
 * @summary Download trip as a calendar file
 */
export const downloadTripIcs = (
  teamSlug: string,
  tripSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<string>(
    { url: `/api/teams/${teamSlug}/trips/${tripSlug}/ics`, method: 'GET', signal },
    options
  )
}

export const getDownloadTripIcsQueryKey = (teamSlug: string, tripSlug: string) => {
  return [`/api/teams/${teamSlug}/trips/${tripSlug}/ics`] as const
}

export const getDownloadTripIcsQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadTripIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTripIcs>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDownloadTripIcsQueryKey(teamSlug, tripSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadTripIcs>>> = ({ signal }) =>
    downloadTripIcs(teamSlug, tripSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && tripSlug !== null && tripSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadTripIcs>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadTripIcsQueryResult = NonNullable<Awaited<ReturnType<typeof downloadTripIcs>>>
export type DownloadTripIcsQueryError = ErrorType<ErrorResponse>

export function useDownloadTripIcs<
  TData = Awaited<ReturnType<typeof downloadTripIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTripIcs>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadTripIcs>>,
          TError,
          Awaited<ReturnType<typeof downloadTripIcs>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadTripIcs<
  TData = Awaited<ReturnType<typeof downloadTripIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTripIcs>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadTripIcs>>,
          TError,
          Awaited<ReturnType<typeof downloadTripIcs>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadTripIcs<
  TData = Awaited<ReturnType<typeof downloadTripIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTripIcs>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download trip as a calendar file
 */

export function useDownloadTripIcs<
  TData = Awaited<ReturnType<typeof downloadTripIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTripIcs>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadTripIcsQueryOptions(teamSlug, tripSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download trip as a calendar file
 */
export const prefetchDownloadTripIcsQuery = async <
  TData = Awaited<ReturnType<typeof downloadTripIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTripIcs>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadTripIcsQueryOptions(teamSlug, tripSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Join a trip as a participant
 * @summary Join trip
 */
export const joinTrip = (
  teamSlug: string,
  tripSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TripParticipationDto>(
    { url: `/api/teams/${teamSlug}/trips/${tripSlug}/join`, method: 'POST', signal },
    options
  )
}

export const getJoinTripMutationKey = () => ['joinTrip'] as const

export const getJoinTripMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof joinTrip>>,
    TError,
    JoinTripMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof joinTrip>>,
  TError,
  JoinTripMutationVariables,
  TContext
> => {
  const mutationKey = getJoinTripMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof joinTrip>>,
    JoinTripMutationVariables
  > = (props) => {
    const { teamSlug, tripSlug } = props ?? {}

    return joinTrip(teamSlug, tripSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type JoinTripMutationResult = NonNullable<Awaited<ReturnType<typeof joinTrip>>>

export type JoinTripMutationError = ErrorType<ErrorResponse | void>
export type JoinTripMutationVariables = { teamSlug: string; tripSlug: string }

/**
 * @summary Join trip
 */
export const useJoinTrip = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof joinTrip>>,
      TError,
      JoinTripMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof joinTrip>>,
  TError,
  JoinTripMutationVariables,
  TContext
> => {
  return useMutation(getJoinTripMutationOptions(options), queryClient)
}
/**
 * Leave a trip as a participant
 * @summary Leave trip
 */
export const leaveTrip = (
  teamSlug: string,
  tripSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/trips/${tripSlug}/leave`, method: 'POST', signal },
    options
  )
}

export const getLeaveTripMutationKey = () => ['leaveTrip'] as const

export const getLeaveTripMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof leaveTrip>>,
    TError,
    LeaveTripMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof leaveTrip>>,
  TError,
  LeaveTripMutationVariables,
  TContext
> => {
  const mutationKey = getLeaveTripMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof leaveTrip>>,
    LeaveTripMutationVariables
  > = (props) => {
    const { teamSlug, tripSlug } = props ?? {}

    return leaveTrip(teamSlug, tripSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type LeaveTripMutationResult = NonNullable<Awaited<ReturnType<typeof leaveTrip>>>

export type LeaveTripMutationError = ErrorType<ErrorResponse | void>
export type LeaveTripMutationVariables = { teamSlug: string; tripSlug: string }

/**
 * @summary Leave trip
 */
export const useLeaveTrip = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof leaveTrip>>,
      TError,
      LeaveTripMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof leaveTrip>>,
  TError,
  LeaveTripMutationVariables,
  TContext
> => {
  return useMutation(getLeaveTripMutationOptions(options), queryClient)
}
/**
 * One page of the people registered to the trip, earliest registrations first, searchable by display name. The trip detail only embeds the first few; this is the whole list, with its total. Members of the team only (and platform administrators): member names are never sent to anyone else.
 * @summary List trip participants
 */
export const getTripParticipants = (
  teamSlug: string,
  tripSlug: string,
  params?: GetTripParticipantsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<ParticipantListResponse>(
    { url: `/api/teams/${teamSlug}/trips/${tripSlug}/participants`, method: 'GET', params, signal },
    options
  )
}

export const getGetTripParticipantsQueryKey = (
  teamSlug: string,
  tripSlug: string,
  params?: GetTripParticipantsParams
) => {
  return [
    `/api/teams/${teamSlug}/trips/${tripSlug}/participants`,
    ...(params ? [params] : []),
  ] as const
}

export const getGetTripParticipantsQueryOptions = <
  TData = Awaited<ReturnType<typeof getTripParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  params?: GetTripParticipantsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripParticipants>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getGetTripParticipantsQueryKey(teamSlug, tripSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTripParticipants>>> = ({ signal }) =>
    getTripParticipants(teamSlug, tripSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && tripSlug !== null && tripSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTripParticipants>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTripParticipantsQueryResult = NonNullable<
  Awaited<ReturnType<typeof getTripParticipants>>
>
export type GetTripParticipantsQueryError = ErrorType<ErrorResponse>

export function useGetTripParticipants<
  TData = Awaited<ReturnType<typeof getTripParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  params: undefined | GetTripParticipantsParams,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getTripParticipants>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTripParticipants>>,
          TError,
          Awaited<ReturnType<typeof getTripParticipants>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetTripParticipants<
  TData = Awaited<ReturnType<typeof getTripParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  params?: GetTripParticipantsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getTripParticipants>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTripParticipants>>,
          TError,
          Awaited<ReturnType<typeof getTripParticipants>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetTripParticipants<
  TData = Awaited<ReturnType<typeof getTripParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  params?: GetTripParticipantsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripParticipants>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary List trip participants
 */

export function useGetTripParticipants<
  TData = Awaited<ReturnType<typeof getTripParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  params?: GetTripParticipantsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripParticipants>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTripParticipantsQueryOptions(teamSlug, tripSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary List trip participants
 */
export const prefetchGetTripParticipantsQuery = async <
  TData = Awaited<ReturnType<typeof getTripParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  tripSlug: string,
  params?: GetTripParticipantsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripParticipants>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTripParticipantsQueryOptions(teamSlug, tripSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Change trip URL slug. Requires organizer permissions.
 * @summary Change trip slug
 */
export const changeTripSlug = (
  teamSlug: string,
  tripSlug: string,
  slugChangeRequest: BodyType<SlugChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TripDto>(
    {
      url: `/api/teams/${teamSlug}/trips/${tripSlug}/slug`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: slugChangeRequest,
      signal,
    },
    options
  )
}

export const getChangeTripSlugMutationKey = () => ['changeTripSlug'] as const

export const getChangeTripSlugMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changeTripSlug>>,
    TError,
    ChangeTripSlugMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changeTripSlug>>,
  TError,
  ChangeTripSlugMutationVariables,
  TContext
> => {
  const mutationKey = getChangeTripSlugMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changeTripSlug>>,
    ChangeTripSlugMutationVariables
  > = (props) => {
    const { teamSlug, tripSlug, data } = props ?? {}

    return changeTripSlug(teamSlug, tripSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangeTripSlugMutationResult = NonNullable<Awaited<ReturnType<typeof changeTripSlug>>>
export type ChangeTripSlugMutationBody = BodyType<SlugChangeRequest>
export type ChangeTripSlugMutationError = ErrorType<ErrorResponse>
export type ChangeTripSlugMutationVariables = {
  teamSlug: string
  tripSlug: string
  data: BodyType<SlugChangeRequest>
}

/**
 * @summary Change trip slug
 */
export const useChangeTripSlug = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changeTripSlug>>,
      TError,
      ChangeTripSlugMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changeTripSlug>>,
  TError,
  ChangeTripSlugMutationVariables,
  TContext
> => {
  return useMutation(getChangeTripSlugMutationOptions(options), queryClient)
}
/**
 * Change the trip's status and nothing else — what a list row can do without the full trip. Same side effects as a status change through the update. Requires organizer permissions. The stages follow the trip.
 * @summary Change trip status
 */
export const changeTripStatus = (
  teamSlug: string,
  tripSlug: string,
  statusChangeRequest: BodyType<StatusChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TripDto>(
    {
      url: `/api/teams/${teamSlug}/trips/${tripSlug}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: statusChangeRequest,
      signal,
    },
    options
  )
}

export const getChangeTripStatusMutationKey = () => ['changeTripStatus'] as const

export const getChangeTripStatusMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changeTripStatus>>,
    TError,
    ChangeTripStatusMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changeTripStatus>>,
  TError,
  ChangeTripStatusMutationVariables,
  TContext
> => {
  const mutationKey = getChangeTripStatusMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changeTripStatus>>,
    ChangeTripStatusMutationVariables
  > = (props) => {
    const { teamSlug, tripSlug, data } = props ?? {}

    return changeTripStatus(teamSlug, tripSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangeTripStatusMutationResult = NonNullable<
  Awaited<ReturnType<typeof changeTripStatus>>
>
export type ChangeTripStatusMutationBody = BodyType<StatusChangeRequest>
export type ChangeTripStatusMutationError = ErrorType<ErrorResponse>
export type ChangeTripStatusMutationVariables = {
  teamSlug: string
  tripSlug: string
  data: BodyType<StatusChangeRequest>
}

/**
 * @summary Change trip status
 */
export const useChangeTripStatus = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changeTripStatus>>,
      TError,
      ChangeTripStatusMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changeTripStatus>>,
  TError,
  ChangeTripStatusMutationVariables,
  TContext
> => {
  return useMutation(getChangeTripStatusMutationOptions(options), queryClient)
}
/**
 * Restore a soft-deleted trip. Requires organizer permissions.
 * @summary Restore trip
 */
export const undeleteTrip = (
  teamSlug: string,
  tripSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TripDto>(
    { url: `/api/teams/${teamSlug}/trips/${tripSlug}/undelete`, method: 'POST', signal },
    options
  )
}

export const getUndeleteTripMutationKey = () => ['undeleteTrip'] as const

export const getUndeleteTripMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof undeleteTrip>>,
    TError,
    UndeleteTripMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof undeleteTrip>>,
  TError,
  UndeleteTripMutationVariables,
  TContext
> => {
  const mutationKey = getUndeleteTripMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof undeleteTrip>>,
    UndeleteTripMutationVariables
  > = (props) => {
    const { teamSlug, tripSlug } = props ?? {}

    return undeleteTrip(teamSlug, tripSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UndeleteTripMutationResult = NonNullable<Awaited<ReturnType<typeof undeleteTrip>>>

export type UndeleteTripMutationError = ErrorType<ErrorResponse>
export type UndeleteTripMutationVariables = { teamSlug: string; tripSlug: string }

/**
 * @summary Restore trip
 */
export const useUndeleteTrip = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof undeleteTrip>>,
      TError,
      UndeleteTripMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof undeleteTrip>>,
  TError,
  UndeleteTripMutationVariables,
  TContext
> => {
  return useMutation(getUndeleteTripMutationOptions(options), queryClient)
}
/**
 * The forecast for the trip, stage by stage: along each stage's route at its estimated passages (stage speed, else 25 km/h), each stage with its own state. Read from the server's cache only — the forecast is refreshed in the background, never on request. Readable by whoever may read the trip, and then always 200: the state is in status. Cache-Control: private, no-cache with an ETag (revalidate with If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.
 * @summary Get trip weather
 */
export const getTripWeather = (
  teamSlug: string,
  tripSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TripWeatherDto>(
    { url: `/api/teams/${teamSlug}/trips/${tripSlug}/weather`, method: 'GET', signal },
    options
  )
}

export const getGetTripWeatherQueryKey = (teamSlug: string, tripSlug: string) => {
  return [`/api/teams/${teamSlug}/trips/${tripSlug}/weather`] as const
}

export const getGetTripWeatherQueryOptions = <
  TData = Awaited<ReturnType<typeof getTripWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTripWeatherQueryKey(teamSlug, tripSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTripWeather>>> = ({ signal }) =>
    getTripWeather(teamSlug, tripSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && tripSlug !== null && tripSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTripWeather>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTripWeatherQueryResult = NonNullable<Awaited<ReturnType<typeof getTripWeather>>>
export type GetTripWeatherQueryError = ErrorType<void | ErrorResponse>

export function useGetTripWeather<
  TData = Awaited<ReturnType<typeof getTripWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripWeather>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTripWeather>>,
          TError,
          Awaited<ReturnType<typeof getTripWeather>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetTripWeather<
  TData = Awaited<ReturnType<typeof getTripWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripWeather>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTripWeather>>,
          TError,
          Awaited<ReturnType<typeof getTripWeather>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetTripWeather<
  TData = Awaited<ReturnType<typeof getTripWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get trip weather
 */

export function useGetTripWeather<
  TData = Awaited<ReturnType<typeof getTripWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTripWeatherQueryOptions(teamSlug, tripSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get trip weather
 */
export const prefetchGetTripWeatherQuery = async <
  TData = Awaited<ReturnType<typeof getTripWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  tripSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTripWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTripWeatherQueryOptions(teamSlug, tripSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
