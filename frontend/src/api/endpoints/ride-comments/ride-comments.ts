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
  ListRideCommentsParams,
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
 * @summary List ride comments
 */
export const listRideComments = (
  teamSlug: string,
  entitySlug: string,
  params?: ListRideCommentsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentListResponse>(
    { url: `/api/teams/${teamSlug}/rides/${entitySlug}/comments`, method: 'GET', params, signal },
    options
  )
}

export const getListRideCommentsQueryKey = (
  teamSlug: string,
  entitySlug: string,
  params?: ListRideCommentsParams
) => {
  return [
    `/api/teams/${teamSlug}/rides/${entitySlug}/comments`,
    ...(params ? [params] : []),
  ] as const
}

export const getListRideCommentsQueryOptions = <
  TData = Awaited<ReturnType<typeof listRideComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListRideCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRideComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getListRideCommentsQueryKey(teamSlug, entitySlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listRideComments>>> = ({ signal }) =>
    listRideComments(teamSlug, entitySlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      entitySlug !== null &&
      entitySlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listRideComments>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListRideCommentsQueryResult = NonNullable<Awaited<ReturnType<typeof listRideComments>>>
export type ListRideCommentsQueryError = ErrorType<void | ErrorResponse>

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List ride comments
 */
export function useListRideComments<
  TData = Awaited<ReturnType<typeof listRideComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params: undefined | ListRideCommentsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRideComments>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listRideComments>>,
          TError,
          Awaited<ReturnType<typeof listRideComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List ride comments
 */
export function useListRideComments<
  TData = Awaited<ReturnType<typeof listRideComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListRideCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRideComments>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listRideComments>>,
          TError,
          Awaited<ReturnType<typeof listRideComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List ride comments
 */
export function useListRideComments<
  TData = Awaited<ReturnType<typeof listRideComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListRideCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRideComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List ride comments
 */
export function useListRideComments<
  TData = Awaited<ReturnType<typeof listRideComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListRideCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRideComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListRideCommentsQueryOptions(teamSlug, entitySlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List ride comments
 */
export const prefetchListRideCommentsQuery = async <
  TData = Awaited<ReturnType<typeof listRideComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  entitySlug: string,
  params?: ListRideCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRideComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListRideCommentsQueryOptions(teamSlug, entitySlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * @summary Create ride comment
 */
export const createRideComment = (
  teamSlug: string,
  entitySlug: string,
  commentRequest: BodyType<CommentRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentDto>(
    {
      url: `/api/teams/${teamSlug}/rides/${entitySlug}/comments`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: commentRequest,
      signal,
    },
    options
  )
}

export const getCreateRideCommentMutationKey = () => ['createRideComment'] as const

export const getCreateRideCommentMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createRideComment>>,
    TError,
    CreateRideCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createRideComment>>,
  TError,
  CreateRideCommentMutationVariables,
  TContext
> => {
  const mutationKey = getCreateRideCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createRideComment>>,
    CreateRideCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, data } = props ?? {}

    return createRideComment(teamSlug, entitySlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateRideCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof createRideComment>>
>
export type CreateRideCommentMutationBody = BodyType<CommentRequest>
export type CreateRideCommentMutationError = ErrorType<ErrorResponse | void>
export type CreateRideCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  data: BodyType<CommentRequest>
}

/** @summary Create ride comment */
export const useCreateRideComment = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createRideComment>>,
      TError,
      CreateRideCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createRideComment>>,
  TError,
  CreateRideCommentMutationVariables,
  TContext
> => {
  return useMutation(getCreateRideCommentMutationOptions(options), queryClient)
}
/**
 * @summary Delete ride comment
 */
export const deleteRideComment = (
  teamSlug: string,
  entitySlug: string,
  commentId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/teams/${teamSlug}/rides/${entitySlug}/comments/${commentId}`,
      method: 'DELETE',
      signal,
    },
    options
  )
}

export const getDeleteRideCommentMutationKey = () => ['deleteRideComment'] as const

export const getDeleteRideCommentMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteRideComment>>,
    TError,
    DeleteRideCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteRideComment>>,
  TError,
  DeleteRideCommentMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteRideCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteRideComment>>,
    DeleteRideCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, commentId } = props ?? {}

    return deleteRideComment(teamSlug, entitySlug, commentId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteRideCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof deleteRideComment>>
>

export type DeleteRideCommentMutationError = ErrorType<void | ErrorResponse>
export type DeleteRideCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  commentId: string
}

/** @summary Delete ride comment */
export const useDeleteRideComment = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteRideComment>>,
      TError,
      DeleteRideCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteRideComment>>,
  TError,
  DeleteRideCommentMutationVariables,
  TContext
> => {
  return useMutation(getDeleteRideCommentMutationOptions(options), queryClient)
}
