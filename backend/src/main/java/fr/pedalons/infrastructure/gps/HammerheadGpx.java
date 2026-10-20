package fr.pedalons.infrastructure.gps;

import fr.pedalons.enums.WaypointType;
import fr.pedalons.infrastructure.gpx.WaypointFormats;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxWaypoint;
import io.github.glandais.engine.gpx.GpxWriterJvm;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.jboss.logging.Logger;

/**
 * The GPX Hammerhead is sent (docs/LEDGER_*.md WEB-100, C3a/C3c). Through its API, a Karoo keeps the
 * waypoints of a GPX only when both {@code <type>} and {@code <sym>} are one of nine exact values
 * (Food, Water, Parking, Camping, Lodging, Geocache, Summit, Generic, Danger): the file Pédalons
 * stores, with its twelve types, is rewritten here, at send time, with the one of the nine each
 * type maps to ({@link WaypointFormats#hammerhead}). Names, descriptions and positions are kept,
 * and so are the points off the track, which the Karoo shows.
 */
public final class HammerheadGpx {

  private static final Logger LOG = Logger.getLogger(HammerheadGpx.class);

  private HammerheadGpx() {}

  /**
   * {@code gpx} with the {@code sym} and {@code type} of its waypoints reduced to Hammerhead's. A
   * file that cannot be read is returned as it is.
   */
  public static byte[] withHammerheadTypes(byte[] gpx) {
    try {
      GpxDocument doc = GpxParserJvm.parse(decode(gpx));
      if (doc.getWaypoints().isEmpty()) {
        return gpx;
      }
      List<GpxWaypoint> waypoints =
          doc.getWaypoints().stream()
              .map(
                  w -> {
                    WaypointType type = WaypointFormats.fromGpx(w.getSymbol(), w.getType());
                    String value = WaypointFormats.hammerhead(type);
                    return new GpxWaypoint(
                        w.getLatitudeDeg(),
                        w.getLongitudeDeg(),
                        w.getElevationM(),
                        w.getName(),
                        w.getDescription(),
                        value,
                        value,
                        null);
                  })
              .toList();
      GpxDocument rewritten = GpxModelJvm.document(doc.getTracks(), doc.getName(), waypoints);
      return GpxWriterJvm.write(rewritten).getBytes(StandardCharsets.UTF_8);
    } catch (Exception e) {
      LOG.warn("GPX unreadable for Hammerhead's types, sent as it is", e);
      return gpx;
    }
  }

  /** UTF-8, else ISO-8859-1 as the pipeline reads a GPX. */
  private static String decode(byte[] gpx) {
    try {
      return StandardCharsets.UTF_8
          .newDecoder()
          .onMalformedInput(CodingErrorAction.REPORT)
          .onUnmappableCharacter(CodingErrorAction.REPORT)
          .decode(ByteBuffer.wrap(gpx))
          .toString();
    } catch (CharacterCodingException e) {
      return new String(gpx, StandardCharsets.ISO_8859_1);
    }
  }
}
