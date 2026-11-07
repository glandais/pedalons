package fr.pedalons.service.gpx;

import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.GpxPreview.PreviewTrack;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.gpx.request.PreviewDepartureEdit;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;

/**
 * The rules of the departure date and the average speed of a GPX preview (docs/LEDGER_*.md
 * API-149): the date is a wall time at the start of the track, resolved to an instant in that
 * point's zone, and follows the track when it moves to another zone.
 */
@ApplicationScoped
public class PreviewDepartures {

  @Inject EventTimezoneResolver timezoneResolver;
  @Inject GpxPreviewRepository repository;

  /**
   * The zone of the first point of the first non-empty track, else Paris: a preview has no team,
   * hence no zone to fall back on.
   */
  public ZoneId zone(List<PreviewTrack> tracks) {
    for (PreviewTrack track : tracks) {
      List<TrackPoint> points = track.trackPoints();
      if (points != null && !points.isEmpty()) {
        TrackPoint first = points.getFirst();
        return timezoneResolver
            .locate(first.lat(), first.lng())
            .orElseGet(PreviewDepartures::fallback);
      }
    }
    return fallback();
  }

  private static ZoneId fallback() {
    return ZoneId.of(Team.DEFAULT_TIMEZONE);
  }

  /** Refuses a date past the account's quota of dated previews to come. */
  private void checkQuota(GpxPreview preview) {
    long others =
        repository.countUpcomingDated(
            preview.getDomain().getId(),
            preview.getCreatedBy().getId(),
            Instant.now(),
            preview.getId());
    if (others >= GpxLimits.MAX_UPCOMING_DATED_PREVIEWS) {
      throw new BadRequestException(ErrorCode.BAD_REQUEST);
    }
  }

  /**
   * Applies a save to the preview. Called once its final tracks are set, under the row lock.
   * <ul>
   *   <li>cleared: no date;
   *   <li>given: the wall time read in the zone of the start of the track;
   *   <li>neither, already dated: the same wall time in the new zone when the track moved;
   * </ul>
   * then, independently, the speed.
   */
  public void apply(GpxPreview preview, PreviewDepartureEdit edit) {
    if (edit.clearDeparture()) {
      preview.setDepartureAt(null);
      preview.setDepartureZone(null);
    } else if (edit.departure() != null) {
      checkQuota(preview);
      ZoneId zone = zone(preview.getTracks());
      preview.setDepartureAt(edit.departure().toInstant(zone));
      preview.setDepartureZone(zone.getId());
    } else if (preview.getDepartureAt() != null) {
      ZoneId zone = zone(preview.getTracks());
      String previous = preview.getDepartureZone();
      if (previous == null) {
        preview.setDepartureZone(zone.getId());
      } else if (!previous.equals(zone.getId())) {
        preview.setDepartureAt(
            EventTimezoneResolver.sameWallTime(
                preview.getDepartureAt(), ZoneId.of(previous), zone));
        preview.setDepartureZone(zone.getId());
      }
    }
    if (edit.clearAverageSpeed()) {
      preview.setAverageSpeed(null);
    } else if (edit.averageSpeed() != null) {
      preview.setAverageSpeed(edit.averageSpeed());
    }
  }
}
