export type WaypointType = (typeof WaypointType)[keyof typeof WaypointType]

export const WaypointType = {
  REGROUP: 'REGROUP',
  SUPPLY: 'SUPPLY',
  WATER: 'WATER',
  CAFE: 'CAFE',
  TOILETS: 'TOILETS',
  DANGER: 'DANGER',
  SUMMIT: 'SUMMIT',
  VIEWPOINT: 'VIEWPOINT',
  BIKE_SHOP: 'BIKE_SHOP',
  REAL_START: 'REAL_START',
  SPLIT: 'SPLIT',
  INFO: 'INFO',
} as const
