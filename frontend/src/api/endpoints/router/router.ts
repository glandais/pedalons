import { useMutation } from '@tanstack/react-query'
import type {
  MutationFunction,
  QueryClient,
  UseMutationOptions,
  UseMutationResult,
} from '@tanstack/react-query'

import type {
  ErrorResponse,
  GpxImportResponse,
  ImportGpxBody,
  LineElevationRequest,
  LineElevationResponse,
  RouterRequest,
  RouterResponse,
} from '../../dto'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType, BodyType } from '../../../lib/axiosInstance.ts'

type SecondParameter<T extends (...args: never) => unknown> = Parameters<T>[1]

/**
 * Calculate a route between two points using the Stadia Maps routing API. Each call is billed against a monthly quota, so the checks come first: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Otherwise ROUTE_PLANNER_DISABLED. Routing failures have their own codes: ROUTING_SEGMENT_TOO_LONG and ROUTING_NO_ROUTE (400), ROUTING_QUOTA_EXCEEDED and ROUTING_UNAVAILABLE (503).
 * @summary Calculate route
 */
export const route = (
  routerRequest: BodyType<RouterRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<RouterResponse>(
    {
      url: `/api/router`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: routerRequest,
      signal,
    },
    options
  )
}

export const getRouteMutationKey = () => ['route'] as const

export const getRouteMutationOptions = <
  TError = ErrorType<ErrorResponse | void>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof route>>,
    TError,
    RouteMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof route>>,
  TError,
  RouteMutationVariables,
  TContext
> => {
  const mutationKey = getRouteMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<Awaited<ReturnType<typeof route>>, RouteMutationVariables> = (
    props
  ) => {
    const { data } = props ?? {}

    return route(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type RouteMutationResult = NonNullable<Awaited<ReturnType<typeof route>>>
export type RouteMutationBody = BodyType<RouterRequest>
export type RouteMutationError = ErrorType<ErrorResponse | void>
export type RouteMutationVariables = { data: BodyType<RouterRequest> }

/**
 * @summary Calculate route
 */
export const useRoute = <TError = ErrorType<ErrorResponse | void>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof route>>,
      TError,
      RouteMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof route>>,
  TError,
  RouteMutationVariables,
  TContext
> => {
  return useMutation(getRouteMutationOptions(options), queryClient)
}
/**
 * Processes each straight line with the FAST elevations, as a routed leg, and returns its densified track with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
 * @summary Read the relief of straight lines
 */
export const lineElevation = (
  lineElevationRequest: BodyType<LineElevationRequest>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<LineElevationResponse>(
    {
      url: `/api/router/elevation`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      data: lineElevationRequest,
      signal,
    },
    options
  )
}

export const getLineElevationMutationKey = () => ['lineElevation'] as const

export const getLineElevationMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof lineElevation>>,
    TError,
    LineElevationMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof lineElevation>>,
  TError,
  LineElevationMutationVariables,
  TContext
> => {
  const mutationKey = getLineElevationMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof lineElevation>>,
    LineElevationMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return lineElevation(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type LineElevationMutationResult = NonNullable<Awaited<ReturnType<typeof lineElevation>>>
export type LineElevationMutationBody = BodyType<LineElevationRequest>
export type LineElevationMutationError = ErrorType<ErrorResponse>
export type LineElevationMutationVariables = { data: BodyType<LineElevationRequest> }

/**
 * @summary Read the relief of straight lines
 */
export const useLineElevation = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof lineElevation>>,
      TError,
      LineElevationMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof lineElevation>>,
  TError,
  LineElevationMutationVariables,
  TContext
> => {
  return useMutation(getLineElevationMutationOptions(options), queryClient)
}
/**
 * Processes a GPX file with the FAST elevations and returns its tracks as polylines, with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
 * @summary Load a GPX file into the route editor
 */
export const importGpx = (
  importGpxBody: BodyType<ImportGpxBody>,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  const formData = new FormData()
  if (importGpxBody.gpxFile !== undefined) {
    formData.append(`gpxFile`, importGpxBody.gpxFile)
  }
  if (importGpxBody.teamSlug !== undefined) {
    formData.append(`teamSlug`, importGpxBody.teamSlug)
  }

  return axiosMutator<GpxImportResponse>(
    {
      url: `/api/router/import-gpx`,
      method: 'POST',
      headers: { 'Content-Type': 'multipart/form-data' },
      data: formData,
      signal,
    },
    options
  )
}

export const getImportGpxMutationKey = () => ['importGpx'] as const

export const getImportGpxMutationOptions = <
  TError = ErrorType<ErrorResponse>,
  TContext = unknown,
>(options?: {
  mutation?: UseMutationOptions<
    Awaited<ReturnType<typeof importGpx>>,
    TError,
    ImportGpxMutationVariables,
    TContext
  >
  request?: SecondParameter<typeof axiosMutator>
}): UseMutationOptions<
  Awaited<ReturnType<typeof importGpx>>,
  TError,
  ImportGpxMutationVariables,
  TContext
> => {
  const mutationKey = getImportGpxMutationKey()
  const { mutation: mutationOptions, request: requestOptions } = options
    ? options.mutation && 'mutationKey' in options.mutation && options.mutation.mutationKey
      ? options
      : { ...options, mutation: { ...options.mutation, mutationKey } }
    : { mutation: { mutationKey }, request: undefined }

  const mutationFn: MutationFunction<
    Awaited<ReturnType<typeof importGpx>>,
    ImportGpxMutationVariables
  > = (props) => {
    const { data } = props ?? {}

    return importGpx(data, requestOptions)
  }

  return { mutationFn, ...mutationOptions }
}

export type ImportGpxMutationResult = NonNullable<Awaited<ReturnType<typeof importGpx>>>
export type ImportGpxMutationBody = BodyType<ImportGpxBody>
export type ImportGpxMutationError = ErrorType<ErrorResponse>
export type ImportGpxMutationVariables = { data: BodyType<ImportGpxBody> }

/**
 * @summary Load a GPX file into the route editor
 */
export const useImportGpx = <TError = ErrorType<ErrorResponse>, TContext = unknown>(
  options?: {
    mutation?: UseMutationOptions<
      Awaited<ReturnType<typeof importGpx>>,
      TError,
      ImportGpxMutationVariables,
      TContext
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseMutationResult<
  Awaited<ReturnType<typeof importGpx>>,
  TError,
  ImportGpxMutationVariables,
  TContext
> => {
  return useMutation(getImportGpxMutationOptions(options), queryClient)
}
