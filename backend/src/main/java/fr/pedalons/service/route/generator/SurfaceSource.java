package fr.pedalons.service.route.generator;

/** osm-route-details {@code surface.source}; {@code NONE} when nothing is known. */
public enum SurfaceSource {
  TAGGED,
  INFERRED_TRACKTYPE,
  INFERRED_HIGHWAY,
  NONE
}
