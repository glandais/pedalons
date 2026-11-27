/**
 * Push notification devices of one platform
 */
export interface AdminPushPlatformStatsDto {
  /** The platform (ANDROID, IOS…) */
  platform: string
  /** Devices registered */
  devices: number
  /** Accounts with at least one device */
  users: number
  /** Devices seen during the last 7 days */
  seenLast7Days: number
}
