package fr.pedalons.enums;

/** Why the retouch is not offered for a route to the caller. */
public enum RouteRetouchUnavailable {
  /** The caller may not plan routes in the team (rights, planner off, route removed). */
  NOT_ALLOWED,
  /** The generator is off, or the engine does not announce route edits. */
  ENGINE_UNAVAILABLE,
  /** The route's street edges are missing or older than its track. */
  NOT_READY,
  /** The route cannot be retouched whatever the time. */
  UNSUPPORTED
}
