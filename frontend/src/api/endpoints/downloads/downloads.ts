import { useQuery } from '@tanstack/react-query'
import type {
  DataTag,
  DefinedInitialDataOptions,
  DefinedUseQueryResult,
  QueryClient,
  QueryFunction,
  QueryKey,
  UndefinedInitialDataOptions,
  UseQueryOptions,
  UseQueryResult,
} from '@tanstack/react-query'

import { axiosMutator } from '../../../lib/axiosInstance.ts'
import type { ErrorType } from '../../../lib/axiosInstance.ts'

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
 * Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download a file
 */
export const downloadPublicAsset = (
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    {
      url: `/api/download/public/assets/${teamSlug}/${assetId}/${fileName}`,
      method: 'GET',
      responseType: 'blob',
      signal,
    },
    options
  )
}

export const getDownloadPublicAssetQueryKey = (
  teamSlug: string,
  assetId: string,
  fileName: string
) => {
  return [`/api/download/public/assets/${teamSlug}/${assetId}/${fileName}`] as const
}

export const getDownloadPublicAssetQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadPublicAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadPublicAsset>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getDownloadPublicAssetQueryKey(teamSlug, assetId, fileName)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadPublicAsset>>> = ({ signal }) =>
    downloadPublicAsset(teamSlug, assetId, fileName, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      assetId !== null &&
      assetId !== undefined &&
      fileName !== null &&
      fileName !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadPublicAsset>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadPublicAssetQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadPublicAsset>>
>
export type DownloadPublicAssetQueryError = ErrorType<unknown>

export function useDownloadPublicAsset<
  TData = Awaited<ReturnType<typeof downloadPublicAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadPublicAsset>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadPublicAsset>>,
          TError,
          Awaited<ReturnType<typeof downloadPublicAsset>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadPublicAsset<
  TData = Awaited<ReturnType<typeof downloadPublicAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadPublicAsset>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadPublicAsset>>,
          TError,
          Awaited<ReturnType<typeof downloadPublicAsset>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadPublicAsset<
  TData = Awaited<ReturnType<typeof downloadPublicAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadPublicAsset>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download a file
 */

export function useDownloadPublicAsset<
  TData = Awaited<ReturnType<typeof downloadPublicAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadPublicAsset>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadPublicAssetQueryOptions(teamSlug, assetId, fileName, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download a file
 */
export const prefetchDownloadPublicAssetQuery = async <
  TData = Awaited<ReturnType<typeof downloadPublicAsset>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadPublicAsset>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadPublicAssetQueryOptions(teamSlug, assetId, fileName, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Serves an avatar under the URL the API gave for it (avatarUrl), in the best format the Accept header allows. Avatars are stored at 256 px: a larger size is served at 256.
 * @summary Download a user's avatar
 */
export const downloadAvatar = (
  fileId: string,
  size: number,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    {
      url: `/api/download/public/avatars/${fileId}/${size}`,
      method: 'GET',
      responseType: 'blob',
      signal,
    },
    options
  )
}

export const getDownloadAvatarQueryKey = (fileId: string, size: number) => {
  return [`/api/download/public/avatars/${fileId}/${size}`] as const
}

export const getDownloadAvatarQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadAvatar>>,
  TError = ErrorType<unknown>,
>(
  fileId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadAvatar>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDownloadAvatarQueryKey(fileId, size)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadAvatar>>> = ({ signal }) =>
    downloadAvatar(fileId, size, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled: fileId !== null && fileId !== undefined && size !== null && size !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadAvatar>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadAvatarQueryResult = NonNullable<Awaited<ReturnType<typeof downloadAvatar>>>
export type DownloadAvatarQueryError = ErrorType<unknown>

export function useDownloadAvatar<
  TData = Awaited<ReturnType<typeof downloadAvatar>>,
  TError = ErrorType<unknown>,
>(
  fileId: string,
  size: number,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadAvatar>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadAvatar>>,
          TError,
          Awaited<ReturnType<typeof downloadAvatar>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadAvatar<
  TData = Awaited<ReturnType<typeof downloadAvatar>>,
  TError = ErrorType<unknown>,
>(
  fileId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadAvatar>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadAvatar>>,
          TError,
          Awaited<ReturnType<typeof downloadAvatar>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadAvatar<
  TData = Awaited<ReturnType<typeof downloadAvatar>>,
  TError = ErrorType<unknown>,
>(
  fileId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadAvatar>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download a user's avatar
 */

export function useDownloadAvatar<
  TData = Awaited<ReturnType<typeof downloadAvatar>>,
  TError = ErrorType<unknown>,
>(
  fileId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadAvatar>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadAvatarQueryOptions(fileId, size, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download a user's avatar
 */
export const prefetchDownloadAvatarQuery = async <
  TData = Awaited<ReturnType<typeof downloadAvatar>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  fileId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadAvatar>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadAvatarQueryOptions(fileId, size, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download an image
 */
export const downloadPublicImage = (
  teamSlug: string,
  assetId: string,
  size: number,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    {
      url: `/api/download/public/images/${teamSlug}/${assetId}/${size}`,
      method: 'GET',
      responseType: 'blob',
      signal,
    },
    options
  )
}

export const getDownloadPublicImageQueryKey = (teamSlug: string, assetId: string, size: number) => {
  return [`/api/download/public/images/${teamSlug}/${assetId}/${size}`] as const
}

export const getDownloadPublicImageQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadPublicImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadPublicImage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDownloadPublicImageQueryKey(teamSlug, assetId, size)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadPublicImage>>> = ({ signal }) =>
    downloadPublicImage(teamSlug, assetId, size, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      assetId !== null &&
      assetId !== undefined &&
      size !== null &&
      size !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadPublicImage>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadPublicImageQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadPublicImage>>
>
export type DownloadPublicImageQueryError = ErrorType<unknown>

export function useDownloadPublicImage<
  TData = Awaited<ReturnType<typeof downloadPublicImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadPublicImage>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadPublicImage>>,
          TError,
          Awaited<ReturnType<typeof downloadPublicImage>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadPublicImage<
  TData = Awaited<ReturnType<typeof downloadPublicImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadPublicImage>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadPublicImage>>,
          TError,
          Awaited<ReturnType<typeof downloadPublicImage>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadPublicImage<
  TData = Awaited<ReturnType<typeof downloadPublicImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadPublicImage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download an image
 */

export function useDownloadPublicImage<
  TData = Awaited<ReturnType<typeof downloadPublicImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadPublicImage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadPublicImageQueryOptions(teamSlug, assetId, size, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download an image
 */
export const prefetchDownloadPublicImageQuery = async <
  TData = Awaited<ReturnType<typeof downloadPublicImage>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadPublicImage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadPublicImageQueryOptions(teamSlug, assetId, size, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download a file
 */
export const downloadUnlistedAsset = (
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    {
      url: `/api/download/public_unlisted/assets/${teamSlug}/${assetId}/${fileName}`,
      method: 'GET',
      responseType: 'blob',
      signal,
    },
    options
  )
}

export const getDownloadUnlistedAssetQueryKey = (
  teamSlug: string,
  assetId: string,
  fileName: string
) => {
  return [`/api/download/public_unlisted/assets/${teamSlug}/${assetId}/${fileName}`] as const
}

export const getDownloadUnlistedAssetQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadUnlistedAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedAsset>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getDownloadUnlistedAssetQueryKey(teamSlug, assetId, fileName)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadUnlistedAsset>>> = ({ signal }) =>
    downloadUnlistedAsset(teamSlug, assetId, fileName, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      assetId !== null &&
      assetId !== undefined &&
      fileName !== null &&
      fileName !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedAsset>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadUnlistedAssetQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadUnlistedAsset>>
>
export type DownloadUnlistedAssetQueryError = ErrorType<unknown>

export function useDownloadUnlistedAsset<
  TData = Awaited<ReturnType<typeof downloadUnlistedAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedAsset>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadUnlistedAsset>>,
          TError,
          Awaited<ReturnType<typeof downloadUnlistedAsset>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadUnlistedAsset<
  TData = Awaited<ReturnType<typeof downloadUnlistedAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedAsset>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadUnlistedAsset>>,
          TError,
          Awaited<ReturnType<typeof downloadUnlistedAsset>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadUnlistedAsset<
  TData = Awaited<ReturnType<typeof downloadUnlistedAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedAsset>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download a file
 */

export function useDownloadUnlistedAsset<
  TData = Awaited<ReturnType<typeof downloadUnlistedAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedAsset>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadUnlistedAssetQueryOptions(teamSlug, assetId, fileName, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download a file
 */
export const prefetchDownloadUnlistedAssetQuery = async <
  TData = Awaited<ReturnType<typeof downloadUnlistedAsset>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedAsset>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadUnlistedAssetQueryOptions(teamSlug, assetId, fileName, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download an image
 */
export const downloadUnlistedImage = (
  teamSlug: string,
  assetId: string,
  size: number,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    {
      url: `/api/download/public_unlisted/images/${teamSlug}/${assetId}/${size}`,
      method: 'GET',
      responseType: 'blob',
      signal,
    },
    options
  )
}

export const getDownloadUnlistedImageQueryKey = (
  teamSlug: string,
  assetId: string,
  size: number
) => {
  return [`/api/download/public_unlisted/images/${teamSlug}/${assetId}/${size}`] as const
}

export const getDownloadUnlistedImageQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadUnlistedImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedImage>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getDownloadUnlistedImageQueryKey(teamSlug, assetId, size)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadUnlistedImage>>> = ({ signal }) =>
    downloadUnlistedImage(teamSlug, assetId, size, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      assetId !== null &&
      assetId !== undefined &&
      size !== null &&
      size !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedImage>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadUnlistedImageQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadUnlistedImage>>
>
export type DownloadUnlistedImageQueryError = ErrorType<unknown>

export function useDownloadUnlistedImage<
  TData = Awaited<ReturnType<typeof downloadUnlistedImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options: {
    query: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedImage>>, TError, TData>
    > &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadUnlistedImage>>,
          TError,
          Awaited<ReturnType<typeof downloadUnlistedImage>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadUnlistedImage<
  TData = Awaited<ReturnType<typeof downloadUnlistedImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedImage>>, TError, TData>
    > &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadUnlistedImage>>,
          TError,
          Awaited<ReturnType<typeof downloadUnlistedImage>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadUnlistedImage<
  TData = Awaited<ReturnType<typeof downloadUnlistedImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedImage>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download an image
 */

export function useDownloadUnlistedImage<
  TData = Awaited<ReturnType<typeof downloadUnlistedImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedImage>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadUnlistedImageQueryOptions(teamSlug, assetId, size, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download an image
 */
export const prefetchDownloadUnlistedImageQuery = async <
  TData = Awaited<ReturnType<typeof downloadUnlistedImage>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<
      UseQueryOptions<Awaited<ReturnType<typeof downloadUnlistedImage>>, TError, TData>
    >
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadUnlistedImageQueryOptions(teamSlug, assetId, size, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download a file
 */
export const downloadTeamAsset = (
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    {
      url: `/api/download/team/assets/${teamSlug}/${assetId}/${fileName}`,
      method: 'GET',
      responseType: 'blob',
      signal,
    },
    options
  )
}

export const getDownloadTeamAssetQueryKey = (
  teamSlug: string,
  assetId: string,
  fileName: string
) => {
  return [`/api/download/team/assets/${teamSlug}/${assetId}/${fileName}`] as const
}

export const getDownloadTeamAssetQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadTeamAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamAsset>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey =
    queryOptions?.queryKey ?? getDownloadTeamAssetQueryKey(teamSlug, assetId, fileName)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadTeamAsset>>> = ({ signal }) =>
    downloadTeamAsset(teamSlug, assetId, fileName, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      assetId !== null &&
      assetId !== undefined &&
      fileName !== null &&
      fileName !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadTeamAsset>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadTeamAssetQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadTeamAsset>>
>
export type DownloadTeamAssetQueryError = ErrorType<unknown>

export function useDownloadTeamAsset<
  TData = Awaited<ReturnType<typeof downloadTeamAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamAsset>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadTeamAsset>>,
          TError,
          Awaited<ReturnType<typeof downloadTeamAsset>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadTeamAsset<
  TData = Awaited<ReturnType<typeof downloadTeamAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamAsset>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadTeamAsset>>,
          TError,
          Awaited<ReturnType<typeof downloadTeamAsset>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadTeamAsset<
  TData = Awaited<ReturnType<typeof downloadTeamAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamAsset>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download a file
 */

export function useDownloadTeamAsset<
  TData = Awaited<ReturnType<typeof downloadTeamAsset>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamAsset>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadTeamAssetQueryOptions(teamSlug, assetId, fileName, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download a file
 */
export const prefetchDownloadTeamAssetQuery = async <
  TData = Awaited<ReturnType<typeof downloadTeamAsset>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  assetId: string,
  fileName: string,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamAsset>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadTeamAssetQueryOptions(teamSlug, assetId, fileName, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}

/**
 * Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download an image
 */
export const downloadTeamImage = (
  teamSlug: string,
  assetId: string,
  size: number,
  options?: SecondParameter<typeof axiosMutator>,
  signal?: AbortSignal
) => {
  return axiosMutator<Blob>(
    {
      url: `/api/download/team/images/${teamSlug}/${assetId}/${size}`,
      method: 'GET',
      responseType: 'blob',
      signal,
    },
    options
  )
}

export const getDownloadTeamImageQueryKey = (teamSlug: string, assetId: string, size: number) => {
  return [`/api/download/team/images/${teamSlug}/${assetId}/${size}`] as const
}

export const getDownloadTeamImageQueryOptions = <
  TData = Awaited<ReturnType<typeof downloadTeamImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamImage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
) => {
  const { query: queryOptions, request: requestOptions } = options ?? {}

  const queryKey = queryOptions?.queryKey ?? getDownloadTeamImageQueryKey(teamSlug, assetId, size)

  const queryFn: QueryFunction<Awaited<ReturnType<typeof downloadTeamImage>>> = ({ signal }) =>
    downloadTeamImage(teamSlug, assetId, size, requestOptions, signal)

  return {
    queryKey,
    queryFn,
    enabled:
      teamSlug !== null &&
      teamSlug !== undefined &&
      assetId !== null &&
      assetId !== undefined &&
      size !== null &&
      size !== undefined,
    ...queryOptions,
  } as UseQueryOptions<Awaited<ReturnType<typeof downloadTeamImage>>, TError, TData> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }
}

export type DownloadTeamImageQueryResult = NonNullable<
  Awaited<ReturnType<typeof downloadTeamImage>>
>
export type DownloadTeamImageQueryError = ErrorType<unknown>

export function useDownloadTeamImage<
  TData = Awaited<ReturnType<typeof downloadTeamImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options: {
    query: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamImage>>, TError, TData>> &
      Pick<
        DefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadTeamImage>>,
          TError,
          Awaited<ReturnType<typeof downloadTeamImage>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): DefinedUseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadTeamImage<
  TData = Awaited<ReturnType<typeof downloadTeamImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamImage>>, TError, TData>> &
      Pick<
        UndefinedInitialDataOptions<
          Awaited<ReturnType<typeof downloadTeamImage>>,
          TError,
          Awaited<ReturnType<typeof downloadTeamImage>>
        >,
        'initialData'
      >
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
export function useDownloadTeamImage<
  TData = Awaited<ReturnType<typeof downloadTeamImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamImage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> }
/**
 * @summary Download an image
 */

export function useDownloadTeamImage<
  TData = Awaited<ReturnType<typeof downloadTeamImage>>,
  TError = ErrorType<unknown>,
>(
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamImage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  },
  queryClient?: QueryClient
): UseQueryResult<TData, TError> & { queryKey: DataTag<QueryKey, TData, TError> } {
  const queryOptions = getDownloadTeamImageQueryOptions(teamSlug, assetId, size, options)

  const query = useQuery(queryOptions, queryClient) as UseQueryResult<TData, TError> & {
    queryKey: DataTag<QueryKey, TData, TError>
  }

  return withQueryKey(query, queryOptions.queryKey)
}

/**
 * @summary Download an image
 */
export const prefetchDownloadTeamImageQuery = async <
  TData = Awaited<ReturnType<typeof downloadTeamImage>>,
  TError = ErrorType<unknown>,
>(
  queryClient: QueryClient,
  teamSlug: string,
  assetId: string,
  size: number,
  options?: {
    query?: Partial<UseQueryOptions<Awaited<ReturnType<typeof downloadTeamImage>>, TError, TData>>
    request?: SecondParameter<typeof axiosMutator>
  }
): Promise<QueryClient> => {
  const queryOptions = getDownloadTeamImageQueryOptions(teamSlug, assetId, size, options)

  await queryClient.query(queryOptions).catch(() => {})

  return queryClient
}
