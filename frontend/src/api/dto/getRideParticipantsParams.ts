export type GetRideParticipantsParams = {
  /** Only this group of the ride (TSID); every group when absent */
  groupId?: string
  /** Page number (0-based) */
  page?: number
  /** Search by display name */
  search?: string
  /** Page size */
  size?: number
}
