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
  ListAdminReportsParams,
  ModerationDecisionRequest,
  ModerationQueueResponse,
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
 * Reports of every team of the domain, grouped by target, with the reporters. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided.
 * @summary List the platform moderation queue
 */
export const listAdminReports = (
  params?: ListAdminReportsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<ModerationQueueResponse>(
    { url: `/api/admin/reports`, method: 'GET', params, signal },
    options
  )
}

export const getListAdminReportsQueryKey = (params?: ListAdminReportsParams) => {
  return [`/api/admin/reports`, ...(params ? [params] : [])] as const
}

export const getListAdminReportsQueryOptions = <
  TData = Awaited<ReturnType<typeof listAdminReports>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListAdminReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAdminReports>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListAdminReportsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listAdminReports>>> = ({ signal }) =>
    listAdminReports(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listAdminReports>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListAdminReportsQueryResult = NonNullable<Awaited<ReturnType<typeof listAdminReports>>>
export type ListAdminReportsQueryError = ErrorType<void | ErrorResponse>

/**
 * Reports of every team of the domain, grouped by target, with the reporters. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided.
 * @summary List the platform moderation queue
 */
export function useListAdminReports<
  TData = Awaited<ReturnType<typeof listAdminReports>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: undefined | ListAdminReportsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAdminReports>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listAdminReports>>,
          TError,
          Awaited<ReturnType<typeof listAdminReports>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Reports of every team of the domain, grouped by target, with the reporters. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided.
 * @summary List the platform moderation queue
 */
export function useListAdminReports<
  TData = Awaited<ReturnType<typeof listAdminReports>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListAdminReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAdminReports>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listAdminReports>>,
          TError,
          Awaited<ReturnType<typeof listAdminReports>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Reports of every team of the domain, grouped by target, with the reporters. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided.
 * @summary List the platform moderation queue
 */
export function useListAdminReports<
  TData = Awaited<ReturnType<typeof listAdminReports>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListAdminReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAdminReports>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Reports of every team of the domain, grouped by target, with the reporters. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided.
 * @summary List the platform moderation queue
 */
export function useListAdminReports<
  TData = Awaited<ReturnType<typeof listAdminReports>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListAdminReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAdminReports>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListAdminReportsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Reports of every team of the domain, grouped by target, with the reporters. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided.
 * @summary List the platform moderation queue
 */
export const prefetchListAdminReportsQuery = async <
  TData = Awaited<ReturnType<typeof listAdminReports>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: ListAdminReportsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAdminReports>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListAdminReportsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Applies the decision to every open report of one queue item: the target in the team named by teamSlug, or in every team when teamSlug is omitted. REMOVE_CONTENT deletes the content (not allowed on a member); DISMISS keeps it, and shows it again if reports had hidden it.
 * @summary Decide about a reported target, in any team
 */
export const resolveAdminReports = (
  moderationDecisionRequest: BodyType<ModerationDecisionRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/admin/reports/resolve`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: moderationDecisionRequest,
      signal,
    },
    options
  )
}

export const getResolveAdminReportsMutationKey = () => ['resolveAdminReports'] as const

export const getResolveAdminReportsMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof resolveAdminReports>>,
    TError,
    ResolveAdminReportsMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof resolveAdminReports>>,
  TError,
  ResolveAdminReportsMutationVariables,
  TContext
> => {
  const mutationKey = getResolveAdminReportsMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof resolveAdminReports>>,
    ResolveAdminReportsMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return resolveAdminReports(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ResolveAdminReportsMutationResult = NonNullable<
  Awaited<ReturnType<typeof resolveAdminReports>>
>
export type ResolveAdminReportsMutationBody = BodyType<ModerationDecisionRequest>
export type ResolveAdminReportsMutationError = ErrorType<ErrorResponse | void>
export type ResolveAdminReportsMutationVariables = { data: BodyType<ModerationDecisionRequest> }

/**
 * Applies the decision to every open report of one queue item: the target in the team named by teamSlug, or in every team when teamSlug is omitted. REMOVE_CONTENT deletes the content (not allowed on a member); DISMISS keeps it, and shows it again if reports had hidden it.
 * @summary Decide about a reported target, in any team
 */
export const useResolveAdminReports = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof resolveAdminReports>>,
      TError,
      ResolveAdminReportsMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof resolveAdminReports>>,
  TError,
  ResolveAdminReportsMutationVariables,
  TContext
> => {
  return useMutation(getResolveAdminReportsMutationOptions(options), queryClient)
}
