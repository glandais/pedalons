/**
 * OAuth 2.0 token error (RFC 6749 §5.2)
 */
export interface OAuthErrorResponse {
  /** invalid_request, invalid_grant or unsupported_grant_type */
  error: string
  /** What was wrong, for the developer */
  error_description: string
}
