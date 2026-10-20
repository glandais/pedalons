package fr.pedalons.domain.gpx;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.io.Serializable;
import java.util.List;

/**
 * The typed waypoints of a GPX-tool preview, as stored in its {@code waypoint_details} JSONB
 * column (docs/LEDGER_*.md WEB-100, C3c). Not part of the contract.
 *
 * <p>The {@code waypoints} column keeps its {@code (name, lat, lng)} shape for the previous release
 * of a rolling deploy, whose JSON reader fails on unknown properties; this document is the new
 * truth and is only read back while {@code trackRevision} is the {@code files_revision} of the
 * preview (the previous release rewrites a track without touching this column).
 *
 * @param trackRevision the {@code files_revision} of the tracks the distances describe
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record PreviewWaypointsDocument(long trackRevision, List<PreviewWaypointDetail> waypoints)
    implements Serializable {

  public PreviewWaypointsDocument withTrackRevision(long revision) {
    return new PreviewWaypointsDocument(revision, waypoints);
  }
}
