/**
 * GPX preview copy request
 */
export interface GpxPreviewCopyRequest {
  /**
   * Name of the copy
   * @minLength 3
   * @maxLength 200
   * @pattern \S
   */
  name: string
}
