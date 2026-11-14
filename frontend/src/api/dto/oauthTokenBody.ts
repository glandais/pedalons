export type OauthTokenBody = {
  grant_type?: string
  code?: string
  client_id?: string
  redirect_uri?: string
  code_verifier?: string
  refresh_token?: string
}
