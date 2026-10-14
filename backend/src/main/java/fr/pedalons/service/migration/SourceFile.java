package fr.pedalons.service.migration;

import java.io.IOException;
import java.nio.file.Path;
import org.jspecify.annotations.Nullable;

/**
 * A biketeam file — GPX track, image or logo — as a {@link BiketeamSource} hands it out. Its
 * metadata is known up front; its bytes are only fetched by {@link #open()}, so a route whose GPX
 * did not change since the last run is never downloaded at all.
 */
public interface SourceFile {

  /** The file name on biketeam's disk; its extension is what the asset pipeline goes by. */
  String fileName();

  /**
   * {@code "<size>:<md5>"} — the format {@code biketeam_migration_map.source_fingerprint} holds,
   * suffixed with {@code "@p<pipeline version>"} for a route ({@code
   * BiketeamMigrationService.routeFingerprint}) — or null when it cannot be computed.
   */
  @Nullable String fingerprint();

  /** Lower-case hex MD5 of the whole file, or null when it cannot be computed. */
  @Nullable String md5();

  /**
   * A local copy of the file, downloaded on first call when the source is remote. The path belongs
   * to the source and is deleted when it is closed.
   */
  Path open() throws IOException;
}
