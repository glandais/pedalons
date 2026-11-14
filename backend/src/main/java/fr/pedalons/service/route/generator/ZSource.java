package fr.pedalons.service.route.generator;

/** Which familiarity array to read: all kinds together, or one ride type's. */
public enum ZSource {
  ALL,
  ROAD,
  GRAVEL,
  MTB;

  static ZSource of(RideType type) {
    return switch (type) {
      case ROAD -> ROAD;
      case GRAVEL -> GRAVEL;
      case MTB -> MTB;
    };
  }
}
