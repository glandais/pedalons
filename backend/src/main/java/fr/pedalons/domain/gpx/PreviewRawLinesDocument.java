package fr.pedalons.domain.gpx;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.io.Serializable;
import java.util.List;

/**
 * The raw lines of a GPX-tool preview, as stored in its {@code raw_lines} JSONB column
 * (docs/LEDGER_*.md API-147): one per track, the track as its source produced it — 2D, neither
 * resampled nor simplified — encoded as a polyline of precision 6, latitude then longitude, like
 * {@code PlannerSource.line}. Not part of the contract.
 *
 * <p>Not a field of {@link GpxPreview.PreviewTrack}: the previous release of a rolling deploy reads
 * the tracks with a JSON reader that fails on unknown properties. Only read back while {@code
 * trackRevision} is the {@code files_revision} of the preview and the number of lines is the number
 * of tracks: the previous release rewrites a preview's track without clearing the column.
 *
 * @param trackRevision the {@code files_revision} of the tracks the lines describe
 */
// Read by hypersistence's own ObjectMapper, which fails on unknown properties (see
// TrackSurfaceDocument).
@JsonIgnoreProperties(ignoreUnknown = true)
public record PreviewRawLinesDocument(long trackRevision, List<String> lines)
    implements Serializable {

  public PreviewRawLinesDocument withTrackRevision(long revision) {
    return new PreviewRawLinesDocument(revision, lines);
  }
}
