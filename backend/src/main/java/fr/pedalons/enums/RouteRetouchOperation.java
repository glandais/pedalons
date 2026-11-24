package fr.pedalons.enums;

/** What a retouch of a saved route does (docs/plans/2026-11-24-retouche-parcours-lot7c.md). */
public enum RouteRetouchOperation {
  /** Aim at a total distance by replacing one stretch of the route. */
  RESIZE,
  /** Keep the route up to a junction, then lead to a new finish. */
  MOVE_END
}
