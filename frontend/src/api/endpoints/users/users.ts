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
  AccountDeletionImpactDto,
  DownloadDataExportParams,
  ErrorResponse,
  ListMyParticipationsParams,
  PairedDeviceDto,
  ProfileSummaryDto,
  PublicationListResponse,
  UpdateUserRequest,
  UploadAvatarBody,
  UserDto,
  UserExportDto,
  UserPreferencesRequest,
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
 * Download a prepared data export archive using the token from the notification email. Only its owner, signed in, may download it. The token is a query parameter, which the access log masks; a path segment would be logged in clear.
 * @summary Download a personal data export
 */
export const downloadDataExport = (
  params: DownloadDataExportParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    { url: `/api/export/download`, method: 'GET', params, responseType: 'blob', signal },
    options
  )
}

export const getDownloadDataExportQueryKey = (params?: DownloadDataExportParams) => {
  return [`/api/export/download`, ...(params ? [params] : [])] as const
}

export const getDownloadDataExportQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadDataExport>>,
  TError = ErrorType<void | Blob>,
>(
  params: DownloadDataExportParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadDataExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDownloadDataExportQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadDataExport>>> = ({ signal }) =>
    downloadDataExport(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof downloadDataExport>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type DownloadDataExportQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadDataExport>>
>
export type DownloadDataExportQueryError = ErrorType<void | Blob>

/**
 * Download a prepared data export archive using the token from the notification email. Only its owner, signed in, may download it. The token is a query parameter, which the access log masks; a path segment would be logged in clear.
 * @summary Download a personal data export
 */
export function useDownloadDataExport<
  TData = Awaited<ReturnType<typeof downloadDataExport>>,
  TError = ErrorType<void | Blob>,
>(
  params: DownloadDataExportParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadDataExport>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadDataExport>>,
          TError,
          Awaited<ReturnType<typeof downloadDataExport>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download a prepared data export archive using the token from the notification email. Only its owner, signed in, may download it. The token is a query parameter, which the access log masks; a path segment would be logged in clear.
 * @summary Download a personal data export
 */
export function useDownloadDataExport<
  TData = Awaited<ReturnType<typeof downloadDataExport>>,
  TError = ErrorType<void | Blob>,
>(
  params: DownloadDataExportParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadDataExport>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadDataExport>>,
          TError,
          Awaited<ReturnType<typeof downloadDataExport>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download a prepared data export archive using the token from the notification email. Only its owner, signed in, may download it. The token is a query parameter, which the access log masks; a path segment would be logged in clear.
 * @summary Download a personal data export
 */
export function useDownloadDataExport<
  TData = Awaited<ReturnType<typeof downloadDataExport>>,
  TError = ErrorType<void | Blob>,
>(
  params: DownloadDataExportParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadDataExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Download a prepared data export archive using the token from the notification email. Only its owner, signed in, may download it. The token is a query parameter, which the access log masks; a path segment would be logged in clear.
 * @summary Download a personal data export
 */
export function useDownloadDataExport<
  TData = Awaited<ReturnType<typeof downloadDataExport>>,
  TError = ErrorType<void | Blob>,
>(
  params: DownloadDataExportParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadDataExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadDataExportQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Download a prepared data export archive using the token from the notification email. Only its owner, signed in, may download it. The token is a query parameter, which the access log masks; a path segment would be logged in clear.
 * @summary Download a personal data export
 */
export const prefetchDownloadDataExportQuery = async <
  TData = Awaited<ReturnType<typeof downloadDataExport>>,
  TError = ErrorType<void | Blob>,
>(
  queryClient: QueryClient,
  params: DownloadDataExportParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadDataExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadDataExportQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Update the current user's profile
 * @summary Update current user
 */
export const updateMe = (
  updateUserRequest: BodyType<UpdateUserRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<UserDto>(
    {
      url: `/api/users/me`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: updateUserRequest,
      signal,
    },
    options
  )
}

export const getUpdateMeMutationKey = () => ['updateMe'] as const

export const getUpdateMeMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateMe>>,
    TError,
    UpdateMeMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateMe>>,
  TError,
  UpdateMeMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateMeMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateMe>>,
    UpdateMeMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return updateMe(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateMeMutationResult = NonNullable<Awaited<ReturnType<typeof updateMe>>>
export type UpdateMeMutationBody = BodyType<UpdateUserRequest>
export type UpdateMeMutationError = ErrorType<ErrorResponse | void>
export type UpdateMeMutationVariables = { data: BodyType<UpdateUserRequest> }

/**
 * Update the current user's profile
 * @summary Update current user
 */
export const useUpdateMe = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateMe>>,
      TError,
      UpdateMeMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateMe>>,
  TError,
  UpdateMeMutationVariables,
  TContext
> => {
  return useMutation(getUpdateMeMutationOptions(options), queryClient)
}
/**
 * Get the current authenticated user's profile.
 * @summary Get current user
 */
export const getMe = (options?: SecondParameter<typeof axiosMutator>, signal?: AbortSignal) => {
  return axiosMutator<UserDto>({ url: `/api/users/me`, method: 'GET', signal }, options)
}

export const getGetMeQueryKey = () => {
  return [`/api/users/me`] as const
}

export const getGetMeQueryOptions = <
  TData = Awaited<ReturnType<typeof getMe>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMe>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetMeQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getMe>>> = ({ signal }) =>
    getMe(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getMe>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetMeQueryResult = NonNullable<Awaited<ReturnType<typeof getMe>>>
export type GetMeQueryError = ErrorType<ErrorResponse | void>

/**
 * Get the current authenticated user's profile.
 * @summary Get current user
 */
export function useGetMe<
  TData = Awaited<ReturnType<typeof getMe>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMe>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getMe>>,
          TError,
          Awaited<ReturnType<typeof getMe>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get the current authenticated user's profile.
 * @summary Get current user
 */
export function useGetMe<
  TData = Awaited<ReturnType<typeof getMe>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMe>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getMe>>,
          TError,
          Awaited<ReturnType<typeof getMe>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get the current authenticated user's profile.
 * @summary Get current user
 */
export function useGetMe<
  TData = Awaited<ReturnType<typeof getMe>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMe>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get the current authenticated user's profile.
 * @summary Get current user
 */
export function useGetMe<
  TData = Awaited<ReturnType<typeof getMe>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMe>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetMeQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get the current authenticated user's profile.
 * @summary Get current user
 */
export const prefetchGetMeQuery = async <
  TData = Awaited<ReturnType<typeof getMe>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMe>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetMeQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Delete the current user's account. The teams they administer and are the only member of are deleted with it; see GET /api/users/me/deletion-impact.
 * @summary Delete current user
 */
export const deleteCurrentUser = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>({ url: `/api/users/me`, method: 'DELETE', signal }, options)
}

export const getDeleteCurrentUserMutationKey = () => ['deleteCurrentUser'] as const

export const getDeleteCurrentUserMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteCurrentUser>>,
    TError,
    void,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<Awaited<ReturnType<typeof deleteCurrentUser>>, TError, void, TContext> => {
  const mutationKey = getDeleteCurrentUserMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof deleteCurrentUser>>, void> = () => {
    return deleteCurrentUser(requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteCurrentUserMutationResult = NonNullable<
  Awaited<ReturnType<typeof deleteCurrentUser>>
>

export type DeleteCurrentUserMutationError = ErrorType<ErrorResponse | void>

/**
 * Delete the current user's account. The teams they administer and are the only member of are deleted with it; see GET /api/users/me/deletion-impact.
 * @summary Delete current user
 */
export const useDeleteCurrentUser = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteCurrentUser>>,
      TError,
      void,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<Awaited<ReturnType<typeof deleteCurrentUser>>, TError, void, TContext> => {
  return useMutation(getDeleteCurrentUserMutationOptions(options), queryClient)
}
/**
 * Upload a new avatar image for the current user. Image will be resized to 256x256.
 * @summary Upload user avatar
 */
export const uploadAvatar = (
  uploadAvatarBody: BodyType<UploadAvatarBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (uploadAvatarBody.file !== undefined) {
    formData.append(`file`, uploadAvatarBody.file)
  }

  return axiosMutator<UserDto>(
    {
      url: `/api/users/me/avatar`,
      method: 'POST',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      signal,
    },
    options
  )
}

export const getUploadAvatarMutationKey = () => ['uploadAvatar'] as const

export const getUploadAvatarMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof uploadAvatar>>,
    TError,
    UploadAvatarMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof uploadAvatar>>,
  TError,
  UploadAvatarMutationVariables,
  TContext
> => {
  const mutationKey = getUploadAvatarMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof uploadAvatar>>,
    UploadAvatarMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return uploadAvatar(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UploadAvatarMutationResult = NonNullable<Awaited<ReturnType<typeof uploadAvatar>>>
export type UploadAvatarMutationBody = BodyType<UploadAvatarBody>
export type UploadAvatarMutationError = ErrorType<ErrorResponse | void>
export type UploadAvatarMutationVariables = { data: BodyType<UploadAvatarBody> }

/**
 * Upload a new avatar image for the current user. Image will be resized to 256x256.
 * @summary Upload user avatar
 */
export const useUploadAvatar = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof uploadAvatar>>,
      TError,
      UploadAvatarMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof uploadAvatar>>,
  TError,
  UploadAvatarMutationVariables,
  TContext
> => {
  return useMutation(getUploadAvatarMutationOptions(options), queryClient)
}
/**
 * Remove the current user's avatar
 * @summary Delete user avatar
 */
export const deleteAvatar = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<UserDto>({ url: `/api/users/me/avatar`, method: 'DELETE', signal }, options)
}

export const getDeleteAvatarMutationKey = () => ['deleteAvatar'] as const

export const getDeleteAvatarMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<Awaited<ReturnType<typeof deleteAvatar>>, TError, void, TContext>
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<Awaited<ReturnType<typeof deleteAvatar>>, TError, void, TContext> => {
  const mutationKey = getDeleteAvatarMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof deleteAvatar>>, void> = () => {
    return deleteAvatar(requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteAvatarMutationResult = NonNullable<Awaited<ReturnType<typeof deleteAvatar>>>

export type DeleteAvatarMutationError = ErrorType<ErrorResponse | void>

/**
 * Remove the current user's avatar
 * @summary Delete user avatar
 */
export const useDeleteAvatar = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<Awaited<ReturnType<typeof deleteAvatar>>, TError, void, TContext>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<Awaited<ReturnType<typeof deleteAvatar>>, TError, void, TContext> => {
  return useMutation(getDeleteAvatarMutationOptions(options), queryClient)
}
/**
 * What deleting the current user's account would do to their teams: the teams deleted with it (they administer them alone), and the teams that refuse the deletion (SOLE_TEAM_ADMIN, or SOLE_MIGRATED_TEAM_ADMIN for a team migrated from biketeam). Read-only.
 * @summary Preview the deletion of the current user
 */
export const getMyDeletionImpact = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AccountDeletionImpactDto>(
    { url: `/api/users/me/deletion-impact`, method: 'GET', signal },
    options
  )
}

export const getGetMyDeletionImpactQueryKey = () => {
  return [`/api/users/me/deletion-impact`] as const
}

export const getGetMyDeletionImpactQueryOptions = <
  TData = Awaited<ReturnType<typeof getMyDeletionImpact>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMyDeletionImpact>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetMyDeletionImpactQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getMyDeletionImpact>>> = ({ signal }) =>
    getMyDeletionImpact(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getMyDeletionImpact>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetMyDeletionImpactQueryResult = NonNullable<
  Awaited<ReturnType<typeof getMyDeletionImpact>>
>
export type GetMyDeletionImpactQueryError = ErrorType<ErrorResponse | void>

/**
 * What deleting the current user's account would do to their teams: the teams deleted with it (they administer them alone), and the teams that refuse the deletion (SOLE_TEAM_ADMIN, or SOLE_MIGRATED_TEAM_ADMIN for a team migrated from biketeam). Read-only.
 * @summary Preview the deletion of the current user
 */
export function useGetMyDeletionImpact<
  TData = Awaited<ReturnType<typeof getMyDeletionImpact>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getMyDeletionImpact>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getMyDeletionImpact>>,
          TError,
          Awaited<ReturnType<typeof getMyDeletionImpact>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What deleting the current user's account would do to their teams: the teams deleted with it (they administer them alone), and the teams that refuse the deletion (SOLE_TEAM_ADMIN, or SOLE_MIGRATED_TEAM_ADMIN for a team migrated from biketeam). Read-only.
 * @summary Preview the deletion of the current user
 */
export function useGetMyDeletionImpact<
  TData = Awaited<ReturnType<typeof getMyDeletionImpact>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getMyDeletionImpact>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getMyDeletionImpact>>,
          TError,
          Awaited<ReturnType<typeof getMyDeletionImpact>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What deleting the current user's account would do to their teams: the teams deleted with it (they administer them alone), and the teams that refuse the deletion (SOLE_TEAM_ADMIN, or SOLE_MIGRATED_TEAM_ADMIN for a team migrated from biketeam). Read-only.
 * @summary Preview the deletion of the current user
 */
export function useGetMyDeletionImpact<
  TData = Awaited<ReturnType<typeof getMyDeletionImpact>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMyDeletionImpact>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What deleting the current user's account would do to their teams: the teams deleted with it (they administer them alone), and the teams that refuse the deletion (SOLE_TEAM_ADMIN, or SOLE_MIGRATED_TEAM_ADMIN for a team migrated from biketeam). Read-only.
 * @summary Preview the deletion of the current user
 */
export function useGetMyDeletionImpact<
  TData = Awaited<ReturnType<typeof getMyDeletionImpact>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMyDeletionImpact>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetMyDeletionImpactQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * What deleting the current user's account would do to their teams: the teams deleted with it (they administer them alone), and the teams that refuse the deletion (SOLE_TEAM_ADMIN, or SOLE_MIGRATED_TEAM_ADMIN for a team migrated from biketeam). Read-only.
 * @summary Preview the deletion of the current user
 */
export const prefetchGetMyDeletionImpactQuery = async <
  TData = Awaited<ReturnType<typeof getMyDeletionImpact>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMyDeletionImpact>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetMyDeletionImpactQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * The devices (Karoo, Garmin) paired with the current account by code and still able to renew their access, newest first. The GPS services the account is connected to are on the profile (connectedServices), not here.
 * @summary List paired devices
 */
export const listPairedDevices = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PairedDeviceDto[]>(
    { url: `/api/users/me/devices`, method: 'GET', signal },
    options
  )
}

export const getListPairedDevicesQueryKey = () => {
  return [`/api/users/me/devices`] as const
}

export const getListPairedDevicesQueryOptions = <
  TData = Awaited<ReturnType<typeof listPairedDevices>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPairedDevices>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListPairedDevicesQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listPairedDevices>>> = ({ signal }) =>
    listPairedDevices(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listPairedDevices>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListPairedDevicesQueryResult = NonNullable<
  Awaited<ReturnType<typeof listPairedDevices>>
>
export type ListPairedDevicesQueryError = ErrorType<ErrorResponse | void>

/**
 * The devices (Karoo, Garmin) paired with the current account by code and still able to renew their access, newest first. The GPS services the account is connected to are on the profile (connectedServices), not here.
 * @summary List paired devices
 */
export function useListPairedDevices<
  TData = Awaited<ReturnType<typeof listPairedDevices>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPairedDevices>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPairedDevices>>,
          TError,
          Awaited<ReturnType<typeof listPairedDevices>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The devices (Karoo, Garmin) paired with the current account by code and still able to renew their access, newest first. The GPS services the account is connected to are on the profile (connectedServices), not here.
 * @summary List paired devices
 */
export function useListPairedDevices<
  TData = Awaited<ReturnType<typeof listPairedDevices>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPairedDevices>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPairedDevices>>,
          TError,
          Awaited<ReturnType<typeof listPairedDevices>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The devices (Karoo, Garmin) paired with the current account by code and still able to renew their access, newest first. The GPS services the account is connected to are on the profile (connectedServices), not here.
 * @summary List paired devices
 */
export function useListPairedDevices<
  TData = Awaited<ReturnType<typeof listPairedDevices>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPairedDevices>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The devices (Karoo, Garmin) paired with the current account by code and still able to renew their access, newest first. The GPS services the account is connected to are on the profile (connectedServices), not here.
 * @summary List paired devices
 */
export function useListPairedDevices<
  TData = Awaited<ReturnType<typeof listPairedDevices>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPairedDevices>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListPairedDevicesQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * The devices (Karoo, Garmin) paired with the current account by code and still able to renew their access, newest first. The GPS services the account is connected to are on the profile (connectedServices), not here.
 * @summary List paired devices
 */
export const prefetchListPairedDevicesQuery = async <
  TData = Awaited<ReturnType<typeof listPairedDevices>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPairedDevices>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListPairedDevicesQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Revoke the pairing of one device: its access token is refused at once (401), its renewal fails, and it must be paired again.
 * @summary Unpair a device
 */
export const unpairDevice = (
  deviceId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/users/me/devices/${deviceId}`, method: 'DELETE', signal },
    options
  )
}

export const getUnpairDeviceMutationKey = () => ['unpairDevice'] as const

export const getUnpairDeviceMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof unpairDevice>>,
    TError,
    UnpairDeviceMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof unpairDevice>>,
  TError,
  UnpairDeviceMutationVariables,
  TContext
> => {
  const mutationKey = getUnpairDeviceMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof unpairDevice>>,
    UnpairDeviceMutationVariables
  > = (props) => {
    const { deviceId } = props ?? {}

    return unpairDevice(deviceId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UnpairDeviceMutationResult = NonNullable<Awaited<ReturnType<typeof unpairDevice>>>

export type UnpairDeviceMutationError = ErrorType<ErrorResponse | void>
export type UnpairDeviceMutationVariables = { deviceId: string }

/**
 * Revoke the pairing of one device: its access token is refused at once (401), its renewal fails, and it must be paired again.
 * @summary Unpair a device
 */
export const useUnpairDevice = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof unpairDevice>>,
      TError,
      UnpairDeviceMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof unpairDevice>>,
  TError,
  UnpairDeviceMutationVariables,
  TContext
> => {
  return useMutation(getUnpairDeviceMutationOptions(options), queryClient)
}
/**
 * Queue a GDPR export of the current user's data. The archive is built in the background and a download link is emailed when it is ready. Limited to one export per hour.
 * @summary Request a personal data export
 */
export const requestExport = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<UserExportDto>(
    { url: `/api/users/me/export`, method: 'POST', signal },
    options
  )
}

export const getRequestExportMutationKey = () => ['requestExport'] as const

export const getRequestExportMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<Awaited<ReturnType<typeof requestExport>>, TError, void, TContext>
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<Awaited<ReturnType<typeof requestExport>>, TError, void, TContext> => {
  const mutationKey = getRequestExportMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof requestExport>>, void> = () => {
    return requestExport(requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RequestExportMutationResult = NonNullable<Awaited<ReturnType<typeof requestExport>>>

export type RequestExportMutationError = ErrorType<ErrorResponse | void>

/**
 * Queue a GDPR export of the current user's data. The archive is built in the background and a download link is emailed when it is ready. Limited to one export per hour.
 * @summary Request a personal data export
 */
export const useRequestExport = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<Awaited<ReturnType<typeof requestExport>>, TError, void, TContext>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<Awaited<ReturnType<typeof requestExport>>, TError, void, TContext> => {
  return useMutation(getRequestExportMutationOptions(options), queryClient)
}
/**
 * Status of the current user's most recent export request, if any.
 * @summary Get the latest data export
 */
export const getLatestExport = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<UserExportDto | void>(
    { url: `/api/users/me/export`, method: 'GET', signal },
    options
  )
}

export const getGetLatestExportQueryKey = () => {
  return [`/api/users/me/export`] as const
}

export const getGetLatestExportQueryOptions = <
  TData = Awaited<ReturnType<typeof getLatestExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getLatestExport>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetLatestExportQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getLatestExport>>> = ({ signal }) =>
    getLatestExport(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getLatestExport>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetLatestExportQueryResult = NonNullable<Awaited<ReturnType<typeof getLatestExport>>>
export type GetLatestExportQueryError = ErrorType<ErrorResponse | void>

/**
 * Status of the current user's most recent export request, if any.
 * @summary Get the latest data export
 */
export function useGetLatestExport<
  TData = Awaited<ReturnType<typeof getLatestExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getLatestExport>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getLatestExport>>,
          TError,
          Awaited<ReturnType<typeof getLatestExport>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Status of the current user's most recent export request, if any.
 * @summary Get the latest data export
 */
export function useGetLatestExport<
  TData = Awaited<ReturnType<typeof getLatestExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getLatestExport>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getLatestExport>>,
          TError,
          Awaited<ReturnType<typeof getLatestExport>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Status of the current user's most recent export request, if any.
 * @summary Get the latest data export
 */
export function useGetLatestExport<
  TData = Awaited<ReturnType<typeof getLatestExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getLatestExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Status of the current user's most recent export request, if any.
 * @summary Get the latest data export
 */
export function useGetLatestExport<
  TData = Awaited<ReturnType<typeof getLatestExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getLatestExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetLatestExportQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Status of the current user's most recent export request, if any.
 * @summary Get the latest data export
 */
export const prefetchGetLatestExportQuery = async <
  TData = Awaited<ReturnType<typeof getLatestExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getLatestExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetLatestExportQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Status of one of the current user's export requests.
 * @summary Get a data export
 */
export const getExport = (
  exportId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<UserExportDto>(
    { url: `/api/users/me/export/${exportId}`, method: 'GET', signal },
    options
  )
}

export const getGetExportQueryKey = (exportId: string) => {
  return [`/api/users/me/export/${exportId}`] as const
}

export const getGetExportQueryOptions = <
  TData = Awaited<ReturnType<typeof getExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  exportId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetExportQueryKey(exportId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getExport>>> = ({ signal }) =>
    getExport(exportId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: exportId !== null && exportId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getExport>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetExportQueryResult = NonNullable<Awaited<ReturnType<typeof getExport>>>
export type GetExportQueryError = ErrorType<ErrorResponse | void>

/**
 * Status of one of the current user's export requests.
 * @summary Get a data export
 */
export function useGetExport<
  TData = Awaited<ReturnType<typeof getExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  exportId: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getExport>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getExport>>,
          TError,
          Awaited<ReturnType<typeof getExport>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Status of one of the current user's export requests.
 * @summary Get a data export
 */
export function useGetExport<
  TData = Awaited<ReturnType<typeof getExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  exportId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getExport>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getExport>>,
          TError,
          Awaited<ReturnType<typeof getExport>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Status of one of the current user's export requests.
 * @summary Get a data export
 */
export function useGetExport<
  TData = Awaited<ReturnType<typeof getExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  exportId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Status of one of the current user's export requests.
 * @summary Get a data export
 */
export function useGetExport<
  TData = Awaited<ReturnType<typeof getExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  exportId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetExportQueryOptions(exportId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Status of one of the current user's export requests.
 * @summary Get a data export
 */
export const prefetchGetExportQuery = async <
  TData = Awaited<ReturnType<typeof getExport>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  exportId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getExport>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetExportQueryOptions(exportId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * The rides and trips the current user is registered to, soonest first. Only publications the user may still see are returned: leaving a team removes its outings from this list.
 * @summary List my participations
 */
export const listMyParticipations = (
  params?: ListMyParticipationsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PublicationListResponse>(
    { url: `/api/users/me/participations`, method: 'GET', params, signal },
    options
  )
}

export const getListMyParticipationsQueryKey = (params?: ListMyParticipationsParams) => {
  return [`/api/users/me/participations`, ...(params ? [params] : [])] as const
}

export const getListMyParticipationsQueryOptions = <
  TData = Awaited<ReturnType<typeof listMyParticipations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: ListMyParticipationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listMyParticipations>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListMyParticipationsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listMyParticipations>>> = ({ signal }) =>
    listMyParticipations(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listMyParticipations>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListMyParticipationsQueryResult = NonNullable<
  Awaited<ReturnType<typeof listMyParticipations>>
>
export type ListMyParticipationsQueryError = ErrorType<ErrorResponse | void>

/**
 * The rides and trips the current user is registered to, soonest first. Only publications the user may still see are returned: leaving a team removes its outings from this list.
 * @summary List my participations
 */
export function useListMyParticipations<
  TData = Awaited<ReturnType<typeof listMyParticipations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params: undefined | ListMyParticipationsParams,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listMyParticipations>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listMyParticipations>>,
          TError,
          Awaited<ReturnType<typeof listMyParticipations>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The rides and trips the current user is registered to, soonest first. Only publications the user may still see are returned: leaving a team removes its outings from this list.
 * @summary List my participations
 */
export function useListMyParticipations<
  TData = Awaited<ReturnType<typeof listMyParticipations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: ListMyParticipationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listMyParticipations>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listMyParticipations>>,
          TError,
          Awaited<ReturnType<typeof listMyParticipations>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The rides and trips the current user is registered to, soonest first. Only publications the user may still see are returned: leaving a team removes its outings from this list.
 * @summary List my participations
 */
export function useListMyParticipations<
  TData = Awaited<ReturnType<typeof listMyParticipations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: ListMyParticipationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listMyParticipations>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The rides and trips the current user is registered to, soonest first. Only publications the user may still see are returned: leaving a team removes its outings from this list.
 * @summary List my participations
 */
export function useListMyParticipations<
  TData = Awaited<ReturnType<typeof listMyParticipations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  params?: ListMyParticipationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listMyParticipations>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListMyParticipationsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * The rides and trips the current user is registered to, soonest first. Only publications the user may still see are returned: leaving a team removes its outings from this list.
 * @summary List my participations
 */
export const prefetchListMyParticipationsQuery = async <
  TData = Awaited<ReturnType<typeof listMyParticipations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  params?: ListMyParticipationsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listMyParticipations>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListMyParticipationsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Set the current user's unit system, colour scheme and language. A partial update: fields omitted (or sent null) are left unchanged. These live on the server so that a member who picks imperial units on their phone sees them on the web too, and so that reinstalling the app does not lose them.
 * @summary Update display preferences
 */
export const updateMyPreferences = (
  userPreferencesRequest: BodyType<UserPreferencesRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<UserDto>(
    {
      url: `/api/users/me/preferences`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: userPreferencesRequest,
      signal,
    },
    options
  )
}

export const getUpdateMyPreferencesMutationKey = () => ['updateMyPreferences'] as const

export const getUpdateMyPreferencesMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateMyPreferences>>,
    TError,
    UpdateMyPreferencesMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateMyPreferences>>,
  TError,
  UpdateMyPreferencesMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateMyPreferencesMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateMyPreferences>>,
    UpdateMyPreferencesMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return updateMyPreferences(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateMyPreferencesMutationResult = NonNullable<
  Awaited<ReturnType<typeof updateMyPreferences>>
>
export type UpdateMyPreferencesMutationBody = BodyType<UserPreferencesRequest>
export type UpdateMyPreferencesMutationError = ErrorType<ErrorResponse | void>
export type UpdateMyPreferencesMutationVariables = { data: BodyType<UserPreferencesRequest> }

/**
 * Set the current user's unit system, colour scheme and language. A partial update: fields omitted (or sent null) are left unchanged. These live on the server so that a member who picks imperial units on their phone sees them on the web too, and so that reinstalling the app does not lose them.
 * @summary Update display preferences
 */
export const useUpdateMyPreferences = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateMyPreferences>>,
      TError,
      UpdateMyPreferencesMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateMyPreferences>>,
  TError,
  UpdateMyPreferencesMutationVariables,
  TContext
> => {
  return useMutation(getUpdateMyPreferencesMutationOptions(options), queryClient)
}
/**
 * What the profile overview shows next to each shortcut, in one request: the next outing and the outing counts, the teams with the user's role, the passkey count, the paired devices, the number of blocked users and where notifications go. The display preferences, contactableByMembers and the connected GPS services are on GET /api/users/me and are not repeated. A fixed number of queries, whatever the amount of data.
 * @summary Summarise the current user's profile
 */
export const getMyProfileSummary = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<ProfileSummaryDto>(
    { url: `/api/users/me/profile-summary`, method: 'GET', signal },
    options
  )
}

export const getGetMyProfileSummaryQueryKey = () => {
  return [`/api/users/me/profile-summary`] as const
}

export const getGetMyProfileSummaryQueryOptions = <
  TData = Awaited<ReturnType<typeof getMyProfileSummary>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMyProfileSummary>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetMyProfileSummaryQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getMyProfileSummary>>> = ({ signal }) =>
    getMyProfileSummary(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getMyProfileSummary>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetMyProfileSummaryQueryResult = NonNullable<
  Awaited<ReturnType<typeof getMyProfileSummary>>
>
export type GetMyProfileSummaryQueryError = ErrorType<ErrorResponse | void>

/**
 * What the profile overview shows next to each shortcut, in one request: the next outing and the outing counts, the teams with the user's role, the passkey count, the paired devices, the number of blocked users and where notifications go. The display preferences, contactableByMembers and the connected GPS services are on GET /api/users/me and are not repeated. A fixed number of queries, whatever the amount of data.
 * @summary Summarise the current user's profile
 */
export function useGetMyProfileSummary<
  TData = Awaited<ReturnType<typeof getMyProfileSummary>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getMyProfileSummary>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getMyProfileSummary>>,
          TError,
          Awaited<ReturnType<typeof getMyProfileSummary>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What the profile overview shows next to each shortcut, in one request: the next outing and the outing counts, the teams with the user's role, the passkey count, the paired devices, the number of blocked users and where notifications go. The display preferences, contactableByMembers and the connected GPS services are on GET /api/users/me and are not repeated. A fixed number of queries, whatever the amount of data.
 * @summary Summarise the current user's profile
 */
export function useGetMyProfileSummary<
  TData = Awaited<ReturnType<typeof getMyProfileSummary>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getMyProfileSummary>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getMyProfileSummary>>,
          TError,
          Awaited<ReturnType<typeof getMyProfileSummary>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What the profile overview shows next to each shortcut, in one request: the next outing and the outing counts, the teams with the user's role, the passkey count, the paired devices, the number of blocked users and where notifications go. The display preferences, contactableByMembers and the connected GPS services are on GET /api/users/me and are not repeated. A fixed number of queries, whatever the amount of data.
 * @summary Summarise the current user's profile
 */
export function useGetMyProfileSummary<
  TData = Awaited<ReturnType<typeof getMyProfileSummary>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMyProfileSummary>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * What the profile overview shows next to each shortcut, in one request: the next outing and the outing counts, the teams with the user's role, the passkey count, the paired devices, the number of blocked users and where notifications go. The display preferences, contactableByMembers and the connected GPS services are on GET /api/users/me and are not repeated. A fixed number of queries, whatever the amount of data.
 * @summary Summarise the current user's profile
 */
export function useGetMyProfileSummary<
  TData = Awaited<ReturnType<typeof getMyProfileSummary>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMyProfileSummary>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetMyProfileSummaryQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * What the profile overview shows next to each shortcut, in one request: the next outing and the outing counts, the teams with the user's role, the passkey count, the paired devices, the number of blocked users and where notifications go. The display preferences, contactableByMembers and the connected GPS services are on GET /api/users/me and are not repeated. A fixed number of queries, whatever the amount of data.
 * @summary Summarise the current user's profile
 */
export const prefetchGetMyProfileSummaryQuery = async <
  TData = Awaited<ReturnType<typeof getMyProfileSummary>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getMyProfileSummary>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetMyProfileSummaryQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
