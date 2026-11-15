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
  AcceptInvitationRequest,
  ErrorResponse,
  InvitationPreviewDto,
  MemberDto,
  MyInvitationListResponse,
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
 * Joins the team the token names. Requires a session: accepting is consenting, and a consent attaches to an account — a public accept handing back a session would make the invitation link a login credential. Idempotent: replaying it, or accepting when already a member, returns the existing membership without changing its role, so an invitation as MEMBER never demotes an administrator.
 * @summary Accept an invitation
 */
export const accept = (
  acceptInvitationRequest: BodyType<AcceptInvitationRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<MemberDto>(
    {
      url: `/api/invitations/accept`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: acceptInvitationRequest,
      signal,
    },
    options
  )
}

export const getAcceptMutationKey = () => ['accept'] as const

export const getAcceptMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof accept>>,
    TError,
    AcceptMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof accept>>,
  TError,
  AcceptMutationVariables,
  TContext
> => {
  const mutationKey = getAcceptMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof accept>>,
    AcceptMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return accept(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AcceptMutationResult = NonNullable<Awaited<ReturnType<typeof accept>>>
export type AcceptMutationBody = BodyType<AcceptInvitationRequest>
export type AcceptMutationError = ErrorType<ErrorResponse>
export type AcceptMutationVariables = { data: BodyType<AcceptInvitationRequest> }

/**
 * Joins the team the token names. Requires a session: accepting is consenting, and a consent attaches to an account — a public accept handing back a session would make the invitation link a login credential. Idempotent: replaying it, or accepting when already a member, returns the existing membership without changing its role, so an invitation as MEMBER never demotes an administrator.
 * @summary Accept an invitation
 */
export const useAccept = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof accept>>,
      TError,
      AcceptMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof accept>>,
  TError,
  AcceptMutationVariables,
  TContext
> => {
  return useMutation(getAcceptMutationOptions(options), queryClient)
}
/**
 * What the invitation says, for whoever holds its token. Public, because an invitation opened in a signed-out browser has to be able to name the team and the person inviting — otherwise the page can only show a bare login form with no explanation of why. Nothing here goes beyond what the e-mail already said, and the invited address comes back masked.
 * @summary Read an invitation
 */
export const preview = (
  acceptInvitationRequest: BodyType<AcceptInvitationRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<InvitationPreviewDto>(
    {
      url: `/api/invitations/preview`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: acceptInvitationRequest,
      signal,
    },
    options
  )
}

export const getPreviewMutationKey = () => ['preview'] as const

export const getPreviewMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof preview>>,
    TError,
    PreviewMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof preview>>,
  TError,
  PreviewMutationVariables,
  TContext
> => {
  const mutationKey = getPreviewMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof preview>>,
    PreviewMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return preview(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type PreviewMutationResult = NonNullable<Awaited<ReturnType<typeof preview>>>
export type PreviewMutationBody = BodyType<AcceptInvitationRequest>
export type PreviewMutationError = ErrorType<ErrorResponse>
export type PreviewMutationVariables = { data: BodyType<AcceptInvitationRequest> }

/**
 * What the invitation says, for whoever holds its token. Public, because an invitation opened in a signed-out browser has to be able to name the team and the person inviting — otherwise the page can only show a bare login form with no explanation of why. Nothing here goes beyond what the e-mail already said, and the invited address comes back masked.
 * @summary Read an invitation
 */
export const usePreview = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof preview>>,
      TError,
      PreviewMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof preview>>,
  TError,
  PreviewMutationVariables,
  TContext
> => {
  return useMutation(getPreviewMutationOptions(options), queryClient)
}
/**
 * Live invitations addressed to the current user, newest first. Teams they already belong to are left out.
 * @summary My pending invitations
 */
export const listMyInvitations = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<MyInvitationListResponse>(
    { url: `/api/users/me/invitations`, method: 'GET', signal },
    options
  )
}

export const getListMyInvitationsQueryKey = () => {
  return [`/api/users/me/invitations`] as const
}

export const getListMyInvitationsQueryOptions = <
  TData = Awaited<ReturnType<typeof listMyInvitations>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyInvitations>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListMyInvitationsQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listMyInvitations>>> = ({ signal }) =>
    listMyInvitations(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listMyInvitations>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListMyInvitationsQueryResult = NonNullable<
  Awaited<ReturnType<typeof listMyInvitations>>
>
export type ListMyInvitationsQueryError = ErrorType<ErrorResponse | void>

/**
 * Live invitations addressed to the current user, newest first. Teams they already belong to are left out.
 * @summary My pending invitations
 */
export function useListMyInvitations<
  TData = Awaited<ReturnType<typeof listMyInvitations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyInvitations>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listMyInvitations>>,
          TError,
          Awaited<ReturnType<typeof listMyInvitations>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Live invitations addressed to the current user, newest first. Teams they already belong to are left out.
 * @summary My pending invitations
 */
export function useListMyInvitations<
  TData = Awaited<ReturnType<typeof listMyInvitations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyInvitations>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listMyInvitations>>,
          TError,
          Awaited<ReturnType<typeof listMyInvitations>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Live invitations addressed to the current user, newest first. Teams they already belong to are left out.
 * @summary My pending invitations
 */
export function useListMyInvitations<
  TData = Awaited<ReturnType<typeof listMyInvitations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyInvitations>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Live invitations addressed to the current user, newest first. Teams they already belong to are left out.
 * @summary My pending invitations
 */
export function useListMyInvitations<
  TData = Awaited<ReturnType<typeof listMyInvitations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyInvitations>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListMyInvitationsQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Live invitations addressed to the current user, newest first. Teams they already belong to are left out.
 * @summary My pending invitations
 */
export const prefetchListMyInvitationsQuery = async <
  TData = Awaited<ReturnType<typeof listMyInvitations>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listMyInvitations>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListMyInvitationsQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Same effect as redeeming the token, for an invitation reached from this list.
 * @summary Accept one of my invitations
 */
export const acceptMyInvitation = (
  invitationId: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<MemberDto>(
    { url: `/api/users/me/invitations/${invitationId}/accept`, method: 'POST', signal },
    options
  )
}

export const getAcceptMyInvitationMutationKey = () => ['acceptMyInvitation'] as const

export const getAcceptMyInvitationMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof acceptMyInvitation>>,
    TError,
    AcceptMyInvitationMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof acceptMyInvitation>>,
  TError,
  AcceptMyInvitationMutationVariables,
  TContext
> => {
  const mutationKey = getAcceptMyInvitationMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof acceptMyInvitation>>,
    AcceptMyInvitationMutationVariables
  > = (props) => {
    const { invitationId } = props ?? {}

    return acceptMyInvitation(invitationId, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AcceptMyInvitationMutationResult = NonNullable<
  Awaited<ReturnType<typeof acceptMyInvitation>>
>

export type AcceptMyInvitationMutationError = ErrorType<ErrorResponse>
export type AcceptMyInvitationMutationVariables = { invitationId: string }

/**
 * Same effect as redeeming the token, for an invitation reached from this list.
 * @summary Accept one of my invitations
 */
export const useAcceptMyInvitation = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof acceptMyInvitation>>,
      TError,
      AcceptMyInvitationMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof acceptMyInvitation>>,
  TError,
  AcceptMyInvitationMutationVariables,
  TContext
> => {
  return useMutation(getAcceptMyInvitationMutationOptions(options), queryClient)
}
