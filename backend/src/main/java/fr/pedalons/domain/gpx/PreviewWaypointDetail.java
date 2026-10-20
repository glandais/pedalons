package fr.pedalons.domain.gpx;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.io.Serializable;
import org.jspecify.annotations.Nullable;

/**
 * A typed, placed waypoint of a GPX-tool preview (docs/LEDGER_*.md WEB-100, C3c), as stored in
 * {@link PreviewWaypointsDocument}. Not part of the contract.
 *
 * <p>{@code type} and {@code origin} are stored as strings and read with {@code parseOrInfo} /
 * {@code parseOrImported}: a value a later release adds does not break an older one.
 *
 * @param id the TSID the waypoint is known by (it becomes a row id on promotion only as a
 *     correspondence for the editor: the route rows are new)
 * @param distance metres along the tracks, null when off the track
 */
// Read by hypersistence's own ObjectMapper, which fails on unknown properties (see
// TrackSurfaceDocument).
@JsonIgnoreProperties(ignoreUnknown = true)
public record PreviewWaypointDetail(
    @Nullable String id,
    String name,
    double lat,
    double lng,
    String type,
    @Nullable String description,
    @Nullable Double distance,
    String origin)
    implements Serializable {}
