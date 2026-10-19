package fr.pedalons.common.planner;

/** What a junction between two pieces of a planner track is. */
public enum PlannerJunctionKind {
  /** A control point of the user. The first and the last junction are always one. */
  CONTROL,
  /** A join: a non-manual point where the nature of the track changes. */
  JOIN
}
