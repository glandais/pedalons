export type Reason = (typeof Reason)[keyof typeof Reason]

export const Reason = {
  ABSENT: 'ABSENT',
  STALE: 'STALE',
  CHANGED: 'CHANGED',
  EXPIRING: 'EXPIRING',
  FORCED: 'FORCED',
  CURRENT: 'CURRENT',
  TEAM_GONE: 'TEAM_GONE',
  PLANNER_OFF: 'PLANNER_OFF',
} as const
