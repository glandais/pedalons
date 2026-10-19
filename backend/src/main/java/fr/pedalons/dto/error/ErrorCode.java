package fr.pedalons.dto.error;

public enum ErrorCode {
  BAD_REQUEST,
  NOT_FOUND,
  UNAUTHORIZED,
  FORBIDDEN,
  INTERNAL_ERROR,
  UNKNOWN,
  VALIDATION,
  BUSINESS_RULE,
  LAST_ADMIN,
  // Deleting an account that is the last admin of a team others still belong to.
  SOLE_TEAM_ADMIN,
  /**
   * Deleting an account that is the last admin of a team migrated from biketeam, members or not: the
   * team would go with it while biketeam keeps redirecting its old addresses there.
   */
  SOLE_MIGRATED_TEAM_ADMIN,
  /**
   * Deleting a team migrated from biketeam: biketeam redirects its old addresses there, and would
   * then send them to a 404. The switch-over is cancelled on biketeam instead (docs/LEDGER_*.md
   * MIG-5).
   */
  MIGRATED_TEAM,
  ALREADY_REGISTERED,
  NOT_REGISTERED,
  INVALID_SLUG,
  SLUG_TAKEN,
  USER_NOT_SYNCED,
  GROUP_FULL,
  RIDE_PAST,
  INVALID_VISIBILITY,
  PUBLIC_TRIP_PRIVATE_ROUTE,
  GPX_FAILURE,
  FILE_REQUIRED,
  FILE_TYPE_REJECTED,
  FILE_DETECTION_FAILED,
  FILE_TOO_LARGE,
  TOO_MANY_TEAM_PAGES,
  GPX_EMPTY,
  /** The tracks of a GPX add up to more than GpxLimits.MAX_TRACK_DISTANCE_METERS (SEC-6). */
  GPX_TOO_LONG,
  /** A GPX merge got fewer than GpxLimits.MIN_MERGE_FILES or more than MAX_MERGE_FILES files. */
  GPX_MERGE_FILE_COUNT,
  /** The files of a GPX merge hold more than GpxLimits.MAX_MERGE_TRACKS tracks together. */
  GPX_MERGE_TOO_MANY_TRACKS,
  ROUTE_PLANNER_DISABLED,
  /** The planner state of a request is malformed, out of bounds or sent with points — HTTP 400. */
  PLANNER_STATE_INVALID,
  /** The routing provider's monthly quota is spent (Stadia Maps answered 429) — HTTP 503. */
  ROUTING_QUOTA_EXCEEDED,
  /** The two points are further apart than the provider routes (Valhalla code 154) — HTTP 400. */
  ROUTING_SEGMENT_TOO_LONG,
  /** No path between the two points, or no road near one of them — HTTP 400. */
  ROUTING_NO_ROUTE,
  /** The routing provider failed, timed out or could not be reached — HTTP 503. */
  ROUTING_UNAVAILABLE,
  /**
   * The geocoder failed, timed out, could not be reached or its quota is spent, while resolving the
   * position of a picked place (GET /api/geocode/place) — HTTP 503.
   */
  GEOCODING_UNAVAILABLE,
  INVALID_FORMAT,
  INVALID_TIMEZONE,
  RENTAL_PERIOD_MISSING,
  STATUS_INVALID,
  PUBLIC_RIDE_PRIVATE_ROUTE,
  // Auth errors
  INVALID_CREDENTIALS,
  /** Too many wrong passwords lately for this address (SEC-7). */
  LOGIN_RATE_LIMITED,
  EMAIL_NOT_VERIFIED,
  EMAIL_ALREADY_EXISTS,
  TOKEN_INVALID,
  TOKEN_EXPIRED,
  SESSION_EXPIRED,
  PASSWORD_NOT_SET,
  PASSKEY_NOT_FOUND,
  USER_NOT_FOUND,
  DOMAIN_NOT_FOUND,
  TEAM_NOT_FOUND,
  TEAM_CREATION_DISABLED,
  USER_TEAM_LIMIT_REACHED,
  TEAM_JOIN_NOT_ALLOWED,
  TEAM_ADD_MEMBER_NOT_ALLOWED,
  // GPS service errors
  GPS_SERVICE_ALREADY_CONNECTED,
  GPS_SERVICE_NOT_CONNECTED,
  GPS_SERVICE_NOT_CONFIGURED,
  GPS_INVALID_STATE,
  GPS_STATE_EXPIRED,
  GPX_NOT_FOUND,
  // Device code flow errors (RFC 8628)
  AUTHORIZATION_PENDING,
  /** Too many unknown pairing codes lately, on this account or on the whole domain (SEC-4). */
  DEVICE_CODE_RATE_LIMITED,
  // Admin errors
  GPS_CREDENTIAL_ALREADY_EXISTS,
  /** OAuth 1.0a asked for a service other than Garmin (docs/LEDGER_*.md API-62). */
  GPS_OAUTH_VERSION_NOT_SUPPORTED,
  /** An OAuth 1.0a credential without its consumer secret, which signs every request. */
  GPS_CLIENT_SECRET_REQUIRED,
  GPS_TOKEN_EXCHANGE_FAILED,
  ENCRYPTION_FAILED,
  DECRYPTION_FAILED,
  // Domain alias errors
  DOMAIN_ALIAS_NOT_FOUND,
  DOMAIN_ALIAS_HOSTNAME_EXISTS,
  DOMAIN_ALIAS_TEAM_MISMATCH,
  // GDPR data export errors
  EXPORT_IN_PROGRESS,
  EXPORT_RATE_LIMITED,
  // Ride groups
  RIDE_GROUP_LEADER_NOT_MEMBER,
  // Classified-ad contact relay
  AD_CONTACT_SELF,
  AD_CONTACT_OPTED_OUT,
  AD_CONTACT_RATE_LIMITED,
  AD_CONTACT_DELIVERY_FAILED,
  EMAIL_NOT_SENT,
  // In-app feedback
  FEEDBACK_RATE_LIMITED,
  // Team invitations
  TEAM_INVITE_INVALID,
  TEAM_INVITE_EXPIRED,
  TEAM_INVITE_REVOKED,
  TEAM_INVITE_ALREADY_USED,
  TEAM_INVITE_ALREADY_MEMBER,
  TEAM_INVITE_EMAIL_MISMATCH,
  TEAM_INVITE_SELF,
  TEAM_INVITE_NOT_PENDING,
  TEAM_INVITE_RATE_LIMITED,
  TEAM_INVITE_DELIVERY_FAILED,
  // Team webhook
  /** Not an https URL, or one that points at a private or local address. */
  WEBHOOK_URL_INVALID,
  // Reporting and blocking
  /** A member reported themselves, or their own content. */
  REPORT_SELF,
  /** A member tried to block themselves. */
  BLOCK_SELF,
  /** A text failed the publication filter (see TextFilter). */
  CONTENT_REJECTED,
  // Team tags (docs/LEDGER_*.md API-59)
  /** A tag label is empty once trimmed, or longer than 32 characters. */
  TAG_LABEL_INVALID,
  /** Another tag of the same team and kind already has this label, whatever the case. */
  TAG_LABEL_TAKEN,
  /** The team already has 100 tags of this kind. */
  TAG_LIMIT_REACHED,
  /** A tag id of a content is unknown, of another team, or of another kind of content. */
  TAG_INVALID,
  /** More than 10 tags on one content. */
  TOO_MANY_TAGS,
  // Assets (docs/LEDGER_*.md API-68)
  /**
   * A content cites an asset it cannot take: unknown, of another team, or already attached to
   * another content — one answer for all three, so it reveals nothing of who holds the asset.
   */
  ASSET_NOT_AVAILABLE,
  // Biketeam live migration (docs/plans/2026-09-22-biketeam-live-migration.md)
  /** The signed biketeam request is malformed, forged, or not for this site. */
  BIKETEAM_REQUEST_INVALID,
  /** The signed biketeam request is past its expiry: start again from biketeam. */
  BIKETEAM_REQUEST_EXPIRED,
  /** The request was already redeemed, or confirmed by someone else. */
  BIKETEAM_REQUEST_ALREADY_USED,
  /** The target slug belongs to a Pédalons team that did not come from this biketeam team. */
  BIKETEAM_SLUG_CONFLICT,
  /** This biketeam team was already migrated to another domain of this platform. */
  BIKETEAM_MIGRATED_IN_OTHER_DOMAIN,
  /** The team exists on Pédalons and the caller does not administer it. */
  BIKETEAM_NOT_TEAM_ADMIN,
  /** A migration of this biketeam team is queued or running. */
  BIKETEAM_MIGRATION_RUNNING,
  /** A reset would trash a team a domain alias is pinned on. */
  BIKETEAM_RESET_BLOCKED,
  /** M2M only: unknown grant, or one that does not match the request it is presented with. */
  BIKETEAM_GRANT_INVALID,
  /** M2M only: the grant lapsed before biketeam redeemed it. */
  BIKETEAM_GRANT_EXPIRED,
  /**
   * M2M only: no such job — unknown id, or a request that was never triggered. The only 404 biketeam
   * takes as the job being lost; any other 404 (proxy, restart) is transient.
   */
  BIKETEAM_JOB_NOT_FOUND
}
