/**
 * Calendar feeds (iCal subscription links)
 */
export interface AdminCalendarStatsDto {
  /** Feeds created */
  tokens: number
  /** Feeds fetched at least once */
  usedEver: number
  /** Feeds fetched during the last 7 days */
  usedLast7Days: number
}
