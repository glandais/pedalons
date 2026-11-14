import * as zod from 'zod'

/**
 * Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download a file
 */
export const DownloadPublicAssetParams = zod.object({
  assetId: zod.string().describe('Asset ID'),
  fileName: zod
    .string()
    .describe('File name: the last segment of the URL, not used to find the file'),
  teamSlug: zod.string().describe('Team slug'),
})

export const DownloadPublicAssetResponse = zod.unknown()

/**
 * Serves an avatar under the URL the API gave for it (avatarUrl), in the best format the Accept header allows. Avatars are stored at 256 px: a larger size is served at 256.
 * @summary Download a user's avatar
 */
export const DownloadAvatarParams = zod.object({
  fileId: zod.string().describe('Avatar file ID, from avatarUrl'),
  size: zod.int().describe('Requested square size in pixels'),
})

export const DownloadAvatarResponse = zod.unknown()

/**
 * Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download an image
 */
export const DownloadPublicImageParams = zod.object({
  assetId: zod.string().describe('Asset ID'),
  size: zod.int().describe('Requested square size in pixels'),
  teamSlug: zod.string().describe('Team slug'),
})

export const DownloadPublicImageResponse = zod.unknown()

/**
 * Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download a file
 */
export const DownloadUnlistedAssetParams = zod.object({
  assetId: zod.string().describe('Asset ID'),
  fileName: zod
    .string()
    .describe('File name: the last segment of the URL, not used to find the file'),
  teamSlug: zod.string().describe('Team slug'),
})

export const DownloadUnlistedAssetResponse = zod.unknown()

/**
 * Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download an image
 */
export const DownloadUnlistedImageParams = zod.object({
  assetId: zod.string().describe('Asset ID'),
  size: zod.int().describe('Requested square size in pixels'),
  teamSlug: zod.string().describe('Team slug'),
})

export const DownloadUnlistedImageResponse = zod.unknown()

/**
 * Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download a file
 */
export const DownloadTeamAssetParams = zod.object({
  assetId: zod.string().describe('Asset ID'),
  fileName: zod
    .string()
    .describe('File name: the last segment of the URL, not used to find the file'),
  teamSlug: zod.string().describe('Team slug'),
})

export const DownloadTeamAssetResponse = zod.unknown()

/**
 * Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
 * @summary Download an image
 */
export const DownloadTeamImageParams = zod.object({
  assetId: zod.string().describe('Asset ID'),
  size: zod.int().describe('Requested square size in pixels'),
  teamSlug: zod.string().describe('Team slug'),
})

export const DownloadTeamImageResponse = zod.unknown()
