export type WaypointOrigin = (typeof WaypointOrigin)[keyof typeof WaypointOrigin]

export const WaypointOrigin = {
  AUTHOR: 'AUTHOR',
  IMPORTED: 'IMPORTED',
} as const
