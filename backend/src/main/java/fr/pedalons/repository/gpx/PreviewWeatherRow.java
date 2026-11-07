package fr.pedalons.repository.gpx;

import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * What the weather needs of a dated GPX preview, without loading the entity and its JSONB columns
 * (docs/LEDGER_*.md API-149).
 *
 * @param filesRevision the track revision, null for the flat layout of the oldest previews
 * @param averageSpeed km/h, null when the person gave none
 */
public record PreviewWeatherRow(
    Long id,
    @Nullable Long filesRevision,
    @Nullable Instant departureAt,
    @Nullable Float averageSpeed) {

  /** The revision a cache key carries: 0 for the flat layout. */
  public long revision() {
    return filesRevision == null ? 0 : filesRevision;
  }
}
