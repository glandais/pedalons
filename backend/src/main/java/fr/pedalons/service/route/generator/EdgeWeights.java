package fr.pedalons.service.route.generator;

import java.util.BitSet;

/**
 * Search weight of every directed state for one request (design §5.3 and §12.7):
 *
 * <pre>length × exp(β · (1 − 2f) · z) × (1 + pJ) × preference(type)</pre>
 *
 * <p>f = 1 makes popular edges (z → 1) cheaper by up to e^β, f = 0 the opposite, f = 0.5 is
 * neutral. The junction term makes a route made of many short edges cost more, a readable route
 * turns little. The preference multiplier favours the surface the ride type wants. Both directions
 * of an edge weigh the same: direction is handled by {@code allowed}. A virtual split piece reads
 * its parent's familiarity and attributes through the query graph and its own length.
 */
final class EdgeWeights {
  private EdgeWeights() {}

  static double[] build(
      QueryGraph g, GeneratorParameters p, double familiarity, RideType type, ZSource source) {
    double[] w = new double[g.stateCount()];
    double exponent = p.beta() * (1 - 2 * familiarity);
    for (int e = 0; e < g.edgeCount(); e++) {
      double len = g.length(e);
      double junction = len <= 0 ? 0 : p.junctionPenalty() * Math.min(1, p.junctionRefM() / len);
      double value =
          len * Math.exp(exponent * g.z(e, source)) * (1 + junction) * preference(g, p, type, e);
      w[2 * e] = value;
      w[2 * e + 1] = value;
    }
    return w;
  }

  /** Plain lengths, for the searches that count metres. */
  static double[] lengths(QueryGraph g) {
    double[] w = new double[g.stateCount()];
    for (int e = 0; e < g.edgeCount(); e++) {
      w[2 * e] = g.length(e);
      w[2 * e + 1] = g.length(e);
    }
    return w;
  }

  // ---- admission and preference (§12.7) ---------------------------------------------------------

  /** {@code way_kind}, with a path or footway that bicycles may use read as a cycleway (api 1.8). */
  static WayKind kindEff(QueryGraph g, int e) {
    WayKind k = g.wayKind(e);
    if ((k == WayKind.PATH || k == WayKind.FOOTWAY) && g.bicycle(e) == Access.YES) {
      return WayKind.CYCLEWAY;
    }
    return k;
  }

  /** Edge ridden by at least one live track of one of the kinds. */
  static boolean by(QueryGraph g, int e, TrackKind... kinds) {
    for (TrackKind k : kinds) {
      if (g.supportByKind(e, k) > 0) {
        return true;
      }
    }
    return false;
  }

  static boolean rollingUnpaved(QueryGraph g, int e) {
    if (g.surfaceClass(e) == SurfaceClass.PAVED) {
      return false;
    }
    String d = g.surfaceDetail(e);
    OsmTrackType t = g.trackType(e);
    return "compacted".equals(d)
        || "fine_gravel".equals(d)
        || "gravel".equals(d)
        || t == OsmTrackType.GRADE1
        || t == OsmTrackType.GRADE2
        || t == OsmTrackType.GRADE3;
  }

  static boolean roughUnpaved(QueryGraph g, int e) {
    String d = g.surfaceDetail(e);
    OsmTrackType t = g.trackType(e);
    return "dirt".equals(d)
        || "sand".equals(d)
        || "grass".equals(d)
        || "rock".equals(d)
        || "wood".equals(d)
        || t == OsmTrackType.GRADE4
        || t == OsmTrackType.GRADE5;
  }

  /** Is the (base) edge admitted for the ride type? Hard rule. */
  static boolean admitted(QueryGraph g, int e, RideType type) {
    WayKind k = kindEff(g, e);
    boolean forbidden = g.bicycle(e) == Access.NO;
    switch (type) {
      case ROAD:
        {
          SurfaceClass sc = g.surfaceClass(e);
          if (k == WayKind.PATH
              || k == WayKind.FOOTWAY
              || k == WayKind.STEPS
              || sc == SurfaceClass.UNPAVED
              || forbidden) {
            return false;
          }
          if ((k == WayKind.MAJOR_ROAD || k == WayKind.MINOR_ROAD || k == WayKind.CYCLEWAY)
              && sc == SurfaceClass.PAVED) {
            return true;
          }
          return by(g, e, TrackKind.ROAD);
        }
      case GRAVEL:
        if (k == WayKind.STEPS) {
          return false;
        }
        if (k == WayKind.PATH || k == WayKind.FOOTWAY || roughUnpaved(g, e) || forbidden) {
          return by(g, e, TrackKind.GRAVEL, TrackKind.MIXED);
        }
        return true;
      case MTB:
      default:
        if (k == WayKind.STEPS || forbidden) {
          return by(g, e, TrackKind.MTB);
        }
        return true;
    }
  }

  /** Multiplier of the weight for the ride type (1 = neutral). */
  static double preference(QueryGraph g, GeneratorParameters p, RideType type, int e) {
    WayKind k = kindEff(g, e);
    SurfaceClass sc = g.surfaceClass(e);
    switch (type) {
      case ROAD:
        {
          boolean sure =
              (k == WayKind.MAJOR_ROAD || k == WayKind.MINOR_ROAD || k == WayKind.CYCLEWAY)
                  && sc == SurfaceClass.PAVED;
          return sure ? 1 : p.roadUncertainFactor();
        }
      case GRAVEL:
        if (rollingUnpaved(g, e) || (k == WayKind.TRACK && sc != SurfaceClass.PAVED)) {
          return p.gravelUnpavedFactor();
        }
        if (k == WayKind.MAJOR_ROAD && sc == SurfaceClass.PAVED) {
          return p.gravelMajorRoadFactor();
        }
        return 1;
      case MTB:
      default:
        if (sc == SurfaceClass.UNPAVED || k == WayKind.PATH || k == WayKind.TRACK) {
          return p.mtbOffroadFactor();
        }
        if (k == WayKind.MAJOR_ROAD) {
          return p.mtbMajorRoadFactor();
        }
        return 1;
    }
  }

  /**
   * Edges the ride type forbids outright. {@link Snapper} prefers an admitted edge, so a start or
   * an end ({@code keep}) lies on a forbidden edge only when no admitted edge is
   * within reach; then the one piece that leads on stays allowed (an end node that is no dead end
   * and has an admitted edge; the shorter piece when both lead on or neither does): the place has
   * no other way out, and refusing it would report the network as too small. The other piece stays
   * banned, so the forbidden stretch is one piece of that edge, at most the whole of it. A start that
   * snapped onto a base node whose every edge is forbidden (the dead end of a footway spur) is handled
   * the same way: the edge that leads on is freed.
   */
  static BitSet banned(QueryGraph g, RideType type, int... keep) {
    BitSet banned = new BitSet(g.edgeCount());
    for (int e = 0; e < g.edgeCount(); e++) {
      if (!g.isMasked(e) && !admitted(g, e, type)) {
        banned.set(e);
      }
    }
    for (int node : keep) {
      boolean virtual = node >= g.base().nodeCount();
      if (!virtual && !allBanned(g, node, banned)) {
        continue;
      }
      int chosen = -1;
      boolean chosenGood = false;
      for (int i = 0; i < g.outCount(node); i++) {
        int state = g.outState(node, i);
        int piece = state >>> 1;
        boolean good = leadsOn(g, type, g.head(state), piece);
        boolean better =
            chosen < 0
                || (good && !chosenGood)
                || (good == chosenGood && g.length(piece) < g.length(chosen));
        if (better) {
          chosen = piece;
          chosenGood = good;
        }
      }
      if (chosen >= 0) {
        banned.clear(chosen);
      }
    }
    return banned;
  }

  /**
   * A base node every edge of which is banned: a start that snapped onto it (within the snap-to-node
   * distance of the end of a forbidden edge) has no other way out either (design 12.13).
   */
  private static boolean allBanned(QueryGraph g, int node, BitSet banned) {
    if (g.outCount(node) == 0) {
      return false;
    }
    for (int i = 0; i < g.outCount(node); i++) {
      if (!banned.get(g.outState(node, i) >>> 1)) {
        return false;
      }
    }
    return true;
  }

  /**
   * Does the far end of a piece lead on: not a dangling end, and another edge the ride type admits
   * leaves it? A piece that ends in a dead end of the forbidden kind is no way out (design 12.13).
   */
  private static boolean leadsOn(QueryGraph g, RideType type, int far, int piece) {
    if (g.dangling(far)) {
      return false;
    }
    for (int i = 0; i < g.outCount(far); i++) {
      int e = g.outState(far, i) >>> 1;
      if (e != piece && !g.isMasked(e) && admitted(g, e, type)) {
        return true;
      }
    }
    return false;
  }

  /** Does the edge carry the primary kinds of the type (familiarity, §12.7)? */
  static boolean primary(QueryGraph g, int e, RideType type) {
    return switch (type) {
      case ROAD -> by(g, e, TrackKind.ROAD, TrackKind.MIXED);
      case GRAVEL -> by(g, e, TrackKind.GRAVEL, TrackKind.MIXED);
      case MTB -> by(g, e, TrackKind.MTB);
    };
  }
}
