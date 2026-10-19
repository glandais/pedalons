export type ImportGpxBody = {
  gpxFile?: Blob | File
  /** @maxLength 250 */
  teamSlug?: string
}
