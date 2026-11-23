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
  AdminActivationResponse,
  AdminDomainAliasDto,
  AdminDomainDto,
  AdminDomainListResponse,
  AdminGpsCredentialDto,
  AdminStatsDto,
  CreateDomainAliasRequest,
  CreateDomainRequest,
  CreateGpsCredentialRequest,
  ErrorResponse,
  GetActivationParams,
  ListDomainsParams,
  UpdateDomainAliasRequest,
  UpdateDomainRequest,
  UpdateGpsCredentialRequest,
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
 * Get a paginated list of all domains
 * @summary List all domains
 */
export const listDomains = (
  params?: ListDomainsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainListResponse>(
    { url: `/api/admin/domains`, method: 'GET', params, signal },
    options
  )
}

export const getListDomainsQueryKey = (params?: ListDomainsParams) => {
  return [`/api/admin/domains`, ...(params ? [params] : [])] as const
}

export const getListDomainsQueryOptions = <
  TData = Awaited<ReturnType<typeof listDomains>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListDomainsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomains>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListDomainsQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listDomains>>> = ({ signal }) =>
    listDomains(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listDomains>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListDomainsQueryResult = NonNullable<Awaited<ReturnType<typeof listDomains>>>
export type ListDomainsQueryError = ErrorType<void | ErrorResponse>

/**
 * Get a paginated list of all domains
 * @summary List all domains
 */
export function useListDomains<
  TData = Awaited<ReturnType<typeof listDomains>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: undefined | ListDomainsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomains>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listDomains>>,
          TError,
          Awaited<ReturnType<typeof listDomains>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all domains
 * @summary List all domains
 */
export function useListDomains<
  TData = Awaited<ReturnType<typeof listDomains>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListDomainsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomains>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listDomains>>,
          TError,
          Awaited<ReturnType<typeof listDomains>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all domains
 * @summary List all domains
 */
export function useListDomains<
  TData = Awaited<ReturnType<typeof listDomains>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListDomainsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomains>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get a paginated list of all domains
 * @summary List all domains
 */
export function useListDomains<
  TData = Awaited<ReturnType<typeof listDomains>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: ListDomainsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomains>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListDomainsQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get a paginated list of all domains
 * @summary List all domains
 */
export const prefetchListDomainsQuery = async <
  TData = Awaited<ReturnType<typeof listDomains>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: ListDomainsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomains>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListDomainsQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a new domain
 * @summary Create domain
 */
export const createDomain = (
  createDomainRequest: BodyType<CreateDomainRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainDto>(
    {
      url: `/api/admin/domains`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: createDomainRequest,
      signal,
    },
    options
  )
}

export const getCreateDomainMutationKey = () => ['createDomain'] as const

export const getCreateDomainMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createDomain>>,
    TError,
    CreateDomainMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createDomain>>,
  TError,
  CreateDomainMutationVariables,
  TContext
> => {
  const mutationKey = getCreateDomainMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createDomain>>,
    CreateDomainMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return createDomain(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateDomainMutationResult = NonNullable<Awaited<ReturnType<typeof createDomain>>>
export type CreateDomainMutationBody = BodyType<CreateDomainRequest>
export type CreateDomainMutationError = ErrorType<ErrorResponse | void>
export type CreateDomainMutationVariables = { data: BodyType<CreateDomainRequest> }

/**
 * Create a new domain
 * @summary Create domain
 */
export const useCreateDomain = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createDomain>>,
      TError,
      CreateDomainMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createDomain>>,
  TError,
  CreateDomainMutationVariables,
  TContext
> => {
  return useMutation(getCreateDomainMutationOptions(options), queryClient)
}
/**
 * Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a team and that signed up to a ride within 7 days. Counts only, computed on the data already stored — no person is named (ledger API-213).
 * @summary Activation of new accounts
 */
export const getActivation = (
  params?: GetActivationParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminActivationResponse>(
    { url: `/api/admin/domains/activation`, method: 'GET', params, signal },
    options
  )
}

export const getGetActivationQueryKey = (params?: GetActivationParams) => {
  return [`/api/admin/domains/activation`, ...(params ? [params] : [])] as const
}

export const getGetActivationQueryOptions = <
  TData = Awaited<ReturnType<typeof getActivation>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: GetActivationParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getActivation>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetActivationQueryKey(params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getActivation>>> = ({ signal }) =>
    getActivation(params, requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getActivation>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetActivationQueryResult = NonNullable<Awaited<ReturnType<typeof getActivation>>>
export type GetActivationQueryError = ErrorType<void | ErrorResponse>

/**
 * Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a team and that signed up to a ride within 7 days. Counts only, computed on the data already stored — no person is named (ledger API-213).
 * @summary Activation of new accounts
 */
export function useGetActivation<
  TData = Awaited<ReturnType<typeof getActivation>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params: undefined | GetActivationParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getActivation>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getActivation>>,
          TError,
          Awaited<ReturnType<typeof getActivation>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a team and that signed up to a ride within 7 days. Counts only, computed on the data already stored — no person is named (ledger API-213).
 * @summary Activation of new accounts
 */
export function useGetActivation<
  TData = Awaited<ReturnType<typeof getActivation>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: GetActivationParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getActivation>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getActivation>>,
          TError,
          Awaited<ReturnType<typeof getActivation>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a team and that signed up to a ride within 7 days. Counts only, computed on the data already stored — no person is named (ledger API-213).
 * @summary Activation of new accounts
 */
export function useGetActivation<
  TData = Awaited<ReturnType<typeof getActivation>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: GetActivationParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getActivation>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a team and that signed up to a ride within 7 days. Counts only, computed on the data already stored — no person is named (ledger API-213).
 * @summary Activation of new accounts
 */
export function useGetActivation<
  TData = Awaited<ReturnType<typeof getActivation>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  params?: GetActivationParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getActivation>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetActivationQueryOptions(params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a team and that signed up to a ride within 7 days. Counts only, computed on the data already stored — no person is named (ledger API-213).
 * @summary Activation of new accounts
 */
export const prefetchGetActivationQuery = async <
  TData = Awaited<ReturnType<typeof getActivation>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  params?: GetActivationParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getActivation>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetActivationQueryOptions(params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get overall platform statistics
 * @summary Get platform statistics
 */
export const getStats = (options?: SecondParameter<typeof axiosMutator>, signal?: AbortSignal) => {
  return axiosMutator<AdminStatsDto>(
    { url: `/api/admin/domains/stats`, method: 'GET', signal },
    options
  )
}

export const getGetStatsQueryKey = () => {
  return [`/api/admin/domains/stats`] as const
}

export const getGetStatsQueryOptions = <
  TData = Awaited<ReturnType<typeof getStats>>,
  TError = ErrorType<void | ErrorResponse>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStats>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetStatsQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getStats>>> = ({ signal }) =>
    getStats(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getStats>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetStatsQueryResult = NonNullable<Awaited<ReturnType<typeof getStats>>>
export type GetStatsQueryError = ErrorType<void | ErrorResponse>

/**
 * Get overall platform statistics
 * @summary Get platform statistics
 */
export function useGetStats<
  TData = Awaited<ReturnType<typeof getStats>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStats>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getStats>>,
          TError,
          Awaited<ReturnType<typeof getStats>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get overall platform statistics
 * @summary Get platform statistics
 */
export function useGetStats<
  TData = Awaited<ReturnType<typeof getStats>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStats>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getStats>>,
          TError,
          Awaited<ReturnType<typeof getStats>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get overall platform statistics
 * @summary Get platform statistics
 */
export function useGetStats<
  TData = Awaited<ReturnType<typeof getStats>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStats>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get overall platform statistics
 * @summary Get platform statistics
 */
export function useGetStats<
  TData = Awaited<ReturnType<typeof getStats>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStats>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetStatsQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get overall platform statistics
 * @summary Get platform statistics
 */
export const prefetchGetStatsQuery = async <
  TData = Awaited<ReturnType<typeof getStats>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getStats>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetStatsQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Update domain information
 * @summary Update domain
 */
export const updateDomain = (
  domainId: string,
  updateDomainRequest: BodyType<UpdateDomainRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainDto>(
    {
      url: `/api/admin/domains/${domainId}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: updateDomainRequest,
      signal,
    },
    options
  )
}

export const getUpdateDomainMutationKey = () => ['updateDomain'] as const

export const getUpdateDomainMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateDomain>>,
    TError,
    UpdateDomainMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateDomain>>,
  TError,
  UpdateDomainMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateDomainMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateDomain>>,
    UpdateDomainMutationVariables
  > = (props) => {
    const { domainId, data } = props ?? {}

    return updateDomain(domainId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateDomainMutationResult = NonNullable<Awaited<ReturnType<typeof updateDomain>>>
export type UpdateDomainMutationBody = BodyType<UpdateDomainRequest>
export type UpdateDomainMutationError = ErrorType<void | ErrorResponse>
export type UpdateDomainMutationVariables = {
  domainId: string
  data: BodyType<UpdateDomainRequest>
}

/**
 * Update domain information
 * @summary Update domain
 */
export const useUpdateDomain = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateDomain>>,
      TError,
      UpdateDomainMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateDomain>>,
  TError,
  UpdateDomainMutationVariables,
  TContext
> => {
  return useMutation(getUpdateDomainMutationOptions(options), queryClient)
}
/**
 * Get detailed domain information
 * @summary Get domain details
 */
export const getDomain = (
  domainId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainDto>(
    { url: `/api/admin/domains/${domainId}`, method: 'GET', signal },
    options
  )
}

export const getGetDomainQueryKey = (domainId: string) => {
  return [`/api/admin/domains/${domainId}`] as const
}

export const getGetDomainQueryOptions = <
  TData = Awaited<ReturnType<typeof getDomain>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getDomain>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetDomainQueryKey(domainId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getDomain>>> = ({ signal }) =>
    getDomain(domainId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: domainId !== null && domainId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getDomain>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetDomainQueryResult = NonNullable<Awaited<ReturnType<typeof getDomain>>>
export type GetDomainQueryError = ErrorType<void | ErrorResponse>

/**
 * Get detailed domain information
 * @summary Get domain details
 */
export function useGetDomain<
  TData = Awaited<ReturnType<typeof getDomain>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getDomain>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getDomain>>,
          TError,
          Awaited<ReturnType<typeof getDomain>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed domain information
 * @summary Get domain details
 */
export function useGetDomain<
  TData = Awaited<ReturnType<typeof getDomain>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getDomain>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getDomain>>,
          TError,
          Awaited<ReturnType<typeof getDomain>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed domain information
 * @summary Get domain details
 */
export function useGetDomain<
  TData = Awaited<ReturnType<typeof getDomain>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getDomain>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed domain information
 * @summary Get domain details
 */
export function useGetDomain<
  TData = Awaited<ReturnType<typeof getDomain>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getDomain>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetDomainQueryOptions(domainId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed domain information
 * @summary Get domain details
 */
export const prefetchGetDomainQuery = async <
  TData = Awaited<ReturnType<typeof getDomain>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getDomain>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetDomainQueryOptions(domainId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Get all dedicated hostnames (aliases) pinned to teams of a domain
 * @summary List domain aliases
 */
export const listDomainAliases = (
  domainId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainAliasDto[]>(
    { url: `/api/admin/domains/${domainId}/aliases`, method: 'GET', signal },
    options
  )
}

export const getListDomainAliasesQueryKey = (domainId: string) => {
  return [`/api/admin/domains/${domainId}/aliases`] as const
}

export const getListDomainAliasesQueryOptions = <
  TData = Awaited<ReturnType<typeof listDomainAliases>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomainAliases>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListDomainAliasesQueryKey(domainId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listDomainAliases>>> = ({ signal }) =>
    listDomainAliases(domainId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: domainId !== null && domainId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listDomainAliases>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListDomainAliasesQueryResult = NonNullable<
  Awaited<ReturnType<typeof listDomainAliases>>
>
export type ListDomainAliasesQueryError = ErrorType<void | ErrorResponse>

/**
 * Get all dedicated hostnames (aliases) pinned to teams of a domain
 * @summary List domain aliases
 */
export function useListDomainAliases<
  TData = Awaited<ReturnType<typeof listDomainAliases>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomainAliases>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listDomainAliases>>,
          TError,
          Awaited<ReturnType<typeof listDomainAliases>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all dedicated hostnames (aliases) pinned to teams of a domain
 * @summary List domain aliases
 */
export function useListDomainAliases<
  TData = Awaited<ReturnType<typeof listDomainAliases>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomainAliases>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listDomainAliases>>,
          TError,
          Awaited<ReturnType<typeof listDomainAliases>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all dedicated hostnames (aliases) pinned to teams of a domain
 * @summary List domain aliases
 */
export function useListDomainAliases<
  TData = Awaited<ReturnType<typeof listDomainAliases>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomainAliases>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all dedicated hostnames (aliases) pinned to teams of a domain
 * @summary List domain aliases
 */
export function useListDomainAliases<
  TData = Awaited<ReturnType<typeof listDomainAliases>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomainAliases>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListDomainAliasesQueryOptions(domainId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get all dedicated hostnames (aliases) pinned to teams of a domain
 * @summary List domain aliases
 */
export const prefetchListDomainAliasesQuery = async <
  TData = Awaited<ReturnType<typeof listDomainAliases>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  domainId: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listDomainAliases>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListDomainAliasesQueryOptions(domainId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a dedicated hostname pinned to a team of the domain
 * @summary Create domain alias
 */
export const createDomainAlias = (
  domainId: string,
  createDomainAliasRequest: BodyType<CreateDomainAliasRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainAliasDto>(
    {
      url: `/api/admin/domains/${domainId}/aliases`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: createDomainAliasRequest,
      signal,
    },
    options
  )
}

export const getCreateDomainAliasMutationKey = () => ['createDomainAlias'] as const

export const getCreateDomainAliasMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createDomainAlias>>,
    TError,
    CreateDomainAliasMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createDomainAlias>>,
  TError,
  CreateDomainAliasMutationVariables,
  TContext
> => {
  const mutationKey = getCreateDomainAliasMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createDomainAlias>>,
    CreateDomainAliasMutationVariables
  > = (props) => {
    const { domainId, data } = props ?? {}

    return createDomainAlias(domainId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateDomainAliasMutationResult = NonNullable<
  Awaited<ReturnType<typeof createDomainAlias>>
>
export type CreateDomainAliasMutationBody = BodyType<CreateDomainAliasRequest>
export type CreateDomainAliasMutationError = ErrorType<ErrorResponse | void>
export type CreateDomainAliasMutationVariables = {
  domainId: string
  data: BodyType<CreateDomainAliasRequest>
}

/**
 * Create a dedicated hostname pinned to a team of the domain
 * @summary Create domain alias
 */
export const useCreateDomainAlias = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createDomainAlias>>,
      TError,
      CreateDomainAliasMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createDomainAlias>>,
  TError,
  CreateDomainAliasMutationVariables,
  TContext
> => {
  return useMutation(getCreateDomainAliasMutationOptions(options), queryClient)
}
/**
 * Update a dedicated hostname's pinned team or branding
 * @summary Update domain alias
 */
export const updateDomainAlias = (
  domainId: string,
  aliasId: string,
  updateDomainAliasRequest: BodyType<UpdateDomainAliasRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainAliasDto>(
    {
      url: `/api/admin/domains/${domainId}/aliases/${aliasId}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: updateDomainAliasRequest,
      signal,
    },
    options
  )
}

export const getUpdateDomainAliasMutationKey = () => ['updateDomainAlias'] as const

export const getUpdateDomainAliasMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateDomainAlias>>,
    TError,
    UpdateDomainAliasMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateDomainAlias>>,
  TError,
  UpdateDomainAliasMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateDomainAliasMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateDomainAlias>>,
    UpdateDomainAliasMutationVariables
  > = (props) => {
    const { domainId, aliasId, data } = props ?? {}

    return updateDomainAlias(domainId, aliasId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateDomainAliasMutationResult = NonNullable<
  Awaited<ReturnType<typeof updateDomainAlias>>
>
export type UpdateDomainAliasMutationBody = BodyType<UpdateDomainAliasRequest>
export type UpdateDomainAliasMutationError = ErrorType<ErrorResponse | void>
export type UpdateDomainAliasMutationVariables = {
  domainId: string
  aliasId: string
  data: BodyType<UpdateDomainAliasRequest>
}

/**
 * Update a dedicated hostname's pinned team or branding
 * @summary Update domain alias
 */
export const useUpdateDomainAlias = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateDomainAlias>>,
      TError,
      UpdateDomainAliasMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateDomainAlias>>,
  TError,
  UpdateDomainAliasMutationVariables,
  TContext
> => {
  return useMutation(getUpdateDomainAliasMutationOptions(options), queryClient)
}
/**
 * Delete a dedicated hostname
 * @summary Delete domain alias
 */
export const deleteDomainAlias = (
  domainId: string,
  aliasId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/admin/domains/${domainId}/aliases/${aliasId}`, method: 'DELETE', signal },
    options
  )
}

export const getDeleteDomainAliasMutationKey = () => ['deleteDomainAlias'] as const

export const getDeleteDomainAliasMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteDomainAlias>>,
    TError,
    DeleteDomainAliasMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteDomainAlias>>,
  TError,
  DeleteDomainAliasMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteDomainAliasMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteDomainAlias>>,
    DeleteDomainAliasMutationVariables
  > = (props) => {
    const { domainId, aliasId } = props ?? {}

    return deleteDomainAlias(domainId, aliasId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteDomainAliasMutationResult = NonNullable<
  Awaited<ReturnType<typeof deleteDomainAlias>>
>

export type DeleteDomainAliasMutationError = ErrorType<void | ErrorResponse>
export type DeleteDomainAliasMutationVariables = { domainId: string; aliasId: string }

/**
 * Delete a dedicated hostname
 * @summary Delete domain alias
 */
export const useDeleteDomainAlias = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteDomainAlias>>,
      TError,
      DeleteDomainAliasMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteDomainAlias>>,
  TError,
  DeleteDomainAliasMutationVariables,
  TContext
> => {
  return useMutation(getDeleteDomainAliasMutationOptions(options), queryClient)
}
/**
 * Enable or disable a dedicated hostname
 * @summary Toggle domain alias active status
 */
export const toggleDomainAliasActive = (
  domainId: string,
  aliasId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainAliasDto>(
    {
      url: `/api/admin/domains/${domainId}/aliases/${aliasId}/toggle-active`,
      method: 'POST',
      signal,
    },
    options
  )
}

export const getToggleDomainAliasActiveMutationKey = () => ['toggleDomainAliasActive'] as const

export const getToggleDomainAliasActiveMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof toggleDomainAliasActive>>,
    TError,
    ToggleDomainAliasActiveMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof toggleDomainAliasActive>>,
  TError,
  ToggleDomainAliasActiveMutationVariables,
  TContext
> => {
  const mutationKey = getToggleDomainAliasActiveMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof toggleDomainAliasActive>>,
    ToggleDomainAliasActiveMutationVariables
  > = (props) => {
    const { domainId, aliasId } = props ?? {}

    return toggleDomainAliasActive(domainId, aliasId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ToggleDomainAliasActiveMutationResult = NonNullable<
  Awaited<ReturnType<typeof toggleDomainAliasActive>>
>

export type ToggleDomainAliasActiveMutationError = ErrorType<void | ErrorResponse>
export type ToggleDomainAliasActiveMutationVariables = { domainId: string; aliasId: string }

/**
 * Enable or disable a dedicated hostname
 * @summary Toggle domain alias active status
 */
export const useToggleDomainAliasActive = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof toggleDomainAliasActive>>,
      TError,
      ToggleDomainAliasActiveMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof toggleDomainAliasActive>>,
  TError,
  ToggleDomainAliasActiveMutationVariables,
  TContext
> => {
  return useMutation(getToggleDomainAliasActiveMutationOptions(options), queryClient)
}
/**
 * Get all GPS credentials for a domain
 * @summary List GPS credentials
 */
export const listDomainGpsCredentials = (
  domainId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminGpsCredentialDto[]>(
    { url: `/api/admin/domains/${domainId}/gps-credentials`, method: 'GET', signal },
    options
  )
}

export const getListDomainGpsCredentialsQueryKey = (domainId: string) => {
  return [`/api/admin/domains/${domainId}/gps-credentials`] as const
}

export const getListDomainGpsCredentialsQueryOptions = <
  TData = Awaited<ReturnType<typeof listDomainGpsCredentials>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listDomainGpsCredentials>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListDomainGpsCredentialsQueryKey(domainId)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listDomainGpsCredentials>>> = ({
    signal,
  }) => listDomainGpsCredentials(domainId, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: domainId !== null && domainId !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listDomainGpsCredentials>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListDomainGpsCredentialsQueryResult = NonNullable<
  Awaited<ReturnType<typeof listDomainGpsCredentials>>
>
export type ListDomainGpsCredentialsQueryError = ErrorType<void | ErrorResponse>

/**
 * Get all GPS credentials for a domain
 * @summary List GPS credentials
 */
export function useListDomainGpsCredentials<
  TData = Awaited<ReturnType<typeof listDomainGpsCredentials>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listDomainGpsCredentials>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listDomainGpsCredentials>>,
          TError,
          Awaited<ReturnType<typeof listDomainGpsCredentials>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all GPS credentials for a domain
 * @summary List GPS credentials
 */
export function useListDomainGpsCredentials<
  TData = Awaited<ReturnType<typeof listDomainGpsCredentials>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listDomainGpsCredentials>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listDomainGpsCredentials>>,
          TError,
          Awaited<ReturnType<typeof listDomainGpsCredentials>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all GPS credentials for a domain
 * @summary List GPS credentials
 */
export function useListDomainGpsCredentials<
  TData = Awaited<ReturnType<typeof listDomainGpsCredentials>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listDomainGpsCredentials>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get all GPS credentials for a domain
 * @summary List GPS credentials
 */
export function useListDomainGpsCredentials<
  TData = Awaited<ReturnType<typeof listDomainGpsCredentials>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  domainId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listDomainGpsCredentials>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListDomainGpsCredentialsQueryOptions(domainId, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get all GPS credentials for a domain
 * @summary List GPS credentials
 */
export const prefetchListDomainGpsCredentialsQuery = async <
  TData = Awaited<ReturnType<typeof listDomainGpsCredentials>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  domainId: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof listDomainGpsCredentials>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListDomainGpsCredentialsQueryOptions(domainId, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a new GPS credential for a domain
 * @summary Create GPS credential
 */
export const createDomainGpsCredential = (
  domainId: string,
  createGpsCredentialRequest: BodyType<CreateGpsCredentialRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminGpsCredentialDto>(
    {
      url: `/api/admin/domains/${domainId}/gps-credentials`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: createGpsCredentialRequest,
      signal,
    },
    options
  )
}

export const getCreateDomainGpsCredentialMutationKey = () => ['createDomainGpsCredential'] as const

export const getCreateDomainGpsCredentialMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createDomainGpsCredential>>,
    TError,
    CreateDomainGpsCredentialMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createDomainGpsCredential>>,
  TError,
  CreateDomainGpsCredentialMutationVariables,
  TContext
> => {
  const mutationKey = getCreateDomainGpsCredentialMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createDomainGpsCredential>>,
    CreateDomainGpsCredentialMutationVariables
  > = (props) => {
    const { domainId, data } = props ?? {}

    return createDomainGpsCredential(domainId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateDomainGpsCredentialMutationResult = NonNullable<
  Awaited<ReturnType<typeof createDomainGpsCredential>>
>
export type CreateDomainGpsCredentialMutationBody = BodyType<CreateGpsCredentialRequest>
export type CreateDomainGpsCredentialMutationError = ErrorType<ErrorResponse | void>
export type CreateDomainGpsCredentialMutationVariables = {
  domainId: string
  data: BodyType<CreateGpsCredentialRequest>
}

/**
 * Create a new GPS credential for a domain
 * @summary Create GPS credential
 */
export const useCreateDomainGpsCredential = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createDomainGpsCredential>>,
      TError,
      CreateDomainGpsCredentialMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createDomainGpsCredential>>,
  TError,
  CreateDomainGpsCredentialMutationVariables,
  TContext
> => {
  return useMutation(getCreateDomainGpsCredentialMutationOptions(options), queryClient)
}
/**
 * Update a GPS credential for a domain
 * @summary Update GPS credential
 */
export const updateDomainGpsCredential = (
  domainId: string,
  credentialId: string,
  updateGpsCredentialRequest: BodyType<UpdateGpsCredentialRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminGpsCredentialDto>(
    {
      url: `/api/admin/domains/${domainId}/gps-credentials/${credentialId}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: updateGpsCredentialRequest,
      signal,
    },
    options
  )
}

export const getUpdateDomainGpsCredentialMutationKey = () => ['updateDomainGpsCredential'] as const

export const getUpdateDomainGpsCredentialMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateDomainGpsCredential>>,
    TError,
    UpdateDomainGpsCredentialMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateDomainGpsCredential>>,
  TError,
  UpdateDomainGpsCredentialMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateDomainGpsCredentialMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateDomainGpsCredential>>,
    UpdateDomainGpsCredentialMutationVariables
  > = (props) => {
    const { domainId, credentialId, data } = props ?? {}

    return updateDomainGpsCredential(domainId, credentialId, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateDomainGpsCredentialMutationResult = NonNullable<
  Awaited<ReturnType<typeof updateDomainGpsCredential>>
>
export type UpdateDomainGpsCredentialMutationBody = BodyType<UpdateGpsCredentialRequest>
export type UpdateDomainGpsCredentialMutationError = ErrorType<ErrorResponse | void>
export type UpdateDomainGpsCredentialMutationVariables = {
  domainId: string
  credentialId: string
  data: BodyType<UpdateGpsCredentialRequest>
}

/**
 * Update a GPS credential for a domain
 * @summary Update GPS credential
 */
export const useUpdateDomainGpsCredential = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateDomainGpsCredential>>,
      TError,
      UpdateDomainGpsCredentialMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateDomainGpsCredential>>,
  TError,
  UpdateDomainGpsCredentialMutationVariables,
  TContext
> => {
  return useMutation(getUpdateDomainGpsCredentialMutationOptions(options), queryClient)
}
/**
 * Delete a GPS credential for a domain
 * @summary Delete GPS credential
 */
export const deleteDomainGpsCredential = (
  domainId: string,
  credentialId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/admin/domains/${domainId}/gps-credentials/${credentialId}`,
      method: 'DELETE',
      signal,
    },
    options
  )
}

export const getDeleteDomainGpsCredentialMutationKey = () => ['deleteDomainGpsCredential'] as const

export const getDeleteDomainGpsCredentialMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteDomainGpsCredential>>,
    TError,
    DeleteDomainGpsCredentialMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteDomainGpsCredential>>,
  TError,
  DeleteDomainGpsCredentialMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteDomainGpsCredentialMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteDomainGpsCredential>>,
    DeleteDomainGpsCredentialMutationVariables
  > = (props) => {
    const { domainId, credentialId } = props ?? {}

    return deleteDomainGpsCredential(domainId, credentialId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteDomainGpsCredentialMutationResult = NonNullable<
  Awaited<ReturnType<typeof deleteDomainGpsCredential>>
>

export type DeleteDomainGpsCredentialMutationError = ErrorType<void | ErrorResponse>
export type DeleteDomainGpsCredentialMutationVariables = { domainId: string; credentialId: string }

/**
 * Delete a GPS credential for a domain
 * @summary Delete GPS credential
 */
export const useDeleteDomainGpsCredential = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteDomainGpsCredential>>,
      TError,
      DeleteDomainGpsCredentialMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteDomainGpsCredential>>,
  TError,
  DeleteDomainGpsCredentialMutationVariables,
  TContext
> => {
  return useMutation(getDeleteDomainGpsCredentialMutationOptions(options), queryClient)
}
/**
 * Enable or disable a domain
 * @summary Toggle domain active status
 */
export const toggleDomainActive = (
  domainId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AdminDomainDto>(
    { url: `/api/admin/domains/${domainId}/toggle-active`, method: 'POST', signal },
    options
  )
}

export const getToggleDomainActiveMutationKey = () => ['toggleDomainActive'] as const

export const getToggleDomainActiveMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof toggleDomainActive>>,
    TError,
    ToggleDomainActiveMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof toggleDomainActive>>,
  TError,
  ToggleDomainActiveMutationVariables,
  TContext
> => {
  const mutationKey = getToggleDomainActiveMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof toggleDomainActive>>,
    ToggleDomainActiveMutationVariables
  > = (props) => {
    const { domainId } = props ?? {}

    return toggleDomainActive(domainId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ToggleDomainActiveMutationResult = NonNullable<
  Awaited<ReturnType<typeof toggleDomainActive>>
>

export type ToggleDomainActiveMutationError = ErrorType<void | ErrorResponse>
export type ToggleDomainActiveMutationVariables = { domainId: string }

/**
 * Enable or disable a domain
 * @summary Toggle domain active status
 */
export const useToggleDomainActive = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof toggleDomainActive>>,
      TError,
      ToggleDomainActiveMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof toggleDomainActive>>,
  TError,
  ToggleDomainActiveMutationVariables,
  TContext
> => {
  return useMutation(getToggleDomainActiveMutationOptions(options), queryClient)
}
