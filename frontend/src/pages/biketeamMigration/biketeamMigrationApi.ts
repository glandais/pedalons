/**
 * The two calls of the biketeam migration page, written by hand: the endpoints are hidden from the
 * OpenAPI contract (a one-off feature only this page calls), so Orval generates nothing for them.
 * They go through `axiosMutator` like the generated clients, so a failure still arrives as an
 * `ApiClientError` carrying the `BIKETEAM_*` code.
 *
 * The types mirror the Java DTOs in backend/src/main/java/fr/pedalons/dto/migration/ and the enums
 * BiketeamMigrationTargetState / BiketeamMigrationBlockReason — field for field; keep them in step.
 *
 * See docs/plans/2026-09-22-biketeam-live-migration.md §4 and §12.2.
 */
import { axiosMutator } from '@/lib/axiosInstance'

/** What the migration would land on, in the domain it is confirmed on. */
export type BiketeamMigrationTargetState =
  'NEW' | 'EXISTING_MIGRATED' | 'SLUG_CONFLICT' | 'MIGRATED_IN_OTHER_DOMAIN'

/** Why the request cannot be confirmed right now — the first that applies. */
export type BiketeamMigrationBlockReason =
  | 'SLUG_CONFLICT'
  | 'MIGRATED_IN_OTHER_DOMAIN'
  | 'REQUEST_ALREADY_USED'
  | 'MIGRATION_RUNNING'
  | 'LOGIN_REQUIRED'
  | 'NOT_TEAM_ADMIN'

/** What the biketeam team holds, as signed by biketeam (deleted items excluded). */
export interface BiketeamMigrationSummaryDto {
  places: number
  /** Biketeam maps. */
  routes: number
  rides: number
  rideTemplates: number
  trips: number
  tripStages: number
  /** Publications, which become posts. */
  publications: number
  faqPage: boolean
  logo: boolean
}

/**
 * A biketeam migration request, as the confirmation page shows it. It carries no option: every
 * migration copies the team to Pédalons, or updates the copy, and changes nothing on biketeam.
 */
export interface BiketeamMigrationPreviewDto {
  requestId: string
  /** Biketeam team id — the mapping key, not necessarily the slug. */
  teamId: string
  teamName: string
  /** The biketeam admin who asked, for display. */
  requestedBy: string
  /** When the signed request expires (ISO-8601 instant). */
  expiresAt: string
  summary: BiketeamMigrationSummaryDto
  /** Name of the Pédalons site the team lands on. */
  targetDomainName: string
  /**
   * Slug of the Pédalons team: the current one of an existing migrated team (it may have been
   * renamed), otherwise the biketeam id normalised to a Pédalons slug (`club_x` → `club-x`).
   */
  targetTeamSlug: string
  targetState: BiketeamMigrationTargetState
  /** Name of the migrated team (EXISTING_MIGRATED) or of the one holding the slug (SLUG_CONFLICT). Always sent. */
  existingTeamName: string | null
  /**
   * Name of the team migrated earlier and now deleted (in the trash) on Pédalons: targetState is
   * NEW, and that team is set aside — it stays deleted, its slug renamed — before the team is
   * created anew. Null otherwise. Always sent.
   */
  trashedTeamSetAside: string | null
  /** Whether the signed-in user can confirm now. */
  confirmable: boolean
  /** Why it cannot be confirmed; null when confirmable. Always sent. */
  blockReason: BiketeamMigrationBlockReason | null
  /** Where "Cancel" goes back to on biketeam. */
  cancelUrl: string
}

/** A confirmed biketeam migration: where to send the browser back. */
export interface BiketeamMigrationConfirmDto {
  /** Biketeam's callback, carrying the request id and the single-use grant. */
  redirectUrl: string
  /** When the grant stops being redeemable (ISO-8601 instant). */
  expiresAt: string
}

/** A signed biketeam migration request, as received in `?request=`. */
export interface BiketeamMigrationTokenRequest {
  requestToken: string
}

/** Public: 400 BIKETEAM_REQUEST_INVALID / BIKETEAM_REQUEST_EXPIRED, 404 when disabled. */
export function previewBiketeamMigration(
  request: BiketeamMigrationTokenRequest
): Promise<BiketeamMigrationPreviewDto> {
  return axiosMutator<BiketeamMigrationPreviewDto>({
    url: '/api/biketeam-migration/preview',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    data: request,
  })
}

/** Signed in: mints the grant biketeam redeems; 400/403/409 carry a BIKETEAM_* code. */
export function confirmBiketeamMigration(
  request: BiketeamMigrationTokenRequest
): Promise<BiketeamMigrationConfirmDto> {
  return axiosMutator<BiketeamMigrationConfirmDto>({
    url: '/api/biketeam-migration/confirm',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    data: request,
  })
}
