import type { ReportQueueStatus } from './reportQueueStatus.ts'

export type ListTeamReportsParams = {
  /** OPEN (default) or RESOLVED */
  status?: ReportQueueStatus
}
