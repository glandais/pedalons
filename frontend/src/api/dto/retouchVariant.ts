export type RetouchVariant = (typeof RetouchVariant)[keyof typeof RetouchVariant]

export const RetouchVariant = {
  BEST: 'BEST',
  KEEP_ALL: 'KEEP_ALL',
  NEAREST: 'NEAREST',
} as const
