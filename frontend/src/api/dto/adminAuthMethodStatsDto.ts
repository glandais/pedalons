/**
 * How the accounts that are not deleted can sign in; the four add up to total
 */
export interface AdminAuthMethodStatsDto {
  /** A password and no passkey */
  passwordOnly: number
  /** A passkey and no password */
  passkeyOnly: number
  /** A password and a passkey */
  passwordAndPasskey: number
  /** Neither: one-time code sent by e-mail only */
  neither: number
}
