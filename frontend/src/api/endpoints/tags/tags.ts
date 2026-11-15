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
  ListTeamTagsParams,
  TagCreateRequest,
  TagDeletedDto,
  TagUpdateRequest,
  TagWithUsageDto,
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
 * The team's tags, sorted by label, each with its usage count. Open to whoever can see the team.
 * @summary List team tags
 */
export const listTeamTags = (
  teamSlug: string,
  params?: ListTeamTagsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TagWithUsageDto[]>(
    { url: `/api/teams/${teamSlug}/tags`, method: 'GET', params, signal },
    options
  )
}

export const getListTeamTagsQueryKey = (teamSlug: string, params?: ListTeamTagsParams) => {
  return [`/api/teams/${teamSlug}/tags`, ...(params ? [params] : [])] as const
}

export const getListTeamTagsQueryOptions = <
  TData = Awaited<ReturnType<typeof listTeamTags>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTeamTagsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamTags>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListTeamTagsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listTeamTags>>> = ({ signal }) =>
    listTeamTags(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listTeamTags>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListTeamTagsQueryResult = NonNullable<Awaited<ReturnType<typeof listTeamTags>>>
export type ListTeamTagsQueryError = ErrorType<ErrorResponse>

/**
 * The team's tags, sorted by label, each with its usage count. Open to whoever can see the team.
 * @summary List team tags
 */
export function useListTeamTags<
  TData = Awaited<ReturnType<typeof listTeamTags>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | ListTeamTagsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamTags>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTeamTags>>,
          TError,
          Awaited<ReturnType<typeof listTeamTags>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The team's tags, sorted by label, each with its usage count. Open to whoever can see the team.
 * @summary List team tags
 */
export function useListTeamTags<
  TData = Awaited<ReturnType<typeof listTeamTags>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTeamTagsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamTags>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTeamTags>>,
          TError,
          Awaited<ReturnType<typeof listTeamTags>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The team's tags, sorted by label, each with its usage count. Open to whoever can see the team.
 * @summary List team tags
 */
export function useListTeamTags<
  TData = Awaited<ReturnType<typeof listTeamTags>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTeamTagsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamTags>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The team's tags, sorted by label, each with its usage count. Open to whoever can see the team.
 * @summary List team tags
 */
export function useListTeamTags<
  TData = Awaited<ReturnType<typeof listTeamTags>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTeamTagsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamTags>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListTeamTagsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * The team's tags, sorted by label, each with its usage count. Open to whoever can see the team.
 * @summary List team tags
 */
export const prefetchListTeamTagsQuery = async <
  TData = Awaited<ReturnType<typeof listTeamTags>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: ListTeamTagsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTeamTags>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListTeamTagsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Requires team admin permissions.
 * @summary Create a team tag
 */
export const createTeamTag = (
  teamSlug: string,
  tagCreateRequest: BodyType<TagCreateRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TagWithUsageDto>(
    {
      url: `/api/teams/${teamSlug}/tags`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: tagCreateRequest,
      signal,
    },
    options
  )
}

export const getCreateTeamTagMutationKey = () => ['createTeamTag'] as const

export const getCreateTeamTagMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createTeamTag>>,
    TError,
    CreateTeamTagMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createTeamTag>>,
  TError,
  CreateTeamTagMutationVariables,
  TContext
> => {
  const mutationKey = getCreateTeamTagMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createTeamTag>>,
    CreateTeamTagMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createTeamTag(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateTeamTagMutationResult = NonNullable<Awaited<ReturnType<typeof createTeamTag>>>
export type CreateTeamTagMutationBody = BodyType<TagCreateRequest>
export type CreateTeamTagMutationError = ErrorType<ErrorResponse>
export type CreateTeamTagMutationVariables = { teamSlug: string; data: BodyType<TagCreateRequest> }

/**
 * Requires team admin permissions.
 * @summary Create a team tag
 */
export const useCreateTeamTag = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createTeamTag>>,
      TError,
      CreateTeamTagMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createTeamTag>>,
  TError,
  CreateTeamTagMutationVariables,
  TContext
> => {
  return useMutation(getCreateTeamTagMutationOptions(options), queryClient)
}
/**
 * Absent fields are unchanged; the kind never changes. Requires team admin.
 * @summary Rename or recolour a team tag
 */
export const updateTeamTag = (
  teamSlug: string,
  tagId: string,
  tagUpdateRequest: BodyType<TagUpdateRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TagWithUsageDto>(
    {
      url: `/api/teams/${teamSlug}/tags/${tagId}`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: tagUpdateRequest,
      signal,
    },
    options
  )
}

export const getUpdateTeamTagMutationKey = () => ['updateTeamTag'] as const

export const getUpdateTeamTagMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateTeamTag>>,
    TError,
    UpdateTeamTagMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateTeamTag>>,
  TError,
  UpdateTeamTagMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateTeamTagMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateTeamTag>>,
    UpdateTeamTagMutationVariables
  > = (props) => {
    const { teamSlug, tagId, data } = props ?? {}

    return updateTeamTag(teamSlug, tagId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateTeamTagMutationResult = NonNullable<Awaited<ReturnType<typeof updateTeamTag>>>
export type UpdateTeamTagMutationBody = BodyType<TagUpdateRequest>
export type UpdateTeamTagMutationError = ErrorType<ErrorResponse>
export type UpdateTeamTagMutationVariables = {
  teamSlug: string
  tagId: string
  data: BodyType<TagUpdateRequest>
}

/**
 * Absent fields are unchanged; the kind never changes. Requires team admin.
 * @summary Rename or recolour a team tag
 */
export const useUpdateTeamTag = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateTeamTag>>,
      TError,
      UpdateTeamTagMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateTeamTag>>,
  TError,
  UpdateTeamTagMutationVariables,
  TContext
> => {
  return useMutation(getUpdateTeamTagMutationOptions(options), queryClient)
}
/**
 * Detaches the tag from every content and deletes it for good. Requires team admin.
 * @summary Delete a team tag
 */
export const deleteTeamTag = (
  teamSlug: string,
  tagId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TagDeletedDto>(
    { url: `/api/teams/${teamSlug}/tags/${tagId}`, method: 'DELETE', signal },
    options
  )
}

export const getDeleteTeamTagMutationKey = () => ['deleteTeamTag'] as const

export const getDeleteTeamTagMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteTeamTag>>,
    TError,
    DeleteTeamTagMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteTeamTag>>,
  TError,
  DeleteTeamTagMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteTeamTagMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteTeamTag>>,
    DeleteTeamTagMutationVariables
  > = (props) => {
    const { teamSlug, tagId } = props ?? {}

    return deleteTeamTag(teamSlug, tagId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteTeamTagMutationResult = NonNullable<Awaited<ReturnType<typeof deleteTeamTag>>>

export type DeleteTeamTagMutationError = ErrorType<ErrorResponse>
export type DeleteTeamTagMutationVariables = { teamSlug: string; tagId: string }

/**
 * Detaches the tag from every content and deletes it for good. Requires team admin.
 * @summary Delete a team tag
 */
export const useDeleteTeamTag = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteTeamTag>>,
      TError,
      DeleteTeamTagMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteTeamTag>>,
  TError,
  DeleteTeamTagMutationVariables,
  TContext
> => {
  return useMutation(getDeleteTeamTagMutationOptions(options), queryClient)
}
