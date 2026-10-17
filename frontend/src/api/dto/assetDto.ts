import type { AssetDimensionsDto } from './assetDimensionsDto.ts'

export interface AssetDto {
  /** ID (TSID) */
  id: string
  /** Filename */
  fileName: string
  /** Content-Type */
  contentType: string
  /** Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is. */
  url: string
  /** Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only. */
  imageUrl?: string
  /** image dimensions */
  imageDimensions?: AssetDimensionsDto
  /** Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests. */
  size?: number
}
