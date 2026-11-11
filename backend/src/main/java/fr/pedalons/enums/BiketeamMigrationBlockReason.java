package fr.pedalons.enums;

/**
 * Why a biketeam migration request cannot be confirmed right now — the first that applies, in this
 * order.
 */
public enum BiketeamMigrationBlockReason {
  SLUG_CONFLICT,
  MIGRATED_IN_OTHER_DOMAIN,
  /** Already redeemed, or confirmed by another account. */
  REQUEST_ALREADY_USED,
  /** A migration of this biketeam team is queued or running. */
  MIGRATION_RUNNING,
  /** Sign in (or create an account) first. */
  LOGIN_REQUIRED,
  /** The team exists on Pédalons and the signed-in account does not administer it. */
  NOT_TEAM_ADMIN
}
