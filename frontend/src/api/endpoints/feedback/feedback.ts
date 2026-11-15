import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type { ErrorReportRequest, ErrorResponse, FeedbackRequest } from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * Files the member's report with the technical context their client attached. It reaches the maintainers as an issue of a private repository, naming the member by id only; tokens and e-mail addresses are redacted from the context and the log.
 * @summary Report a bug or suggest something
 */
export const sendFeedback = (
  feedbackRequest: BodyType<FeedbackRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/feedback`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: feedbackRequest,
      signal,
    },
    options
  )
}

export const getSendFeedbackMutationKey = () => ['sendFeedback'] as const

export const getSendFeedbackMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof sendFeedback>>,
    TError,
    SendFeedbackMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof sendFeedback>>,
  TError,
  SendFeedbackMutationVariables,
  TContext
> => {
  const mutationKey = getSendFeedbackMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof sendFeedback>>,
    SendFeedbackMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return sendFeedback(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type SendFeedbackMutationResult = NonNullable<Awaited<ReturnType<typeof sendFeedback>>>
export type SendFeedbackMutationBody = BodyType<FeedbackRequest>
export type SendFeedbackMutationError = ErrorType<ErrorResponse | void>
export type SendFeedbackMutationVariables = { data: BodyType<FeedbackRequest> }

/**
 * Files the member's report with the technical context their client attached. It reaches the maintainers as an issue of a private repository, naming the member by id only; tokens and e-mail addresses are redacted from the context and the log.
 * @summary Report a bug or suggest something
 */
export const useSendFeedback = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof sendFeedback>>,
      TError,
      SendFeedbackMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof sendFeedback>>,
  TError,
  SendFeedbackMutationVariables,
  TContext
> => {
  return useMutation(getSendFeedbackMutationOptions(options), queryClient)
}
/**
 * Sent by a client, without the member's intervention, when it catches an unhandled error. The same error reported by many clients becomes one issue. Always 204 once valid, including past the per-member quota, where it is dropped: a client must never retry nor surface this call's failure.
 * @summary Report an unhandled error
 */
export const reportClientError = (
  errorReportRequest: BodyType<ErrorReportRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<void>(
    {
      url: `/api/feedback/errors`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: errorReportRequest,
      signal,
    },
    options
  )
}

export const getReportClientErrorMutationKey = () => ['reportClientError'] as const

export const getReportClientErrorMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof reportClientError>>,
    TError,
    ReportClientErrorMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof reportClientError>>,
  TError,
  ReportClientErrorMutationVariables,
  TContext
> => {
  const mutationKey = getReportClientErrorMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof reportClientError>>,
    ReportClientErrorMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return reportClientError(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ReportClientErrorMutationResult = NonNullable<
  Awaited<ReturnType<typeof reportClientError>>
>
export type ReportClientErrorMutationBody = BodyType<ErrorReportRequest>
export type ReportClientErrorMutationError = ErrorType<ErrorResponse | void>
export type ReportClientErrorMutationVariables = { data: BodyType<ErrorReportRequest> }

/**
 * Sent by a client, without the member's intervention, when it catches an unhandled error. The same error reported by many clients becomes one issue. Always 204 once valid, including past the per-member quota, where it is dropped: a client must never retry nor surface this call's failure.
 * @summary Report an unhandled error
 */
export const useReportClientError = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof reportClientError>>,
      TError,
      ReportClientErrorMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof reportClientError>>,
  TError,
  ReportClientErrorMutationVariables,
  TContext
> => {
  return useMutation(getReportClientErrorMutationOptions(options), queryClient)
}
