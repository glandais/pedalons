export type RouteRetouchOperation =
  (typeof RouteRetouchOperation)[keyof typeof RouteRetouchOperation]

export const RouteRetouchOperation = {
  RESIZE: 'RESIZE',
  MOVE_END: 'MOVE_END',
} as const
