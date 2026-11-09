export type ListUsersParams = {
  /** Show only platform admins */
  adminOnly?: boolean
  /** Filter by domain ID */
  domainId?: string
  /** Page number (0-indexed) */
  page?: number
  /** Search by email or name */
  search?: string
  /** Page size */
  size?: number
}
