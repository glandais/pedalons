import * as zod from 'zod'

/**
 * Called by the site's consent screen once the signed-in user pressed « Autoriser »: mints a single-use authorization code and returns the redirect_uri to send the browser to. Not for applications — they send the browser to /oauth/authorize.
 * @summary Approve an OAuth authorization request
 */
export const oauthAuthorizeBodyClientIdMax = 40

export const oauthAuthorizeBodyClientIdRegExp = new RegExp('\\S')
export const oauthAuthorizeBodyRedirectUriMax = 2000

export const oauthAuthorizeBodyRedirectUriRegExp = new RegExp('\\S')
export const oauthAuthorizeBodyCodeChallengeRegExp = new RegExp('^[A-Za-z0-9_-]{43}$')
export const oauthAuthorizeBodyCodeChallengeMethodRegExp = new RegExp('^S256$')
export const oauthAuthorizeBodyStateMax = 500

export const OauthAuthorizeBody = zod
  .object({
    clientId: zod
      .string()
      .max(oauthAuthorizeBodyClientIdMax)
      .regex(oauthAuthorizeBodyClientIdRegExp)
      .describe(
        'The name the application gave itself (client_id). Free text: applications are not registered.'
      ),
    redirectUri: zod
      .string()
      .max(oauthAuthorizeBodyRedirectUriMax)
      .regex(oauthAuthorizeBodyRedirectUriRegExp)
      .describe(
        'Where the code is sent (redirect_uri): any absolute URL or deep link, without a fragment. Not checked against anything.'
      ),
    codeChallenge: zod
      .string()
      .regex(oauthAuthorizeBodyCodeChallengeRegExp)
      .describe('PKCE challenge (code_challenge): BASE64URL(SHA-256(code_verifier))'),
    codeChallengeMethod: zod
      .string()
      .regex(oauthAuthorizeBodyCodeChallengeMethodRegExp)
      .describe('PKCE method (code_challenge_method): S256 only'),
    state: zod
      .string()
      .max(oauthAuthorizeBodyStateMax)
      .optional()
      .describe('Opaque value given back to the application with the code (state)'),
    confirmed: zod
      .boolean()
      .describe(
        'Must be true: the user explicitly confirmed, on a screen naming the application and where the code goes'
      ),
  })
  .describe('Approval of an OAuth 2.0 authorization request by the signed-in user')

export const OauthAuthorizeResponse = zod
  .object({
    redirectUri: zod
      .string()
      .describe("The application's redirect_uri, carrying the authorization code and the state"),
  })
  .describe('Where the site sends the browser once an OAuth 2.0 request is approved')

/**
 * The OAuth 2.0 token endpoint (RFC 6749 §3.2), form-encoded. grant_type=authorization_code takes code, client_id, redirect_uri (both as sent to /oauth/authorize) and code_verifier (PKCE); a code is good once, for five minutes. grant_type=refresh_token takes refresh_token, which rotates: keep the one of the answer. Access tokens last 15 minutes, a refresh token 90 days after its last use, until the user revokes the application from their profile.
 * @summary Exchange an authorization code, or refresh an access token
 */
export const OauthTokenBody = zod.object({
  grant_type: zod.string().optional(),
  code: zod.string().optional(),
  client_id: zod.string().optional(),
  redirect_uri: zod.string().optional(),
  code_verifier: zod.string().optional(),
  refresh_token: zod.string().optional(),
})

export const OauthTokenResponse = zod
  .object({
    access_token: zod
      .string()
      .describe('Access token, sent as « Authorization: Bearer … » on every API call'),
    token_type: zod.string().describe("Always 'Bearer'"),
    expires_in: zod.int().describe('Lifetime of the access token, in seconds'),
    refresh_token: zod
      .string()
      .optional()
      .describe(
        'Refresh token, to keep in place of the one presented: it rotates at every refresh. Absent when the refresh came within the grace of a rotation made by another one — keep the token already held.'
      ),
  })
  .describe('OAuth 2.0 token response (RFC 6749 §5.1)')
