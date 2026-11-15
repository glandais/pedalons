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
  TeamWebhookDto,
  TeamWebhookRequest,
  TeamWebhookTestDto,
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
 * The message format is read from the URL: Slack, Discord, or a structured JSON document for anything else. Only https URLs to public addresses are accepted. Omitting the URL keeps the current one.
 * @summary Create or change the team's webhook
 */
export const saveTeamWebhook = (
  teamSlug: string,
  teamWebhookRequest: BodyType<TeamWebhookRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamWebhookDto>(
    {
      url: `/api/teams/${teamSlug}/webhook`,
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      data: teamWebhookRequest,
      signal,
    },
    options
  )
}

export const getSaveTeamWebhookMutationKey = () => ['saveTeamWebhook'] as const

export const getSaveTeamWebhookMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof saveTeamWebhook>>,
    TError,
    SaveTeamWebhookMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof saveTeamWebhook>>,
  TError,
  SaveTeamWebhookMutationVariables,
  TContext
> => {
  const mutationKey = getSaveTeamWebhookMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof saveTeamWebhook>>,
    SaveTeamWebhookMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return saveTeamWebhook(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type SaveTeamWebhookMutationResult = NonNullable<Awaited<ReturnType<typeof saveTeamWebhook>>>
export type SaveTeamWebhookMutationBody = BodyType<TeamWebhookRequest>
export type SaveTeamWebhookMutationError = ErrorType<ErrorResponse | void>
export type SaveTeamWebhookMutationVariables = {
  teamSlug: string
  data: BodyType<TeamWebhookRequest>
}

/**
 * The message format is read from the URL: Slack, Discord, or a structured JSON document for anything else. Only https URLs to public addresses are accepted. Omitting the URL keeps the current one.
 * @summary Create or change the team's webhook
 */
export const useSaveTeamWebhook = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof saveTeamWebhook>>,
      TError,
      SaveTeamWebhookMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof saveTeamWebhook>>,
  TError,
  SaveTeamWebhookMutationVariables,
  TContext
> => {
  return useMutation(getSaveTeamWebhookMutationOptions(options), queryClient)
}
/**
 * The webhook with its URL masked — the URL is a secret. `configured` is false when the team has none.
 * @summary Get the team's webhook
 */
export const getTeamWebhook = (
  teamSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamWebhookDto>(
    { url: `/api/teams/${teamSlug}/webhook`, method: 'GET', signal },
    options
  )
}

export const getGetTeamWebhookQueryKey = (teamSlug: string) => {
  return [`/api/teams/${teamSlug}/webhook`] as const
}

export const getGetTeamWebhookQueryOptions = <
  TData = Awaited<ReturnType<typeof getTeamWebhook>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamWebhook>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetTeamWebhookQueryKey(teamSlug)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getTeamWebhook>>> = ({ signal }) =>
    getTeamWebhook(teamSlug, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof getTeamWebhook>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type GetTeamWebhookQueryResult = NonNullable<Awaited<ReturnType<typeof getTeamWebhook>>>
export type GetTeamWebhookQueryError = ErrorType<void | ErrorResponse>

/**
 * The webhook with its URL masked — the URL is a secret. `configured` is false when the team has none.
 * @summary Get the team's webhook
 */
export function useGetTeamWebhook<
  TData = Awaited<ReturnType<typeof getTeamWebhook>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamWebhook>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamWebhook>>,
          TError,
          Awaited<ReturnType<typeof getTeamWebhook>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The webhook with its URL masked — the URL is a secret. `configured` is false when the team has none.
 * @summary Get the team's webhook
 */
export function useGetTeamWebhook<
  TData = Awaited<ReturnType<typeof getTeamWebhook>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamWebhook>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getTeamWebhook>>,
          TError,
          Awaited<ReturnType<typeof getTeamWebhook>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The webhook with its URL masked — the URL is a secret. `configured` is false when the team has none.
 * @summary Get the team's webhook
 */
export function useGetTeamWebhook<
  TData = Awaited<ReturnType<typeof getTeamWebhook>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamWebhook>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * The webhook with its URL masked — the URL is a secret. `configured` is false when the team has none.
 * @summary Get the team's webhook
 */
export function useGetTeamWebhook<
  TData = Awaited<ReturnType<typeof getTeamWebhook>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamWebhook>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetTeamWebhookQueryOptions(teamSlug, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * The webhook with its URL masked — the URL is a secret. `configured` is false when the team has none.
 * @summary Get the team's webhook
 */
export const prefetchGetTeamWebhookQuery = async <
  TData = Awaited<ReturnType<typeof getTeamWebhook>>,
  TError = ErrorType<void | ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getTeamWebhook>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetTeamWebhookQueryOptions(teamSlug, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * @summary Remove the team's webhook
 */
export const deleteTeamWebhook = (
  teamSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/webhook`, method: 'DELETE', signal },
    options
  )
}

export const getDeleteTeamWebhookMutationKey = () => ['deleteTeamWebhook'] as const

export const getDeleteTeamWebhookMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deleteTeamWebhook>>,
    TError,
    DeleteTeamWebhookMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deleteTeamWebhook>>,
  TError,
  DeleteTeamWebhookMutationVariables,
  TContext
> => {
  const mutationKey = getDeleteTeamWebhookMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deleteTeamWebhook>>,
    DeleteTeamWebhookMutationVariables
  > = (props) => {
    const { teamSlug } = props ?? {}

    return deleteTeamWebhook(teamSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeleteTeamWebhookMutationResult = NonNullable<
  Awaited<ReturnType<typeof deleteTeamWebhook>>
>

export type DeleteTeamWebhookMutationError = ErrorType<void | ErrorResponse>
export type DeleteTeamWebhookMutationVariables = { teamSlug: string }

/** @summary Remove the team's webhook */
export const useDeleteTeamWebhook = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deleteTeamWebhook>>,
      TError,
      DeleteTeamWebhookMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deleteTeamWebhook>>,
  TError,
  DeleteTeamWebhookMutationVariables,
  TContext
> => {
  return useMutation(getDeleteTeamWebhookMutationOptions(options), queryClient)
}
/**
 * Posts a test message now and reports how the endpoint answered.
 * @summary Send a test message to the team's webhook
 */
export const testTeamWebhook = (
  teamSlug: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamWebhookTestDto>(
    { url: `/api/teams/${teamSlug}/webhook/test`, method: 'POST', signal },
    options
  )
}

export const getTestTeamWebhookMutationKey = () => ['testTeamWebhook'] as const

export const getTestTeamWebhookMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof testTeamWebhook>>,
    TError,
    TestTeamWebhookMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof testTeamWebhook>>,
  TError,
  TestTeamWebhookMutationVariables,
  TContext
> => {
  const mutationKey = getTestTeamWebhookMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof testTeamWebhook>>,
    TestTeamWebhookMutationVariables
  > = (props) => {
    const { teamSlug } = props ?? {}

    return testTeamWebhook(teamSlug, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type TestTeamWebhookMutationResult = NonNullable<Awaited<ReturnType<typeof testTeamWebhook>>>

export type TestTeamWebhookMutationError = ErrorType<ErrorResponse | void>
export type TestTeamWebhookMutationVariables = { teamSlug: string }

/**
 * Posts a test message now and reports how the endpoint answered.
 * @summary Send a test message to the team's webhook
 */
export const useTestTeamWebhook = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof testTeamWebhook>>,
      TError,
      TestTeamWebhookMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof testTeamWebhook>>,
  TError,
  TestTeamWebhookMutationVariables,
  TContext
> => {
  return useMutation(getTestTeamWebhookMutationOptions(options), queryClient)
}
