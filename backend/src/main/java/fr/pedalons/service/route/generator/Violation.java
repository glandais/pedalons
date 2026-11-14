package fr.pedalons.service.route.generator;

/** A hard guarantee (plan §2) a route can break; see {@link RouteGuarantees}. */
public enum Violation {
  EMPTY,
  WRONG_START,
  WRONG_END,
  DISCONTINUOUS,
  NOT_ON_NETWORK,
  ONE_WAY,
  U_TURN,
  SHARP_TURN,
  DEAD_END,
  EDGE_USED_MORE_THAN_TWICE,
  REUSE_OUTSIDE_TAIL,
  TAIL_TOO_LONG,
  TOO_MANY_CROSSINGS,
  CORRIDOR_DOUBLED,
  DISTANCE_OUT_OF_TOLERANCE
}
