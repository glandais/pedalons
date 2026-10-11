import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type {
  ActivateAccountRequest,
  AuthResponse,
  EmailChangeRequest,
  EmailLinkPreviewResponse,
  ErrorResponse,
  ForgotPasswordRequest,
  LoginRequest,
  MessageResponse,
  OtpRequest,
  RegisterRequest,
  ResetPasswordRequest,
  VerifyOtpRequest,
  VerifyTokenRequest,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * Apply an address change from its link. Opens no session: a signed-in client refreshes its user.
 * @summary Confirm a new address
 */
export const confirmEmailChange = (
  verifyTokenRequest: BodyType<VerifyTokenRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/auth/confirm-email-change`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: verifyTokenRequest,
      signal,
    },
    options
  )
}

export const getConfirmEmailChangeMutationKey = () => ['confirmEmailChange'] as const

export const getConfirmEmailChangeMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof confirmEmailChange>>,
    TError,
    ConfirmEmailChangeMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof confirmEmailChange>>,
  TError,
  ConfirmEmailChangeMutationVariables,
  TContext
> => {
  const mutationKey = getConfirmEmailChangeMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof confirmEmailChange>>,
    ConfirmEmailChangeMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return confirmEmailChange(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ConfirmEmailChangeMutationResult = NonNullable<
  Awaited<ReturnType<typeof confirmEmailChange>>
>
export type ConfirmEmailChangeMutationBody = BodyType<VerifyTokenRequest>
export type ConfirmEmailChangeMutationError = ErrorType<ErrorResponse>
export type ConfirmEmailChangeMutationVariables = { data: BodyType<VerifyTokenRequest> }

/**
 * @summary Confirm a new address
 */
export const useConfirmEmailChange = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof confirmEmailChange>>,
      TError,
      ConfirmEmailChangeMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof confirmEmailChange>>,
  TError,
  ConfirmEmailChangeMutationVariables,
  TContext
> => {
  return useMutation(getConfirmEmailChangeMutationOptions(options), queryClient)
}
/**
 * Change the signed-in user's email address. Sends a verification link to the new address; the change applies once that link is followed.
 * @summary Request email change
 */
export const requestEmailChange = (
  emailChangeRequest: BodyType<EmailChangeRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<MessageResponse>(
    {
      url: `/api/auth/email/change-request`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: emailChangeRequest,
      signal,
    },
    options
  )
}

export const getRequestEmailChangeMutationKey = () => ['requestEmailChange'] as const

export const getRequestEmailChangeMutationOptions = <
  TError = ErrorType<void | ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof requestEmailChange>>,
    TError,
    RequestEmailChangeMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof requestEmailChange>>,
  TError,
  RequestEmailChangeMutationVariables,
  TContext
> => {
  const mutationKey = getRequestEmailChangeMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof requestEmailChange>>,
    RequestEmailChangeMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return requestEmailChange(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RequestEmailChangeMutationResult = NonNullable<
  Awaited<ReturnType<typeof requestEmailChange>>
>
export type RequestEmailChangeMutationBody = BodyType<EmailChangeRequest>
export type RequestEmailChangeMutationError = ErrorType<void | ErrorResponse>
export type RequestEmailChangeMutationVariables = { data: BodyType<EmailChangeRequest> }

/**
 * @summary Request email change
 */
export const useRequestEmailChange = <TError = ErrorType<void | ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof requestEmailChange>>,
      TError,
      RequestEmailChangeMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof requestEmailChange>>,
  TError,
  RequestEmailChangeMutationVariables,
  TContext
> => {
  return useMutation(getRequestEmailChangeMutationOptions(options), queryClient)
}
/**
 * Send a 6-digit code to the user's email to reset their password
 * @summary Request password reset
 */
export const forgotPassword = (
  forgotPasswordRequest: BodyType<ForgotPasswordRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<MessageResponse>(
    {
      url: `/api/auth/forgot-password`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: forgotPasswordRequest,
      signal,
    },
    options
  )
}

export const getForgotPasswordMutationKey = () => ['forgotPassword'] as const

export const getForgotPasswordMutationOptions = <
  TError = ErrorType<void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof forgotPassword>>,
    TError,
    ForgotPasswordMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof forgotPassword>>,
  TError,
  ForgotPasswordMutationVariables,
  TContext
> => {
  const mutationKey = getForgotPasswordMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof forgotPassword>>,
    ForgotPasswordMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return forgotPassword(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ForgotPasswordMutationResult = NonNullable<Awaited<ReturnType<typeof forgotPassword>>>
export type ForgotPasswordMutationBody = BodyType<ForgotPasswordRequest>
export type ForgotPasswordMutationError = ErrorType<void>
export type ForgotPasswordMutationVariables = { data: BodyType<ForgotPasswordRequest> }

/**
 * @summary Request password reset
 */
export const useForgotPassword = <TError = ErrorType<void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof forgotPassword>>,
      TError,
      ForgotPasswordMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof forgotPassword>>,
  TError,
  ForgotPasswordMutationVariables,
  TContext
> => {
  return useMutation(getForgotPasswordMutationOptions(options), queryClient)
}
/**
 * Authenticate using email and password
 * @summary Login with password
 */
export const loginWithPassword = (
  loginRequest: BodyType<LoginRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AuthResponse>(
    {
      url: `/api/auth/login`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: loginRequest,
      signal,
    },
    options
  )
}

export const getLoginWithPasswordMutationKey = () => ['loginWithPassword'] as const

export const getLoginWithPasswordMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof loginWithPassword>>,
    TError,
    LoginWithPasswordMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof loginWithPassword>>,
  TError,
  LoginWithPasswordMutationVariables,
  TContext
> => {
  const mutationKey = getLoginWithPasswordMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof loginWithPassword>>,
    LoginWithPasswordMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return loginWithPassword(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type LoginWithPasswordMutationResult = NonNullable<
  Awaited<ReturnType<typeof loginWithPassword>>
>
export type LoginWithPasswordMutationBody = BodyType<LoginRequest>
export type LoginWithPasswordMutationError = ErrorType<ErrorResponse>
export type LoginWithPasswordMutationVariables = { data: BodyType<LoginRequest> }

/**
 * @summary Login with password
 */
export const useLoginWithPassword = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof loginWithPassword>>,
      TError,
      LoginWithPasswordMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof loginWithPassword>>,
  TError,
  LoginWithPasswordMutationVariables,
  TContext
> => {
  return useMutation(getLoginWithPasswordMutationOptions(options), queryClient)
}
/**
 * Logout and invalidate the refresh token
 * @summary Logout
 */
export const logout = (options?: SecondParameter<typeof axiosMutator>, signal?: AbortSignal) => {
  return axiosMutator<void>({ url: `/api/auth/logout`, method: 'POST', signal }, options)
}

export const getLogoutMutationKey = () => ['logout'] as const

export const getLogoutMutationOptions = <
  TError = ErrorType<unknown>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<Awaited<ReturnType<typeof logout>>, TError, void, TContext>
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<Awaited<ReturnType<typeof logout>>, TError, void, TContext> => {
  const mutationKey = getLogoutMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof logout>>, void> = () => {
    return logout(requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type LogoutMutationResult = NonNullable<Awaited<ReturnType<typeof logout>>>

export type LogoutMutationError = ErrorType<unknown>

/**
 * @summary Logout
 */
export const useLogout = <TError = ErrorType<unknown>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<Awaited<ReturnType<typeof logout>>, TError, void, TContext>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<Awaited<ReturnType<typeof logout>>, TError, void, TContext> => {
  return useMutation(getLogoutMutationOptions(options), queryClient)
}
/**
 * Logout from all devices by invalidating all refresh tokens
 * @summary Logout all sessions
 */
export const logoutAll = (options?: SecondParameter<typeof axiosMutator>, signal?: AbortSignal) => {
  return axiosMutator<void>({ url: `/api/auth/logout-all`, method: 'POST', signal }, options)
}

export const getLogoutAllMutationKey = () => ['logoutAll'] as const

export const getLogoutAllMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<Awaited<ReturnType<typeof logoutAll>>, TError, void, TContext>
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<Awaited<ReturnType<typeof logoutAll>>, TError, void, TContext> => {
  const mutationKey = getLogoutAllMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof logoutAll>>, void> = () => {
    return logoutAll(requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type LogoutAllMutationResult = NonNullable<Awaited<ReturnType<typeof logoutAll>>>

export type LogoutAllMutationError = ErrorType<ErrorResponse | void>

/**
 * @summary Logout all sessions
 */
export const useLogoutAll = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<Awaited<ReturnType<typeof logoutAll>>, TError, void, TContext>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<Awaited<ReturnType<typeof logoutAll>>, TError, void, TContext> => {
  return useMutation(getLogoutAllMutationOptions(options), queryClient)
}
/**
 * Send a 6-digit OTP code to the user's email for passwordless login
 * @summary Request OTP
 */
export const requestOtp = (
  otpRequest: BodyType<OtpRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<MessageResponse>(
    {
      url: `/api/auth/otp`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: otpRequest,
      signal,
    },
    options
  )
}

export const getRequestOtpMutationKey = () => ['requestOtp'] as const

export const getRequestOtpMutationOptions = <
  TError = ErrorType<void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof requestOtp>>,
    TError,
    RequestOtpMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof requestOtp>>,
  TError,
  RequestOtpMutationVariables,
  TContext
> => {
  const mutationKey = getRequestOtpMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof requestOtp>>,
    RequestOtpMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return requestOtp(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RequestOtpMutationResult = NonNullable<Awaited<ReturnType<typeof requestOtp>>>
export type RequestOtpMutationBody = BodyType<OtpRequest>
export type RequestOtpMutationError = ErrorType<void>
export type RequestOtpMutationVariables = { data: BodyType<OtpRequest> }

/**
 * @summary Request OTP
 */
export const useRequestOtp = <TError = ErrorType<void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof requestOtp>>,
      TError,
      RequestOtpMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof requestOtp>>,
  TError,
  RequestOtpMutationVariables,
  TContext
> => {
  return useMutation(getRequestOtpMutationOptions(options), queryClient)
}
/**
 * Verify OTP code and authenticate
 * @summary Verify OTP
 */
export const verifyOtp = (
  verifyOtpRequest: BodyType<VerifyOtpRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AuthResponse>(
    {
      url: `/api/auth/otp/verify`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: verifyOtpRequest,
      signal,
    },
    options
  )
}

export const getVerifyOtpMutationKey = () => ['verifyOtp'] as const

export const getVerifyOtpMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof verifyOtp>>,
    TError,
    VerifyOtpMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof verifyOtp>>,
  TError,
  VerifyOtpMutationVariables,
  TContext
> => {
  const mutationKey = getVerifyOtpMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof verifyOtp>>,
    VerifyOtpMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return verifyOtp(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type VerifyOtpMutationResult = NonNullable<Awaited<ReturnType<typeof verifyOtp>>>
export type VerifyOtpMutationBody = BodyType<VerifyOtpRequest>
export type VerifyOtpMutationError = ErrorType<ErrorResponse>
export type VerifyOtpMutationVariables = { data: BodyType<VerifyOtpRequest> }

/**
 * @summary Verify OTP
 */
export const useVerifyOtp = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof verifyOtp>>,
      TError,
      VerifyOtpMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof verifyOtp>>,
  TError,
  VerifyOtpMutationVariables,
  TContext
> => {
  return useMutation(getVerifyOtpMutationOptions(options), queryClient)
}
/**
 * Get a new access token from the refresh token (cookie on the web, X-Refresh-Token header on mobile). The refresh token is rotated: the new one comes back in the cookie, or in refreshToken for the header flow, and the one presented is then only honoured for a short grace, without rotating again (refreshToken absent). Presented after that grace, it is rotated again from itself: the successor it had (lost by the client) is dropped, and it is refused once the new one is presented.
 * @summary Refresh access token
 */
export const refresh = (options?: SecondParameter<typeof axiosMutator>, signal?: AbortSignal) => {
  return axiosMutator<AuthResponse>({ url: `/api/auth/refresh`, method: 'POST', signal }, options)
}

export const getRefreshMutationKey = () => ['refresh'] as const

export const getRefreshMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<Awaited<ReturnType<typeof refresh>>, TError, void, TContext>
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<Awaited<ReturnType<typeof refresh>>, TError, void, TContext> => {
  const mutationKey = getRefreshMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof refresh>>, void> = () => {
    return refresh(requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RefreshMutationResult = NonNullable<Awaited<ReturnType<typeof refresh>>>

export type RefreshMutationError = ErrorType<ErrorResponse>

/**
 * @summary Refresh access token
 */
export const useRefresh = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<Awaited<ReturnType<typeof refresh>>, TError, void, TContext>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<Awaited<ReturnType<typeof refresh>>, TError, void, TContext> => {
  return useMutation(getRefreshMutationOptions(options), queryClient)
}
/**
 * Register a new user. A verification email will be sent.
 * @summary Register new user
 */
export const register = (
  registerRequest: BodyType<RegisterRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<MessageResponse>(
    {
      url: `/api/auth/register`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: registerRequest,
      signal,
    },
    options
  )
}

export const getRegisterMutationKey = () => ['register'] as const

export const getRegisterMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof register>>,
    TError,
    RegisterMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof register>>,
  TError,
  RegisterMutationVariables,
  TContext
> => {
  const mutationKey = getRegisterMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof register>>,
    RegisterMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return register(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RegisterMutationResult = NonNullable<Awaited<ReturnType<typeof register>>>
export type RegisterMutationBody = BodyType<RegisterRequest>
export type RegisterMutationError = ErrorType<ErrorResponse>
export type RegisterMutationVariables = { data: BodyType<RegisterRequest> }

/**
 * @summary Register new user
 */
export const useRegister = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof register>>,
      TError,
      RegisterMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof register>>,
  TError,
  RegisterMutationVariables,
  TContext
> => {
  return useMutation(getRegisterMutationOptions(options), queryClient)
}
/**
 * Verify the reset token and set a new password
 * @summary Reset password
 */
export const resetPassword = (
  resetPasswordRequest: BodyType<ResetPasswordRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AuthResponse>(
    {
      url: `/api/auth/reset-password`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: resetPasswordRequest,
      signal,
    },
    options
  )
}

export const getResetPasswordMutationKey = () => ['resetPassword'] as const

export const getResetPasswordMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof resetPassword>>,
    TError,
    ResetPasswordMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof resetPassword>>,
  TError,
  ResetPasswordMutationVariables,
  TContext
> => {
  const mutationKey = getResetPasswordMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof resetPassword>>,
    ResetPasswordMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return resetPassword(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ResetPasswordMutationResult = NonNullable<Awaited<ReturnType<typeof resetPassword>>>
export type ResetPasswordMutationBody = BodyType<ResetPasswordRequest>
export type ResetPasswordMutationError = ErrorType<ErrorResponse>
export type ResetPasswordMutationVariables = { data: BodyType<ResetPasswordRequest> }

/**
 * @summary Reset password
 */
export const useResetPassword = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof resetPassword>>,
      TError,
      ResetPasswordMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof resetPassword>>,
  TError,
  ResetPasswordMutationVariables,
  TContext
> => {
  return useMutation(getResetPasswordMutationOptions(options), queryClient)
}
/**
 * Complete a sign-up from its verification link: the password is chosen here, then the new account is signed in.
 * @summary Activate an account
 */
export const activateAccount = (
  activateAccountRequest: BodyType<ActivateAccountRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<AuthResponse>(
    {
      url: `/api/auth/verify-email`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: activateAccountRequest,
      signal,
    },
    options
  )
}

export const getActivateAccountMutationKey = () => ['activateAccount'] as const

export const getActivateAccountMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof activateAccount>>,
    TError,
    ActivateAccountMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof activateAccount>>,
  TError,
  ActivateAccountMutationVariables,
  TContext
> => {
  const mutationKey = getActivateAccountMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof activateAccount>>,
    ActivateAccountMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return activateAccount(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ActivateAccountMutationResult = NonNullable<Awaited<ReturnType<typeof activateAccount>>>
export type ActivateAccountMutationBody = BodyType<ActivateAccountRequest>
export type ActivateAccountMutationError = ErrorType<ErrorResponse>
export type ActivateAccountMutationVariables = { data: BodyType<ActivateAccountRequest> }

/**
 * @summary Activate an account
 */
export const useActivateAccount = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof activateAccount>>,
      TError,
      ActivateAccountMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof activateAccount>>,
  TError,
  ActivateAccountMutationVariables,
  TContext
> => {
  return useMutation(getActivateAccountMutationOptions(options), queryClient)
}
/**
 * The address a sign-up or address-change link verifies, and what following it does. Does not spend the link: the page shows the address before anything happens.
 * @summary Read a verification link
 */
export const previewEmailLink = (
  verifyTokenRequest: BodyType<VerifyTokenRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<EmailLinkPreviewResponse>(
    {
      url: `/api/auth/verify-email/preview`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: verifyTokenRequest,
      signal,
    },
    options
  )
}

export const getPreviewEmailLinkMutationKey = () => ['previewEmailLink'] as const

export const getPreviewEmailLinkMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof previewEmailLink>>,
    TError,
    PreviewEmailLinkMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof previewEmailLink>>,
  TError,
  PreviewEmailLinkMutationVariables,
  TContext
> => {
  const mutationKey = getPreviewEmailLinkMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof previewEmailLink>>,
    PreviewEmailLinkMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return previewEmailLink(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type PreviewEmailLinkMutationResult = NonNullable<
  Awaited<ReturnType<typeof previewEmailLink>>
>
export type PreviewEmailLinkMutationBody = BodyType<VerifyTokenRequest>
export type PreviewEmailLinkMutationError = ErrorType<ErrorResponse>
export type PreviewEmailLinkMutationVariables = { data: BodyType<VerifyTokenRequest> }

/**
 * @summary Read a verification link
 */
export const usePreviewEmailLink = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof previewEmailLink>>,
      TError,
      PreviewEmailLinkMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof previewEmailLink>>,
  TError,
  PreviewEmailLinkMutationVariables,
  TContext
> => {
  return useMutation(getPreviewEmailLinkMutationOptions(options), queryClient)
}
