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
  CommentDto,
  CommentListResponse,
  CommentRequest,
  ErrorResponse,
  ListPostCommentsParams,
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
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List post comments
 */
export const listPostComments = (
  teamSlug: string,
  entitySlug: string,
  params?: ListPostCommentsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentListResponse>(
    { url: `/api/teams/${teamSlug}/posts/${entitySlug}/comments`, method: 'GET', params, signal },
    options
  )
}

export const getListPostCommentsQueryKey = (
  teamSlug: string,
  entitySlug: string,
  params?: ListPostCommentsParams
) => {
  return [
    `/api/teams/${teamSlug}/posts/${entitySlug}/comments`,
    ...(params ? [params] : []),
  ] as const
}

export const getListPostCommentsQueryOptions = <
  TData = Awaited<ReturnType<typeof listPostComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListPostCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPostComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getListPostCommentsQueryKey(teamSlug, entitySlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listPostComments>>> = ({ signal }) =>
    listPostComments(teamSlug, entitySlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      entitySlug !== null &&
      entitySlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listPostComments>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListPostCommentsQueryResult = NonNullable<Awaited<ReturnType<typeof listPostComments>>>
export type ListPostCommentsQueryError = ErrorType<void | ErrorResponse>

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List post comments
 */
export function useListPostComments<
  TData = Awaited<ReturnType<typeof listPostComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params: undefined | ListPostCommentsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPostComments>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPostComments>>,
          TError,
          Awaited<ReturnType<typeof listPostComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List post comments
 */
export function useListPostComments<
  TData = Awaited<ReturnType<typeof listPostComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListPostCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPostComments>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPostComments>>,
          TError,
          Awaited<ReturnType<typeof listPostComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List post comments
 */
export function useListPostComments<
  TData = Awaited<ReturnType<typeof listPostComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListPostCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPostComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List post comments
 */
export function useListPostComments<
  TData = Awaited<ReturnType<typeof listPostComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListPostCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPostComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListPostCommentsQueryOptions(teamSlug, entitySlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List post comments
 */
export const prefetchListPostCommentsQuery = async <
  TData = Awaited<ReturnType<typeof listPostComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  entitySlug: string,
  params?: ListPostCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPostComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListPostCommentsQueryOptions(teamSlug, entitySlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * @summary Create post comment
 */
export const createPostComment = (
  teamSlug: string,
  entitySlug: string,
  commentRequest: BodyType<CommentRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentDto>(
    {
      url: `/api/teams/${teamSlug}/posts/${entitySlug}/comments`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: commentRequest,
      signal,
    },
    options
  )
}

export const getCreatePostCommentMutationKey = () => ['createPostComment'] as const

export const getCreatePostCommentMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createPostComment>>,
    TError,
    CreatePostCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createPostComment>>,
  TError,
  CreatePostCommentMutationVariables,
  TContext
> => {
  const mutationKey = getCreatePostCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createPostComment>>,
    CreatePostCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, data } = props ?? {}

    return createPostComment(teamSlug, entitySlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreatePostCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof createPostComment>>
>
export type CreatePostCommentMutationBody = BodyType<CommentRequest>
export type CreatePostCommentMutationError = ErrorType<ErrorResponse | void>
export type CreatePostCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  data: BodyType<CommentRequest>
}

/** @summary Create post comment */
export const useCreatePostComment = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createPostComment>>,
      TError,
      CreatePostCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createPostComment>>,
  TError,
  CreatePostCommentMutationVariables,
  TContext
> => {
  return useMutation(getCreatePostCommentMutationOptions(options), queryClient)
}
/**
 * @summary Delete post comment
 */
export const deletePostComment = (
  teamSlug: string,
  entitySlug: string,
  commentId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/teams/${teamSlug}/posts/${entitySlug}/comments/${commentId}`,
      method: 'DELETE',
      signal,
    },
    options
  )
}

export const getDeletePostCommentMutationKey = () => ['deletePostComment'] as const

export const getDeletePostCommentMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deletePostComment>>,
    TError,
    DeletePostCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deletePostComment>>,
  TError,
  DeletePostCommentMutationVariables,
  TContext
> => {
  const mutationKey = getDeletePostCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deletePostComment>>,
    DeletePostCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, commentId } = props ?? {}

    return deletePostComment(teamSlug, entitySlug, commentId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeletePostCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof deletePostComment>>
>

export type DeletePostCommentMutationError = ErrorType<void | ErrorResponse>
export type DeletePostCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  commentId: string
}

/** @summary Delete post comment */
export const useDeletePostComment = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deletePostComment>>,
      TError,
      DeletePostCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deletePostComment>>,
  TError,
  DeletePostCommentMutationVariables,
  TContext
> => {
  return useMutation(getDeletePostCommentMutationOptions(options), queryClient)
}
