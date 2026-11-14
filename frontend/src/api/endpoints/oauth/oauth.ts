import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type {
  ErrorResponse,
  OAuthAuthorizeRequest,
  OAuthAuthorizeResponse,
  OAuthErrorResponse,
  OAuthTokenResponse,
  OauthTokenBody,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * Called by the site's consent screen once the signed-in user pressed « Autoriser »: mints a single-use authorization code and returns the redirect_uri to send the browser to. Not for applications — they send the browser to /oauth/authorize.
 * @summary Approve an OAuth authorization request
 */
export const oauthAuthorize = (
  oAuthAuthorizeRequest: BodyType<OAuthAuthorizeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<OAuthAuthorizeResponse>(
    {
      url: `/api/oauth/authorize`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: oAuthAuthorizeRequest,
      signal,
    },
    options
  )
}

export const getOauthAuthorizeMutationKey = () => ['oauthAuthorize'] as const

export const getOauthAuthorizeMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof oauthAuthorize>>,
    TError,
    OauthAuthorizeMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof oauthAuthorize>>,
  TError,
  OauthAuthorizeMutationVariables,
  TContext
> => {
  const mutationKey = getOauthAuthorizeMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof oauthAuthorize>>,
    OauthAuthorizeMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return oauthAuthorize(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type OauthAuthorizeMutationResult = NonNullable<Awaited<ReturnType<typeof oauthAuthorize>>>
export type OauthAuthorizeMutationBody = BodyType<OAuthAuthorizeRequest>
export type OauthAuthorizeMutationError = ErrorType<ErrorResponse | void>
export type OauthAuthorizeMutationVariables = { data: BodyType<OAuthAuthorizeRequest> }

/**
 * @summary Approve an OAuth authorization request
 */
export const useOauthAuthorize = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof oauthAuthorize>>,
      TError,
      OauthAuthorizeMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof oauthAuthorize>>,
  TError,
  OauthAuthorizeMutationVariables,
  TContext
> => {
  return useMutation(getOauthAuthorizeMutationOptions(options), queryClient)
}
/**
 * The OAuth 2.0 token endpoint (RFC 6749 §3.2), form-encoded. grant_type=authorization_code takes code, client_id, redirect_uri (both as sent to /oauth/authorize) and code_verifier (PKCE); a code is good once, for five minutes. grant_type=refresh_token takes refresh_token, which rotates: keep the one of the answer. Access tokens last 15 minutes, a refresh token 90 days after its last use, until the user revokes the application from their profile.
 * @summary Exchange an authorization code, or refresh an access token
 */
export const oauthToken = (
  oauthTokenBody: BodyType<OauthTokenBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formUrlEncoded = new URLSearchParams()
  if (oauthTokenBody.grant_type !== undefined) {
    formUrlEncoded.append(`grant_type`, oauthTokenBody.grant_type)
  }
  if (oauthTokenBody.code !== undefined) {
    formUrlEncoded.append(`code`, oauthTokenBody.code)
  }
  if (oauthTokenBody.client_id !== undefined) {
    formUrlEncoded.append(`client_id`, oauthTokenBody.client_id)
  }
  if (oauthTokenBody.redirect_uri !== undefined) {
    formUrlEncoded.append(`redirect_uri`, oauthTokenBody.redirect_uri)
  }
  if (oauthTokenBody.code_verifier !== undefined) {
    formUrlEncoded.append(`code_verifier`, oauthTokenBody.code_verifier)
  }
  if (oauthTokenBody.refresh_token !== undefined) {
    formUrlEncoded.append(`refresh_token`, oauthTokenBody.refresh_token)
  }

  return axiosMutator<OAuthTokenResponse>(
    {
      url: `/api/oauth/token`,
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      data: formUrlEncoded,
      signal,
    },
    options
  )
}

export const getOauthTokenMutationKey = () => ['oauthToken'] as const

export const getOauthTokenMutationOptions = <
  TError = ErrorType<OAuthErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof oauthToken>>,
    TError,
    OauthTokenMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof oauthToken>>,
  TError,
  OauthTokenMutationVariables,
  TContext
> => {
  const mutationKey = getOauthTokenMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof oauthToken>>,
    OauthTokenMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return oauthToken(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type OauthTokenMutationResult = NonNullable<Awaited<ReturnType<typeof oauthToken>>>
export type OauthTokenMutationBody = BodyType<OauthTokenBody>
export type OauthTokenMutationError = ErrorType<OAuthErrorResponse>
export type OauthTokenMutationVariables = { data: BodyType<OauthTokenBody> }

/**
 * @summary Exchange an authorization code, or refresh an access token
 */
export const useOauthToken = <TError = ErrorType<OAuthErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof oauthToken>>,
      TError,
      OauthTokenMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof oauthToken>>,
  TError,
  OauthTokenMutationVariables,
  TContext
> => {
  return useMutation(getOauthTokenMutationOptions(options), queryClient)
}
