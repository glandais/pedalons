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
  ListTripStageCommentsParams,
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
 * @summary List trip stage comments
 */
export const listTripStageComments = (
  teamSlug: string,
  entitySlug: string,
  params?: ListTripStageCommentsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentListResponse>(
    { url: `/api/teams/${teamSlug}/stages/${entitySlug}/comments`, method: 'GET', params, signal },
    options
  )
}

export const getListTripStageCommentsQueryKey = (
  teamSlug: string,
  entitySlug: string,
  params?: ListTripStageCommentsParams
) => {
  return [
    `/api/teams/${teamSlug}/stages/${entitySlug}/comments`,
    ...(params ? [params] : []),
  ] as const
}

export const getListTripStageCommentsQueryOptions = <
  TData = Awaited<ReturnType<typeof listTripStageComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListTripStageCommentsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listTripStageComments>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getListTripStageCommentsQueryKey(teamSlug, entitySlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listTripStageComments>>> = ({ signal }) =>
    listTripStageComments(teamSlug, entitySlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      entitySlug !== null &&
      entitySlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listTripStageComments>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListTripStageCommentsQueryResult = NonNullable<
  Awaited<ReturnType<typeof listTripStageComments>>
>
export type ListTripStageCommentsQueryError = ErrorType<void | ErrorResponse>

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip stage comments
 */
export function useListTripStageComments<
  TData = Awaited<ReturnType<typeof listTripStageComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params: undefined | ListTripStageCommentsParams,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listTripStageComments>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTripStageComments>>,
          TError,
          Awaited<ReturnType<typeof listTripStageComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip stage comments
 */
export function useListTripStageComments<
  TData = Awaited<ReturnType<typeof listTripStageComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListTripStageCommentsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listTripStageComments>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTripStageComments>>,
          TError,
          Awaited<ReturnType<typeof listTripStageComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip stage comments
 */
export function useListTripStageComments<
  TData = Awaited<ReturnType<typeof listTripStageComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListTripStageCommentsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listTripStageComments>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip stage comments
 */
export function useListTripStageComments<
  TData = Awaited<ReturnType<typeof listTripStageComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListTripStageCommentsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listTripStageComments>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListTripStageCommentsQueryOptions(teamSlug, entitySlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip stage comments
 */
export const prefetchListTripStageCommentsQuery = async <
  TData = Awaited<ReturnType<typeof listTripStageComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  entitySlug: string,
  params?: ListTripStageCommentsParams,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listTripStageComments>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListTripStageCommentsQueryOptions(teamSlug, entitySlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * @summary Create trip stage comment
 */
export const createTripStageComment = (
  teamSlug: string,
  entitySlug: string,
  commentRequest: BodyType<CommentRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentDto>(
    {
      url: `/api/teams/${teamSlug}/stages/${entitySlug}/comments`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: commentRequest,
      signal,
    },
    options
  )
}

export const getCreateTripStageCommentMutationKey = () => ['createTripStageComment'] as const

export const getCreateTripStageCommentMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createTripStageComment>>,
    TError,
    CreateTripStageCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createTripStageComment>>,
  TError,
  CreateTripStageCommentMutationVariables,
  TContext
> => {
  const mutationKey = getCreateTripStageCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createTripStageComment>>,
    CreateTripStageCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, data } = props ?? {}

    return createTripStageComment(teamSlug, entitySlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateTripStageCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof createTripStageComment>>
>
export type CreateTripStageCommentMutationBody = BodyType<CommentRequest>
export type CreateTripStageCommentMutationError = ErrorType<ErrorResponse | void>
export type CreateTripStageCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  data: BodyType<CommentRequest>
}

/** @summary Create trip stage comment */
export const useCreateTripStageComment = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createTripStageComment>>,
      TError,
      CreateTripStageCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createTripStageComment>>,
  TError,
  CreateTripStageCommentMutationVariables,
  TContext
> => {
  return useMutation(getCreateTripStageCommentMutationOptions(options), queryClient)
}
/**
 * @summary Delete trip stage comment
 */
export const deleteTripStageComment = (
  teamSlug: string,
  entitySlug: string,
  commentId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/teams/${teamSlug}/stages/${entitySlug}/comments/${commentId}`,
      method: 'DELETE',
      signal,
    },
    options
  )
}

export const getDeleteTripStageCommentMutationKey = () => ['deleteTripStageComment'] as const

export const getDeleteTripStageCommentMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteTripStageComment>>,
    TError,
    DeleteTripStageCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteTripStageComment>>,
  TError,
  DeleteTripStageCommentMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteTripStageCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteTripStageComment>>,
    DeleteTripStageCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, commentId } = props ?? {}

    return deleteTripStageComment(teamSlug, entitySlug, commentId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteTripStageCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof deleteTripStageComment>>
>

export type DeleteTripStageCommentMutationError = ErrorType<void | ErrorResponse>
export type DeleteTripStageCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  commentId: string
}

/** @summary Delete trip stage comment */
export const useDeleteTripStageComment = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteTripStageComment>>,
      TError,
      DeleteTripStageCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteTripStageComment>>,
  TError,
  DeleteTripStageCommentMutationVariables,
  TContext
> => {
  return useMutation(getDeleteTripStageCommentMutationOptions(options), queryClient)
}
