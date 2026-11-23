export type RouterEngine = (typeof RouterEngine)[keyof typeof RouterEngine]

export const RouterEngine = {
  STADIA: 'STADIA',
  PEDALONS: 'PEDALONS',
} as const
