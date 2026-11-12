export type PublicationWhen = (typeof PublicationWhen)[keyof typeof PublicationWhen]

export const PublicationWhen = {
  UPCOMING: 'UPCOMING',
  PAST: 'PAST',
  UPCOMING_FIRST: 'UPCOMING_FIRST',
} as const
