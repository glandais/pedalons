package fr.pedalons.dto.router.request;

/** The engine that calculates a leg of the planner. */
public enum RouterEngine {
  /** Stadia Maps (Valhalla): every profile; the default. */
  STADIA,
  /** The engine of osm-route-details: the four bicycle profiles, with the team's roads. */
  PEDALONS
}
