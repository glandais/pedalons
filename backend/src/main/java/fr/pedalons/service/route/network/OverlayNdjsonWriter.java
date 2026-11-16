package fr.pedalons.service.route.network;

import fr.pedalons.repository.route.GeneratorSourceRepository.TrackRow;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Set;
import org.jboss.logging.Logger;

/**
 * Writes the deposit body of a team: one NDJSON line per track, {@code
 * {"type":…,"excluded":…,"network_edges":…}}, then the mandatory last line {@code
 * {"end":{"tracks":N}}} (lot 3b plan §6.3, contract api 1.9). The jsonb text goes in as stored, never
 * parsed here beyond its header; a document that is not current, or longer than the service
 * accepts, goes as {@code null}.
 */
public final class OverlayNdjsonWriter {

  private static final Logger LOG = Logger.getLogger(OverlayNdjsonWriter.class);
  private static final Set<String> TYPES = Set.of("ROAD", "GRAVEL", "MTB");

  private final OutputStream out;
  private final long maxDocumentBytes;
  private long tracks;
  private long excluded;
  private long notCurrent;
  private long bytes;

  public OverlayNdjsonWriter(OutputStream out, long maxDocumentBytes) {
    this.out = out;
    this.maxDocumentBytes = maxDocumentBytes;
  }

  /** What was written, for the log line. */
  public record Stats(long tracks, long excluded, long notCurrent, long bytes) {}

  public void track(TrackRow row) throws IOException {
    tracks++;
    if (row.excluded()) {
      excluded++;
    }
    String type =
        row.surfaceType() != null && TYPES.contains(row.surfaceType())
            ? row.surfaceType()
            : "MIXED";
    byte[] document = null;
    if (NetworkEdgesHeader.current(NetworkEdgesHeader.read(row.document()), row.original())
        && row.document().indexOf('\n') < 0) {
      byte[] bytesOfDocument = row.document().getBytes(StandardCharsets.UTF_8);
      if (bytesOfDocument.length <= maxDocumentBytes) {
        document = bytesOfDocument;
      } else {
        LOG.warnf(
            "Route generator deposit: the document of track %s is above the service's limit,"
                + " sent as unreadable",
            fr.pedalons.common.TsidUtils.toString(row.trackId()));
      }
    }
    if (document == null) {
      notCurrent++;
    }
    write("{\"type\":\"" + type + "\",\"excluded\":" + row.excluded() + ",\"network_edges\":");
    if (document == null) {
      write("null");
    } else {
      out.write(document);
      bytes += document.length;
    }
    write("}\n");
  }

  /** The last line. Call it once, after the last track. */
  public void finish() throws IOException {
    write("{\"end\":{\"tracks\":" + tracks + "}}\n");
  }

  public Stats stats() {
    return new Stats(tracks, excluded, notCurrent, bytes);
  }

  private void write(String text) throws IOException {
    byte[] b = text.getBytes(StandardCharsets.UTF_8);
    out.write(b);
    bytes += b.length;
  }
}
