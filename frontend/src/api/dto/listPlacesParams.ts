export type ListPlacesParams = {
  /** Filter to end places only */
  filterEnd?: boolean
  /** Filter to start places only */
  filterStart?: boolean
  /** Page number */
  page?: number
  /** Search by name or address */
  search?: string
  /** Page size */
  size?: number
}
