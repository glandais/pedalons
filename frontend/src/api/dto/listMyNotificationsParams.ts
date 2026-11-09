export type ListMyNotificationsParams = {
  /** Page number (0-indexed) */
  page?: number
  /** Page size (max 200) */
  size?: number
  /** Only unread notifications */
  unreadOnly?: boolean
}
