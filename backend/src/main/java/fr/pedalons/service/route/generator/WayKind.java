package fr.pedalons.service.route.generator;

/** osm-route-details {@code way_kind}; the order is the code stored by the graph. */
public enum WayKind {
  MAJOR_ROAD,
  MINOR_ROAD,
  TRACK,
  PATH,
  CYCLEWAY,
  FOOTWAY,
  STEPS,
  UNKNOWN
}
