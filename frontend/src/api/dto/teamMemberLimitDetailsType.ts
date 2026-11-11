export type TeamMemberLimitDetailsType =
  (typeof TeamMemberLimitDetailsType)[keyof typeof TeamMemberLimitDetailsType]

export const TeamMemberLimitDetailsType = {
  TEAM_MEMBER_LIMIT_REACHED: 'TEAM_MEMBER_LIMIT_REACHED',
} as const
