import * as zod from 'zod'

/**
 * @summary Create asset
 */
export const UploadAssetParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const UploadAssetQueryParams = zod.object({
  assetType: zod.enum(['LOGO', 'IMAGE', 'ATTACHMENT']).describe('Asset type'),
})

export const UploadAssetBody = zod.object({
  file: zod.instanceof(Blob).optional(),
})

export const UploadAssetResponse = zod.object({
  id: zod.string().describe('ID (TSID)'),
  fileName: zod.string().describe('Filename'),
  contentType: zod.string().describe('Content-Type'),
  url: zod
    .string()
    .describe(
      'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
    ),
  imageUrl: zod
    .string()
    .optional()
    .describe(
      'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
    ),
  imageDimensions: zod
    .object({
      width: zod.int().optional(),
      height: zod.int().optional(),
    })
    .optional()
    .describe('image dimensions'),
  size: zod
    .int()
    .optional()
    .describe(
      'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
    ),
})
