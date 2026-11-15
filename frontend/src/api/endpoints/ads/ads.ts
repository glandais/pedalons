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
  AdContactRequest,
  AdDto,
  AdEditDto,
  AdListResponse,
  AdRequest,
  CountAdsParams,
  CountResponse,
  ErrorResponse,
  ListAdsParams,
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
 * Get paginated list of ads for a team with optional filtering
 * @summary List ads
 */
export const listAds = (
  teamSlug: string,
  params?: ListAdsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdListResponse>(
    { url: `/api/teams/${teamSlug}/classifieds`, method: 'GET', params, signal },
    options
  )
}

export const getListAdsQueryKey = (teamSlug: string, params?: ListAdsParams) => {
  return [`/api/teams/${teamSlug}/classifieds`, ...(params ? [params] : [])] as const
}

export const getListAdsQueryOptions = <
  TData = Awaited<ReturnType<typeof listAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: ListAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListAdsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listAds>>> = ({ signal }) =>
    listAds(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listAds>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListAdsQueryResult = NonNullable<Awaited<ReturnType<typeof listAds>>>
export type ListAdsQueryError = ErrorType<void | ErrorResponse>

/**
 * Get paginated list of ads for a team with optional filtering
 * @summary List ads
 */
export function useListAds<
  TData = Awaited<ReturnType<typeof listAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | ListAdsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAds>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listAds>>,
          TError,
          Awaited<ReturnType<typeof listAds>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of ads for a team with optional filtering
 * @summary List ads
 */
export function useListAds<
  TData = Awaited<ReturnType<typeof listAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: ListAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAds>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listAds>>,
          TError,
          Awaited<ReturnType<typeof listAds>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of ads for a team with optional filtering
 * @summary List ads
 */
export function useListAds<
  TData = Awaited<ReturnType<typeof listAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: ListAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of ads for a team with optional filtering
 * @summary List ads
 */
export function useListAds<
  TData = Awaited<ReturnType<typeof listAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: ListAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListAdsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get paginated list of ads for a team with optional filtering
 * @summary List ads
 */
export const prefetchListAdsQuery = async <
  TData = Awaited<ReturnType<typeof listAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: ListAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listAds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListAdsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a new ad. Any team member can create ads.
 * @summary Create ad
 */
export const createAd = (
  teamSlug: string,
  adRequest: BodyType<AdRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdDto>(
    {
      url: `/api/teams/${teamSlug}/classifieds`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: adRequest,
      signal,
    },
    options
  )
}

export const getCreateAdMutationKey = () => ['createAd'] as const

export const getCreateAdMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createAd>>,
    TError,
    CreateAdMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createAd>>,
  TError,
  CreateAdMutationVariables,
  TContext
> => {
  const mutationKey = getCreateAdMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createAd>>,
    CreateAdMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createAd(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateAdMutationResult = NonNullable<Awaited<ReturnType<typeof createAd>>>
export type CreateAdMutationBody = BodyType<AdRequest>
export type CreateAdMutationError = ErrorType<ErrorResponse>
export type CreateAdMutationVariables = { teamSlug: string; data: BodyType<AdRequest> }

/**
 * Create a new ad. Any team member can create ads.
 * @summary Create ad
 */
export const useCreateAd = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createAd>>,
      TError,
      CreateAdMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createAd>>,
  TError,
  CreateAdMutationVariables,
  TContext
> => {
  return useMutation(getCreateAdMutationOptions(options), queryClient)
}
/**
 * How many of the team's classifieds match the filters, with none of them read. Accepts exactly the same filters as the classifieds list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count ads
 */
export const countAds = (
  teamSlug: string,
  params?: CountAdsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<CountResponse>(
    { url: `/api/teams/${teamSlug}/classifieds/count`, method: 'GET', params, signal },
    options
  )
}

export const getCountAdsQueryKey = (teamSlug: string, params?: CountAdsParams) => {
  return [`/api/teams/${teamSlug}/classifieds/count`, ...(params ? [params] : [])] as const
}

export const getCountAdsQueryOptions = <
  TData = Awaited<ReturnType<typeof countAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: CountAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getCountAdsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof countAds>>> = ({ signal }) =>
    countAds(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof countAds>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type CountAdsQueryResult = NonNullable<Awaited<ReturnType<typeof countAds>>>
export type CountAdsQueryError = ErrorType<void | ErrorResponse>

/**
 * How many of the team's classifieds match the filters, with none of them read. Accepts exactly the same filters as the classifieds list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count ads
 */
export function useCountAds<
  TData = Awaited<ReturnType<typeof countAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | CountAdsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAds>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof countAds>>,
          TError,
          Awaited<ReturnType<typeof countAds>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many of the team's classifieds match the filters, with none of them read. Accepts exactly the same filters as the classifieds list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count ads
 */
export function useCountAds<
  TData = Awaited<ReturnType<typeof countAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: CountAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAds>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof countAds>>,
          TError,
          Awaited<ReturnType<typeof countAds>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many of the team's classifieds match the filters, with none of them read. Accepts exactly the same filters as the classifieds list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count ads
 */
export function useCountAds<
  TData = Awaited<ReturnType<typeof countAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: CountAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * How many of the team's classifieds match the filters, with none of them read. Accepts exactly the same filters as the classifieds list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count ads
 */
export function useCountAds<
  TData = Awaited<ReturnType<typeof countAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  params?: CountAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getCountAdsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * How many of the team's classifieds match the filters, with none of them read. Accepts exactly the same filters as the classifieds list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count ads
 */
export const prefetchCountAdsQuery = async <
  TData = Awaited<ReturnType<typeof countAds>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: CountAdsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof countAds>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getCountAdsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Update ad information. Only the creator or an admin can update.
 * @summary Update ad
 */
export const updateAd = (
  teamSlug: string,
  slug: string,
  adRequest: BodyType<AdRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdDto>(
    {
      url: `/api/teams/${teamSlug}/classifieds/${slug}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: adRequest,
      signal,
    },
    options
  )
}

export const getUpdateAdMutationKey = () => ['updateAd'] as const

export const getUpdateAdMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateAd>>,
    TError,
    UpdateAdMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateAd>>,
  TError,
  UpdateAdMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateAdMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateAd>>,
    UpdateAdMutationVariables
  > = (props) => {
    const { teamSlug, slug, data } = props ?? {}

    return updateAd(teamSlug, slug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateAdMutationResult = NonNullable<Awaited<ReturnType<typeof updateAd>>>
export type UpdateAdMutationBody = BodyType<AdRequest>
export type UpdateAdMutationError = ErrorType<ErrorResponse>
export type UpdateAdMutationVariables = {
  teamSlug: string
  slug: string
  data: BodyType<AdRequest>
}

/**
 * Update ad information. Only the creator or an admin can update.
 * @summary Update ad
 */
export const useUpdateAd = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateAd>>,
      TError,
      UpdateAdMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateAd>>,
  TError,
  UpdateAdMutationVariables,
  TContext
> => {
  return useMutation(getUpdateAdMutationOptions(options), queryClient)
}
/**
 * Get detailed ad information
 * @summary Get ad details
 */
export const getAd = (
  teamSlug: string,
  slug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdDto>(
    { url: `/api/teams/${teamSlug}/classifieds/${slug}`, method: 'GET', signal },
    options
  )
}

export const getGetAdQueryKey = (teamSlug: string, slug: string) => {
  return [`/api/teams/${teamSlug}/classifieds/${slug}`] as const
}

export const getGetAdQueryOptions = <
  TData = Awaited<ReturnType<typeof getAd>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAd>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetAdQueryKey(teamSlug, slug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getAd>>> = ({ signal }) =>
    getAd(teamSlug, slug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined && slug !== null && slug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getAd>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetAdQueryResult = NonNullable<Awaited<ReturnType<typeof getAd>>>
export type GetAdQueryError = ErrorType<void | ErrorResponse>

/**
 * Get detailed ad information
 * @summary Get ad details
 */
export function useGetAd<
  TData = Awaited<ReturnType<typeof getAd>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAd>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAd>>,
          TError,
          Awaited<ReturnType<typeof getAd>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ad information
 * @summary Get ad details
 */
export function useGetAd<
  TData = Awaited<ReturnType<typeof getAd>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAd>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAd>>,
          TError,
          Awaited<ReturnType<typeof getAd>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ad information
 * @summary Get ad details
 */
export function useGetAd<
  TData = Awaited<ReturnType<typeof getAd>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAd>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ad information
 * @summary Get ad details
 */
export function useGetAd<
  TData = Awaited<ReturnType<typeof getAd>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAd>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetAdQueryOptions(teamSlug, slug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed ad information
 * @summary Get ad details
 */
export const prefetchGetAdQuery = async <
  TData = Awaited<ReturnType<typeof getAd>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAd>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetAdQueryOptions(teamSlug, slug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Soft delete an ad. Only the creator or an admin can delete.
 * @summary Delete ad
 */
export const deleteAd = (
  teamSlug: string,
  slug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/classifieds/${slug}`, method: 'DELETE', signal },
    options
  )
}

export const getDeleteAdMutationKey = () => ['deleteAd'] as const

export const getDeleteAdMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteAd>>,
    TError,
    DeleteAdMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteAd>>,
  TError,
  DeleteAdMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteAdMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteAd>>,
    DeleteAdMutationVariables
  > = (props) => {
    const { teamSlug, slug } = props ?? {}

    return deleteAd(teamSlug, slug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteAdMutationResult = NonNullable<Awaited<ReturnType<typeof deleteAd>>>

export type DeleteAdMutationError = ErrorType<ErrorResponse>
export type DeleteAdMutationVariables = { teamSlug: string; slug: string }

/**
 * Soft delete an ad. Only the creator or an admin can delete.
 * @summary Delete ad
 */
export const useDeleteAd = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteAd>>,
      TError,
      DeleteAdMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteAd>>,
  TError,
  DeleteAdMutationVariables,
  TContext
> => {
  return useMutation(getDeleteAdMutationOptions(options), queryClient)
}
/**
 * Relays a message to the author of an ad. Neither party's address appears anywhere in this API: the server sends the email and sets Reply-To to the caller, so the author can answer directly. Writing therefore discloses the caller's address to the author — a one-way disclosure the caller chose — while the author's address is never disclosed at all. Requires the same access as reading the ad.
 * @summary Contact an ad's author
 */
export const contactAdAuthor = (
  teamSlug: string,
  slug: string,
  adContactRequest: BodyType<AdContactRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/teams/${teamSlug}/classifieds/${slug}/contact`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: adContactRequest,
      signal,
    },
    options
  )
}

export const getContactAdAuthorMutationKey = () => ['contactAdAuthor'] as const

export const getContactAdAuthorMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof contactAdAuthor>>,
    TError,
    ContactAdAuthorMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof contactAdAuthor>>,
  TError,
  ContactAdAuthorMutationVariables,
  TContext
> => {
  const mutationKey = getContactAdAuthorMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof contactAdAuthor>>,
    ContactAdAuthorMutationVariables
  > = (props) => {
    const { teamSlug, slug, data } = props ?? {}

    return contactAdAuthor(teamSlug, slug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ContactAdAuthorMutationResult = NonNullable<Awaited<ReturnType<typeof contactAdAuthor>>>
export type ContactAdAuthorMutationBody = BodyType<AdContactRequest>
export type ContactAdAuthorMutationError = ErrorType<ErrorResponse>
export type ContactAdAuthorMutationVariables = {
  teamSlug: string
  slug: string
  data: BodyType<AdContactRequest>
}

/**
 * Relays a message to the author of an ad. Neither party's address appears anywhere in this API: the server sends the email and sets Reply-To to the caller, so the author can answer directly. Writing therefore discloses the caller's address to the author — a one-way disclosure the caller chose — while the author's address is never disclosed at all. Requires the same access as reading the ad.
 * @summary Contact an ad's author
 */
export const useContactAdAuthor = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof contactAdAuthor>>,
      TError,
      ContactAdAuthorMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof contactAdAuthor>>,
  TError,
  ContactAdAuthorMutationVariables,
  TContext
> => {
  return useMutation(getContactAdAuthorMutationOptions(options), queryClient)
}
/**
 * Get detailed ad information
 * @summary Get ad details for edit
 */
export const getAdEdit = (
  teamSlug: string,
  slug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdEditDto>(
    { url: `/api/teams/${teamSlug}/classifieds/${slug}/edit`, method: 'GET', signal },
    options
  )
}

export const getGetAdEditQueryKey = (teamSlug: string, slug: string) => {
  return [`/api/teams/${teamSlug}/classifieds/${slug}/edit`] as const
}

export const getGetAdEditQueryOptions = <
  TData = Awaited<ReturnType<typeof getAdEdit>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdEdit>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetAdEditQueryKey(teamSlug, slug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getAdEdit>>> = ({ signal }) =>
    getAdEdit(teamSlug, slug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined && slug !== null && slug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getAdEdit>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetAdEditQueryResult = NonNullable<Awaited<ReturnType<typeof getAdEdit>>>
export type GetAdEditQueryError = ErrorType<void | ErrorResponse>

/**
 * Get detailed ad information
 * @summary Get ad details for edit
 */
export function useGetAdEdit<
  TData = Awaited<ReturnType<typeof getAdEdit>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdEdit>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAdEdit>>,
          TError,
          Awaited<ReturnType<typeof getAdEdit>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ad information
 * @summary Get ad details for edit
 */
export function useGetAdEdit<
  TData = Awaited<ReturnType<typeof getAdEdit>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdEdit>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getAdEdit>>,
          TError,
          Awaited<ReturnType<typeof getAdEdit>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ad information
 * @summary Get ad details for edit
 */
export function useGetAdEdit<
  TData = Awaited<ReturnType<typeof getAdEdit>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdEdit>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ad information
 * @summary Get ad details for edit
 */
export function useGetAdEdit<
  TData = Awaited<ReturnType<typeof getAdEdit>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdEdit>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetAdEditQueryOptions(teamSlug, slug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed ad information
 * @summary Get ad details for edit
 */
export const prefetchGetAdEditQuery = async <
  TData = Awaited<ReturnType<typeof getAdEdit>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  slug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAdEdit>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetAdEditQueryOptions(teamSlug, slug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Change ad URL slug. Requires admin permissions.
 * @summary Change ad slug
 */
export const changeAdSlug = (
  teamSlug: string,
  slug: string,
  slugChangeRequest: BodyType<SlugChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdDto>(
    {
      url: `/api/teams/${teamSlug}/classifieds/${slug}/slug`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: slugChangeRequest,
      signal,
    },
    options
  )
}

export const getChangeAdSlugMutationKey = () => ['changeAdSlug'] as const

export const getChangeAdSlugMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changeAdSlug>>,
    TError,
    ChangeAdSlugMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changeAdSlug>>,
  TError,
  ChangeAdSlugMutationVariables,
  TContext
> => {
  const mutationKey = getChangeAdSlugMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changeAdSlug>>,
    ChangeAdSlugMutationVariables
  > = (props) => {
    const { teamSlug, slug, data } = props ?? {}

    return changeAdSlug(teamSlug, slug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangeAdSlugMutationResult = NonNullable<Awaited<ReturnType<typeof changeAdSlug>>>
export type ChangeAdSlugMutationBody = BodyType<SlugChangeRequest>
export type ChangeAdSlugMutationError = ErrorType<ErrorResponse>
export type ChangeAdSlugMutationVariables = {
  teamSlug: string
  slug: string
  data: BodyType<SlugChangeRequest>
}

/**
 * Change ad URL slug. Requires admin permissions.
 * @summary Change ad slug
 */
export const useChangeAdSlug = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changeAdSlug>>,
      TError,
      ChangeAdSlugMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changeAdSlug>>,
  TError,
  ChangeAdSlugMutationVariables,
  TContext
> => {
  return useMutation(getChangeAdSlugMutationOptions(options), queryClient)
}
/**
 * Change the ad's status and nothing else — what a list row can do without the full ad. Same side effects as a status change through the update. Requires the team admin or the ad's author.
 * @summary Change ad status
 */
export const changeAdStatus = (
  teamSlug: string,
  slug: string,
  statusChangeRequest: BodyType<StatusChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdDto>(
    {
      url: `/api/teams/${teamSlug}/classifieds/${slug}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      data: statusChangeRequest,
      signal,
    },
    options
  )
}

export const getChangeAdStatusMutationKey = () => ['changeAdStatus'] as const

export const getChangeAdStatusMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof changeAdStatus>>,
    TError,
    ChangeAdStatusMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof changeAdStatus>>,
  TError,
  ChangeAdStatusMutationVariables,
  TContext
> => {
  const mutationKey = getChangeAdStatusMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof changeAdStatus>>,
    ChangeAdStatusMutationVariables
  > = (props) => {
    const { teamSlug, slug, data } = props ?? {}

    return changeAdStatus(teamSlug, slug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ChangeAdStatusMutationResult = NonNullable<Awaited<ReturnType<typeof changeAdStatus>>>
export type ChangeAdStatusMutationBody = BodyType<StatusChangeRequest>
export type ChangeAdStatusMutationError = ErrorType<ErrorResponse>
export type ChangeAdStatusMutationVariables = {
  teamSlug: string
  slug: string
  data: BodyType<StatusChangeRequest>
}

/**
 * Change the ad's status and nothing else — what a list row can do without the full ad. Same side effects as a status change through the update. Requires the team admin or the ad's author.
 * @summary Change ad status
 */
export const useChangeAdStatus = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof changeAdStatus>>,
      TError,
      ChangeAdStatusMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof changeAdStatus>>,
  TError,
  ChangeAdStatusMutationVariables,
  TContext
> => {
  return useMutation(getChangeAdStatusMutationOptions(options), queryClient)
}
/**
 * Restore a soft-deleted ad. Only the creator or an admin can restore.
 * @summary Restore ad
 */
export const undeleteAd = (
  teamSlug: string,
  slug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdEditDto>(
    { url: `/api/teams/${teamSlug}/classifieds/${slug}/undelete`, method: 'POST', signal },
    options
  )
}

export const getUndeleteAdMutationKey = () => ['undeleteAd'] as const

export const getUndeleteAdMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof undeleteAd>>,
    TError,
    UndeleteAdMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof undeleteAd>>,
  TError,
  UndeleteAdMutationVariables,
  TContext
> => {
  const mutationKey = getUndeleteAdMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof undeleteAd>>,
    UndeleteAdMutationVariables
  > = (props) => {
    const { teamSlug, slug } = props ?? {}

    return undeleteAd(teamSlug, slug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UndeleteAdMutationResult = NonNullable<Awaited<ReturnType<typeof undeleteAd>>>

export type UndeleteAdMutationError = ErrorType<ErrorResponse>
export type UndeleteAdMutationVariables = { teamSlug: string; slug: string }

/**
 * Restore a soft-deleted ad. Only the creator or an admin can restore.
 * @summary Restore ad
 */
export const useUndeleteAd = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof undeleteAd>>,
      TError,
      UndeleteAdMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof undeleteAd>>,
  TError,
  UndeleteAdMutationVariables,
  TContext
> => {
  return useMutation(getUndeleteAdMutationOptions(options), queryClient)
}
