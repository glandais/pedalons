export type DeviceListRoutesParams = {
  /** Also return, on each registered group, teamName, startPlaceName, status and endDateTime, and list the groups of a cancelled ride. Off by default: a device that does not ask keeps the response it always had. */
  details?: boolean
  /** User's current latitude (for proximity sorting) */
  lat?: number
  /** User's current longitude (for proximity sorting) */
  lon?: number
  /** Also return registeredStages, the upcoming stages of the trips the user is registered for. Off by default: a device that does not ask keeps the response it always had. */
  stages?: boolean
}
