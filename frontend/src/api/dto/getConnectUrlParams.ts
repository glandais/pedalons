import type { GpsConnectReturn } from './gpsConnectReturn.ts'

export type GetConnectUrlParams = {
  /** Where the OAuth callback sends the browser back to. PROFILE when absent. */
  returnTo?: GpsConnectReturn
}
