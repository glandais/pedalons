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
  ListTripCommentsParams,
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
 * @summary List trip comments
 */
export const listTripComments = (
  teamSlug: string,
  entitySlug: string,
  params?: ListTripCommentsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentListResponse>(
    { url: `/api/teams/${teamSlug}/trips/${entitySlug}/comments`, method: 'GET', params, signal },
    options
  )
}

export const getListTripCommentsQueryKey = (
  teamSlug: string,
  entitySlug: string,
  params?: ListTripCommentsParams
) => {
  return [
    `/api/teams/${teamSlug}/trips/${entitySlug}/comments`,
    ...(params ? [params] : []),
  ] as const
}

export const getListTripCommentsQueryOptions = <
  TData = Awaited<ReturnType<typeof listTripComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListTripCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTripComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getListTripCommentsQueryKey(teamSlug, entitySlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listTripComments>>> = ({ signal }) =>
    listTripComments(teamSlug, entitySlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      entitySlug !== null &&
      entitySlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listTripComments>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListTripCommentsQueryResult = NonNullable<Awaited<ReturnType<typeof listTripComments>>>
export type ListTripCommentsQueryError = ErrorType<void | ErrorResponse>

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip comments
 */
export function useListTripComments<
  TData = Awaited<ReturnType<typeof listTripComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params: undefined | ListTripCommentsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTripComments>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTripComments>>,
          TError,
          Awaited<ReturnType<typeof listTripComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip comments
 */
export function useListTripComments<
  TData = Awaited<ReturnType<typeof listTripComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListTripCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTripComments>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTripComments>>,
          TError,
          Awaited<ReturnType<typeof listTripComments>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip comments
 */
export function useListTripComments<
  TData = Awaited<ReturnType<typeof listTripComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListTripCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTripComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip comments
 */
export function useListTripComments<
  TData = Awaited<ReturnType<typeof listTripComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  entitySlug: string,
  params?: ListTripCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTripComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListTripCommentsQueryOptions(teamSlug, entitySlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Top-level comments with their replies. Passing neither page nor size returns the whole tree, as before this endpoint took parameters; passing either paginates the top-level comments. parentId switches to listing the replies of a single comment.
 * @summary List trip comments
 */
export const prefetchListTripCommentsQuery = async <
  TData = Awaited<ReturnType<typeof listTripComments>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  entitySlug: string,
  params?: ListTripCommentsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTripComments>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListTripCommentsQueryOptions(teamSlug, entitySlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * @summary Create trip comment
 */
export const createTripComment = (
  teamSlug: string,
  entitySlug: string,
  commentRequest: BodyType<CommentRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CommentDto>(
    {
      url: `/api/teams/${teamSlug}/trips/${entitySlug}/comments`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: commentRequest,
      signal,
    },
    options
  )
}

export const getCreateTripCommentMutationKey = () => ['createTripComment'] as const

export const getCreateTripCommentMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createTripComment>>,
    TError,
    CreateTripCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createTripComment>>,
  TError,
  CreateTripCommentMutationVariables,
  TContext
> => {
  const mutationKey = getCreateTripCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createTripComment>>,
    CreateTripCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, data } = props ?? {}

    return createTripComment(teamSlug, entitySlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateTripCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof createTripComment>>
>
export type CreateTripCommentMutationBody = BodyType<CommentRequest>
export type CreateTripCommentMutationError = ErrorType<ErrorResponse | void>
export type CreateTripCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  data: BodyType<CommentRequest>
}

/** @summary Create trip comment */
export const useCreateTripComment = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createTripComment>>,
      TError,
      CreateTripCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createTripComment>>,
  TError,
  CreateTripCommentMutationVariables,
  TContext
> => {
  return useMutation(getCreateTripCommentMutationOptions(options), queryClient)
}
/**
 * @summary Delete trip comment
 */
export const deleteTripComment = (
  teamSlug: string,
  entitySlug: string,
  commentId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/teams/${teamSlug}/trips/${entitySlug}/comments/${commentId}`,
      method: 'DELETE',
      signal,
    },
    options
  )
}

export const getDeleteTripCommentMutationKey = () => ['deleteTripComment'] as const

export const getDeleteTripCommentMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteTripComment>>,
    TError,
    DeleteTripCommentMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteTripComment>>,
  TError,
  DeleteTripCommentMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteTripCommentMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteTripComment>>,
    DeleteTripCommentMutationVariables
  > = (props) => {
    const { teamSlug, entitySlug, commentId } = props ?? {}

    return deleteTripComment(teamSlug, entitySlug, commentId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteTripCommentMutationResult = NonNullable<
  Awaited<ReturnType<typeof deleteTripComment>>
>

export type DeleteTripCommentMutationError = ErrorType<void | ErrorResponse>
export type DeleteTripCommentMutationVariables = {
  teamSlug: string
  entitySlug: string
  commentId: string
}

/** @summary Delete trip comment */
export const useDeleteTripComment = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteTripComment>>,
      TError,
      DeleteTripCommentMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteTripComment>>,
  TError,
  DeleteTripCommentMutationVariables,
  TContext
> => {
  return useMutation(getDeleteTripCommentMutationOptions(options), queryClient)
}
