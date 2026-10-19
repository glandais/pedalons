package fr.pedalons.common.planner;

/** What a piece of a planner track is (docs/LEDGER_*.md WEB-100, C4a). */
public enum PlannerPieceMode {
  /** Routed by the router between its two junctions. */
  ROUTED,
  /** A straight line between its two junctions. */
  DIRECT,
  /** A range of a source track, never copied into the piece. */
  IMPORTED
}
