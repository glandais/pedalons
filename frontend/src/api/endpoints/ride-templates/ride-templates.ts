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
  ListTemplatesParams,
  RideTemplateDto,
  RideTemplateListResponse,
  RideTemplateRequest,
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
 * Get paginated list of ride templates for a team
 * @summary List ride templates
 */
export const listTemplates = (
  teamSlug: string,
  params?: ListTemplatesParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideTemplateListResponse>(
    { url: `/api/teams/${teamSlug}/ride-templates`, method: 'GET', params, signal },
    options
  )
}

export const getListTemplatesQueryKey = (teamSlug: string, params?: ListTemplatesParams) => {
  return [`/api/teams/${teamSlug}/ride-templates`, ...(params ? [params] : [])] as const
}

export const getListTemplatesQueryOptions = <
  TData = Awaited<ReturnType<typeof listTemplates>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTemplatesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTemplates>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListTemplatesQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listTemplates>>> = ({ signal }) =>
    listTemplates(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listTemplates>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListTemplatesQueryResult = NonNullable<Awaited<ReturnType<typeof listTemplates>>>
export type ListTemplatesQueryError = ErrorType<ErrorResponse>

/**
 * Get paginated list of ride templates for a team
 * @summary List ride templates
 */
export function useListTemplates<
  TData = Awaited<ReturnType<typeof listTemplates>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | ListTemplatesParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTemplates>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTemplates>>,
          TError,
          Awaited<ReturnType<typeof listTemplates>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of ride templates for a team
 * @summary List ride templates
 */
export function useListTemplates<
  TData = Awaited<ReturnType<typeof listTemplates>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTemplatesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTemplates>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listTemplates>>,
          TError,
          Awaited<ReturnType<typeof listTemplates>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of ride templates for a team
 * @summary List ride templates
 */
export function useListTemplates<
  TData = Awaited<ReturnType<typeof listTemplates>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTemplatesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTemplates>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get paginated list of ride templates for a team
 * @summary List ride templates
 */
export function useListTemplates<
  TData = Awaited<ReturnType<typeof listTemplates>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListTemplatesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTemplates>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListTemplatesQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get paginated list of ride templates for a team
 * @summary List ride templates
 */
export const prefetchListTemplatesQuery = async <
  TData = Awaited<ReturnType<typeof listTemplates>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: ListTemplatesParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listTemplates>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListTemplatesQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Create a new ride template. Requires organizer permissions.
 * @summary Create ride template
 */
export const createTemplate = (
  teamSlug: string,
  rideTemplateRequest: BodyType<RideTemplateRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideTemplateDto>(
    {
      url: `/api/teams/${teamSlug}/ride-templates`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: rideTemplateRequest,
      signal,
    },
    options
  )
}

export const getCreateTemplateMutationKey = () => ['createTemplate'] as const

export const getCreateTemplateMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof createTemplate>>,
    TError,
    CreateTemplateMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof createTemplate>>,
  TError,
  CreateTemplateMutationVariables,
  TContext
> => {
  const mutationKey = getCreateTemplateMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof createTemplate>>,
    CreateTemplateMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return createTemplate(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type CreateTemplateMutationResult = NonNullable<Awaited<ReturnType<typeof createTemplate>>>
export type CreateTemplateMutationBody = BodyType<RideTemplateRequest>
export type CreateTemplateMutationError = ErrorType<ErrorResponse>
export type CreateTemplateMutationVariables = {
  teamSlug: string
  data: BodyType<RideTemplateRequest>
}

/**
 * Create a new ride template. Requires organizer permissions.
 * @summary Create ride template
 */
export const useCreateTemplate = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof createTemplate>>,
      TError,
      CreateTemplateMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof createTemplate>>,
  TError,
  CreateTemplateMutationVariables,
  TContext
> => {
  return useMutation(getCreateTemplateMutationOptions(options), queryClient)
}
/**
 * Update ride template information. Requires organizer permissions.
 * @summary Update ride template
 */
export const updateTemplate = (
  teamSlug: string,
  templateSlug: string,
  rideTemplateRequest: BodyType<RideTemplateRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideTemplateDto>(
    {
      url: `/api/teams/${teamSlug}/ride-templates/${templateSlug}`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: rideTemplateRequest,
      signal,
    },
    options
  )
}

export const getUpdateTemplateMutationKey = () => ['updateTemplate'] as const

export const getUpdateTemplateMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof updateTemplate>>,
    TError,
    UpdateTemplateMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof updateTemplate>>,
  TError,
  UpdateTemplateMutationVariables,
  TContext
> => {
  const mutationKey = getUpdateTemplateMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof updateTemplate>>,
    UpdateTemplateMutationVariables
  > = (props) => {
    const { teamSlug, templateSlug, data } = props ?? {}

    return updateTemplate(teamSlug, templateSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type UpdateTemplateMutationResult = NonNullable<Awaited<ReturnType<typeof updateTemplate>>>
export type UpdateTemplateMutationBody = BodyType<RideTemplateRequest>
export type UpdateTemplateMutationError = ErrorType<ErrorResponse>
export type UpdateTemplateMutationVariables = {
  teamSlug: string
  templateSlug: string
  data: BodyType<RideTemplateRequest>
}

/**
 * Update ride template information. Requires organizer permissions.
 * @summary Update ride template
 */
export const useUpdateTemplate = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof updateTemplate>>,
      TError,
      UpdateTemplateMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof updateTemplate>>,
  TError,
  UpdateTemplateMutationVariables,
  TContext
> => {
  return useMutation(getUpdateTemplateMutationOptions(options), queryClient)
}
/**
 * Get detailed ride template information
 * @summary Get ride template
 */
export const getTemplate = (
  teamSlug: string,
  templateSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RideTemplateDto>(
    { url: `/api/teams/${teamSlug}/ride-templates/${templateSlug}`, method: 'GET', signal },
    options
  )
}

export const getGetTemplateQueryKey = (teamSlug: string, templateSlug: string) => {
  return [`/api/teams/${teamSlug}/ride-templates/${templateSlug}`] as const
}

export const getGetTemplateQueryOptions = <
  TData = Awaited<ReturnType<typeof getTemplate>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  templateSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTemplate>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTemplateQueryKey(teamSlug, templateSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTemplate>>> = ({ signal }) =>
    getTemplate(teamSlug, templateSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      templateSlug !== null &&
      templateSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTemplate>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTemplateQueryResult = NonNullable<Awaited<ReturnType<typeof getTemplate>>>
export type GetTemplateQueryError = ErrorType<ErrorResponse>

/**
 * Get detailed ride template information
 * @summary Get ride template
 */
export function useGetTemplate<
  TData = Awaited<ReturnType<typeof getTemplate>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  templateSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTemplate>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTemplate>>,
          TError,
          Awaited<ReturnType<typeof getTemplate>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ride template information
 * @summary Get ride template
 */
export function useGetTemplate<
  TData = Awaited<ReturnType<typeof getTemplate>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  templateSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTemplate>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTemplate>>,
          TError,
          Awaited<ReturnType<typeof getTemplate>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ride template information
 * @summary Get ride template
 */
export function useGetTemplate<
  TData = Awaited<ReturnType<typeof getTemplate>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  templateSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTemplate>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get detailed ride template information
 * @summary Get ride template
 */
export function useGetTemplate<
  TData = Awaited<ReturnType<typeof getTemplate>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  templateSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTemplate>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTemplateQueryOptions(teamSlug, templateSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get detailed ride template information
 * @summary Get ride template
 */
export const prefetchGetTemplateQuery = async <
  TData = Awaited<ReturnType<typeof getTemplate>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  templateSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTemplate>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTemplateQueryOptions(teamSlug, templateSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Soft delete a ride template. Requires organizer permissions.
 * @summary Delete ride template
 */
export const deleteTemplate = (
  teamSlug: string,
  templateSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/ride-templates/${templateSlug}`, method: 'DELETE', signal },
    options
  )
}

export const getDeleteTemplateMutationKey = () => ['deleteTemplate'] as const

export const getDeleteTemplateMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteTemplate>>,
    TError,
    DeleteTemplateMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteTemplate>>,
  TError,
  DeleteTemplateMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteTemplateMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteTemplate>>,
    DeleteTemplateMutationVariables
  > = (props) => {
    const { teamSlug, templateSlug } = props ?? {}

    return deleteTemplate(teamSlug, templateSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteTemplateMutationResult = NonNullable<Awaited<ReturnType<typeof deleteTemplate>>>

export type DeleteTemplateMutationError = ErrorType<ErrorResponse>
export type DeleteTemplateMutationVariables = { teamSlug: string; templateSlug: string }

/**
 * Soft delete a ride template. Requires organizer permissions.
 * @summary Delete ride template
 */
export const useDeleteTemplate = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteTemplate>>,
      TError,
      DeleteTemplateMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteTemplate>>,
  TError,
  DeleteTemplateMutationVariables,
  TContext
> => {
  return useMutation(getDeleteTemplateMutationOptions(options), queryClient)
}
