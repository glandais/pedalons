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
  ListRouteCommentsParams,
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
 * @summary List route comments
 */
export const listRouteComments = (
  teamSlug: string,
  entitySlug: string,
  params?: ListRouteCommentsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentListResponse>(
    { url: `/api/teams/${teamSlug}/routes/${entitySlug}/comments`, method: 'GET', params, signal },
    options
  )
}

export const getListRouteCommentsQueryKey = (
  teamSlug: string,
  entitySlug: string,
  params?: ListRouteCommentsParams
) => {
  return [
    `/api/teams/${teamSlug}/routes/${entitySlug}/comments`,
    ...(params ? [params] : []),
  ] as const
}

export const getListRouteCommentsQueryOptions = <
  TData = Awaited<ReturnType<typeof listRouteComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListRouteCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRouteComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getListRouteCommentsQueryKey(teamSlug, entitySlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listRouteComments>>> = ({ signal }) =>
    listRouteComments(teamSlug, entitySlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      entitySlug !== null &&
      entitySlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listRouteComments>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListRouteCommentsQueryResult = NonNullable<
  Awaited<ReturnType<typeof listRouteComments>>
>
export type ListRouteCommentsQueryError = ErrorType<void | ErrorResponse>

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List route comments
 */
export function useListRouteComments<
  TData = Awaited<ReturnType<typeof listRouteComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params: undefined | ListRouteCommentsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRouteComments>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listRouteComments>>,
          TError,
          Awaited<ReturnType<typeof listRouteComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List route comments
 */
export function useListRouteComments<
  TData = Awaited<ReturnType<typeof listRouteComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListRouteCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRouteComments>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listRouteComments>>,
          TError,
          Awaited<ReturnType<typeof listRouteComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List route comments
 */
export function useListRouteComments<
  TData = Awaited<ReturnType<typeof listRouteComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListRouteCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRouteComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List route comments
 */
export function useListRouteComments<
  TData = Awaited<ReturnType<typeof listRouteComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListRouteCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRouteComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListRouteCommentsQueryOptions(teamSlug, entitySlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List route comments
 */
export const prefetchListRouteCommentsQuery = async <
  TData = Awaited<ReturnType<typeof listRouteComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  entitySlug: string,
  params?: ListRouteCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listRouteComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListRouteCommentsQueryOptions(teamSlug, entitySlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * @summary Create route comment
 */
export const createRouteComment = (
  teamSlug: string,
  entitySlug: string,
  commentRequest: BodyType<CommentRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentDto>(
    {
      url: `/api/teams/${teamSlug}/routes/${entitySlug}/comments`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: commentRequest,
      signal,
    },
    options
  )
}

export const getCreateRouteCommentMutationKey = () => ['createRouteComment'] as const

export const getCreateRouteCommentMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createRouteComment>>,
    TError,
    CreateRouteCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createRouteComment>>,
  TError,
  CreateRouteCommentMutationVariables,
  TContext
> => {
  const mutationKey = getCreateRouteCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createRouteComment>>,
    CreateRouteCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, data } = props ?? {}

    return createRouteComment(teamSlug, entitySlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateRouteCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof createRouteComment>>
>
export type CreateRouteCommentMutationBody = BodyType<CommentRequest>
export type CreateRouteCommentMutationError = ErrorType<ErrorResponse | void>
export type CreateRouteCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  data: BodyType<CommentRequest>
}

/** @summary Create route comment */
export const useCreateRouteComment = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createRouteComment>>,
      TError,
      CreateRouteCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createRouteComment>>,
  TError,
  CreateRouteCommentMutationVariables,
  TContext
> => {
  return useMutation(getCreateRouteCommentMutationOptions(options), queryClient)
}
/**
 * @summary Delete route comment
 */
export const deleteRouteComment = (
  teamSlug: string,
  entitySlug: string,
  commentId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/teams/${teamSlug}/routes/${entitySlug}/comments/${commentId}`,
      method: 'DELETE',
      signal,
    },
    options
  )
}

export const getDeleteRouteCommentMutationKey = () => ['deleteRouteComment'] as const

export const getDeleteRouteCommentMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteRouteComment>>,
    TError,
    DeleteRouteCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteRouteComment>>,
  TError,
  DeleteRouteCommentMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteRouteCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteRouteComment>>,
    DeleteRouteCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, commentId } = props ?? {}

    return deleteRouteComment(teamSlug, entitySlug, commentId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteRouteCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof deleteRouteComment>>
>

export type DeleteRouteCommentMutationError = ErrorType<void | ErrorResponse>
export type DeleteRouteCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  commentId: string
}

/** @summary Delete route comment */
export const useDeleteRouteComment = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteRouteComment>>,
      TError,
      DeleteRouteCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteRouteComment>>,
  TError,
  DeleteRouteCommentMutationVariables,
  TContext
> => {
  return useMutation(getDeleteRouteCommentMutationOptions(options), queryClient)
}
