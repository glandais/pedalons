package fr.pedalons.dto.router.request;

/** An option of the engine of osm-route-details that the planner screen can offer. */
public enum RouterEngineOption {
  /** The traffic cursor ({@code useRoads}). */
  USE_ROADS,
  /** The switch that makes main roads cost more ({@code avoidMainRoads}). */
  AVOID_MAIN_ROADS
}
