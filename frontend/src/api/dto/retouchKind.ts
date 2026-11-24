export type RetouchKind = (typeof RetouchKind)[keyof typeof RetouchKind]

export const RetouchKind = {
  SHORTEN: 'SHORTEN',
  LENGTHEN: 'LENGTHEN',
  MOVE_END: 'MOVE_END',
  TRUNCATE: 'TRUNCATE',
} as const
