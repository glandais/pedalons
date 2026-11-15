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
  ReorderPagesRequest,
  SlugChangeRequest,
  TeamPageDto,
  TeamPageRequest,
  TeamPageSummaryDto,
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
 * Get list of additional pages for a team
 * @summary List team pages
 */
export const listPages = (
  teamSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamPageSummaryDto[]>(
    { url: `/api/teams/${teamSlug}/pages`, method: 'GET', signal },
    options
  )
}

export const getListPagesQueryKey = (teamSlug: string) => {
  return [`/api/teams/${teamSlug}/pages`] as const
}

export const getListPagesQueryOptions = <
  TData = Awaited<ReturnType<typeof listPages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPages>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListPagesQueryKey(teamSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listPages>>> = ({ signal }) =>
    listPages(teamSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listPages>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListPagesQueryResult = NonNullable<Awaited<ReturnType<typeof listPages>>>
export type ListPagesQueryError = ErrorType<ErrorResponse>

/**
 * Get list of additional pages for a team
 * @summary List team pages
 */
export function useListPages<
  TData = Awaited<ReturnType<typeof listPages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPages>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPages>>,
          TError,
          Awaited<ReturnType<typeof listPages>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get list of additional pages for a team
 * @summary List team pages
 */
export function useListPages<
  TData = Awaited<ReturnType<typeof listPages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPages>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPages>>,
          TError,
          Awaited<ReturnType<typeof listPages>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get list of additional pages for a team
 * @summary List team pages
 */
export function useListPages<
  TData = Awaited<ReturnType<typeof listPages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPages>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get list of additional pages for a team
 * @summary List team pages
 */
export function useListPages<
  TData = Awaited<ReturnType<typeof listPages>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPages>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListPagesQueryOptions(teamSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get list of additional pages for a team
 * @summary List team pages
 */
export const prefetchListPagesQuery = async <
  TData = Awaited<ReturnType<typeof listPages>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPages>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListPagesQueryOptions(teamSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a new team page. Requires admin permissions. Maximum 3 additional pages per team.
 * @summary Create page
 */
export const createPage = (
  teamSlug: string,
  teamPageRequest: BodyType<TeamPageRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamPageDto>(
    {
      url: `/api/teams/${teamSlug}/pages`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: teamPageRequest,
      signal,
    },
    options
  )
}

export const getCreatePageMutationKey = () => ['createPage'] as const

export const getCreatePageMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createPage>>,
    TError,
    CreatePageMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createPage>>,
  TError,
  CreatePageMutationVariables,
  TContext
> => {
  const mutationKey = getCreatePageMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createPage>>,
    CreatePageMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createPage(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreatePageMutationResult = NonNullable<Awaited<ReturnType<typeof createPage>>>
export type CreatePageMutationBody = BodyType<TeamPageRequest>
export type CreatePageMutationError = ErrorType<ErrorResponse>
export type CreatePageMutationVariables = { teamSlug: string; data: BodyType<TeamPageRequest> }

/**
 * Create a new team page. Requires admin permissions. Maximum 3 additional pages per team.
 * @summary Create page
 */
export const useCreatePage = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createPage>>,
      TError,
      CreatePageMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createPage>>,
  TError,
  CreatePageMutationVariables,
  TContext
> => {
  return useMutation(getCreatePageMutationOptions(options), queryClient)
}
/**
 * Reorder team pages. Requires admin permissions.
 * @summary Reorder pages
 */
export const reorderPages = (
  teamSlug: string,
  reorderPagesRequest: BodyType<ReorderPagesRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamPageSummaryDto[]>(
    {
      url: `/api/teams/${teamSlug}/pages/reorder`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: reorderPagesRequest,
      signal,
    },
    options
  )
}

export const getReorderPagesMutationKey = () => ['reorderPages'] as const

export const getReorderPagesMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof reorderPages>>,
    TError,
    ReorderPagesMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof reorderPages>>,
  TError,
  ReorderPagesMutationVariables,
  TContext
> => {
  const mutationKey = getReorderPagesMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof reorderPages>>,
    ReorderPagesMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return reorderPages(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ReorderPagesMutationResult = NonNullable<Awaited<ReturnType<typeof reorderPages>>>
export type ReorderPagesMutationBody = BodyType<ReorderPagesRequest>
export type ReorderPagesMutationError = ErrorType<ErrorResponse>
export type ReorderPagesMutationVariables = {
  teamSlug: string
  data: BodyType<ReorderPagesRequest>
}

/**
 * Reorder team pages. Requires admin permissions.
 * @summary Reorder pages
 */
export const useReorderPages = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof reorderPages>>,
      TError,
      ReorderPagesMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof reorderPages>>,
  TError,
  ReorderPagesMutationVariables,
  TContext
> => {
  return useMutation(getReorderPagesMutationOptions(options), queryClient)
}
/**
 * Update page information. Requires admin permissions.
 * @summary Update page
 */
export const updatePage = (
  teamSlug: string,
  pageSlug: string,
  teamPageRequest: BodyType<TeamPageRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamPageDto>(
    {
      url: `/api/teams/${teamSlug}/pages/${pageSlug}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: teamPageRequest,
      signal,
    },
    options
  )
}

export const getUpdatePageMutationKey = () => ['updatePage'] as const

export const getUpdatePageMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updatePage>>,
    TError,
    UpdatePageMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updatePage>>,
  TError,
  UpdatePageMutationVariables,
  TContext
> => {
  const mutationKey = getUpdatePageMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updatePage>>,
    UpdatePageMutationVariables
  > = (props) => {
    const { teamSlug, pageSlug, data } = props ?? {}

    return updatePage(teamSlug, pageSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdatePageMutationResult = NonNullable<Awaited<ReturnType<typeof updatePage>>>
export type UpdatePageMutationBody = BodyType<TeamPageRequest>
export type UpdatePageMutationError = ErrorType<ErrorResponse>
export type UpdatePageMutationVariables = {
  teamSlug: string
  pageSlug: string
  data: BodyType<TeamPageRequest>
}

/**
 * Update page information. Requires admin permissions.
 * @summary Update page
 */
export const useUpdatePage = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updatePage>>,
      TError,
      UpdatePageMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updatePage>>,
  TError,
  UpdatePageMutationVariables,
  TContext
> => {
  return useMutation(getUpdatePageMutationOptions(options), queryClient)
}
/**
 * Get detailed page information
 * @summary Get page details
 */
export const getPage = (
  teamSlug: string,
  pageSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamPageDto>(
    { url: `/api/teams/${teamSlug}/pages/${pageSlug}`, method: 'GET', signal },
    options
  )
}

export const getGetPageQueryKey = (teamSlug: string, pageSlug: string) => {
  return [`/api/teams/${teamSlug}/pages/${pageSlug}`] as const
}

export const getGetPageQueryOptions = <
  TData = Awaited<ReturnType<typeof getPage>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  pageSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetPageQueryKey(teamSlug, pageSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getPage>>> = ({ signal }) =>
    getPage(teamSlug, pageSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null && teamSlug !== undefined && pageSlug !== null && pageSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getPage>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetPageQueryResult = NonNullable<Awaited<ReturnType<typeof getPage>>>
export type GetPageQueryError = ErrorType<ErrorResponse>

/**
 * Get detailed page information
 * @summary Get page details
 */
export function useGetPage<
  TData = Awaited<ReturnType<typeof getPage>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  pageSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPage>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPage>>,
          TError,
          Awaited<ReturnType<typeof getPage>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed page information
 * @summary Get page details
 */
export function useGetPage<
  TData = Awaited<ReturnType<typeof getPage>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  pageSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPage>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getPage>>,
          TError,
          Awaited<ReturnType<typeof getPage>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed page information
 * @summary Get page details
 */
export function useGetPage<
  TData = Awaited<ReturnType<typeof getPage>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  pageSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed page information
 * @summary Get page details
 */
export function useGetPage<
  TData = Awaited<ReturnType<typeof getPage>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  pageSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetPageQueryOptions(teamSlug, pageSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed page information
 * @summary Get page details
 */
export const prefetchGetPageQuery = async <
  TData = Awaited<ReturnType<typeof getPage>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  pageSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getPage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetPageQueryOptions(teamSlug, pageSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Delete a team page. Requires admin permissions.
 * @summary Delete page
 */
export const deletePage = (
  teamSlug: string,
  pageSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/pages/${pageSlug}`, method: 'DELETE', signal },
    options
  )
}

export const getDeletePageMutationKey = () => ['deletePage'] as const

export const getDeletePageMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deletePage>>,
    TError,
    DeletePageMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deletePage>>,
  TError,
  DeletePageMutationVariables,
  TContext
> => {
  const mutationKey = getDeletePageMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deletePage>>,
    DeletePageMutationVariables
  > = (props) => {
    const { teamSlug, pageSlug } = props ?? {}

    return deletePage(teamSlug, pageSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeletePageMutationResult = NonNullable<Awaited<ReturnType<typeof deletePage>>>

export type DeletePageMutationError = ErrorType<ErrorResponse>
export type DeletePageMutationVariables = { teamSlug: string; pageSlug: string }

/**
 * Delete a team page. Requires admin permissions.
 * @summary Delete page
 */
export const useDeletePage = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deletePage>>,
      TError,
      DeletePageMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deletePage>>,
  TError,
  DeletePageMutationVariables,
  TContext
> => {
  return useMutation(getDeletePageMutationOptions(options), queryClient)
}
/**
 * Change page URL slug. Requires admin permissions.
 * @summary Change page slug
 */
export const changePageSlug = (
  teamSlug: string,
  pageSlug: string,
  slugChangeRequest: BodyType<SlugChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamPageDto>(
    {
      url: `/api/teams/${teamSlug}/pages/${pageSlug}/slug`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: slugChangeRequest,
      signal,
    },
    options
  )
}

export const getChangePageSlugMutationKey = () => ['changePageSlug'] as const

export const getChangePageSlugMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changePageSlug>>,
    TError,
    ChangePageSlugMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changePageSlug>>,
  TError,
  ChangePageSlugMutationVariables,
  TContext
> => {
  const mutationKey = getChangePageSlugMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changePageSlug>>,
    ChangePageSlugMutationVariables
  > = (props) => {
    const { teamSlug, pageSlug, data } = props ?? {}

    return changePageSlug(teamSlug, pageSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangePageSlugMutationResult = NonNullable<Awaited<ReturnType<typeof changePageSlug>>>
export type ChangePageSlugMutationBody = BodyType<SlugChangeRequest>
export type ChangePageSlugMutationError = ErrorType<ErrorResponse>
export type ChangePageSlugMutationVariables = {
  teamSlug: string
  pageSlug: string
  data: BodyType<SlugChangeRequest>
}

/**
 * Change page URL slug. Requires admin permissions.
 * @summary Change page slug
 */
export const useChangePageSlug = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changePageSlug>>,
      TError,
      ChangePageSlugMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changePageSlug>>,
  TError,
  ChangePageSlugMutationVariables,
  TContext
> => {
  return useMutation(getChangePageSlugMutationOptions(options), queryClient)
}
/**
 * Restore a soft-deleted team page. Requires admin permissions.
 * @summary Restore page
 */
export const undeletePage = (
  teamSlug: string,
  pageSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamPageDto>(
    { url: `/api/teams/${teamSlug}/pages/${pageSlug}/undelete`, method: 'POST', signal },
    options
  )
}

export const getUndeletePageMutationKey = () => ['undeletePage'] as const

export const getUndeletePageMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof undeletePage>>,
    TError,
    UndeletePageMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof undeletePage>>,
  TError,
  UndeletePageMutationVariables,
  TContext
> => {
  const mutationKey = getUndeletePageMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof undeletePage>>,
    UndeletePageMutationVariables
  > = (props) => {
    const { teamSlug, pageSlug } = props ?? {}

    return undeletePage(teamSlug, pageSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UndeletePageMutationResult = NonNullable<Awaited<ReturnType<typeof undeletePage>>>

export type UndeletePageMutationError = ErrorType<ErrorResponse>
export type UndeletePageMutationVariables = { teamSlug: string; pageSlug: string }

/**
 * Restore a soft-deleted team page. Requires admin permissions.
 * @summary Restore page
 */
export const useUndeletePage = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof undeletePage>>,
      TError,
      UndeletePageMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof undeletePage>>,
  TError,
  UndeletePageMutationVariables,
  TContext
> => {
  return useMutation(getUndeletePageMutationOptions(options), queryClient)
}
