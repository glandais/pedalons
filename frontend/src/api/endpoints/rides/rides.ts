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
  GetRideParticipantsParams,
  ParticipantListResponse,
  RideDto,
  RideParticipationDto,
  RideRequest,
  RideWeatherDto,
  SlugChangeRequest,
  StatusChangeRequest,
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
 * Create a new ride with optional groups
 * @summary Create ride
 */
export const createRide = (
  teamSlug: string,
  rideRequest: BodyType<RideRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideDto>(
    {
      url: `/api/teams/${teamSlug}/rides`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: rideRequest,
      signal,
    },
    options
  )
}

export const getCreateRideMutationKey = () => ['createRide'] as const

export const getCreateRideMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createRide>>,
    TError,
    CreateRideMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createRide>>,
  TError,
  CreateRideMutationVariables,
  TContext
> => {
  const mutationKey = getCreateRideMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createRide>>,
    CreateRideMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createRide(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateRideMutationResult = NonNullable<Awaited<ReturnType<typeof createRide>>>
export type CreateRideMutationBody = BodyType<RideRequest>
export type CreateRideMutationError = ErrorType<ErrorResponse>
export type CreateRideMutationVariables = { teamSlug: string; data: BodyType<RideRequest> }

/**
 * @summary Create ride
 */
export const useCreateRide = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createRide>>,
      TError,
      CreateRideMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createRide>>,
  TError,
  CreateRideMutationVariables,
  TContext
> => {
  return useMutation(getCreateRideMutationOptions(options), queryClient)
}
/**
 * Update ride information. Requires organizer permissions.
 * @summary Update ride
 */
export const updateRide = (
  teamSlug: string,
  rideSlug: string,
  rideRequest: BodyType<RideRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideDto>(
    {
      url: `/api/teams/${teamSlug}/rides/${rideSlug}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: rideRequest,
      signal,
    },
    options
  )
}

export const getUpdateRideMutationKey = () => ['updateRide'] as const

export const getUpdateRideMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateRide>>,
    TError,
    UpdateRideMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateRide>>,
  TError,
  UpdateRideMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateRideMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateRide>>,
    UpdateRideMutationVariables
  > = (props) => {
    const { teamSlug, rideSlug, data } = props ?? {}

    return updateRide(teamSlug, rideSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateRideMutationResult = NonNullable<Awaited<ReturnType<typeof updateRide>>>
export type UpdateRideMutationBody = BodyType<RideRequest>
export type UpdateRideMutationError = ErrorType<ErrorResponse>
export type UpdateRideMutationVariables = {
  teamSlug: string
  rideSlug: string
  data: BodyType<RideRequest>
}

/**
 * @summary Update ride
 */
export const useUpdateRide = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateRide>>,
      TError,
      UpdateRideMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateRide>>,
  TError,
  UpdateRideMutationVariables,
  TContext
> => {
  return useMutation(getUpdateRideMutationOptions(options), queryClient)
}
/**
 * Get detailed ride information including groups
 * @summary Get ride details
 */
export const getRide = (
  teamSlug: string,
  rideSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideDto>(
    { url: `/api/teams/${teamSlug}/rides/${rideSlug}`, method: 'GET', signal },
    options
  )
}

export const getGetRideQueryKey = (teamSlug: string, rideSlug: string) => {
  return [`/api/teams/${teamSlug}/rides/${rideSlug}`] as const
}

export const getGetRideQueryOptions = <
  TData = Awaited<ReturnType<typeof getRide>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRide>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRideQueryKey(teamSlug, rideSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRide>>> = ({ signal }) =>
    getRide(teamSlug, rideSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && rideSlug !== null && rideSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRide>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRideQueryResult = NonNullable<Awaited<ReturnType<typeof getRide>>>
export type GetRideQueryError = ErrorType<ErrorResponse>

export function useGetRide<
  TData = Awaited<ReturnType<typeof getRide>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRide>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRide>>,
          TError,
          Awaited<ReturnType<typeof getRide>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRide<
  TData = Awaited<ReturnType<typeof getRide>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRide>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRide>>,
          TError,
          Awaited<ReturnType<typeof getRide>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRide<
  TData = Awaited<ReturnType<typeof getRide>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRide>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get ride details
 */

export function useGetRide<
  TData = Awaited<ReturnType<typeof getRide>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRide>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRideQueryOptions(teamSlug, rideSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get ride details
 */
export const prefetchGetRideQuery = async <
  TData = Awaited<ReturnType<typeof getRide>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRide>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRideQueryOptions(teamSlug, rideSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Soft delete a ride. Requires organizer permissions.
 * @summary Delete ride
 */
export const deleteRide = (
  teamSlug: string,
  rideSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/rides/${rideSlug}`, method: 'DELETE', signal },
    options
  )
}

export const getDeleteRideMutationKey = () => ['deleteRide'] as const

export const getDeleteRideMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteRide>>,
    TError,
    DeleteRideMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteRide>>,
  TError,
  DeleteRideMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteRideMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteRide>>,
    DeleteRideMutationVariables
  > = (props) => {
    const { teamSlug, rideSlug } = props ?? {}

    return deleteRide(teamSlug, rideSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteRideMutationResult = NonNullable<Awaited<ReturnType<typeof deleteRide>>>

export type DeleteRideMutationError = ErrorType<ErrorResponse>
export type DeleteRideMutationVariables = { teamSlug: string; rideSlug: string }

/**
 * @summary Delete ride
 */
export const useDeleteRide = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteRide>>,
      TError,
      DeleteRideMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteRide>>,
  TError,
  DeleteRideMutationVariables,
  TContext
> => {
  return useMutation(getDeleteRideMutationOptions(options), queryClient)
}
/**
 * Join a ride group
 * @summary Join ride group
 */
export const joinGroup = (
  teamSlug: string,
  rideSlug: string,
  groupId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideParticipationDto>(
    {
      url: `/api/teams/${teamSlug}/rides/${rideSlug}/groups/${groupId}/join`,
      method: 'POST',
      signal,
    },
    options
  )
}

export const getJoinGroupMutationKey = () => ['joinGroup'] as const

export const getJoinGroupMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof joinGroup>>,
    TError,
    JoinGroupMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof joinGroup>>,
  TError,
  JoinGroupMutationVariables,
  TContext
> => {
  const mutationKey = getJoinGroupMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof joinGroup>>,
    JoinGroupMutationVariables
  > = (props) => {
    const { teamSlug, rideSlug, groupId } = props ?? {}

    return joinGroup(teamSlug, rideSlug, groupId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type JoinGroupMutationResult = NonNullable<Awaited<ReturnType<typeof joinGroup>>>

export type JoinGroupMutationError = ErrorType<ErrorResponse | void>
export type JoinGroupMutationVariables = { teamSlug: string; rideSlug: string; groupId: string }

/**
 * @summary Join ride group
 */
export const useJoinGroup = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof joinGroup>>,
      TError,
      JoinGroupMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof joinGroup>>,
  TError,
  JoinGroupMutationVariables,
  TContext
> => {
  return useMutation(getJoinGroupMutationOptions(options), queryClient)
}
/**
 * Leave a ride group
 * @summary Leave ride group
 */
export const leaveGroup = (
  teamSlug: string,
  rideSlug: string,
  groupId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/teams/${teamSlug}/rides/${rideSlug}/groups/${groupId}/leave`,
      method: 'POST',
      signal,
    },
    options
  )
}

export const getLeaveGroupMutationKey = () => ['leaveGroup'] as const

export const getLeaveGroupMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof leaveGroup>>,
    TError,
    LeaveGroupMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof leaveGroup>>,
  TError,
  LeaveGroupMutationVariables,
  TContext
> => {
  const mutationKey = getLeaveGroupMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof leaveGroup>>,
    LeaveGroupMutationVariables
  > = (props) => {
    const { teamSlug, rideSlug, groupId } = props ?? {}

    return leaveGroup(teamSlug, rideSlug, groupId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type LeaveGroupMutationResult = NonNullable<Awaited<ReturnType<typeof leaveGroup>>>

export type LeaveGroupMutationError = ErrorType<ErrorResponse | void>
export type LeaveGroupMutationVariables = { teamSlug: string; rideSlug: string; groupId: string }

/**
 * @summary Leave ride group
 */
export const useLeaveGroup = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof leaveGroup>>,
      TError,
      LeaveGroupMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof leaveGroup>>,
  TError,
  LeaveGroupMutationVariables,
  TContext
> => {
  return useMutation(getLeaveGroupMutationOptions(options), queryClient)
}
/**
 * One VEVENT for the ride, to add it on its own to a calendar. Readable by whoever may read the ride; no calendar token.
 * @summary Download ride as a calendar file
 */
export const downloadRideIcs = (
  teamSlug: string,
  rideSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<string>(
    { url: `/api/teams/${teamSlug}/rides/${rideSlug}/ics`, method: 'GET', signal },
    options
  )
}

export const getDownloadRideIcsQueryKey = (teamSlug: string, rideSlug: string) => {
  return [`/api/teams/${teamSlug}/rides/${rideSlug}/ics`] as const
}

export const getDownloadRideIcsQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadRideIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadRideIcs>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDownloadRideIcsQueryKey(teamSlug, rideSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadRideIcs>>> = ({ signal }) =>
    downloadRideIcs(teamSlug, rideSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && rideSlug !== null && rideSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadRideIcs>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadRideIcsQueryResult = NonNullable<Awaited<ReturnType<typeof downloadRideIcs>>>
export type DownloadRideIcsQueryError = ErrorType<ErrorResponse>

export function useDownloadRideIcs<
  TData = Awaited<ReturnType<typeof downloadRideIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadRideIcs>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadRideIcs>>,
          TError,
          Awaited<ReturnType<typeof downloadRideIcs>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadRideIcs<
  TData = Awaited<ReturnType<typeof downloadRideIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadRideIcs>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadRideIcs>>,
          TError,
          Awaited<ReturnType<typeof downloadRideIcs>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadRideIcs<
  TData = Awaited<ReturnType<typeof downloadRideIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadRideIcs>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download ride as a calendar file
 */

export function useDownloadRideIcs<
  TData = Awaited<ReturnType<typeof downloadRideIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadRideIcs>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadRideIcsQueryOptions(teamSlug, rideSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download ride as a calendar file
 */
export const prefetchDownloadRideIcsQuery = async <
  TData = Awaited<ReturnType<typeof downloadRideIcs>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadRideIcs>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadRideIcsQueryOptions(teamSlug, rideSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * One page of the people registered to the ride, or to one of its groups, earliest registrations first, searchable by display name. The ride detail only embeds the first few; this is the whole list, with its total. Members of the team only (and platform administrators): member names are never sent to anyone else.
 * @summary List ride participants
 */
export const getRideParticipants = (
  teamSlug: string,
  rideSlug: string,
  params?: GetRideParticipantsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<ParticipantListResponse>(
    { url: `/api/teams/${teamSlug}/rides/${rideSlug}/participants`, method: 'GET', params, signal },
    options
  )
}

export const getGetRideParticipantsQueryKey = (
  teamSlug: string,
  rideSlug: string,
  params?: GetRideParticipantsParams
) => {
  return [
    `/api/teams/${teamSlug}/rides/${rideSlug}/participants`,
    ...(params ? [params] : []),
  ] as const
}

export const getGetRideParticipantsQueryOptions = <
  TData = Awaited<ReturnType<typeof getRideParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  params?: GetRideParticipantsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideParticipants>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getGetRideParticipantsQueryKey(teamSlug, rideSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRideParticipants>>> = ({ signal }) =>
    getRideParticipants(teamSlug, rideSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && rideSlug !== null && rideSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRideParticipants>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRideParticipantsQueryResult = NonNullable<
  Awaited<ReturnType<typeof getRideParticipants>>
>
export type GetRideParticipantsQueryError = ErrorType<ErrorResponse>

export function useGetRideParticipants<
  TData = Awaited<ReturnType<typeof getRideParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  params: undefined | GetRideParticipantsParams,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRideParticipants>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRideParticipants>>,
          TError,
          Awaited<ReturnType<typeof getRideParticipants>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRideParticipants<
  TData = Awaited<ReturnType<typeof getRideParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  params?: GetRideParticipantsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRideParticipants>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRideParticipants>>,
          TError,
          Awaited<ReturnType<typeof getRideParticipants>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRideParticipants<
  TData = Awaited<ReturnType<typeof getRideParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  params?: GetRideParticipantsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideParticipants>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary List ride participants
 */

export function useGetRideParticipants<
  TData = Awaited<ReturnType<typeof getRideParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  params?: GetRideParticipantsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideParticipants>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRideParticipantsQueryOptions(teamSlug, rideSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary List ride participants
 */
export const prefetchGetRideParticipantsQuery = async <
  TData = Awaited<ReturnType<typeof getRideParticipants>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  rideSlug: string,
  params?: GetRideParticipantsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideParticipants>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRideParticipantsQueryOptions(teamSlug, rideSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Change ride URL slug. Requires organizer permissions.
 * @summary Change ride slug
 */
export const changeRideSlug = (
  teamSlug: string,
  rideSlug: string,
  slugChangeRequest: BodyType<SlugChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideDto>(
    {
      url: `/api/teams/${teamSlug}/rides/${rideSlug}/slug`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: slugChangeRequest,
      signal,
    },
    options
  )
}

export const getChangeRideSlugMutationKey = () => ['changeRideSlug'] as const

export const getChangeRideSlugMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changeRideSlug>>,
    TError,
    ChangeRideSlugMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changeRideSlug>>,
  TError,
  ChangeRideSlugMutationVariables,
  TContext
> => {
  const mutationKey = getChangeRideSlugMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changeRideSlug>>,
    ChangeRideSlugMutationVariables
  > = (props) => {
    const { teamSlug, rideSlug, data } = props ?? {}

    return changeRideSlug(teamSlug, rideSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangeRideSlugMutationResult = NonNullable<Awaited<ReturnType<typeof changeRideSlug>>>
export type ChangeRideSlugMutationBody = BodyType<SlugChangeRequest>
export type ChangeRideSlugMutationError = ErrorType<ErrorResponse>
export type ChangeRideSlugMutationVariables = {
  teamSlug: string
  rideSlug: string
  data: BodyType<SlugChangeRequest>
}

/**
 * @summary Change ride slug
 */
export const useChangeRideSlug = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changeRideSlug>>,
      TError,
      ChangeRideSlugMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changeRideSlug>>,
  TError,
  ChangeRideSlugMutationVariables,
  TContext
> => {
  return useMutation(getChangeRideSlugMutationOptions(options), queryClient)
}
/**
 * Change the ride's status and nothing else — what a list row can do without the full ride. Same side effects as a status change through the update. Requires organizer permissions.
 * @summary Change ride status
 */
export const changeRideStatus = (
  teamSlug: string,
  rideSlug: string,
  statusChangeRequest: BodyType<StatusChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideDto>(
    {
      url: `/api/teams/${teamSlug}/rides/${rideSlug}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: statusChangeRequest,
      signal,
    },
    options
  )
}

export const getChangeRideStatusMutationKey = () => ['changeRideStatus'] as const

export const getChangeRideStatusMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changeRideStatus>>,
    TError,
    ChangeRideStatusMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changeRideStatus>>,
  TError,
  ChangeRideStatusMutationVariables,
  TContext
> => {
  const mutationKey = getChangeRideStatusMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changeRideStatus>>,
    ChangeRideStatusMutationVariables
  > = (props) => {
    const { teamSlug, rideSlug, data } = props ?? {}

    return changeRideStatus(teamSlug, rideSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangeRideStatusMutationResult = NonNullable<
  Awaited<ReturnType<typeof changeRideStatus>>
>
export type ChangeRideStatusMutationBody = BodyType<StatusChangeRequest>
export type ChangeRideStatusMutationError = ErrorType<ErrorResponse>
export type ChangeRideStatusMutationVariables = {
  teamSlug: string
  rideSlug: string
  data: BodyType<StatusChangeRequest>
}

/**
 * @summary Change ride status
 */
export const useChangeRideStatus = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changeRideStatus>>,
      TError,
      ChangeRideStatusMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changeRideStatus>>,
  TError,
  ChangeRideStatusMutationVariables,
  TContext
> => {
  return useMutation(getChangeRideStatusMutationOptions(options), queryClient)
}
/**
 * Restore a soft-deleted ride. Requires organizer permissions.
 * @summary Restore ride
 */
export const undeleteRide = (
  teamSlug: string,
  rideSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideDto>(
    { url: `/api/teams/${teamSlug}/rides/${rideSlug}/undelete`, method: 'POST', signal },
    options
  )
}

export const getUndeleteRideMutationKey = () => ['undeleteRide'] as const

export const getUndeleteRideMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof undeleteRide>>,
    TError,
    UndeleteRideMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof undeleteRide>>,
  TError,
  UndeleteRideMutationVariables,
  TContext
> => {
  const mutationKey = getUndeleteRideMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof undeleteRide>>,
    UndeleteRideMutationVariables
  > = (props) => {
    const { teamSlug, rideSlug } = props ?? {}

    return undeleteRide(teamSlug, rideSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UndeleteRideMutationResult = NonNullable<Awaited<ReturnType<typeof undeleteRide>>>

export type UndeleteRideMutationError = ErrorType<ErrorResponse>
export type UndeleteRideMutationVariables = { teamSlug: string; rideSlug: string }

/**
 * @summary Restore ride
 */
export const useUndeleteRide = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof undeleteRide>>,
      TError,
      UndeleteRideMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof undeleteRide>>,
  TError,
  UndeleteRideMutationVariables,
  TContext
> => {
  return useMutation(getUndeleteRideMutationOptions(options), queryClient)
}
/**
 * The forecast for the ride: at the meeting point when it leaves, then along each group's route at its estimated passages (group speed, else 25 km/h). Read from the server's cache only — the forecast is refreshed in the background, never on request. Readable by whoever may read the ride, and then always 200: the state is in status. Cache-Control: private, no-cache with an ETag (revalidate with If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.
 * @summary Get ride weather
 */
export const getRideWeather = (
  teamSlug: string,
  rideSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideWeatherDto>(
    { url: `/api/teams/${teamSlug}/rides/${rideSlug}/weather`, method: 'GET', signal },
    options
  )
}

export const getGetRideWeatherQueryKey = (teamSlug: string, rideSlug: string) => {
  return [`/api/teams/${teamSlug}/rides/${rideSlug}/weather`] as const
}

export const getGetRideWeatherQueryOptions = <
  TData = Awaited<ReturnType<typeof getRideWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRideWeatherQueryKey(teamSlug, rideSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRideWeather>>> = ({ signal }) =>
    getRideWeather(teamSlug, rideSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && rideSlug !== null && rideSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getRideWeather>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetRideWeatherQueryResult = NonNullable<Awaited<ReturnType<typeof getRideWeather>>>
export type GetRideWeatherQueryError = ErrorType<void | ErrorResponse>

export function useGetRideWeather<
  TData = Awaited<ReturnType<typeof getRideWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideWeather>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRideWeather>>,
          TError,
          Awaited<ReturnType<typeof getRideWeather>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRideWeather<
  TData = Awaited<ReturnType<typeof getRideWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideWeather>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRideWeather>>,
          TError,
          Awaited<ReturnType<typeof getRideWeather>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useGetRideWeather<
  TData = Awaited<ReturnType<typeof getRideWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Get ride weather
 */

export function useGetRideWeather<
  TData = Awaited<ReturnType<typeof getRideWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRideWeatherQueryOptions(teamSlug, rideSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Get ride weather
 */
export const prefetchGetRideWeatherQuery = async <
  TData = Awaited<ReturnType<typeof getRideWeather>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  rideSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getRideWeather>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRideWeatherQueryOptions(teamSlug, rideSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
