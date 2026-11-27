/**
 * A count for one calendar month (UTC)
 */
export interface AdminMonthCountDto {
  /** Calendar month, YYYY-MM (UTC) */
  month: string
  /** How many */
  count: number
}
