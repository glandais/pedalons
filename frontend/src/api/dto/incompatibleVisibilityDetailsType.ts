export type IncompatibleVisibilityDetailsType =
  (typeof IncompatibleVisibilityDetailsType)[keyof typeof IncompatibleVisibilityDetailsType]

export const IncompatibleVisibilityDetailsType = {
  INCOMPATIBLE_VISIBILITY: 'INCOMPATIBLE_VISIBILITY',
} as const
