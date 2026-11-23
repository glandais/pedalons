export type RouterEngineOption = (typeof RouterEngineOption)[keyof typeof RouterEngineOption]

export const RouterEngineOption = {
  USE_ROADS: 'USE_ROADS',
  AVOID_MAIN_ROADS: 'AVOID_MAIN_ROADS',
} as const
