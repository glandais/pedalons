package fr.pedalons.service.route.network;

import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.service.route.generator.Access;
import fr.pedalons.service.route.generator.EdgeSurface;
import fr.pedalons.service.route.generator.LatLon;
import fr.pedalons.service.route.generator.NodeRef;
import fr.pedalons.service.route.generator.Oneway;
import fr.pedalons.service.route.generator.OsmTrackType;
import fr.pedalons.service.route.generator.SurfaceClass;
import fr.pedalons.service.route.generator.SurfaceSource;
import fr.pedalons.service.route.generator.TrackEdge;
import fr.pedalons.service.route.generator.TrackInput;
import fr.pedalons.service.route.generator.TrackKind;
import fr.pedalons.service.route.generator.WayKind;
import fr.pedalons.service.route.planner.PolylineCodec;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * Maps the stored {@link NetworkEdgesDocument} of a track to the engine's {@link TrackInput}
 * (ledger docs/LEDGER_*.md API-198, lot 3 plan §1; rules of the lot 2 design §12.1).
 *
 * <p>Pure, and one instance per build: it holds the intern tables, so that a complete edge ridden
 * by hundreds of routes is held once (geometry shared by its encoded string, node by its id).
 * Unknown values never throw; an edge that cannot be used is dropped and counted, never the track.
 */
public final class TrackInputMapper {
  private final int maxPointsPerEdge;
  private final Map<String, NodeRef> nodes = new HashMap<>();
  private final Map<String, List<LatLon>> geometries = new HashMap<>();
  private int droppedEdges;
  private long distinctPoints;

  public TrackInputMapper(int maxPointsPerEdge) {
    this.maxPointsPerEdge = maxPointsPerEdge;
  }

  /** {@code Route.surfaceType} mapped one to one; null (an old row) is {@code MIXED}. */
  public static TrackKind kindOf(@Nullable String surfaceType) {
    if (surfaceType == null) {
      return TrackKind.MIXED;
    }
    try {
      return TrackKind.valueOf(surfaceType);
    } catch (IllegalArgumentException e) {
      return TrackKind.MIXED;
    }
  }

  public TrackInput map(long trackId, boolean excluded, TrackKind kind, NetworkEdgesDocument doc) {
    List<NetworkEdgesDocument.Node> docNodes = doc.nodes();
    List<TrackEdge> out = new ArrayList<>(doc.edges().size());
    for (NetworkEdgesDocument.Edge e : doc.edges()) {
      TrackEdge mapped = mapEdge(e, docNodes);
      if (mapped == null) {
        droppedEdges++;
      } else {
        out.add(mapped);
      }
    }
    return new TrackInput(trackId, excluded, kind, out);
  }

  /** Edges dropped so far (negative length, undecodable or absent geometry). */
  public int droppedEdges() {
    return droppedEdges;
  }

  /** Points held in the shared geometries, for the cache weigher. */
  public long distinctPoints() {
    return distinctPoints;
  }

  private @Nullable TrackEdge mapEdge(
      NetworkEdgesDocument.Edge e, List<NetworkEdgesDocument.Node> docNodes) {
    if (!Double.isFinite(e.trv()) || e.trv() < 0) {
      return null;
    }
    List<LatLon> geometry = geometry(e.g());
    if (geometry == null) {
      return null;
    }
    return new TrackEdge(
        node(e.fn(), docNodes),
        node(e.tn(), docNodes),
        e.p(),
        e.len(),
        e.trv(),
        e.fo(),
        e.to(),
        oneway(e.ow()),
        geometry,
        e.tg() - e.fg(),
        e.tl() - e.fl(),
        surface(e),
        wayKind(e.wk()),
        trackType(e.tt()),
        access(e.bi()),
        access(e.ft()));
  }

  private @Nullable NodeRef node(
      @Nullable Integer index, List<NetworkEdgesDocument.Node> docNodes) {
    if (index == null || index < 0 || index >= docNodes.size()) {
      return null;
    }
    NetworkEdgesDocument.Node n = docNodes.get(index);
    return nodes.computeIfAbsent(
        n.id(), id -> new NodeRef(id, new LatLon(n.lat(), n.lon()), n.degree()));
  }

  private @Nullable List<LatLon> geometry(@Nullable String encoded) {
    if (encoded == null || encoded.isEmpty()) {
      return null;
    }
    List<LatLon> known = geometries.get(encoded);
    if (known != null) {
      return known;
    }
    double[][] pts;
    try {
      pts = PolylineCodec.decode2Within(encoded, maxPointsPerEdge);
    } catch (RuntimeException ex) {
      return null;
    }
    if (pts == null || pts.length < 2) {
      return null;
    }
    LatLon[] latLons = new LatLon[pts.length];
    for (int i = 0; i < pts.length; i++) {
      latLons[i] = new LatLon(pts[i][1], pts[i][0]);
    }
    // List.of(array) is an immutable list: TrackEdge's List.copyOf returns this very instance
    List<LatLon> shared = List.of(latLons);
    geometries.put(encoded, shared);
    distinctPoints += latLons.length;
    return shared;
  }

  private static Oneway oneway(@Nullable String ow) {
    if (ow == null) {
      return Oneway.FORWARD;
    }
    return switch (ow) {
      case "both" -> Oneway.BOTH;
      case "against" -> Oneway.AGAINST;
      default -> Oneway.FORWARD;
    };
  }

  private static @Nullable EdgeSurface surface(NetworkEdgesDocument.Edge e) {
    if (e.sc() == null) {
      return null;
    }
    SurfaceClass cls =
        switch (e.sc()) {
          case "paved" -> SurfaceClass.PAVED;
          case "unpaved" -> SurfaceClass.UNPAVED;
          default -> SurfaceClass.UNKNOWN;
        };
    String detail = e.sd() == null ? null : e.sd().toLowerCase(Locale.ROOT);
    SurfaceSource source =
        e.ss() == null
            ? SurfaceSource.NONE
            : switch (e.ss()) {
              case "tagged" -> SurfaceSource.TAGGED;
              case "inferred_tracktype" -> SurfaceSource.INFERRED_TRACKTYPE;
              case "inferred_highway" -> SurfaceSource.INFERRED_HIGHWAY;
              default -> SurfaceSource.NONE;
            };
    return new EdgeSurface(cls, detail, source);
  }

  private static @Nullable WayKind wayKind(@Nullable String wk) {
    if (wk == null) {
      return null;
    }
    try {
      return WayKind.valueOf(wk.toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException ex) {
      return WayKind.UNKNOWN;
    }
  }

  private static @Nullable OsmTrackType trackType(@Nullable String tt) {
    if (tt == null) {
      return null;
    }
    try {
      return OsmTrackType.valueOf(tt.toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException ex) {
      return null;
    }
  }

  private static @Nullable Access access(@Nullable String value) {
    if (value == null) {
      return null;
    }
    try {
      return Access.valueOf(value.toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException ex) {
      return null;
    }
  }
}
