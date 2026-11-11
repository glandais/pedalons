/**
 * Route duplication request
 */
export interface RouteDuplicateRequest {
  /**
   * Name of the copy
   * @minLength 3
   * @maxLength 200
   * @pattern \S
   */
  name: string
}
