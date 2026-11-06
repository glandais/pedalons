package fr.pedalons.service.surface;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import fr.pedalons.enums.TrackSurface;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Surface;
import fr.pedalons.service.surface.TraceSurfaceProjection.Range;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * From the typology of osm-route-details to a stored {@link TrackSurfaceDocument} of version 2
 * (docs/LEDGER_*.md API-150): the projection of its surfaces on the classes of the contract, the
 * one place the table of the plan (§5.2, decision D6) lives, and its segments carried onto the
 * stored track. Pure.
 *
 * <p>The document stores the class each stretch was projected to, not the service's value, which
 * goes in {@code ways}: the previous release reads these codes as they are, so a rolling deploy or
 * a rollback serves those documents right, and the merging of short stretches works on what the
 * clients draw. The cost is that a change of the table re-projects from {@code ways}.
 */
public final class RouteDetailsSurfaces {

  /** The costing recorded in every document: the service matches as a bicycle (decision D3). */
  private static final String COSTING = "bicycle";

  /** A track shorter than this has nothing to match. */
  private static final double MIN_LENGTH_M = 1;

  static final String TOO_SHORT = "too-short";

  /** The service answered, and knows the surface of no stretch of the track. */
  static final String NO_TYPOLOGY = "no-typology";

  /** What is stored of a stretch beside its class: the service's own values. */
  private record Way(
      @Nullable String wayKind,
      @Nullable String structure,
      @Nullable Boolean matched,
      @Nullable String surfaceClass,
      @Nullable String detail) {

    static final Way UNKNOWN = new Way(null, null, null, null, null);
    static final Way OFF_NETWORK =
        new Way(TrackSurfaceDocument.OFF_NETWORK, null, null, null, null);
  }

  private RouteDetailsSurfaces() {}

  /**
   * The class of a stretch, from {@code surface.detail} when the service gave one it knows, else
   * from {@code surface.class} and the way kind. The list of details is open: an unknown one falls
   * back on the class. {@code matched} plays no part: a way closed to bicycles ({@code matched:
   * false} with a typology, api 1.1) keeps the surface of that way, and without a typology the class
   * is {@code unknown}.
   */
  static TrackSurface project(@Nullable Surface surface, @Nullable String wayKind) {
    if (surface == null) {
      return TrackSurface.UNKNOWN;
    }
    if (surface.detail() != null) {
      switch (surface.detail()) {
        case "asphalt", "concrete", "paving_stones", "wood" -> {
          return TrackSurface.PAVED;
        }
        case "sett", "cobblestone" -> {
          return TrackSurface.PAVED_ROUGH;
        }
        case "compacted", "fine_gravel", "gravel" -> {
          return TrackSurface.GRAVEL;
        }
        case "dirt", "sand", "grass" -> {
          return TrackSurface.DIRT;
        }
        case "rock" -> {
          return TrackSurface.PATH;
        }
        default -> {
          // A value of a later release of the service: its class says enough
        }
      }
    }
    return switch (surface.surfaceClass()) {
      case "paved" -> TrackSurface.PAVED;
      case "unpaved" -> isTrail(wayKind) ? TrackSurface.PATH : TrackSurface.GRAVEL;
      case null, default -> TrackSurface.UNKNOWN;
    };
  }

  private static boolean isTrail(@Nullable String wayKind) {
    return "path".equals(wayKind) || "footway".equals(wayKind) || "steps".equals(wayKind);
  }

  /**
   * The document of one track.
   *
   * @param offNetwork {@code [from, to]} metres along the stored track of its straight pieces
   */
  public static TrackSurfaceDocument document(
      RouteSurfaceAnswer answer, List<double[]> offNetwork, Instant now) {
    double length = answer.storedLength();
    if (answer.segments().isEmpty() || length < MIN_LENGTH_M) {
      return unavailable(TOO_SHORT, length, now);
    }
    List<Range<String>> surfaces = new ArrayList<>(answer.segments().size());
    List<Range<Way>> ways = new ArrayList<>(answer.segments().size());
    for (Segment s : answer.segments()) {
      double from = toStored(s.fromM(), answer.answerM(), answer.storedM());
      double to = toStored(s.toM(), answer.answerM(), answer.storedM());
      if (to > from) {
        surfaces.add(new Range<>(from, to, project(s.surface(), s.wayKind()).code()));
        ways.add(new Range<>(from, to, wayOf(s)));
      }
    }
    // The straight pieces first, as for osm-surface: a fully drawn track has a surface to show
    List<Range<String>> surfaceCover =
        SurfaceRanges.normalize(
            SurfaceRanges.overlay(surfaces, offNetwork, TrackSurfaceDocument.OFF_NETWORK),
            length,
            TrackSurfaceDocument.UNKNOWN);
    if (surfaceCover.stream().allMatch(r -> TrackSurfaceDocument.UNKNOWN.equals(r.value()))) {
      return unavailable(NO_TYPOLOGY, length, now);
    }
    List<Range<Way>> wayCover =
        SurfaceRanges.normalize(
            SurfaceRanges.overlay(ways, offNetwork, Way.OFF_NETWORK), length, Way.UNKNOWN);
    return document(length, surfaceCover, wayCover, answer.dataVersions(), now);
  }

  private static TrackSurfaceDocument document(
      double length,
      List<Range<String>> surfaces,
      List<Range<Way>> ways,
      @Nullable JsonNode dataVersions,
      Instant now) {
    return new TrackSurfaceDocument(
        TrackSurfaceDocument.VERSION_ROUTE_DETAILS,
        TrackSurfaceDocument.STATUS_OK,
        null,
        null,
        now,
        COSTING,
        length,
        surfaces.stream().map(r -> new SurfaceRange(r.from(), r.to(), r.value())).toList(),
        ways.stream().map(RouteDetailsSurfaces::wayRange).toList(),
        dataVersions);
  }

  private static TrackSurfaceDocument unavailable(String reason, double length, Instant now) {
    return TrackSurfaceDocument.unavailable(
        TrackSurfaceDocument.VERSION_ROUTE_DETAILS, reason, length, COSTING, now);
  }

  private static Way wayOf(Segment s) {
    Surface surface = s.surface();
    return new Way(
        s.wayKind(),
        s.structure(),
        s.matched(),
        surface == null ? null : surface.surfaceClass(),
        surface == null ? null : surface.detail());
  }

  private static WayRange wayRange(Range<Way> r) {
    Way way = r.value() == null ? Way.UNKNOWN : r.value();
    return new WayRange(
        r.from(),
        r.to(),
        way.wayKind(),
        null,
        way.structure(),
        way.matched(),
        way.surfaceClass(),
        way.detail());
  }

  /**
   * A distance of the answer on the stored axis: linear between the two anchors around it, clamped
   * at the ends.
   *
   * @param answerM the anchors on the answer's axis, non-decreasing
   * @param storedM the same anchors on the stored axis
   */
  static double toStored(double d, double[] answerM, double[] storedM) {
    int last = answerM.length - 1;
    if (d <= answerM[0]) {
      return storedM[0];
    }
    if (d >= answerM[last]) {
      return storedM[last];
    }
    // Invariant: answerM[lo] <= d < answerM[hi]
    int lo = 0;
    int hi = last;
    while (hi - lo > 1) {
      int mid = (lo + hi) >>> 1;
      if (answerM[mid] <= d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    double t = (d - answerM[lo]) / (answerM[hi] - answerM[lo]);
    return storedM[lo] + (storedM[hi] - storedM[lo]) * t;
  }
}
