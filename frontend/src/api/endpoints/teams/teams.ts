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
  GetTeamTimezoneParams,
  ListTeamsParams,
  PreviewTeamTimezoneChangeParams,
  SlugChangeRequest,
  TeamDashboardDto,
  TeamDetailDto,
  TeamListResponse,
  TeamRequest,
  TeamTimezoneChangePreviewDto,
  TeamTimezoneDto,
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
 * Get a paginated list of public teams with optional search
 * @summary List public teams
 */
export const listTeams = (
  params?: ListTeamsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamListResponse>(
    { url: `/api/teams`, method: 'GET', params, signal },
    options
  )
}

export const getListTeamsQueryKey = (params?: ListTeamsParams) => {
  return [`/api/teams`, ...(params ? [params] : [])] as const
}

export const getListTeamsQueryOptions = <
  TData = Awaited<ReturnType<typeof listTeams>>,
  TError = ErrorType<unknown>,
>(
  params?: ListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeams>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListTeamsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listTeams>>> = ({ signal }) =>
    listTeams(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listTeams>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListTeamsQueryResult = NonNullable<Awaited<ReturnType<typeof listTeams>>>
export type ListTeamsQueryError = ErrorType<unknown>

/**
 * Get a paginated list of public teams with optional search
 * @summary List public teams
 */
export function useListTeams<
  TData = Awaited<ReturnType<typeof listTeams>>,
  TError = ErrorType<unknown>,
>(
  params: undefined | ListTeamsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeams>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTeams>>,
          TError,
          Awaited<ReturnType<typeof listTeams>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of public teams with optional search
 * @summary List public teams
 */
export function useListTeams<
  TData = Awaited<ReturnType<typeof listTeams>>,
  TError = ErrorType<unknown>,
>(
  params?: ListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeams>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTeams>>,
          TError,
          Awaited<ReturnType<typeof listTeams>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of public teams with optional search
 * @summary List public teams
 */
export function useListTeams<
  TData = Awaited<ReturnType<typeof listTeams>>,
  TError = ErrorType<unknown>,
>(
  params?: ListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeams>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of public teams with optional search
 * @summary List public teams
 */
export function useListTeams<
  TData = Awaited<ReturnType<typeof listTeams>>,
  TError = ErrorType<unknown>,
>(
  params?: ListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeams>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListTeamsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get a paginated list of public teams with optional search
 * @summary List public teams
 */
export const prefetchListTeamsQuery = async <
  TData = Awaited<ReturnType<typeof listTeams>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  params?: ListTeamsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeams>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListTeamsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a new team. The current user will be set as the team owner.
 * @summary Create team
 */
export const createTeam = (
  teamRequest: BodyType<TeamRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamDetailDto>(
    {
      url: `/api/teams`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: teamRequest,
      signal,
    },
    options
  )
}

export const getCreateTeamMutationKey = () => ['createTeam'] as const

export const getCreateTeamMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createTeam>>,
    TError,
    CreateTeamMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createTeam>>,
  TError,
  CreateTeamMutationVariables,
  TContext
> => {
  const mutationKey = getCreateTeamMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createTeam>>,
    CreateTeamMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return createTeam(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateTeamMutationResult = NonNullable<Awaited<ReturnType<typeof createTeam>>>
export type CreateTeamMutationBody = BodyType<TeamRequest>
export type CreateTeamMutationError = ErrorType<ErrorResponse | void>
export type CreateTeamMutationVariables = { data: BodyType<TeamRequest> }

/**
 * Create a new team. The current user will be set as the team owner.
 * @summary Create team
 */
export const useCreateTeam = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createTeam>>,
      TError,
      CreateTeamMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createTeam>>,
  TError,
  CreateTeamMutationVariables,
  TContext
> => {
  return useMutation(getCreateTeamMutationOptions(options), queryClient)
}
/**
 * Update team information. Requires ADMIN role.
 * @summary Update team
 */
export const updateTeam = (
  teamSlug: string,
  teamRequest: BodyType<TeamRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamDetailDto>(
    {
      url: `/api/teams/${teamSlug}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: teamRequest,
      signal,
    },
    options
  )
}

export const getUpdateTeamMutationKey = () => ['updateTeam'] as const

export const getUpdateTeamMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateTeam>>,
    TError,
    UpdateTeamMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateTeam>>,
  TError,
  UpdateTeamMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateTeamMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateTeam>>,
    UpdateTeamMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return updateTeam(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateTeamMutationResult = NonNullable<Awaited<ReturnType<typeof updateTeam>>>
export type UpdateTeamMutationBody = BodyType<TeamRequest>
export type UpdateTeamMutationError = ErrorType<ErrorResponse>
export type UpdateTeamMutationVariables = { teamSlug: string; data: BodyType<TeamRequest> }

/**
 * Update team information. Requires ADMIN role.
 * @summary Update team
 */
export const useUpdateTeam = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateTeam>>,
      TError,
      UpdateTeamMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateTeam>>,
  TError,
  UpdateTeamMutationVariables,
  TContext
> => {
  return useMutation(getUpdateTeamMutationOptions(options), queryClient)
}
/**
 * Get detailed team information by URL slug
 * @summary Get team by slug
 */
export const getTeam = (
  teamSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamDetailDto>(
    { url: `/api/teams/${teamSlug}`, method: 'GET', signal },
    options
  )
}

export const getGetTeamQueryKey = (teamSlug: string) => {
  return [`/api/teams/${teamSlug}`] as const
}

export const getGetTeamQueryOptions = <
  TData = Awaited<ReturnType<typeof getTeam>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeam>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTeamQueryKey(teamSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTeam>>> = ({ signal }) =>
    getTeam(teamSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTeam>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTeamQueryResult = NonNullable<Awaited<ReturnType<typeof getTeam>>>
export type GetTeamQueryError = ErrorType<ErrorResponse>

/**
 * Get detailed team information by URL slug
 * @summary Get team by slug
 */
export function useGetTeam<
  TData = Awaited<ReturnType<typeof getTeam>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeam>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeam>>,
          TError,
          Awaited<ReturnType<typeof getTeam>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed team information by URL slug
 * @summary Get team by slug
 */
export function useGetTeam<
  TData = Awaited<ReturnType<typeof getTeam>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeam>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeam>>,
          TError,
          Awaited<ReturnType<typeof getTeam>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed team information by URL slug
 * @summary Get team by slug
 */
export function useGetTeam<
  TData = Awaited<ReturnType<typeof getTeam>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeam>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed team information by URL slug
 * @summary Get team by slug
 */
export function useGetTeam<
  TData = Awaited<ReturnType<typeof getTeam>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeam>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTeamQueryOptions(teamSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed team information by URL slug
 * @summary Get team by slug
 */
export const prefetchGetTeamQuery = async <
  TData = Awaited<ReturnType<typeof getTeam>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeam>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTeamQueryOptions(teamSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Soft delete a team. Requires OWNER role.
 * @summary Delete team
 */
export const deleteTeam = (
  teamSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>({ url: `/api/teams/${teamSlug}`, method: 'DELETE', signal }, options)
}

export const getDeleteTeamMutationKey = () => ['deleteTeam'] as const

export const getDeleteTeamMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteTeam>>,
    TError,
    DeleteTeamMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteTeam>>,
  TError,
  DeleteTeamMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteTeamMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteTeam>>,
    DeleteTeamMutationVariables
  > = (props) => {
    const { teamSlug } = props ?? {}

    return deleteTeam(teamSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteTeamMutationResult = NonNullable<Awaited<ReturnType<typeof deleteTeam>>>

export type DeleteTeamMutationError = ErrorType<ErrorResponse>
export type DeleteTeamMutationVariables = { teamSlug: string }

/**
 * Soft delete a team. Requires OWNER role.
 * @summary Delete team
 */
export const useDeleteTeam = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteTeam>>,
      TError,
      DeleteTeamMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteTeam>>,
  TError,
  DeleteTeamMutationVariables,
  TContext
> => {
  return useMutation(getDeleteTeamMutationOptions(options), queryClient)
}
/**
 * Everything a « Tableau de bord » shows, in one call, graded by the caller's role. A visitor (anonymous, or signed in without belonging to the team) gets the public part only: upcoming rides, latest posts and new routes, under the usual visibility rules (PUBLIC entities only), with role, myUpcoming, latestAds, organizer and admin null. A member gets the member sections, an organizer the organizer block too, an administrator the admin block too. Each section is a short page of the matching list, and is null when the team has disabled its module. The teams switcher, the unread notification count and the calendar token are not part of it.
 * @summary Get the team dashboard
 */
export const getTeamDashboard = (
  teamSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamDashboardDto>(
    { url: `/api/teams/${teamSlug}/dashboard`, method: 'GET', signal },
    options
  )
}

export const getGetTeamDashboardQueryKey = (teamSlug: string) => {
  return [`/api/teams/${teamSlug}/dashboard`] as const
}

export const getGetTeamDashboardQueryOptions = <
  TData = Awaited<ReturnType<typeof getTeamDashboard>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamDashboard>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTeamDashboardQueryKey(teamSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTeamDashboard>>> = ({ signal }) =>
    getTeamDashboard(teamSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTeamDashboard>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTeamDashboardQueryResult = NonNullable<Awaited<ReturnType<typeof getTeamDashboard>>>
export type GetTeamDashboardQueryError = ErrorType<ErrorResponse>

/**
 * Everything a « Tableau de bord » shows, in one call, graded by the caller's role. A visitor (anonymous, or signed in without belonging to the team) gets the public part only: upcoming rides, latest posts and new routes, under the usual visibility rules (PUBLIC entities only), with role, myUpcoming, latestAds, organizer and admin null. A member gets the member sections, an organizer the organizer block too, an administrator the admin block too. Each section is a short page of the matching list, and is null when the team has disabled its module. The teams switcher, the unread notification count and the calendar token are not part of it.
 * @summary Get the team dashboard
 */
export function useGetTeamDashboard<
  TData = Awaited<ReturnType<typeof getTeamDashboard>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamDashboard>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamDashboard>>,
          TError,
          Awaited<ReturnType<typeof getTeamDashboard>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Everything a « Tableau de bord » shows, in one call, graded by the caller's role. A visitor (anonymous, or signed in without belonging to the team) gets the public part only: upcoming rides, latest posts and new routes, under the usual visibility rules (PUBLIC entities only), with role, myUpcoming, latestAds, organizer and admin null. A member gets the member sections, an organizer the organizer block too, an administrator the admin block too. Each section is a short page of the matching list, and is null when the team has disabled its module. The teams switcher, the unread notification count and the calendar token are not part of it.
 * @summary Get the team dashboard
 */
export function useGetTeamDashboard<
  TData = Awaited<ReturnType<typeof getTeamDashboard>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamDashboard>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamDashboard>>,
          TError,
          Awaited<ReturnType<typeof getTeamDashboard>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Everything a « Tableau de bord » shows, in one call, graded by the caller's role. A visitor (anonymous, or signed in without belonging to the team) gets the public part only: upcoming rides, latest posts and new routes, under the usual visibility rules (PUBLIC entities only), with role, myUpcoming, latestAds, organizer and admin null. A member gets the member sections, an organizer the organizer block too, an administrator the admin block too. Each section is a short page of the matching list, and is null when the team has disabled its module. The teams switcher, the unread notification count and the calendar token are not part of it.
 * @summary Get the team dashboard
 */
export function useGetTeamDashboard<
  TData = Awaited<ReturnType<typeof getTeamDashboard>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamDashboard>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Everything a « Tableau de bord » shows, in one call, graded by the caller's role. A visitor (anonymous, or signed in without belonging to the team) gets the public part only: upcoming rides, latest posts and new routes, under the usual visibility rules (PUBLIC entities only), with role, myUpcoming, latestAds, organizer and admin null. A member gets the member sections, an organizer the organizer block too, an administrator the admin block too. Each section is a short page of the matching list, and is null when the team has disabled its module. The teams switcher, the unread notification count and the calendar token are not part of it.
 * @summary Get the team dashboard
 */
export function useGetTeamDashboard<
  TData = Awaited<ReturnType<typeof getTeamDashboard>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamDashboard>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTeamDashboardQueryOptions(teamSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Everything a « Tableau de bord » shows, in one call, graded by the caller's role. A visitor (anonymous, or signed in without belonging to the team) gets the public part only: upcoming rides, latest posts and new routes, under the usual visibility rules (PUBLIC entities only), with role, myUpcoming, latestAds, organizer and admin null. A member gets the member sections, an organizer the organizer block too, an administrator the admin block too. Each section is a short page of the matching list, and is null when the team has disabled its module. The teams switcher, the unread notification count and the calendar token are not part of it.
 * @summary Get the team dashboard
 */
export const prefetchGetTeamDashboardQuery = async <
  TData = Awaited<ReturnType<typeof getTeamDashboard>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamDashboard>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTeamDashboardQueryOptions(teamSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Change team URL slug. Requires ADMIN role.
 * @summary Change team slug
 */
export const changeTeamSlug = (
  teamSlug: string,
  slugChangeRequest: BodyType<SlugChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamDetailDto>(
    {
      url: `/api/teams/${teamSlug}/slug`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: slugChangeRequest,
      signal,
    },
    options
  )
}

export const getChangeTeamSlugMutationKey = () => ['changeTeamSlug'] as const

export const getChangeTeamSlugMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changeTeamSlug>>,
    TError,
    ChangeTeamSlugMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changeTeamSlug>>,
  TError,
  ChangeTeamSlugMutationVariables,
  TContext
> => {
  const mutationKey = getChangeTeamSlugMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changeTeamSlug>>,
    ChangeTeamSlugMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return changeTeamSlug(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangeTeamSlugMutationResult = NonNullable<Awaited<ReturnType<typeof changeTeamSlug>>>
export type ChangeTeamSlugMutationBody = BodyType<SlugChangeRequest>
export type ChangeTeamSlugMutationError = ErrorType<ErrorResponse>
export type ChangeTeamSlugMutationVariables = {
  teamSlug: string
  data: BodyType<SlugChangeRequest>
}

/**
 * Change team URL slug. Requires ADMIN role.
 * @summary Change team slug
 */
export const useChangeTeamSlug = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changeTeamSlug>>,
      TError,
      ChangeTeamSlugMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changeTeamSlug>>,
  TError,
  ChangeTeamSlugMutationVariables,
  TContext
> => {
  return useMutation(getChangeTeamSlugMutationOptions(options), queryClient)
}
/**
 * The IANA zone of the given point, else the team's own: the zone the backend will read an event's wall times in once that point is its start (docs/LEDGER_*.md API-60). For the editors' field labels only — the backend resolves the zone of a saved entity itself. Organisers and above.
 * @summary Zone of a point for the team
 */
export const getTeamTimezone = (
  teamSlug: string,
  params?: GetTeamTimezoneParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamTimezoneDto>(
    { url: `/api/teams/${teamSlug}/timezone`, method: 'GET', params, signal },
    options
  )
}

export const getGetTeamTimezoneQueryKey = (teamSlug: string, params?: GetTeamTimezoneParams) => {
  return [`/api/teams/${teamSlug}/timezone`, ...(params ? [params] : [])] as const
}

export const getGetTeamTimezoneQueryOptions = <
  TData = Awaited<ReturnType<typeof getTeamTimezone>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamTimezoneParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamTimezone>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTeamTimezoneQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTeamTimezone>>> = ({ signal }) =>
    getTeamTimezone(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTeamTimezone>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTeamTimezoneQueryResult = NonNullable<Awaited<ReturnType<typeof getTeamTimezone>>>
export type GetTeamTimezoneQueryError = ErrorType<ErrorResponse>

/**
 * The IANA zone of the given point, else the team's own: the zone the backend will read an event's wall times in once that point is its start (docs/LEDGER_*.md API-60). For the editors' field labels only — the backend resolves the zone of a saved entity itself. Organisers and above.
 * @summary Zone of a point for the team
 */
export function useGetTeamTimezone<
  TData = Awaited<ReturnType<typeof getTeamTimezone>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | GetTeamTimezoneParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamTimezone>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamTimezone>>,
          TError,
          Awaited<ReturnType<typeof getTeamTimezone>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The IANA zone of the given point, else the team's own: the zone the backend will read an event's wall times in once that point is its start (docs/LEDGER_*.md API-60). For the editors' field labels only — the backend resolves the zone of a saved entity itself. Organisers and above.
 * @summary Zone of a point for the team
 */
export function useGetTeamTimezone<
  TData = Awaited<ReturnType<typeof getTeamTimezone>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamTimezoneParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamTimezone>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamTimezone>>,
          TError,
          Awaited<ReturnType<typeof getTeamTimezone>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The IANA zone of the given point, else the team's own: the zone the backend will read an event's wall times in once that point is its start (docs/LEDGER_*.md API-60). For the editors' field labels only — the backend resolves the zone of a saved entity itself. Organisers and above.
 * @summary Zone of a point for the team
 */
export function useGetTeamTimezone<
  TData = Awaited<ReturnType<typeof getTeamTimezone>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamTimezoneParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamTimezone>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The IANA zone of the given point, else the team's own: the zone the backend will read an event's wall times in once that point is its start (docs/LEDGER_*.md API-60). For the editors' field labels only — the backend resolves the zone of a saved entity itself. Organisers and above.
 * @summary Zone of a point for the team
 */
export function useGetTeamTimezone<
  TData = Awaited<ReturnType<typeof getTeamTimezone>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: GetTeamTimezoneParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamTimezone>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTeamTimezoneQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * The IANA zone of the given point, else the team's own: the zone the backend will read an event's wall times in once that point is its start (docs/LEDGER_*.md API-60). For the editors' field labels only — the backend resolves the zone of a saved entity itself. Organisers and above.
 * @summary Zone of a point for the team
 */
export const prefetchGetTeamTimezoneQuery = async <
  TData = Awaited<ReturnType<typeof getTeamTimezone>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: GetTeamTimezoneParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamTimezone>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTeamTimezoneQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * What saving the team with this zone would do, without writing anything (docs/LEDGER_*.md API-60, plan §9): its upcoming rides, trips, stages and posts that no place or route locates keep their wall time in the new zone, the past ones keep their instant. Team admins only.
 * @summary Preview a change of the team's zone
 */
export const previewTeamTimezoneChange = (
  teamSlug: string,
  params: PreviewTeamTimezoneChangeParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamTimezoneChangePreviewDto>(
    { url: `/api/teams/${teamSlug}/timezone/change-preview`, method: 'GET', params, signal },
    options
  )
}

export const getPreviewTeamTimezoneChangeQueryKey = (
  teamSlug: string,
  params?: PreviewTeamTimezoneChangeParams
) => {
  return [`/api/teams/${teamSlug}/timezone/change-preview`, ...(params ? [params] : [])] as const
}

export const getPreviewTeamTimezoneChangeQueryOptions = <
  TData = Awaited<ReturnType<typeof previewTeamTimezoneChange>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: PreviewTeamTimezoneChangeParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof previewTeamTimezoneChange>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getPreviewTeamTimezoneChangeQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof previewTeamTimezoneChange>>> = ({
    signal,
  }) => previewTeamTimezoneChange(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof previewTeamTimezoneChange>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type PreviewTeamTimezoneChangeQueryResult = NonNullable<
  Awaited<ReturnType<typeof previewTeamTimezoneChange>>
>
export type PreviewTeamTimezoneChangeQueryError = ErrorType<ErrorResponse>

/**
 * What saving the team with this zone would do, without writing anything (docs/LEDGER_*.md API-60, plan §9): its upcoming rides, trips, stages and posts that no place or route locates keep their wall time in the new zone, the past ones keep their instant. Team admins only.
 * @summary Preview a change of the team's zone
 */
export function usePreviewTeamTimezoneChange<
  TData = Awaited<ReturnType<typeof previewTeamTimezoneChange>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: PreviewTeamTimezoneChangeParams,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof previewTeamTimezoneChange>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof previewTeamTimezoneChange>>,
          TError,
          Awaited<ReturnType<typeof previewTeamTimezoneChange>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What saving the team with this zone would do, without writing anything (docs/LEDGER_*.md API-60, plan §9): its upcoming rides, trips, stages and posts that no place or route locates keep their wall time in the new zone, the past ones keep their instant. Team admins only.
 * @summary Preview a change of the team's zone
 */
export function usePreviewTeamTimezoneChange<
  TData = Awaited<ReturnType<typeof previewTeamTimezoneChange>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: PreviewTeamTimezoneChangeParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof previewTeamTimezoneChange>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof previewTeamTimezoneChange>>,
          TError,
          Awaited<ReturnType<typeof previewTeamTimezoneChange>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What saving the team with this zone would do, without writing anything (docs/LEDGER_*.md API-60, plan §9): its upcoming rides, trips, stages and posts that no place or route locates keep their wall time in the new zone, the past ones keep their instant. Team admins only.
 * @summary Preview a change of the team's zone
 */
export function usePreviewTeamTimezoneChange<
  TData = Awaited<ReturnType<typeof previewTeamTimezoneChange>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: PreviewTeamTimezoneChangeParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof previewTeamTimezoneChange>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What saving the team with this zone would do, without writing anything (docs/LEDGER_*.md API-60, plan §9): its upcoming rides, trips, stages and posts that no place or route locates keep their wall time in the new zone, the past ones keep their instant. Team admins only.
 * @summary Preview a change of the team's zone
 */
export function usePreviewTeamTimezoneChange<
  TData = Awaited<ReturnType<typeof previewTeamTimezoneChange>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: PreviewTeamTimezoneChangeParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof previewTeamTimezoneChange>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getPreviewTeamTimezoneChangeQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * What saving the team with this zone would do, without writing anything (docs/LEDGER_*.md API-60, plan §9): its upcoming rides, trips, stages and posts that no place or route locates keep their wall time in the new zone, the past ones keep their instant. Team admins only.
 * @summary Preview a change of the team's zone
 */
export const prefetchPreviewTeamTimezoneChangeQuery = async <
  TData = Awaited<ReturnType<typeof previewTeamTimezoneChange>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params: PreviewTeamTimezoneChangeParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof previewTeamTimezoneChange>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getPreviewTeamTimezoneChangeQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
