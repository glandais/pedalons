package fr.pedalons.domain.gpx;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import java.io.Serializable;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The surfaces of a GPX-tool preview, as stored in its {@code surfaces} JSONB column (docs/LEDGER_*.md
 * WEB-100, C1b): one document per track, null where a track has none. Not part of the contract.
 *
 * <p>Only read back while {@code trackRevision} is the {@code files_revision} of the preview and
 * the number of tracks is the one of the preview: the previous release of a rolling deploy rewrites
 * a preview's track without clearing the column.
 *
 * @param trackRevision the {@code files_revision} of the tracks the documents describe
 */
// Read by hypersistence's own ObjectMapper, which fails on unknown properties (see
// TrackSurfaceDocument).
@JsonIgnoreProperties(ignoreUnknown = true)
public record PreviewSurfacesDocument(
    long trackRevision, List<@Nullable TrackSurfaceDocument> tracks) implements Serializable {

  public PreviewSurfacesDocument withTrackRevision(long revision) {
    return new PreviewSurfacesDocument(revision, tracks);
  }
}
