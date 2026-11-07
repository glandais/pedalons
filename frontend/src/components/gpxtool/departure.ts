import { normalizeWallTime, type WallTime } from '@/utils/wallTime'

/**
 * What the departure fields of a GPX preview hold: the clock at the track's start (no zone, the
 * server reads it in the zone of the first point) and an average speed, always in km/h whatever
 * unit the field shows. Both are optional and independent.
 */
export interface DepartureValue {
  departure?: WallTime
  averageSpeed?: number
}

/**
 * What the server is told, in the shape of `GpxPreviewUpdateRequest`: nothing for what did not move
 * (the server then keeps it, and makes the date follow the track), a value for what was set or
 * changed, a `clear…` flag for what was emptied.
 */
export interface DepartureChange {
  departure?: WallTime
  clearDeparture?: boolean
  averageSpeed?: number
  clearAverageSpeed?: boolean
}

/**
 * Bounds of the average speed in km/h: a copy of `GpxLimits.MIN_AVERAGE_SPEED_KMH` and
 * `MAX_AVERAGE_SPEED_KMH` in the backend (a tiny speed would push the passages out of the
 * forecast's range, so the server refuses it with a 400).
 */
export const MIN_AVERAGE_SPEED_KMH = 10
export const MAX_AVERAGE_SPEED_KMH = 60

/** Nothing until the value has moved: the server then keeps the date and makes it follow the track. */
export function departureChange(initial: DepartureValue, current: DepartureValue): DepartureChange {
  const change: DepartureChange = {}
  if (current.departure !== initial.departure) {
    if (current.departure) change.departure = normalizeWallTime(current.departure)
    else change.clearDeparture = true
  }
  if (current.averageSpeed !== initial.averageSpeed) {
    if (current.averageSpeed !== undefined) change.averageSpeed = current.averageSpeed
    else change.clearAverageSpeed = true
  }
  return change
}

/** The form fields of a file upload: text, and no key at all for what is empty. */
export function departureFormFields(value: DepartureChange): {
  departure?: string
  averageSpeed?: string
} {
  const fields: { departure?: string; averageSpeed?: string } = {}
  if (value.departure) fields.departure = normalizeWallTime(value.departure)
  if (value.averageSpeed !== undefined) fields.averageSpeed = String(value.averageSpeed)
  return fields
}

/** The creation JSON of a drawn track: only what is set (a creation has nothing to clear). */
export function departureJsonFields(value: DepartureChange): {
  departure?: string
  averageSpeed?: number
} {
  return {
    ...(value.departure ? { departure: normalizeWallTime(value.departure) } : {}),
    ...(value.averageSpeed !== undefined ? { averageSpeed: value.averageSpeed } : {}),
  }
}
