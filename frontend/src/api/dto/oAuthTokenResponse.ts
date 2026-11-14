/**
 * OAuth 2.0 token response (RFC 6749 §5.1)
 */
export interface OAuthTokenResponse {
  /** Access token, sent as « Authorization: Bearer … » on every API call */
  access_token: string
  /** Always 'Bearer' */
  token_type: string
  /** Lifetime of the access token, in seconds */
  expires_in: number
  /** Refresh token, to keep in place of the one presented: it rotates at every refresh. Absent when the refresh came within the grace of a rotation made by another one — keep the token already held. */
  refresh_token?: string
}
