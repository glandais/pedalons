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
  BlockedUsersResponse,
  ErrorResponse,
  ListTeamReportsParams,
  ModerationDecisionRequest,
  ModerationQueueResponse,
  ReportRequest,
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
 * Files a report in a team, about a comment, a publication, an ad, a route or a member the caller can read there. Idempotent: reporting the same target again changes nothing. The target disappears from the caller's lists at once; the team's organizers and administrators are notified, without the caller's name.
 * @summary Report content or a member
 */
export const reportContent = (
  reportRequest: BodyType<ReportRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/reports`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: reportRequest,
      signal,
    },
    options
  )
}

export const getReportContentMutationKey = () => ['reportContent'] as const

export const getReportContentMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof reportContent>>,
    TError,
    ReportContentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof reportContent>>,
  TError,
  ReportContentMutationVariables,
  TContext
> => {
  const mutationKey = getReportContentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof reportContent>>,
    ReportContentMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return reportContent(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ReportContentMutationResult = NonNullable<Awaited<ReturnType<typeof reportContent>>>
export type ReportContentMutationBody = BodyType<ReportRequest>
export type ReportContentMutationError = ErrorType<ErrorResponse | void>
export type ReportContentMutationVariables = { data: BodyType<ReportRequest> }

/**
 * Files a report in a team, about a comment, a publication, an ad, a route or a member the caller can read there. Idempotent: reporting the same target again changes nothing. The target disappears from the caller's lists at once; the team's organizers and administrators are notified, without the caller's name.
 * @summary Report content or a member
 */
export const useReportContent = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof reportContent>>,
      TError,
      ReportContentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof reportContent>>,
  TError,
  ReportContentMutationVariables,
  TContext
> => {
  return useMutation(getReportContentMutationOptions(options), queryClient)
}
/**
 * Reports grouped by target, without the reporters' identities. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided. Reports about the caller — their content, or themselves — are left out.
 * @summary List the team's moderation queue
 */
export const listTeamReports = (
  teamSlug: string,
  params?: ListTeamReportsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<ModerationQueueResponse>(
    { url: `/api/teams/${teamSlug}/reports`, method: 'GET', params, signal },
    options
  )
}

export const getListTeamReportsQueryKey = (teamSlug: string, params?: ListTeamReportsParams) => {
  return [`/api/teams/${teamSlug}/reports`, ...(params ? [params] : [])] as const
}

export const getListTeamReportsQueryOptions = <
  TData = Awaited<ReturnType<typeof listTeamReports>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTeamReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamReports>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListTeamReportsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listTeamReports>>> = ({ signal }) =>
    listTeamReports(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listTeamReports>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListTeamReportsQueryResult = NonNullable<Awaited<ReturnType<typeof listTeamReports>>>
export type ListTeamReportsQueryError = ErrorType<ErrorResponse>

/**
 * Reports grouped by target, without the reporters' identities. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided. Reports about the caller — their content, or themselves — are left out.
 * @summary List the team's moderation queue
 */
export function useListTeamReports<
  TData = Awaited<ReturnType<typeof listTeamReports>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | ListTeamReportsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamReports>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTeamReports>>,
          TError,
          Awaited<ReturnType<typeof listTeamReports>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Reports grouped by target, without the reporters' identities. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided. Reports about the caller — their content, or themselves — are left out.
 * @summary List the team's moderation queue
 */
export function useListTeamReports<
  TData = Awaited<ReturnType<typeof listTeamReports>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTeamReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamReports>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTeamReports>>,
          TError,
          Awaited<ReturnType<typeof listTeamReports>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Reports grouped by target, without the reporters' identities. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided. Reports about the caller — their content, or themselves — are left out.
 * @summary List the team's moderation queue
 */
export function useListTeamReports<
  TData = Awaited<ReturnType<typeof listTeamReports>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTeamReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamReports>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Reports grouped by target, without the reporters' identities. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided. Reports about the caller — their content, or themselves — are left out.
 * @summary List the team's moderation queue
 */
export function useListTeamReports<
  TData = Awaited<ReturnType<typeof listTeamReports>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTeamReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamReports>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListTeamReportsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Reports grouped by target, without the reporters' identities. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided. Reports about the caller — their content, or themselves — are left out.
 * @summary List the team's moderation queue
 */
export const prefetchListTeamReportsQuery = async <
  TData = Awaited<ReturnType<typeof listTeamReports>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: ListTeamReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamReports>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListTeamReportsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Applies the decision to every open report of the target. REMOVE_CONTENT deletes the content (not allowed on a member); DISMISS keeps it, and shows it again if reports had hidden it.
 * @summary Decide about a reported target
 */
export const resolveTeamReports = (
  teamSlug: string,
  moderationDecisionRequest: BodyType<ModerationDecisionRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/teams/${teamSlug}/reports/resolve`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: moderationDecisionRequest,
      signal,
    },
    options
  )
}

export const getResolveTeamReportsMutationKey = () => ['resolveTeamReports'] as const

export const getResolveTeamReportsMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof resolveTeamReports>>,
    TError,
    ResolveTeamReportsMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof resolveTeamReports>>,
  TError,
  ResolveTeamReportsMutationVariables,
  TContext
> => {
  const mutationKey = getResolveTeamReportsMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof resolveTeamReports>>,
    ResolveTeamReportsMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return resolveTeamReports(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ResolveTeamReportsMutationResult = NonNullable<
  Awaited<ReturnType<typeof resolveTeamReports>>
>
export type ResolveTeamReportsMutationBody = BodyType<ModerationDecisionRequest>
export type ResolveTeamReportsMutationError = ErrorType<ErrorResponse>
export type ResolveTeamReportsMutationVariables = {
  teamSlug: string
  data: BodyType<ModerationDecisionRequest>
}

/**
 * Applies the decision to every open report of the target. REMOVE_CONTENT deletes the content (not allowed on a member); DISMISS keeps it, and shows it again if reports had hidden it.
 * @summary Decide about a reported target
 */
export const useResolveTeamReports = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof resolveTeamReports>>,
      TError,
      ResolveTeamReportsMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof resolveTeamReports>>,
  TError,
  ResolveTeamReportsMutationVariables,
  TContext
> => {
  return useMutation(getResolveTeamReportsMutationOptions(options), queryClient)
}
/**
 * Most recent first.
 * @summary List the members I blocked
 */
export const listMyBlockedUsers = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<BlockedUsersResponse>(
    { url: `/api/users/me/blocks`, method: 'GET', signal },
    options
  )
}

export const getListMyBlockedUsersQueryKey = () => {
  return [`/api/users/me/blocks`] as const
}

export const getListMyBlockedUsersQueryOptions = <
  TData = Awaited<ReturnType<typeof listMyBlockedUsers>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyBlockedUsers>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListMyBlockedUsersQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listMyBlockedUsers>>> = ({ signal }) =>
    listMyBlockedUsers(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listMyBlockedUsers>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListMyBlockedUsersQueryResult = NonNullable<
  Awaited<ReturnType<typeof listMyBlockedUsers>>
>
export type ListMyBlockedUsersQueryError = ErrorType<ErrorResponse | void>

/**
 * Most recent first.
 * @summary List the members I blocked
 */
export function useListMyBlockedUsers<
  TData = Awaited<ReturnType<typeof listMyBlockedUsers>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyBlockedUsers>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listMyBlockedUsers>>,
          TError,
          Awaited<ReturnType<typeof listMyBlockedUsers>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Most recent first.
 * @summary List the members I blocked
 */
export function useListMyBlockedUsers<
  TData = Awaited<ReturnType<typeof listMyBlockedUsers>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listMyBlockedUsers>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listMyBlockedUsers>>,
          TError,
          Awaited<ReturnType<typeof listMyBlockedUsers>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Most recent first.
 * @summary List the members I blocked
 */
export function useListMyBlockedUsers<
  TData = Awaited<ReturnType<typeof listMyBlockedUsers>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyBlockedUsers>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Most recent first.
 * @summary List the members I blocked
 */
export function useListMyBlockedUsers<
  TData = Awaited<ReturnType<typeof listMyBlockedUsers>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyBlockedUsers>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListMyBlockedUsersQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Most recent first.
 * @summary List the members I blocked
 */
export const prefetchListMyBlockedUsersQuery = async <
  TData = Awaited<ReturnType<typeof listMyBlockedUsers>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyBlockedUsers>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListMyBlockedUsersQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Idempotent.
 * @summary Unblock a member
 */
export const unblockUser = (
  userId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/users/me/blocks/${userId}`, method: 'DELETE', signal },
    options
  )
}

export const getUnblockUserMutationKey = () => ['unblockUser'] as const

export const getUnblockUserMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof unblockUser>>,
    TError,
    UnblockUserMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof unblockUser>>,
  TError,
  UnblockUserMutationVariables,
  TContext
> => {
  const mutationKey = getUnblockUserMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof unblockUser>>,
    UnblockUserMutationVariables
  > = (props) => {
    const { userId } = props ?? {}

    return unblockUser(userId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UnblockUserMutationResult = NonNullable<Awaited<ReturnType<typeof unblockUser>>>

export type UnblockUserMutationError = ErrorType<ErrorResponse | void>
export type UnblockUserMutationVariables = { userId: string }

/**
 * Idempotent.
 * @summary Unblock a member
 */
export const useUnblockUser = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof unblockUser>>,
      TError,
      UnblockUserMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof unblockUser>>,
  TError,
  UnblockUserMutationVariables,
  TContext
> => {
  return useMutation(getUnblockUserMutationOptions(options), queryClient)
}
/**
 * Hides the member's comments, posts and ads from the caller, and the comment notifications they cause. Idempotent.
 * @summary Block a member
 */
export const blockUser = (
  userId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/users/me/blocks/${userId}`, method: 'PUT', signal },
    options
  )
}

export const getBlockUserMutationKey = () => ['blockUser'] as const

export const getBlockUserMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof blockUser>>,
    TError,
    BlockUserMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof blockUser>>,
  TError,
  BlockUserMutationVariables,
  TContext
> => {
  const mutationKey = getBlockUserMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof blockUser>>,
    BlockUserMutationVariables
  > = (props) => {
    const { userId } = props ?? {}

    return blockUser(userId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type BlockUserMutationResult = NonNullable<Awaited<ReturnType<typeof blockUser>>>

export type BlockUserMutationError = ErrorType<ErrorResponse | void>
export type BlockUserMutationVariables = { userId: string }

/**
 * Hides the member's comments, posts and ads from the caller, and the comment notifications they cause. Idempotent.
 * @summary Block a member
 */
export const useBlockUser = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof blockUser>>,
      TError,
      BlockUserMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof blockUser>>,
  TError,
  BlockUserMutationVariables,
  TContext
> => {
  return useMutation(getBlockUserMutationOptions(options), queryClient)
}
