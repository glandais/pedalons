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
  AuthResponse,
  AuthenticateBody,
  ErrorResponse,
  PasskeyAuthenticationRequest,
  PasskeyDto,
  RegisterPasskeyBody,
  RegisterPasskeyParams,
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
 * List all passkeys registered for the current user
 * @summary List passkeys
 */
export const listPasskeys = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PasskeyDto[]>({ url: `/api/auth/passkeys`, method: 'GET', signal }, options)
}

export const getListPasskeysQueryKey = () => {
  return [`/api/auth/passkeys`] as const
}

export const getListPasskeysQueryOptions = <
  TData = Awaited<ReturnType<typeof listPasskeys>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPasskeys>>, TError, TData>>
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getListPasskeysQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof listPasskeys>>> = ({ signal }) =>
    listPasskeys(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof listPasskeys>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type ListPasskeysQueryResult = NonNullable<Awaited<ReturnType<typeof listPasskeys>>>
export type ListPasskeysQueryError = ErrorType<ErrorResponse | void>

/**
 * List all passkeys registered for the current user
 * @summary List passkeys
 */
export function useListPasskeys<
  TData = Awaited<ReturnType<typeof listPasskeys>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPasskeys>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPasskeys>>,
          TError,
          Awaited<ReturnType<typeof listPasskeys>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * List all passkeys registered for the current user
 * @summary List passkeys
 */
export function useListPasskeys<
  TData = Awaited<ReturnType<typeof listPasskeys>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPasskeys>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof listPasskeys>>,
          TError,
          Awaited<ReturnType<typeof listPasskeys>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * List all passkeys registered for the current user
 * @summary List passkeys
 */
export function useListPasskeys<
  TData = Awaited<ReturnType<typeof listPasskeys>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPasskeys>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * List all passkeys registered for the current user
 * @summary List passkeys
 */
export function useListPasskeys<
  TData = Awaited<ReturnType<typeof listPasskeys>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPasskeys>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getListPasskeysQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * List all passkeys registered for the current user
 * @summary List passkeys
 */
export const prefetchListPasskeysQuery = async <
  TData = Awaited<ReturnType<typeof listPasskeys>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof listPasskeys>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getListPasskeysQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Authenticate using a passkey
 * @summary Authenticate with passkey
 */
export const authenticate = (
  authenticateBody: BodyType<AuthenticateBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AuthResponse>(
    {
      url: `/api/auth/passkeys/authenticate`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: authenticateBody,
      signal,
    },
    options
  )
}

export const getAuthenticateMutationKey = () => ['authenticate'] as const

export const getAuthenticateMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof authenticate>>,
    TError,
    AuthenticateMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof authenticate>>,
  TError,
  AuthenticateMutationVariables,
  TContext
> => {
  const mutationKey = getAuthenticateMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof authenticate>>,
    AuthenticateMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return authenticate(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type AuthenticateMutationResult = NonNullable<Awaited<ReturnType<typeof authenticate>>>
export type AuthenticateMutationBody = BodyType<AuthenticateBody>
export type AuthenticateMutationError = ErrorType<void | ErrorResponse>
export type AuthenticateMutationVariables = { data: BodyType<AuthenticateBody> }

/**
 * Authenticate using a passkey
 * @summary Authenticate with passkey
 */
export const useAuthenticate = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof authenticate>>,
      TError,
      AuthenticateMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof authenticate>>,
  TError,
  AuthenticateMutationVariables,
  TContext
> => {
  return useMutation(getAuthenticateMutationOptions(options), queryClient)
}
/**
 * Get WebAuthn options for authenticating with a passkey
 * @summary Get authentication options
 */
export const getAuthenticationOptions = (
  passkeyAuthenticationRequest: BodyType<PasskeyAuthenticationRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>(
    {
      url: `/api/auth/passkeys/authentication-options`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: passkeyAuthenticationRequest,
      signal,
    },
    options
  )
}

export const getGetAuthenticationOptionsMutationKey = () => ['getAuthenticationOptions'] as const

export const getGetAuthenticationOptionsMutationOptions = <
  TError = ErrorType<void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof getAuthenticationOptions>>,
    TError,
    GetAuthenticationOptionsMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof getAuthenticationOptions>>,
  TError,
  GetAuthenticationOptionsMutationVariables,
  TContext
> => {
  const mutationKey = getGetAuthenticationOptionsMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof getAuthenticationOptions>>,
    GetAuthenticationOptionsMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return getAuthenticationOptions(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type GetAuthenticationOptionsMutationResult = NonNullable<
  Awaited<ReturnType<typeof getAuthenticationOptions>>
>
export type GetAuthenticationOptionsMutationBody = BodyType<PasskeyAuthenticationRequest>
export type GetAuthenticationOptionsMutationError = ErrorType<void>
export type GetAuthenticationOptionsMutationVariables = {
  data: BodyType<PasskeyAuthenticationRequest>
}

/**
 * Get WebAuthn options for authenticating with a passkey
 * @summary Get authentication options
 */
export const useGetAuthenticationOptions = <TError = ErrorType<void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof getAuthenticationOptions>>,
      TError,
      GetAuthenticationOptionsMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof getAuthenticationOptions>>,
  TError,
  GetAuthenticationOptionsMutationVariables,
  TContext
> => {
  return useMutation(getGetAuthenticationOptionsMutationOptions(options), queryClient)
}
/**
 * Verify and register a new passkey for the current user
 * @summary Register passkey
 */
export const registerPasskey = (
  registerPasskeyBody: BodyType<RegisterPasskeyBody>,
  params?: RegisterPasskeyParams,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<PasskeyDto>(
    {
      url: `/api/auth/passkeys/register`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: registerPasskeyBody,
      params,
      signal,
    },
    options
  )
}

export const getRegisterPasskeyMutationKey = () => ['registerPasskey'] as const

export const getRegisterPasskeyMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof registerPasskey>>,
    TError,
    RegisterPasskeyMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof registerPasskey>>,
  TError,
  RegisterPasskeyMutationVariables,
  TContext
> => {
  const mutationKey = getRegisterPasskeyMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof registerPasskey>>,
    RegisterPasskeyMutationVariables
  > = (props) => {
    const { data, params } = props ?? {}

    return registerPasskey(data, params, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RegisterPasskeyMutationResult = NonNullable<Awaited<ReturnType<typeof registerPasskey>>>
export type RegisterPasskeyMutationBody = BodyType<RegisterPasskeyBody>
export type RegisterPasskeyMutationError = ErrorType<ErrorResponse | void>
export type RegisterPasskeyMutationVariables = {
  data: BodyType<RegisterPasskeyBody>
  params?: RegisterPasskeyParams
}

/**
 * Verify and register a new passkey for the current user
 * @summary Register passkey
 */
export const useRegisterPasskey = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof registerPasskey>>,
      TError,
      RegisterPasskeyMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof registerPasskey>>,
  TError,
  RegisterPasskeyMutationVariables,
  TContext
> => {
  return useMutation(getRegisterPasskeyMutationOptions(options), queryClient)
}
/**
 * Get WebAuthn options for registering a new passkey
 * @summary Get registration options
 */
export const getRegistrationOptions = (
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<unknown>(
    { url: `/api/auth/passkeys/registration-options`, method: 'GET', signal },
    options
  )
}

export const getGetRegistrationOptionsQueryKey = () => {
  return [`/api/auth/passkeys/registration-options`] as const
}

export const getGetRegistrationOptionsQueryOptions = <
  TData = Awaited<ReturnType<typeof getRegistrationOptions>>,
  TError = ErrorType<ErrorResponse | void>,
>(options?: {
  query?: Partial<
    UseQueryOptions<Awaited<ReturnType<typeof getRegistrationOptions>>, TError, TData>
  >
  request?: SecondParameter<typeof axiosMutator>
}) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getGetRegistrationOptionsQueryKey()

  const queryFn: QueryFunction<Awaited<ReturnType<typeof getRegistrationOptions>>> = ({ signal }) =>
    getRegistrationOptions(requestOptions, signal)

  return { queryKey, queryFn, ...queryOptions } as UseQueryOptions<
    Awaited<ReturnType<typeof getRegistrationOptions>>,
    TError,
    TData
  > & { queryKey: DataTag<QueryKey, TData, TError> }
}

export type GetRegistrationOptionsQueryResult = NonNullable<
  Awaited<ReturnType<typeof getRegistrationOptions>>
>
export type GetRegistrationOptionsQueryError = ErrorType<ErrorResponse | void>

/**
 * Get WebAuthn options for registering a new passkey
 * @summary Get registration options
 */
export function useGetRegistrationOptions<
  TData = Awaited<ReturnType<typeof getRegistrationOptions>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRegistrationOptions>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRegistrationOptions>>,
          TError,
          Awaited<ReturnType<typeof getRegistrationOptions>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get WebAuthn options for registering a new passkey
 * @summary Get registration options
 */
export function useGetRegistrationOptions<
  TData = Awaited<ReturnType<typeof getRegistrationOptions>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRegistrationOptions>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof getRegistrationOptions>>,
          TError,
          Awaited<ReturnType<typeof getRegistrationOptions>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get WebAuthn options for registering a new passkey
 * @summary Get registration options
 */
export function useGetRegistrationOptions<
  TData = Awaited<ReturnType<typeof getRegistrationOptions>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRegistrationOptions>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * Get WebAuthn options for registering a new passkey
 * @summary Get registration options
 */
export function useGetRegistrationOptions<
  TData = Awaited<ReturnType<typeof getRegistrationOptions>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRegistrationOptions>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getGetRegistrationOptionsQueryOptions(options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * Get WebAuthn options for registering a new passkey
 * @summary Get registration options
 */
export const prefetchGetRegistrationOptionsQuery = async <
  TData = Awaited<ReturnType<typeof getRegistrationOptions>>,
  TError = ErrorType<ErrorResponse | void>,
>(
  queryClient: QueryClient,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof getRegistrationOptions>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getGetRegistrationOptionsQueryOptions(options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Delete a passkey
 * @summary Delete passkey
 */
export const deletePasskey = (
  id: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>({ url: `/api/auth/passkeys/${id}`, method: 'DELETE', signal }, options)
}

export const getDeletePasskeyMutationKey = () => ['deletePasskey'] as const

export const getDeletePasskeyMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof deletePasskey>>,
    TError,
    DeletePasskeyMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof deletePasskey>>,
  TError,
  DeletePasskeyMutationVariables,
  TContext
> => {
  const mutationKey = getDeletePasskeyMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof deletePasskey>>,
    DeletePasskeyMutationVariables
  > = (props) => {
    const { id } = props ?? {}

    return deletePasskey(id, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type DeletePasskeyMutationResult = NonNullable<Awaited<ReturnType<typeof deletePasskey>>>

export type DeletePasskeyMutationError = ErrorType<ErrorResponse | void>
export type DeletePasskeyMutationVariables = { id: string }

/**
 * Delete a passkey
 * @summary Delete passkey
 */
export const useDeletePasskey = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof deletePasskey>>,
      TError,
      DeletePasskeyMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof deletePasskey>>,
  TError,
  DeletePasskeyMutationVariables,
  TContext
> => {
  return useMutation(getDeletePasskeyMutationOptions(options), queryClient)
}
