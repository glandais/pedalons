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
  CreateInvitationRequest,
  ErrorResponse,
  ListInvitationsParams,
  TeamInvitationDto,
  TeamInvitationListResponse,
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
 * Administrators only. This is where a mistyped address shows up: since the creation call cannot tell the admin that an address is unknown, the pending list is what makes a typo visible and revocable.
 * @summary List a team's invitations
 */
export const listInvitations = (
  teamSlug: string,
  params?: ListInvitationsParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamInvitationListResponse>(
    { url: `/api/teams/${teamSlug}/invitations`, method: 'GET', params, signal },
    options
  )
}

export const getListInvitationsQueryKey = (teamSlug: string, params?: ListInvitationsParams) => {
  return [`/api/teams/${teamSlug}/invitations`, ...(params ? [params] : [])] as const
}

export const getListInvitationsQueryOptions = <
  TData = Awaited<ReturnType<typeof listInvitations>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListInvitationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listInvitations>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListInvitationsQueryKey(teamSlug, params)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listInvitations>>> = ({ signal }) =>
    listInvitations(teamSlug, params, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: teamSlug !== null && teamSlug !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof listInvitations>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type ListInvitationsQueryResult = NonNullable<Awaited<ReturnType<typeof listInvitations>>>
export type ListInvitationsQueryError = ErrorType<ErrorResponse>

/**
 * Administrators only. This is where a mistyped address shows up: since the creation call cannot tell the admin that an address is unknown, the pending list is what makes a typo visible and revocable.
 * @summary List a team's invitations
 */
export function useListInvitations<
  TData = Awaited<ReturnType<typeof listInvitations>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params: undefined | ListInvitationsParams,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listInvitations>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listInvitations>>,
          TError,
          Awaited<ReturnType<typeof listInvitations>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Administrators only. This is where a mistyped address shows up: since the creation call cannot tell the admin that an address is unknown, the pending list is what makes a typo visible and revocable.
 * @summary List a team's invitations
 */
export function useListInvitations<
  TData = Awaited<ReturnType<typeof listInvitations>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListInvitationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listInvitations>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listInvitations>>,
          TError,
          Awaited<ReturnType<typeof listInvitations>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Administrators only. This is where a mistyped address shows up: since the creation call cannot tell the admin that an address is unknown, the pending list is what makes a typo visible and revocable.
 * @summary List a team's invitations
 */
export function useListInvitations<
  TData = Awaited<ReturnType<typeof listInvitations>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListInvitationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listInvitations>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Administrators only. This is where a mistyped address shows up: since the creation call cannot tell the admin that an address is unknown, the pending list is what makes a typo visible and revocable.
 * @summary List a team's invitations
 */
export function useListInvitations<
  TData = Awaited<ReturnType<typeof listInvitations>>,
  TError = ErrorType<ErrorResponse>,
>(
  teamSlug: string,
  params?: ListInvitationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listInvitations>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListInvitationsQueryOptions(teamSlug, params, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Administrators only. This is where a mistyped address shows up: since the creation call cannot tell the admin that an address is unknown, the pending list is what makes a typo visible and revocable.
 * @summary List a team's invitations
 */
export const prefetchListInvitationsQuery = async <
  TData = Awaited<ReturnType<typeof listInvitations>>,
  TError = ErrorType<ErrorResponse>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  params?: ListInvitationsParams,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listInvitations>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListInvitationsQueryOptions(teamSlug, params, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Sends an invitation to join the team. The response is the same whether or not an account already exists for the address — only the wording of the e-mail differs — because answering differently would give anyone who administers a team an account-existence probe for the whole domain. Re-inviting the same address is not an error: the previous pending invitation is revoked and a fresh one issued, which is how 'resend' works. Nobody becomes a member until they accept.
 * @summary Invite an e-mail address
 */
export const invite = (
  teamSlug: string,
  createInvitationRequest: BodyType<CreateInvitationRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<TeamInvitationDto>(
    {
      url: `/api/teams/${teamSlug}/invitations`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: createInvitationRequest,
      signal,
    },
    options
  )
}

export const getInviteMutationKey = () => ['invite'] as const

export const getInviteMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof invite>>,
    TError,
    InviteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof invite>>,
  TError,
  InviteMutationVariables,
  TContext
> => {
  const mutationKey = getInviteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof invite>>,
    InviteMutationVariables
  > = (props) => {
    const { teamSlug, data } = props ?? {}

    return invite(teamSlug, data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type InviteMutationResult = NonNullable<Awaited<ReturnType<typeof invite>>>
export type InviteMutationBody = BodyType<CreateInvitationRequest>
export type InviteMutationError = ErrorType<ErrorResponse>
export type InviteMutationVariables = { teamSlug: string; data: BodyType<CreateInvitationRequest> }

/**
 * Sends an invitation to join the team. The response is the same whether or not an account already exists for the address — only the wording of the e-mail differs — because answering differently would give anyone who administers a team an account-existence probe for the whole domain. Re-inviting the same address is not an error: the previous pending invitation is revoked and a fresh one issued, which is how 'resend' works. Nobody becomes a member until they accept.
 * @summary Invite an e-mail address
 */
export const useInvite = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof invite>>,
      TError,
      InviteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof invite>>,
  TError,
  InviteMutationVariables,
  TContext
> => {
  return useMutation(getInviteMutationOptions(options), queryClient)
}
/**
 * Withdraws a pending invitation. This is also the recourse when an invitation should no longer stand — the inviter having left the team, say — since acceptance does not re-check who sent it.
 * @summary Revoke an invitation
 */
export const revoke = (
  teamSlug: string,
  invitationId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    { url: `/api/teams/${teamSlug}/invitations/${invitationId}`, method: 'DELETE', signal },
    options
  )
}

export const getRevokeMutationKey = () => ['revoke'] as const

export const getRevokeMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof revoke>>,
    TError,
    RevokeMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof revoke>>,
  TError,
  RevokeMutationVariables,
  TContext
> => {
  const mutationKey = getRevokeMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof revoke>>,
    RevokeMutationVariables
  > = (props) => {
    const { teamSlug, invitationId } = props ?? {}

    return revoke(teamSlug, invitationId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RevokeMutationResult = NonNullable<Awaited<ReturnType<typeof revoke>>>

export type RevokeMutationError = ErrorType<ErrorResponse>
export type RevokeMutationVariables = { teamSlug: string; invitationId: string }

/**
 * Withdraws a pending invitation. This is also the recourse when an invitation should no longer stand — the inviter having left the team, say — since acceptance does not re-check who sent it.
 * @summary Revoke an invitation
 */
export const useRevoke = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof revoke>>,
      TError,
      RevokeMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof revoke>>,
  TError,
  RevokeMutationVariables,
  TContext
> => {
  return useMutation(getRevokeMutationOptions(options), queryClient)
}
