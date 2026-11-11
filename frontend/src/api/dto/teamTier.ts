export type TeamTier = (typeof TeamTier)[keyof typeof TeamTier]

export const TeamTier = {
  FREE: 'FREE',
  UNLOCKED: 'UNLOCKED',
} as const
