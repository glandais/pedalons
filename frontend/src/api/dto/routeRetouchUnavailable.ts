export type RouteRetouchUnavailable =
  (typeof RouteRetouchUnavailable)[keyof typeof RouteRetouchUnavailable]

export const RouteRetouchUnavailable = {
  NOT_ALLOWED: 'NOT_ALLOWED',
  ENGINE_UNAVAILABLE: 'ENGINE_UNAVAILABLE',
  NOT_READY: 'NOT_READY',
  UNSUPPORTED: 'UNSUPPORTED',
} as const
