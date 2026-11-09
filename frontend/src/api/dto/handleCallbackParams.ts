export type HandleCallbackParams = {
  code?: string
  error?: string
  /** OAuth 1.0a request token */
  oauth_token?: string
  /** OAuth 1.0a verifier */
  oauth_verifier?: string
  state?: string
}
