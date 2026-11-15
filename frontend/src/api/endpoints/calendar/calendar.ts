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
  CalendarEventsResponse,
  CalendarTokenDto,
  ErrorResponse,
  GetEventsParams,
  GetGlobalIcsFeedParams,
  GetTeamEventsParams,
  GetTeamIcsFeedParams,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType } from '../../../lib/axiosInstance.ts'

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
 * Get calendar events for all teams the user belongs to
 * @summary Get calendar events
 */
export const getEvents = (
  params?: GetEventsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CalendarEventsResponse>(
    { url: `/api/calendar/events`, method: 'GET', params, signal },
    options
  )
}

export const getGetEventsQueryKey = (params?: GetEventsParams) => {
  return [`/api/calendar/events`, ...(params ? [params] : [])] as const
}

export const getGetEventsQueryOptions = <
  TData = Awaited<ReturnType<typeof getEvents>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: GetEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getEvents>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetEventsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getEvents>>> = ({ signal }) =>
    getEvents(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getEvents>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetEventsQueryResult = NonNullable<Awaited<ReturnType<typeof getEvents>>>
export type GetEventsQueryError = ErrorType<ErrorResponse | void>

/**
 * Get calendar events for all teams the user belongs to
 * @summary Get calendar events
 */
export function useGetEvents<
  TData = Awaited<ReturnType<typeof getEvents>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params: undefined | GetEventsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getEvents>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getEvents>>,
          TError,
          Awaited<ReturnType<typeof getEvents>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get calendar events for all teams the user belongs to
 * @summary Get calendar events
 */
export function useGetEvents<
  TData = Awaited<ReturnType<typeof getEvents>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: GetEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getEvents>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getEvents>>,
          TError,
          Awaited<ReturnType<typeof getEvents>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get calendar events for all teams the user belongs to
 * @summary Get calendar events
 */
export function useGetEvents<
  TData = Awaited<ReturnType<typeof getEvents>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: GetEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getEvents>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get calendar events for all teams the user belongs to
 * @summary Get calendar events
 */
export function useGetEvents<
  TData = Awaited<ReturnType<typeof getEvents>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: GetEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getEvents>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetEventsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get calendar events for all teams the user belongs to
 * @summary Get calendar events
 */
export const prefetchGetEventsQuery = async <
  TData = Awaited<ReturnType<typeof getEvents>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  params?: GetEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getEvents>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetEventsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get ICS calendar feed for all user's teams (requires token)
 * @summary Get global ICS feed
 */
export const getGlobalIcsFeed = (
  params?: GetGlobalIcsFeedParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>({ url: `/api/calendar/ics`, method: 'GET', params, signal }, options)
}

export const getGetGlobalIcsFeedQueryKey = (params?: GetGlobalIcsFeedParams) => {
  return [`/api/calendar/ics`, ...(params ? [params] : [])] as const
}

export const getGetGlobalIcsFeedQueryOptions = <
  TData = Awaited<ReturnType<typeof getGlobalIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: GetGlobalIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getGlobalIcsFeed>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetGlobalIcsFeedQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getGlobalIcsFeed>>> = ({ signal }) =>
    getGlobalIcsFeed(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getGlobalIcsFeed>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetGlobalIcsFeedQueryResult = NonNullable<Awaited<ReturnType<typeof getGlobalIcsFeed>>>
export type GetGlobalIcsFeedQueryError = ErrorType<ErrorResponse>

/**
 * Get ICS calendar feed for all user's teams (requires token)
 * @summary Get global ICS feed
 */
export function useGetGlobalIcsFeed<
  TData = Awaited<ReturnType<typeof getGlobalIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  params: undefined | GetGlobalIcsFeedParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getGlobalIcsFeed>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getGlobalIcsFeed>>,
          TError,
          Awaited<ReturnType<typeof getGlobalIcsFeed>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get ICS calendar feed for all user's teams (requires token)
 * @summary Get global ICS feed
 */
export function useGetGlobalIcsFeed<
  TData = Awaited<ReturnType<typeof getGlobalIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: GetGlobalIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getGlobalIcsFeed>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getGlobalIcsFeed>>,
          TError,
          Awaited<ReturnType<typeof getGlobalIcsFeed>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get ICS calendar feed for all user's teams (requires token)
 * @summary Get global ICS feed
 */
export function useGetGlobalIcsFeed<
  TData = Awaited<ReturnType<typeof getGlobalIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: GetGlobalIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getGlobalIcsFeed>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get ICS calendar feed for all user's teams (requires token)
 * @summary Get global ICS feed
 */
export function useGetGlobalIcsFeed<
  TData = Awaited<ReturnType<typeof getGlobalIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  params?: GetGlobalIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getGlobalIcsFeed>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetGlobalIcsFeedQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get ICS calendar feed for all user's teams (requires token)
 * @summary Get global ICS feed
 */
export const prefetchGetGlobalIcsFeedQuery = async <
  TData = Awaited<ReturnType<typeof getGlobalIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: GetGlobalIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getGlobalIcsFeed>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetGlobalIcsFeedQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get or create the user's calendar token for ICS feed access
 * @summary Get calendar token
 */
export const getToken = (options?: SecondParameter<typeof axiosMutator>, signal?: AbortSignal) => {
  return axiosMutator<CalendarTokenDto>(
    { url: `/api/calendar/token`, method: 'GET', signal },
    options
  )
}

export const getGetTokenQueryKey = () => {
  return [`/api/calendar/token`] as const
}

export const getGetTokenQueryOptions = <
  TData = Awaited<ReturnType<typeof getToken>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getToken>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTokenQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getToken>>> = ({ signal }) =>
    getToken(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getToken>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetTokenQueryResult = NonNullable<Awaited<ReturnType<typeof getToken>>>
export type GetTokenQueryError = ErrorType<ErrorResponse | void>

/**
 * Get or create the user's calendar token for ICS feed access
 * @summary Get calendar token
 */
export function useGetToken<
  TData = Awaited<ReturnType<typeof getToken>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getToken>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getToken>>,
          TError,
          Awaited<ReturnType<typeof getToken>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get or create the user's calendar token for ICS feed access
 * @summary Get calendar token
 */
export function useGetToken<
  TData = Awaited<ReturnType<typeof getToken>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getToken>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getToken>>,
          TError,
          Awaited<ReturnType<typeof getToken>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get or create the user's calendar token for ICS feed access
 * @summary Get calendar token
 */
export function useGetToken<
  TData = Awaited<ReturnType<typeof getToken>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getToken>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get or create the user's calendar token for ICS feed access
 * @summary Get calendar token
 */
export function useGetToken<
  TData = Awaited<ReturnType<typeof getToken>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getToken>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTokenQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get or create the user's calendar token for ICS feed access
 * @summary Get calendar token
 */
export const prefetchGetTokenQuery = async <
  TData = Awaited<ReturnType<typeof getToken>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getToken>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTokenQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Regenerate the user's calendar token, invalidating the old one
 * @summary Regenerate calendar token
 */
export const regenerateToken = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CalendarTokenDto>(
    { url: `/api/calendar/token/regenerate`, method: 'POST', signal },
    options
  )
}

export const getRegenerateTokenMutationKey = () => ['regenerateToken'] as const

export const getRegenerateTokenMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<Awaited<ReturnType<typeof regenerateToken>>, TError, void, TContext>
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<Awaited<ReturnType<typeof regenerateToken>>, TError, void, TContext> => {
  const mutationKey = getRegenerateTokenMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof regenerateToken>>, void> = () => {
    return regenerateToken(requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RegenerateTokenMutationResult = NonNullable<Awaited<ReturnType<typeof regenerateToken>>>

export type RegenerateTokenMutationError = ErrorType<ErrorResponse | void>

/**
 * Regenerate the user's calendar token, invalidating the old one
 * @summary Regenerate calendar token
 */
export const useRegenerateToken = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof regenerateToken>>,
      TError,
      void,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<Awaited<ReturnType<typeof regenerateToken>>, TError, void, TContext> => {
  return useMutation(getRegenerateTokenMutationOptions(options), queryClient)
}
/**
 * Get calendar events for a specific team
 * @summary Get team calendar events
 */
export const getTeamEvents = (
  teamSlug: string,
  params?: GetTeamEventsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CalendarEventsResponse>(
    { url: `/api/teams/${teamSlug}/calendar/events`, method: 'GET', params, signal },
    options
  )
}

export const getGetTeamEventsQueryKey = (teamSlug: string, params?: GetTeamEventsParams) => {
  return [`/api/teams/${teamSlug}/calendar/events`, ...(params ? [params] : [])] as const
}

export const getGetTeamEventsQueryOptions = <
  TData = Awaited<ReturnType<typeof getTeamEvents>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamEvents>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTeamEventsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTeamEvents>>> = ({ signal }) =>
    getTeamEvents(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTeamEvents>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTeamEventsQueryResult = NonNullable<Awaited<ReturnType<typeof getTeamEvents>>>
export type GetTeamEventsQueryError = ErrorType<ErrorResponse>

/**
 * Get calendar events for a specific team
 * @summary Get team calendar events
 */
export function useGetTeamEvents<
  TData = Awaited<ReturnType<typeof getTeamEvents>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | GetTeamEventsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamEvents>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamEvents>>,
          TError,
          Awaited<ReturnType<typeof getTeamEvents>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get calendar events for a specific team
 * @summary Get team calendar events
 */
export function useGetTeamEvents<
  TData = Awaited<ReturnType<typeof getTeamEvents>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamEvents>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamEvents>>,
          TError,
          Awaited<ReturnType<typeof getTeamEvents>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get calendar events for a specific team
 * @summary Get team calendar events
 */
export function useGetTeamEvents<
  TData = Awaited<ReturnType<typeof getTeamEvents>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamEvents>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get calendar events for a specific team
 * @summary Get team calendar events
 */
export function useGetTeamEvents<
  TData = Awaited<ReturnType<typeof getTeamEvents>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamEvents>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTeamEventsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get calendar events for a specific team
 * @summary Get team calendar events
 */
export const prefetchGetTeamEventsQuery = async <
  TData = Awaited<ReturnType<typeof getTeamEvents>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: GetTeamEventsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamEvents>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTeamEventsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get ICS calendar feed for a specific team (requires token)
 * @summary Get team ICS feed
 */
export const getTeamIcsFeed = (
  teamSlug: string,
  params?: GetTeamIcsFeedParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>(
    { url: `/api/teams/${teamSlug}/calendar/ics`, method: 'GET', params, signal },
    options
  )
}

export const getGetTeamIcsFeedQueryKey = (teamSlug: string, params?: GetTeamIcsFeedParams) => {
  return [`/api/teams/${teamSlug}/calendar/ics`, ...(params ? [params] : [])] as const
}

export const getGetTeamIcsFeedQueryOptions = <
  TData = Awaited<ReturnType<typeof getTeamIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamIcsFeed>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTeamIcsFeedQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTeamIcsFeed>>> = ({ signal }) =>
    getTeamIcsFeed(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTeamIcsFeed>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTeamIcsFeedQueryResult = NonNullable<Awaited<ReturnType<typeof getTeamIcsFeed>>>
export type GetTeamIcsFeedQueryError = ErrorType<ErrorResponse>

/**
 * Get ICS calendar feed for a specific team (requires token)
 * @summary Get team ICS feed
 */
export function useGetTeamIcsFeed<
  TData = Awaited<ReturnType<typeof getTeamIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | GetTeamIcsFeedParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamIcsFeed>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamIcsFeed>>,
          TError,
          Awaited<ReturnType<typeof getTeamIcsFeed>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get ICS calendar feed for a specific team (requires token)
 * @summary Get team ICS feed
 */
export function useGetTeamIcsFeed<
  TData = Awaited<ReturnType<typeof getTeamIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamIcsFeed>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamIcsFeed>>,
          TError,
          Awaited<ReturnType<typeof getTeamIcsFeed>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get ICS calendar feed for a specific team (requires token)
 * @summary Get team ICS feed
 */
export function useGetTeamIcsFeed<
  TData = Awaited<ReturnType<typeof getTeamIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamIcsFeed>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get ICS calendar feed for a specific team (requires token)
 * @summary Get team ICS feed
 */
export function useGetTeamIcsFeed<
  TData = Awaited<ReturnType<typeof getTeamIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamIcsFeed>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTeamIcsFeedQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get ICS calendar feed for a specific team (requires token)
 * @summary Get team ICS feed
 */
export const prefetchGetTeamIcsFeedQuery = async <
  TData = Awaited<ReturnType<typeof getTeamIcsFeed>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: GetTeamIcsFeedParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamIcsFeed>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTeamIcsFeedQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
