/**
 * Where the site sends the browser once an OAuth 2.0 request is approved
 */
export interface OAuthAuthorizeResponse {
  /** The application's redirect_uri, carrying the authorization code and the state */
  redirectUri: string
}
