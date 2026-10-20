package fr.pedalons.service.gpx;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.gpx.GpxPreview.PreviewWaypoint;
import fr.pedalons.domain.gpx.PreviewWaypointDetail;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import fr.pedalons.service.route.waypoint.AnchoredWaypoint;
import fr.pedalons.service.route.waypoint.WaypointDraft;
import fr.pedalons.service.route.waypoint.WaypointDrafts.Known;
import io.hypersistence.tsid.TSID;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Predicate;
import org.jspecify.annotations.Nullable;

/**
 * Conversions between the stored waypoints of a GPX-tool preview ({@link PreviewWaypointDetail})
 * and the placed waypoints of the pipeline (docs/LEDGER_*.md WEB-100, C3c). A preview has no rows:
 * its waypoints are identified by a TSID of their own, which an editor sends back.
 */
public final class PreviewWaypoints {

  private PreviewWaypoints() {}

  private static @Nullable Long idOf(PreviewWaypointDetail detail) {
    String id = detail.id();
    if (id == null) {
      return null;
    }
    try {
      return TsidUtils.toLong(id);
    } catch (RuntimeException e) {
      return null;
    }
  }

  public static List<Known> known(List<PreviewWaypointDetail> details) {
    List<Known> known = new ArrayList<>(details.size());
    for (PreviewWaypointDetail d : details) {
      Long id = idOf(d);
      if (id != null) {
        known.add(new Known(id, WaypointOrigin.parseOrImported(d.origin()), d.distance()));
      }
    }
    return known;
  }

  /**
   * The drafts of the stored waypoints {@code keep} selects, hinting the distance they had on a
   * track of length {@code oldTotal}. {@code keepIds}: whether a draft names the stored point
   * (editing a preview) or is a new one (promotion into a route, whose rows are new).
   */
  public static List<WaypointDraft> drafts(
      List<PreviewWaypointDetail> details,
      @Nullable Float oldTotal,
      boolean keepIds,
      Predicate<PreviewWaypointDetail> keep) {
    List<WaypointDraft> drafts = new ArrayList<>(details.size());
    for (PreviewWaypointDetail d : details) {
      if (!keep.test(d)) {
        continue;
      }
      drafts.add(
          new WaypointDraft(
              keepIds ? idOf(d) : null,
              d.lat(),
              d.lng(),
              d.name(),
              d.description(),
              WaypointType.parseOrInfo(d.type()),
              WaypointOrigin.parseOrImported(d.origin()),
              d.distance(),
              oldTotal == null ? null : oldTotal.doubleValue()));
    }
    return drafts;
  }

  public static boolean isAuthor(PreviewWaypointDetail detail) {
    return WaypointOrigin.parseOrImported(detail.origin()) == WaypointOrigin.AUTHOR;
  }

  /** The placed waypoints, a TSID given to each that has none. */
  public static List<PreviewWaypointDetail> toDetails(List<AnchoredWaypoint> anchored) {
    List<PreviewWaypointDetail> details = new ArrayList<>(anchored.size());
    for (AnchoredWaypoint w : anchored) {
      long id = w.id() != null ? w.id() : TSID.Factory.getTsid().toLong();
      details.add(
          new PreviewWaypointDetail(
              TsidUtils.toString(id),
              w.name(),
              w.lat(),
              w.lng(),
              w.type().name(),
              w.description(),
              w.distance(),
              w.origin().name()));
    }
    return details;
  }

  public static List<AnchoredWaypoint> toAnchored(List<PreviewWaypointDetail> details) {
    return details.stream()
        .map(
            d ->
                new AnchoredWaypoint(
                    idOf(d),
                    d.lat(),
                    d.lng(),
                    d.name(),
                    d.description(),
                    WaypointType.parseOrInfo(d.type()),
                    WaypointOrigin.parseOrImported(d.origin()),
                    d.distance()))
        .toList();
  }

  /** The historical {@code (name, lat, lng)} column, which the previous release reads. */
  public static List<PreviewWaypoint> legacy(List<PreviewWaypointDetail> details) {
    return details.stream().map(d -> new PreviewWaypoint(d.name(), d.lat(), d.lng())).toList();
  }

  /** Whether two readings of the stored waypoints are the same but for their distances. */
  public static boolean sameIgnoringDistance(
      List<PreviewWaypointDetail> a, List<PreviewWaypointDetail> b) {
    return strip(a).equals(strip(b));
  }

  private static List<PreviewWaypointDetail> strip(List<PreviewWaypointDetail> details) {
    return details.stream()
        .map(
            d ->
                new PreviewWaypointDetail(
                    d.id(),
                    d.name(),
                    d.lat(),
                    d.lng(),
                    d.type(),
                    d.description(),
                    null,
                    d.origin()))
        .toList();
  }

  /** Whether the stored waypoints already are {@code anchored} (same ids, same content). */
  public static boolean same(List<PreviewWaypointDetail> stored, List<AnchoredWaypoint> anchored) {
    if (stored.size() != anchored.size()) {
      return false;
    }
    List<AnchoredWaypoint> current = toAnchored(stored);
    for (int i = 0; i < anchored.size(); i++) {
      AnchoredWaypoint a = anchored.get(i);
      boolean found = false;
      for (AnchoredWaypoint c : current) {
        if (a.id() != null
            && a.id().equals(c.id())
            && a.type() == c.type()
            && a.origin() == c.origin()
            && a.name().equals(c.name())
            && java.util.Objects.equals(a.description(), c.description())
            && Math.abs(a.lat() - c.lat()) < 1e-9
            && Math.abs(a.lng() - c.lng()) < 1e-9
            && fr.pedalons.service.route.waypoint.WaypointRows.sameDistance(
                a.distance(), c.distance())) {
          found = true;
          break;
        }
      }
      if (!found) {
        return false;
      }
    }
    return true;
  }
}
