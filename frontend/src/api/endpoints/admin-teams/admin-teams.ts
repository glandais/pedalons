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
  AdminListTeamsParams,
  AdminTeamAttributesRequest,
  AdminTeamDto,
  AdminTeamListResponse,
  ErrorResponse,
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
 * Get a paginated list of all teams
 * @summary List all teams
 */
export const adminListTeams = (
  params?: AdminListTeamsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminTeamListResponse>(
    { url: `/api/admin/teams`, method: 'GET', params, signal },
    options
  )
}

export const getAdminListTeamsQueryKey = (params?: AdminListTeamsParams) => {
  return [`/api/admin/teams`, ...(params ? [params] : [])] as const
}

export const getAdminListTeamsQueryOptions = <
  TData = Awaited<ReturnType<typeof adminListTeams>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: AdminListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminListTeams>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getAdminListTeamsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof adminListTeams>>> = ({ signal }) =>
    adminListTeams(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof adminListTeams>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type AdminListTeamsQueryResult = NonNullable<Awaited<ReturnType<typeof adminListTeams>>>
export type AdminListTeamsQueryError = ErrorType<void | ErrorResponse>

/**
 * Get a paginated list of all teams
 * @summary List all teams
 */
export function useAdminListTeams<
  TData = Awaited<ReturnType<typeof adminListTeams>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: undefined | AdminListTeamsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminListTeams>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof adminListTeams>>,
          TError,
          Awaited<ReturnType<typeof adminListTeams>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all teams
 * @summary List all teams
 */
export function useAdminListTeams<
  TData = Awaited<ReturnType<typeof adminListTeams>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: AdminListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminListTeams>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof adminListTeams>>,
          TError,
          Awaited<ReturnType<typeof adminListTeams>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all teams
 * @summary List all teams
 */
export function useAdminListTeams<
  TData = Awaited<ReturnType<typeof adminListTeams>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: AdminListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminListTeams>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all teams
 * @summary List all teams
 */
export function useAdminListTeams<
  TData = Awaited<ReturnType<typeof adminListTeams>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: AdminListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminListTeams>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getAdminListTeamsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get a paginated list of all teams
 * @summary List all teams
 */
export const prefetchAdminListTeamsQuery = async <
  TData = Awaited<ReturnType<typeof adminListTeams>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: AdminListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminListTeams>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getAdminListTeamsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get detailed team information
 * @summary Get team details
 */
export const adminGetTeam = (
  teamId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminTeamDto>(
    { url: `/api/admin/teams/${teamId}`, method: 'GET', signal },
    options
  )
}

export const getAdminGetTeamQueryKey = (teamId: string) => {
  return [`/api/admin/teams/${teamId}`] as const
}

export const getAdminGetTeamQueryOptions = <
  TData = Awaited<ReturnType<typeof adminGetTeam>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminGetTeam>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getAdminGetTeamQueryKey(teamId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof adminGetTeam>>> = ({ signal }) =>
    adminGetTeam(teamId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamId !== null && teamId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof adminGetTeam>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type AdminGetTeamQueryResult = NonNullable<Awaited<ReturnType<typeof adminGetTeam>>>
export type AdminGetTeamQueryError = ErrorType<void | ErrorResponse>

/**
 * Get detailed team information
 * @summary Get team details
 */
export function useAdminGetTeam<
  TData = Awaited<ReturnType<typeof adminGetTeam>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamId: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminGetTeam>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof adminGetTeam>>,
          TError,
          Awaited<ReturnType<typeof adminGetTeam>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed team information
 * @summary Get team details
 */
export function useAdminGetTeam<
  TData = Awaited<ReturnType<typeof adminGetTeam>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminGetTeam>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof adminGetTeam>>,
          TError,
          Awaited<ReturnType<typeof adminGetTeam>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed team information
 * @summary Get team details
 */
export function useAdminGetTeam<
  TData = Awaited<ReturnType<typeof adminGetTeam>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminGetTeam>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed team information
 * @summary Get team details
 */
export function useAdminGetTeam<
  TData = Awaited<ReturnType<typeof adminGetTeam>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminGetTeam>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getAdminGetTeamQueryOptions(teamId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed team information
 * @summary Get team details
 */
export const prefetchAdminGetTeamQuery = async <
  TData = Awaited<ReturnType<typeof adminGetTeam>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof adminGetTeam>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getAdminGetTeamQueryOptions(teamId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Update platform-controlled team governance attributes
 * @summary Update team governance attributes
 */
export const adminUpdateTeamAttributes = (
  teamId: string,
  adminTeamAttributesRequest: BodyType<AdminTeamAttributesRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminTeamDto>(
    {
      url: `/api/admin/teams/${teamId}/attributes`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: adminTeamAttributesRequest,
      signal,
    },
    options
  )
}

export const getAdminUpdateTeamAttributesMutationKey = () => ['adminUpdateTeamAttributes'] as const

export const getAdminUpdateTeamAttributesMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof adminUpdateTeamAttributes>>,
    TError,
    AdminUpdateTeamAttributesMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof adminUpdateTeamAttributes>>,
  TError,
  AdminUpdateTeamAttributesMutationVariables,
  TContext
> => {
  const mutationKey = getAdminUpdateTeamAttributesMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof adminUpdateTeamAttributes>>,
    AdminUpdateTeamAttributesMutationVariables
  > = (props) => {
    const { teamId, data } = props ?? {}

    return adminUpdateTeamAttributes(teamId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AdminUpdateTeamAttributesMutationResult = NonNullable<
  Awaited<ReturnType<typeof adminUpdateTeamAttributes>>
>
export type AdminUpdateTeamAttributesMutationBody = BodyType<AdminTeamAttributesRequest>
export type AdminUpdateTeamAttributesMutationError = ErrorType<void | ErrorResponse>
export type AdminUpdateTeamAttributesMutationVariables = {
  teamId: string
  data: BodyType<AdminTeamAttributesRequest>
}

/**
 * Update platform-controlled team governance attributes
 * @summary Update team governance attributes
 */
export const useAdminUpdateTeamAttributes = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof adminUpdateTeamAttributes>>,
      TError,
      AdminUpdateTeamAttributesMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof adminUpdateTeamAttributes>>,
  TError,
  AdminUpdateTeamAttributesMutationVariables,
  TContext
> => {
  return useMutation(getAdminUpdateTeamAttributesMutationOptions(options), queryClient)
}
/**
 * Toggle team soft-delete status (archive/restore)
 * @summary Toggle team deleted
 */
export const adminToggleTeamDeleted = (
  teamId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminTeamDto>(
    { url: `/api/admin/teams/${teamId}/toggle-deleted`, method: 'POST', signal },
    options
  )
}

export const getAdminToggleTeamDeletedMutationKey = () => ['adminToggleTeamDeleted'] as const

export const getAdminToggleTeamDeletedMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof adminToggleTeamDeleted>>,
    TError,
    AdminToggleTeamDeletedMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof adminToggleTeamDeleted>>,
  TError,
  AdminToggleTeamDeletedMutationVariables,
  TContext
> => {
  const mutationKey = getAdminToggleTeamDeletedMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof adminToggleTeamDeleted>>,
    AdminToggleTeamDeletedMutationVariables
  > = (props) => {
    const { teamId } = props ?? {}

    return adminToggleTeamDeleted(teamId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AdminToggleTeamDeletedMutationResult = NonNullable<
  Awaited<ReturnType<typeof adminToggleTeamDeleted>>
>

export type AdminToggleTeamDeletedMutationError = ErrorType<void | ErrorResponse>
export type AdminToggleTeamDeletedMutationVariables = { teamId: string }

/**
 * Toggle team soft-delete status (archive/restore)
 * @summary Toggle team deleted
 */
export const useAdminToggleTeamDeleted = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof adminToggleTeamDeleted>>,
      TError,
      AdminToggleTeamDeletedMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof adminToggleTeamDeleted>>,
  TError,
  AdminToggleTeamDeletedMutationVariables,
  TContext
> => {
  return useMutation(getAdminToggleTeamDeletedMutationOptions(options), queryClient)
}
