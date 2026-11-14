/**
 * Approval of an OAuth 2.0 authorization request by the signed-in user
 */
export interface OAuthAuthorizeRequest {
  /**
   * The name the application gave itself (client_id). Free text: applications are not registered.
   * @maxLength 40
   * @pattern \S
   */
  clientId: string
  /**
   * Where the code is sent (redirect_uri): any absolute URL or deep link, without a fragment. Not checked against anything.
   * @maxLength 2000
   * @pattern \S
   */
  redirectUri: string
  /**
   * PKCE challenge (code_challenge): BASE64URL(SHA-256(code_verifier))
   * @pattern ^[A-Za-z0-9_-]{43}$
   */
  codeChallenge: string
  /**
   * PKCE method (code_challenge_method): S256 only
   * @pattern ^S256$
   */
  codeChallengeMethod: string
  /**
   * Opaque value given back to the application with the code (state)
   * @maxLength 500
   */
  state?: string
  /** Must be true: the user explicitly confirmed, on a screen naming the application and where the code goes */
  confirmed: boolean
}
