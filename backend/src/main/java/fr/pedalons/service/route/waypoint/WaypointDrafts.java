package fr.pedalons.service.route.waypoint;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.dto.routes.request.WaypointRequest;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import fr.pedalons.service.route.GpxLimits;
import io.github.glandais.engine.gpx.GpxDocument;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Predicate;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Builds the {@link WaypointDraft}s of a track computation from the three places they come from: a
 * GPX document, a request, and the rows already stored (docs/LEDGER_*.md WEB-100, C3c).
 */
public final class WaypointDrafts {

  private static final Logger LOG = Logger.getLogger(WaypointDrafts.class);

  private WaypointDrafts() {}

  /** What is stored of a waypoint the editor may send back by id. */
  public record Known(long id, WaypointOrigin origin, @Nullable Double distance) {}

  public static List<Known> knownOf(Collection<GpxWaypoint> rows) {
    return rows.stream().map(r -> new Known(r.getId(), r.getOrigin(), r.getDistanceM())).toList();
  }

  /**
   * The waypoints of a sanitized document ({@link fr.pedalons.service.route.GpxSanitizer} already
   * typed them): imported, with no hint of distance, at most {@link GpxLimits#MAX_WAYPOINTS}.
   */
  public static List<WaypointDraft> fromDocument(GpxDocument sanitized) {
    List<io.github.glandais.engine.gpx.GpxWaypoint> source = sanitized.getWaypoints();
    if (source.size() > GpxLimits.MAX_WAYPOINTS) {
      LOG.warnf(
          "GPX with %d waypoints, keeping the first %d", source.size(), GpxLimits.MAX_WAYPOINTS);
    }
    return source.stream()
        .limit(GpxLimits.MAX_WAYPOINTS)
        .map(
            w ->
                new WaypointDraft(
                    null,
                    w.getLatitudeDeg(),
                    w.getLongitudeDeg(),
                    Objects.requireNonNullElse(w.getName(), ""),
                    null,
                    WaypointType.parseOrInfo(w.getType()),
                    WaypointOrigin.IMPORTED,
                    null,
                    null))
        .toList();
  }

  /**
   * The drafts of the rows kept as they are, each hinting the distance it had. {@code oldTotal} is
   * the length of the track it was placed on: the hint is rescaled onto the new one.
   */
  public static List<WaypointDraft> fromRows(
      Collection<GpxWaypoint> rows, @Nullable Float oldTotal, Predicate<GpxWaypoint> keep) {
    List<WaypointDraft> drafts = new ArrayList<>(rows.size());
    for (GpxWaypoint row : rows) {
      if (!keep.test(row)) {
        continue;
      }
      drafts.add(
          new WaypointDraft(
              row.getId(),
              row.getGeometry().getPosition().getLat(),
              row.getGeometry().getPosition().getLon(),
              row.getName(),
              row.getDescription(),
              row.typeOrInfo(),
              row.getOrigin(),
              row.getDistanceM(),
              oldTotal == null ? null : oldTotal.doubleValue()));
    }
    return drafts;
  }

  /**
   * The drafts of an editor's list, which replaces the waypoints.
   *
   * <p>An {@code id} naming one of {@code known} keeps its origin and, without a {@code distance}
   * in the request, the distance it had (rescaled by {@code oldTotal}); an unknown id is a new
   * point, as is none. A malformed or repeated id is a 400.
   */
  public static List<WaypointDraft> fromRequest(
      List<WaypointRequest> requests, Collection<Known> known, @Nullable Float oldTotal) {
    Map<Long, Known> byId = new HashMap<>();
    known.forEach(k -> byId.put(k.id(), k));
    Set<Long> seen = new HashSet<>();
    List<WaypointDraft> drafts = new ArrayList<>(requests.size());
    for (WaypointRequest request : requests) {
      Long id = parseId(request.id());
      Known existing = id == null ? null : byId.get(id);
      if (id != null && !seen.add(id)) {
        throw new BadRequestException();
      }
      WaypointOrigin origin =
          existing != null
              ? existing.origin()
              : Objects.requireNonNullElse(request.origin(), WaypointOrigin.AUTHOR);
      Double previous = null;
      Double previousTotal = null;
      if (request.distance() != null) {
        previous = request.distance();
      } else if (existing != null && existing.distance() != null && oldTotal != null) {
        previous = existing.distance();
        previousTotal = oldTotal.doubleValue();
      } else if (existing != null && existing.distance() != null) {
        previous = existing.distance();
      }
      drafts.add(
          new WaypointDraft(
              existing != null ? existing.id() : null,
              roundCoordinate(request.position().lat()),
              roundCoordinate(request.position().lng()),
              cleanName(request.name()),
              cleanDescription(request.description()),
              request.type(),
              origin,
              previous,
              previousTotal));
    }
    return drafts;
  }

  private static @Nullable Long parseId(@Nullable String id) {
    if (id == null || id.isBlank()) {
      return null;
    }
    try {
      return TsidUtils.toLong(id);
    } catch (RuntimeException e) {
      throw new BadRequestException(fr.pedalons.dto.error.ErrorCode.BAD_REQUEST, e);
    }
  }

  /** Control characters out, then stripped: a name is one line. */
  /**
   * A coordinate from the editor, at 7 decimals (about 1 cm): the map hands its full double
   * precision, which the GPX would otherwise carry digit for digit.
   */
  static double roundCoordinate(double degrees) {
    return Math.round(degrees * 1e7) / 1e7;
  }

  public static String cleanName(String name) {
    return name.replaceAll("\\p{Cntrl}", " ").strip();
  }

  /** The line breaks stay, every other control character goes; empty is none. */
  public static @Nullable String cleanDescription(@Nullable String description) {
    if (description == null) {
      return null;
    }
    String cleaned = description.replaceAll("[\\p{Cntrl}&&[^\\n]]", " ").strip();
    return cleaned.isEmpty() ? null : cleaned;
  }
}
