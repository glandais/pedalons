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
  AdminUserDto,
  AdminUserListResponse,
  AssignPlatformRoleRequest,
  ErrorResponse,
  ListUsersParams,
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
 * Get a paginated list of all users
 * @summary List all users
 */
export const listUsers = (
  params?: ListUsersParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminUserListResponse>(
    { url: `/api/admin/users`, method: 'GET', params, signal },
    options
  )
}

export const getListUsersQueryKey = (params?: ListUsersParams) => {
  return [`/api/admin/users`, ...(params ? [params] : [])] as const
}

export const getListUsersQueryOptions = <
  TData = Awaited<ReturnType<typeof listUsers>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListUsersParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listUsers>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListUsersQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listUsers>>> = ({ signal }) =>
    listUsers(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listUsers>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListUsersQueryResult = NonNullable<Awaited<ReturnType<typeof listUsers>>>
export type ListUsersQueryError = ErrorType<void | ErrorResponse>

/**
 * Get a paginated list of all users
 * @summary List all users
 */
export function useListUsers<
  TData = Awaited<ReturnType<typeof listUsers>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: undefined | ListUsersParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listUsers>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listUsers>>,
          TError,
          Awaited<ReturnType<typeof listUsers>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all users
 * @summary List all users
 */
export function useListUsers<
  TData = Awaited<ReturnType<typeof listUsers>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListUsersParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listUsers>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listUsers>>,
          TError,
          Awaited<ReturnType<typeof listUsers>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all users
 * @summary List all users
 */
export function useListUsers<
  TData = Awaited<ReturnType<typeof listUsers>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListUsersParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listUsers>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all users
 * @summary List all users
 */
export function useListUsers<
  TData = Awaited<ReturnType<typeof listUsers>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListUsersParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listUsers>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListUsersQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get a paginated list of all users
 * @summary List all users
 */
export const prefetchListUsersQuery = async <
  TData = Awaited<ReturnType<typeof listUsers>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: ListUsersParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listUsers>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListUsersQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get detailed user information
 * @summary Get user details
 */
export const getAdminUser = (
  userId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminUserDto>(
    { url: `/api/admin/users/${userId}`, method: 'GET', signal },
    options
  )
}

export const getGetAdminUserQueryKey = (userId: string) => {
  return [`/api/admin/users/${userId}`] as const
}

export const getGetAdminUserQueryOptions = <
  TData = Awaited<ReturnType<typeof getAdminUser>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  userId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdminUser>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetAdminUserQueryKey(userId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getAdminUser>>> = ({ signal }) =>
    getAdminUser(userId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: userId !== null && userId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getAdminUser>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetAdminUserQueryResult = NonNullable<Awaited<ReturnType<typeof getAdminUser>>>
export type GetAdminUserQueryError = ErrorType<void | ErrorResponse>

/**
 * Get detailed user information
 * @summary Get user details
 */
export function useGetAdminUser<
  TData = Awaited<ReturnType<typeof getAdminUser>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  userId: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdminUser>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAdminUser>>,
          TError,
          Awaited<ReturnType<typeof getAdminUser>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed user information
 * @summary Get user details
 */
export function useGetAdminUser<
  TData = Awaited<ReturnType<typeof getAdminUser>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  userId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdminUser>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAdminUser>>,
          TError,
          Awaited<ReturnType<typeof getAdminUser>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed user information
 * @summary Get user details
 */
export function useGetAdminUser<
  TData = Awaited<ReturnType<typeof getAdminUser>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  userId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdminUser>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed user information
 * @summary Get user details
 */
export function useGetAdminUser<
  TData = Awaited<ReturnType<typeof getAdminUser>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  userId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdminUser>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetAdminUserQueryOptions(userId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed user information
 * @summary Get user details
 */
export const prefetchGetAdminUserQuery = async <
  TData = Awaited<ReturnType<typeof getAdminUser>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  userId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdminUser>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetAdminUserQueryOptions(userId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Assign or remove a platform role from a user
 * @summary Assign platform role
 */
export const assignPlatformRole = (
  userId: string,
  assignPlatformRoleRequest: BodyType<AssignPlatformRoleRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminUserDto>(
    {
      url: `/api/admin/users/${userId}/platform-role`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: assignPlatformRoleRequest,
      signal,
    },
    options
  )
}

export const getAssignPlatformRoleMutationKey = () => ['assignPlatformRole'] as const

export const getAssignPlatformRoleMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof assignPlatformRole>>,
    TError,
    AssignPlatformRoleMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof assignPlatformRole>>,
  TError,
  AssignPlatformRoleMutationVariables,
  TContext
> => {
  const mutationKey = getAssignPlatformRoleMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof assignPlatformRole>>,
    AssignPlatformRoleMutationVariables
  > = (props) => {
    const { userId, data } = props ?? {}

    return assignPlatformRole(userId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AssignPlatformRoleMutationResult = NonNullable<
  Awaited<ReturnType<typeof assignPlatformRole>>
>
export type AssignPlatformRoleMutationBody = BodyType<AssignPlatformRoleRequest>
export type AssignPlatformRoleMutationError = ErrorType<void | ErrorResponse>
export type AssignPlatformRoleMutationVariables = {
  userId: string
  data: BodyType<AssignPlatformRoleRequest>
}

/**
 * Assign or remove a platform role from a user
 * @summary Assign platform role
 */
export const useAssignPlatformRole = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof assignPlatformRole>>,
      TError,
      AssignPlatformRoleMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof assignPlatformRole>>,
  TError,
  AssignPlatformRoleMutationVariables,
  TContext
> => {
  return useMutation(getAssignPlatformRoleMutationOptions(options), queryClient)
}
