import type { ReportQueueStatus } from './reportQueueStatus.ts'

export type ListAdminReportsParams = {
  /** OPEN (default) or RESOLVED */
  status?: ReportQueueStatus
}
