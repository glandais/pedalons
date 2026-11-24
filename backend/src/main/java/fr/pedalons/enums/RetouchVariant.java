package fr.pedalons.enums;

/** Which choice a retouched route that moves the finish makes. */
public enum RetouchVariant {
  /** The smallest change. */
  BEST,
  /** The whole route, then the way to the new finish. */
  KEEP_ALL,
  /** Leave the route where it comes closest to the new finish. */
  NEAREST
}
