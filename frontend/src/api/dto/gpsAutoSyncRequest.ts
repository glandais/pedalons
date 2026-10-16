/**
 * Turns the automatic route sync of one GPS service on or off
 */
export interface GpsAutoSyncRequest {
  /** true to send the routes of the user's upcoming rides to this service automatically; false to stop, which also removes from the service the upcoming routes the sync sent */
  enabled: boolean
}
