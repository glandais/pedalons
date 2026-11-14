package fr.pedalons.service.route.edges;

import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.domain.route.NetworkEdgesDocument.Node;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.EdgeNode;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Surface;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * Builds the stored {@link NetworkEdgesDocument} from an answer (docs/LEDGER_*.md API-198, lot 1).
 * Pure: it only reshapes. Polylines are kept as received, nodes are deduplicated by id in the
 * order of first use, and the unmatched metres are summed per reason.
 */
public final class NetworkEdgesDocuments {

  /** The key of the metres without a reason: a service that answers none. */
  static final String UNKNOWN_REASON = "unknown";

  private NetworkEdgesDocuments() {}

  /**
   * The document of {@code answer}, for the track revision {@code rev} (the {@code file_id} of the
   * route's original GPX).
   */
  public static NetworkEdgesDocument from(NetworkEdgesAnswer answer, long rev, Instant now) {
    if (answer.tooShort()) {
      return NetworkEdgesDocument.tooShort(rev, now, answer.lengthM());
    }
    List<Node> nodes = new ArrayList<>();
    Map<String, Integer> indexOf = new HashMap<>();
    List<NetworkEdgesDocument.Edge> edges = new ArrayList<>(answer.edges().size());
    double covered = 0;
    for (RouteDetailsResponse.Edge e : answer.edges()) {
      Integer fn = nodeIndex(e.fromNode(), nodes, indexOf);
      Integer tn = nodeIndex(e.toNode(), nodes, indexOf);
      Surface surface = e.surface();
      edges.add(
          new NetworkEdgesDocument.Edge(
              e.fromM(),
              e.toM(),
              fn,
              tn,
              e.partial(),
              e.lengthM(),
              e.traversedM(),
              e.fromOffsetM(),
              e.toOffsetM(),
              e.oneway(),
              e.geometry(),
              e.fromGainCumM(),
              e.toGainCumM(),
              e.fromLossCumM(),
              e.toLossCumM(),
              e.structure(),
              surface == null ? null : surface.surfaceClass(),
              surface == null ? null : surface.detail(),
              surface == null ? null : surface.source(),
              e.wayKind(),
              e.tracktype(),
              e.bicycle(),
              e.foot()));
      covered += Math.max(0, e.toM() - e.fromM());
    }
    RouteDetailsResponse.Meta meta = answer.meta();
    return new NetworkEdgesDocument(
        NetworkEdgesDocument.VERSION,
        rev,
        now,
        NetworkEdgesDocument.STATUS_OK,
        meta == null ? null : meta.apiVersion(),
        meta == null ? null : meta.rulesVersion(),
        meta == null ? null : meta.profile(),
        meta == null ? null : meta.dataVersions(),
        answer.lengthM(),
        List.copyOf(nodes),
        List.copyOf(edges),
        unmatched(answer.segments()),
        covered);
  }

  private static @Nullable Integer nodeIndex(
      @Nullable EdgeNode node, List<Node> nodes, Map<String, Integer> indexOf) {
    if (node == null) {
      return null;
    }
    Integer known = indexOf.get(node.id());
    if (known != null) {
      return known;
    }
    nodes.add(new Node(node.id(), node.lat(), node.lon(), node.degree()));
    indexOf.put(node.id(), nodes.size() - 1);
    return nodes.size() - 1;
  }

  /**
   * Metres of the segments that were not matched, per {@code unmatched_reason} (key {@value
   * #UNKNOWN_REASON} when absent). A reason this release does not know keeps its own key.
   */
  static Map<String, Double> unmatched(List<RouteDetailsResponse.Segment> segments) {
    Map<String, Double> out = new LinkedHashMap<>();
    for (RouteDetailsResponse.Segment s : segments) {
      if (s.matched()) {
        continue;
      }
      String reason = s.unmatchedReason() == null ? UNKNOWN_REASON : s.unmatchedReason();
      out.merge(reason, Math.max(0, s.toM() - s.fromM()), Double::sum);
    }
    return out;
  }
}
