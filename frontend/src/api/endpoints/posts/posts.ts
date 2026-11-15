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
  PostDto,
  PostRequest,
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
 * Create a new post with optional groups
 * @summary Create post
 */
export const createPost = (
  teamSlug: string,
  postRequest: BodyType<PostRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PostDto>(
    {
      url: `/api/teams/${teamSlug}/posts`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: postRequest,
      signal,
    },
    options
  )
}

export const getCreatePostMutationKey = () => ['createPost'] as const

export const getCreatePostMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createPost>>,
    TError,
    CreatePostMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createPost>>,
  TError,
  CreatePostMutationVariables,
  TContext
> => {
  const mutationKey = getCreatePostMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createPost>>,
    CreatePostMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createPost(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreatePostMutationResult = NonNullable<Awaited<ReturnType<typeof createPost>>>
export type CreatePostMutationBody = BodyType<PostRequest>
export type CreatePostMutationError = ErrorType<ErrorResponse>
export type CreatePostMutationVariables = { teamSlug: string; data: BodyType<PostRequest> }

/**
 * Create a new post with optional groups
 * @summary Create post
 */
export const useCreatePost = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createPost>>,
      TError,
      CreatePostMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createPost>>,
  TError,
  CreatePostMutationVariables,
  TContext
> => {
  return useMutation(getCreatePostMutationOptions(options), queryClient)
}
/**
 * Update post information. Requires organizer permissions.
 * @summary Update post
 */
export const updatePost = (
  teamSlug: string,
  postSlug: string,
  postRequest: BodyType<PostRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PostDto>(
    {
      url: `/api/teams/${teamSlug}/posts/${postSlug}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: postRequest,
      signal,
    },
    options
  )
}

export const getUpdatePostMutationKey = () => ['updatePost'] as const

export const getUpdatePostMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updatePost>>,
    TError,
    UpdatePostMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updatePost>>,
  TError,
  UpdatePostMutationVariables,
  TContext
> => {
  const mutationKey = getUpdatePostMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updatePost>>,
    UpdatePostMutationVariables
  > = (props) => {
    const { teamSlug, postSlug, data } = props ?? {}

    return updatePost(teamSlug, postSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdatePostMutationResult = NonNullable<Awaited<ReturnType<typeof updatePost>>>
export type UpdatePostMutationBody = BodyType<PostRequest>
export type UpdatePostMutationError = ErrorType<ErrorResponse>
export type UpdatePostMutationVariables = {
  teamSlug: string
  postSlug: string
  data: BodyType<PostRequest>
}

/**
 * Update post information. Requires organizer permissions.
 * @summary Update post
 */
export const useUpdatePost = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updatePost>>,
      TError,
      UpdatePostMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updatePost>>,
  TError,
  UpdatePostMutationVariables,
  TContext
> => {
  return useMutation(getUpdatePostMutationOptions(options), queryClient)
}
/**
 * Get detailed post information including groups
 * @summary Get post details
 */
export const getPost = (
  teamSlug: string,
  postSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PostDto>(
    { url: `/api/teams/${teamSlug}/posts/${postSlug}`, method: 'GET', signal },
    options
  )
}

export const getGetPostQueryKey = (teamSlug: string, postSlug: string) => {
  return [`/api/teams/${teamSlug}/posts/${postSlug}`] as const
}

export const getGetPostQueryOptions = <
  TData = Awaited<ReturnType<typeof getPost>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  postSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPost>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetPostQueryKey(teamSlug, postSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getPost>>> = ({ signal }) =>
    getPost(teamSlug, postSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && postSlug !== null && postSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getPost>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetPostQueryResult = NonNullable<Awaited<ReturnType<typeof getPost>>>
export type GetPostQueryError = ErrorType<ErrorResponse>

/**
 * Get detailed post information including groups
 * @summary Get post details
 */
export function useGetPost<
  TData = Awaited<ReturnType<typeof getPost>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  postSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPost>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPost>>,
          TError,
          Awaited<ReturnType<typeof getPost>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed post information including groups
 * @summary Get post details
 */
export function useGetPost<
  TData = Awaited<ReturnType<typeof getPost>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  postSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPost>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPost>>,
          TError,
          Awaited<ReturnType<typeof getPost>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed post information including groups
 * @summary Get post details
 */
export function useGetPost<
  TData = Awaited<ReturnType<typeof getPost>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  postSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPost>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed post information including groups
 * @summary Get post details
 */
export function useGetPost<
  TData = Awaited<ReturnType<typeof getPost>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  postSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPost>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetPostQueryOptions(teamSlug, postSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed post information including groups
 * @summary Get post details
 */
export const prefetchGetPostQuery = async <
  TData = Awaited<ReturnType<typeof getPost>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  postSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPost>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetPostQueryOptions(teamSlug, postSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Soft delete a post. Requires organizer permissions.
 * @summary Delete post
 */
export const deletePost = (
  teamSlug: string,
  postSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/posts/${postSlug}`, method: 'DELETE', signal },
    options
  )
}

export const getDeletePostMutationKey = () => ['deletePost'] as const

export const getDeletePostMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deletePost>>,
    TError,
    DeletePostMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deletePost>>,
  TError,
  DeletePostMutationVariables,
  TContext
> => {
  const mutationKey = getDeletePostMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deletePost>>,
    DeletePostMutationVariables
  > = (props) => {
    const { teamSlug, postSlug } = props ?? {}

    return deletePost(teamSlug, postSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeletePostMutationResult = NonNullable<Awaited<ReturnType<typeof deletePost>>>

export type DeletePostMutationError = ErrorType<ErrorResponse>
export type DeletePostMutationVariables = { teamSlug: string; postSlug: string }

/**
 * Soft delete a post. Requires organizer permissions.
 * @summary Delete post
 */
export const useDeletePost = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deletePost>>,
      TError,
      DeletePostMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deletePost>>,
  TError,
  DeletePostMutationVariables,
  TContext
> => {
  return useMutation(getDeletePostMutationOptions(options), queryClient)
}
/**
 * Change post URL slug. Requires organizer permissions.
 * @summary Change post slug
 */
export const changePostSlug = (
  teamSlug: string,
  postSlug: string,
  slugChangeRequest: BodyType<SlugChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PostDto>(
    {
      url: `/api/teams/${teamSlug}/posts/${postSlug}/slug`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: slugChangeRequest,
      signal,
    },
    options
  )
}

export const getChangePostSlugMutationKey = () => ['changePostSlug'] as const

export const getChangePostSlugMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changePostSlug>>,
    TError,
    ChangePostSlugMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changePostSlug>>,
  TError,
  ChangePostSlugMutationVariables,
  TContext
> => {
  const mutationKey = getChangePostSlugMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changePostSlug>>,
    ChangePostSlugMutationVariables
  > = (props) => {
    const { teamSlug, postSlug, data } = props ?? {}

    return changePostSlug(teamSlug, postSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangePostSlugMutationResult = NonNullable<Awaited<ReturnType<typeof changePostSlug>>>
export type ChangePostSlugMutationBody = BodyType<SlugChangeRequest>
export type ChangePostSlugMutationError = ErrorType<ErrorResponse | void>
export type ChangePostSlugMutationVariables = {
  teamSlug: string
  postSlug: string
  data: BodyType<SlugChangeRequest>
}

/**
 * Change post URL slug. Requires organizer permissions.
 * @summary Change post slug
 */
export const useChangePostSlug = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changePostSlug>>,
      TError,
      ChangePostSlugMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changePostSlug>>,
  TError,
  ChangePostSlugMutationVariables,
  TContext
> => {
  return useMutation(getChangePostSlugMutationOptions(options), queryClient)
}
/**
 * Change the post's status and nothing else — what a list row can do without the full post. Same side effects as a status change through the update. Requires organizer permissions.
 * @summary Change post status
 */
export const changePostStatus = (
  teamSlug: string,
  postSlug: string,
  statusChangeRequest: BodyType<StatusChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PostDto>(
    {
      url: `/api/teams/${teamSlug}/posts/${postSlug}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: statusChangeRequest,
      signal,
    },
    options
  )
}

export const getChangePostStatusMutationKey = () => ['changePostStatus'] as const

export const getChangePostStatusMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changePostStatus>>,
    TError,
    ChangePostStatusMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changePostStatus>>,
  TError,
  ChangePostStatusMutationVariables,
  TContext
> => {
  const mutationKey = getChangePostStatusMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changePostStatus>>,
    ChangePostStatusMutationVariables
  > = (props) => {
    const { teamSlug, postSlug, data } = props ?? {}

    return changePostStatus(teamSlug, postSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangePostStatusMutationResult = NonNullable<
  Awaited<ReturnType<typeof changePostStatus>>
>
export type ChangePostStatusMutationBody = BodyType<StatusChangeRequest>
export type ChangePostStatusMutationError = ErrorType<ErrorResponse>
export type ChangePostStatusMutationVariables = {
  teamSlug: string
  postSlug: string
  data: BodyType<StatusChangeRequest>
}

/**
 * Change the post's status and nothing else — what a list row can do without the full post. Same side effects as a status change through the update. Requires organizer permissions.
 * @summary Change post status
 */
export const useChangePostStatus = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changePostStatus>>,
      TError,
      ChangePostStatusMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changePostStatus>>,
  TError,
  ChangePostStatusMutationVariables,
  TContext
> => {
  return useMutation(getChangePostStatusMutationOptions(options), queryClient)
}
/**
 * Restore a soft-deleted post. Requires organizer permissions.
 * @summary Restore post
 */
export const undeletePost = (
  teamSlug: string,
  postSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PostDto>(
    { url: `/api/teams/${teamSlug}/posts/${postSlug}/undelete`, method: 'POST', signal },
    options
  )
}

export const getUndeletePostMutationKey = () => ['undeletePost'] as const

export const getUndeletePostMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof undeletePost>>,
    TError,
    UndeletePostMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof undeletePost>>,
  TError,
  UndeletePostMutationVariables,
  TContext
> => {
  const mutationKey = getUndeletePostMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof undeletePost>>,
    UndeletePostMutationVariables
  > = (props) => {
    const { teamSlug, postSlug } = props ?? {}

    return undeletePost(teamSlug, postSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UndeletePostMutationResult = NonNullable<Awaited<ReturnType<typeof undeletePost>>>

export type UndeletePostMutationError = ErrorType<ErrorResponse>
export type UndeletePostMutationVariables = { teamSlug: string; postSlug: string }

/**
 * Restore a soft-deleted post. Requires organizer permissions.
 * @summary Restore post
 */
export const useUndeletePost = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof undeletePost>>,
      TError,
      UndeletePostMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof undeletePost>>,
  TError,
  UndeletePostMutationVariables,
  TContext
> => {
  return useMutation(getUndeletePostMutationOptions(options), queryClient)
}
