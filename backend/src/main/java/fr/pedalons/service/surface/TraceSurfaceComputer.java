package fr.pedalons.service.surface;

import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import fr.pedalons.infrastructure.valhalla.TraceAttributesClient;
import fr.pedalons.infrastructure.valhalla.TraceAttributesRequest;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.Edge;
import fr.pedalons.infrastructure.valhalla.ValhallaErrors;
import fr.pedalons.service.surface.TraceSurfaceProjection.Range;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.function.Function;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jspecify.annotations.Nullable;

/**
 * Computes the surface along a saved track with the trace attributes of osm-surface
 * (docs/LEDGER_*.md WEB-100, C1b, and OPS-57; the Stadia Maps trials it was designed on in
 * docs/research/2026-10-19-stadia-surfaces.md): the track is sent in
 * {@code map_snap} mode, in slices when it exceeds what one request accepts, and the answers are
 * projected back onto the stored points ({@link TraceSurfaceProjection}).
 *
 * <p>Called by the surface worker only, never during an HTTP request. A slice the provider
 * definitively cannot match (sea, nothing to snap to) is unknown on its own: a ferry does not
 * spoil the rest of the track. Any other failure fails the whole track, for a retry later, and
 * nothing is stored.
 */
@ApplicationScoped
public class TraceSurfaceComputer {

  /** Under the measured 200 km limit of a request (205 km answered 154). */
  static final double MAX_REQUEST_M = 190_000;

  /** Sent on each side of a slice's core: the matching settles at the edges, 100 % agreement with one call. */
  static final double OVERLAP_M = 500;

  /** What a slice answers for: the request less both overlaps, less room for the point spacing. */
  static final double CORE_M = MAX_REQUEST_M - 2 * OVERLAP_M - 1_000;

  /** Under the measured 16 000 points of a request (16 100 answered 153). */
  static final int MAX_POINTS = 15_000;

  /** A track shorter than this has nothing to match. */
  static final double MIN_LENGTH_M = 1;

  /** Valhalla 400s that no retry changes: no route, nothing to snap to, the distance limit. */
  static final Set<Integer> DEFINITIVE_CODES = Set.of(123, 171, 443, 444, 154);

  private static final String BICYCLE = "bicycle";

  /** The use and cycle lane of a way: the pair stored per range. */
  private record Way(@Nullable String use, @Nullable String cycleLane) {
    static final Way UNKNOWN = new Way(null, null);
  }

  /** The provider failed in a way that a later attempt may not: the whole track is retried. */
  public static class TransientTraceException extends RuntimeException {
    public TransientTraceException(String message) {
      super(message);
    }
  }

  @Inject @RestClient TraceAttributesClient client;

  /** The costing of a track, from the profile of its planner state (none: it was sent as a file). */
  public static String costingOf(@Nullable RouterProfile profile) {
    if (profile == null) {
      return BICYCLE;
    }
    return switch (profile) {
      case RUN_HIKE -> "pedestrian";
      case MOTORCYCLE -> "auto";
      default -> BICYCLE;
    };
  }

  /**
   * One track's surface.
   *
   * @param offNetwork {@code [from, to]} metres along the track of its straight pieces
   * @throws TransientTraceException when the provider failed otherwise than definitively
   */
  public TrackSurfaceDocument compute(
      List<TrackPoint> points, String costing, List<double[]> offNetwork, Instant now) {
    return compute(points, costing, offNetwork, now, client::traceAttributes);
  }

  static TrackSurfaceDocument compute(
      List<TrackPoint> points,
      String costing,
      List<double[]> offNetwork,
      Instant now,
      Function<TraceAttributesRequest, TraceAttributesResponse> call) {
    int n = points.size();
    double length = n == 0 ? 0 : points.getLast().dist();
    if (n < 2 || length < MIN_LENGTH_M) {
      return TrackSurfaceDocument.unavailable("too-short", length, costing, now);
    }
    double[] dist = new double[n];
    double[] lat = new double[n];
    double[] lon = new double[n];
    for (int i = 0; i < n; i++) {
      TrackPoint p = points.get(i);
      dist[i] = p.dist();
      lat[i] = p.lat();
      lon[i] = p.lng();
    }

    List<Range<String>> surfaces = new ArrayList<>();
    List<Range<Way>> ways = new ArrayList<>();
    Long changeset = null;
    int slices = 0;
    int definitive = 0;
    int firstDefinitiveCode = -1;
    double start = 0;
    while (start < length) {
      double end = Math.min(length, start + CORE_M);
      int i0 = lastAtOrBefore(dist, Math.max(0, start - OVERLAP_M));
      int i1 = firstAtOrAfter(dist, Math.min(length, end + OVERLAP_M));
      if (i1 - i0 + 1 > MAX_POINTS) {
        i1 = i0 + MAX_POINTS - 1;
        end = Math.max(start + (dist[i1] - start) / 2, dist[i1] - OVERLAP_M);
        end = Math.max(end, Math.min(length, start + 1));
      }
      slices++;
      TraceAttributesRequest request =
          TraceAttributesRequest.of(Polyline6Encoder.encode(lat, lon, i0, i1), costing);
      TraceAttributesResponse response = null;
      try {
        response = call.apply(request);
      } catch (WebApplicationException e) {
        int status = e.getResponse().getStatus();
        int code = ValhallaErrors.errorCode(e.getResponse());
        if (status == 400 && DEFINITIVE_CODES.contains(code)) {
          definitive++;
          if (firstDefinitiveCode < 0) {
            firstDefinitiveCode = code;
          }
        } else {
          throw new TransientTraceException(
              "osm-surface trace attributes failed, status " + status + ", error_code " + code);
        }
      } catch (ProcessingException e) {
        throw new TransientTraceException(
            "osm-surface trace attributes unreachable: " + e.getClass().getSimpleName());
      }
      if (response == null) {
        surfaces.add(new Range<>(start, end, TrackSurfaceDocument.UNKNOWN));
        ways.add(new Range<>(start, end, Way.UNKNOWN));
      } else {
        double[] d = new double[i1 - i0 + 1];
        for (int k = 0; k < d.length; k++) {
          d[k] = dist[i0 + k] - dist[i0];
        }
        surfaces.addAll(
            clip(TraceSurfaceProjection.project(d, response, Edge::surface), dist[i0], start, end));
        ways.addAll(
            clip(
                TraceSurfaceProjection.project(d, response, e -> new Way(e.use(), e.cycleLane())),
                dist[i0],
                start,
                end));
        if (changeset == null) {
          changeset = response.osmChangeset();
        }
      }
      start = end;
    }
    if (definitive == slices) {
      return TrackSurfaceDocument.unavailable(
          "valhalla-" + firstDefinitiveCode, length, costing, now);
    }

    List<Range<String>> surfaceCover =
        SurfaceRanges.normalize(
            SurfaceRanges.overlay(
                unknownFor(surfaces, TrackSurfaceDocument.UNKNOWN),
                offNetwork,
                TrackSurfaceDocument.OFF_NETWORK),
            length,
            TrackSurfaceDocument.UNKNOWN);
    List<Range<Way>> wayCover =
        SurfaceRanges.normalize(
            SurfaceRanges.overlay(
                unknownFor(ways, Way.UNKNOWN),
                offNetwork,
                new Way(TrackSurfaceDocument.OFF_NETWORK, null)),
            length,
            Way.UNKNOWN);
    return new TrackSurfaceDocument(
        TrackSurfaceDocument.VERSION,
        TrackSurfaceDocument.STATUS_OK,
        null,
        changeset,
        now,
        costing,
        length,
        surfaceCover.stream().map(r -> new SurfaceRange(r.from(), r.to(), r.value())).toList(),
        wayCover.stream()
            .map(r -> new WayRange(r.from(), r.to(), r.value().use(), r.value().cycleLane()))
            .toList());
  }

  /** The ranges with the stretches the matching left without a value given {@code unknown}. */
  private static <V> List<Range<V>> unknownFor(List<Range<V>> ranges, V unknown) {
    List<Range<V>> out = new ArrayList<>(ranges.size());
    for (Range<V> r : ranges) {
      out.add(r.value() == null ? new Range<>(r.from(), r.to(), unknown) : r);
    }
    return out;
  }

  /** A slice's ranges moved by {@code shift} onto the track and cut to its core {@code [from, to]}. */
  private static <V> List<Range<V>> clip(
      List<Range<V>> ranges, double shift, double from, double to) {
    List<Range<V>> out = new ArrayList<>(ranges.size());
    for (Range<V> r : ranges) {
      double a = Math.max(from, r.from() + shift);
      double b = Math.min(to, r.to() + shift);
      if (b > a) {
        out.add(new Range<>(a, b, r.value()));
      }
    }
    return out;
  }

  /** The last index whose distance is at most {@code d} (the first when none is). */
  private static int lastAtOrBefore(double[] dist, double d) {
    int lo = 0;
    int hi = dist.length - 1;
    int found = 0;
    while (lo <= hi) {
      int mid = (lo + hi) >>> 1;
      if (dist[mid] <= d) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  /** The first index whose distance is at least {@code d} (the last when none is). */
  private static int firstAtOrAfter(double[] dist, double d) {
    int lo = 0;
    int hi = dist.length - 1;
    int found = dist.length - 1;
    while (lo <= hi) {
      int mid = (lo + hi) >>> 1;
      if (dist[mid] >= d) {
        found = mid;
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
    return found;
  }
}
