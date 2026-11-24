package fr.pedalons.enums;

/** What changed in a retouched route. */
public enum RetouchKind {
  SHORTEN,
  LENGTHEN,
  MOVE_END,
  /** The new finish lies on the route: it is cut there. */
  TRUNCATE
}
