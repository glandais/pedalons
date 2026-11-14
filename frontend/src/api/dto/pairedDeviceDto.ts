import type { Instant } from './instant.ts'
import type { PairedDeviceType } from './pairedDeviceType.ts'

/**
 * A device (Karoo, Garmin) paired with the account by code, or an external application the user authorized through OAuth
 */
export interface PairedDeviceDto {
  /** Pairing ID, to unpair the device */
  id: string
  /** Kind of device. OTHER for an external application: applicationName then names it */
  type: PairedDeviceType
  /** For an access opened through OAuth, the name the application gave itself (client_id) — unverified. Absent for a device. */
  applicationName?: string
  /** When the device was paired */
  pairedAt: Instant
  /** When the device last renewed its access */
  lastUsedAt?: Instant
}
