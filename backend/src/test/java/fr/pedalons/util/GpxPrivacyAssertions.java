package fr.pedalons.util;

import static org.junit.jupiter.api.Assertions.*;

import com.garmin.fit.DecodeOptions;
import com.garmin.fit.FitDecoder;
import com.garmin.fit.RecordMesg;
import fr.pedalons.infrastructure.gpx.FitExporter;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.List;

/**
 * docs/LEDGER_*.md API-44: assertions that a stored GPX or FIT file carries geometry only, for the
 * fixture {@link #ACTIVITY} — an activity export with a timestamp, heart rate, cadence, power and
 * temperature on every point, and an author, e-mail and device serial in its metadata.
 */
public final class GpxPrivacyAssertions {

  public static final String ACTIVITY = "src/test/resources/activity_with_sensors.gpx";

  private GpxPrivacyAssertions() {}

  public static Path activityGpx() {
    return new File(ACTIVITY).toPath();
  }

  /** The fixture as a device would record it in FIT: with its clock, unsanitized. */
  public static byte[] activityFit() throws IOException {
    GpxDocument dirty = GpxParserJvm.parse(Files.readString(activityGpx(), StandardCharsets.UTF_8));
    return FitExporter.toFitBytes(GpxToPathJvm.tracksAsPaths(dirty), dirty.getName());
  }

  /** A GPX serialization with nothing of the fixture's clock, sensors or author left in it. */
  public static void assertGpxHasNoPersonalData(String xml) {
    assertFalse(xml.contains("2025-"), "a recorded timestamp survived");
    assertFalse(xml.contains("<extensions>"), "a sensor extension survived");
    assertFalse(xml.contains("hr>"), "heart rate survived");
    assertFalse(xml.contains("cad>"), "cadence survived");
    assertFalse(xml.contains("atemp>"), "temperature survived");
    assertFalse(xml.contains("power>"), "power survived");
    assertFalse(xml.contains("Jane"), "the author survived");
    assertFalse(xml.contains("example.com"), "the author's e-mail or link survived");
    assertFalse(xml.contains("3412345678"), "the device's serial number survived");
  }

  /**
   * A FIT course with no recorded time, power, heart rate or cadence on any record. A sanitized
   * track has no clock, so the course starts at the FIT epoch (1989-12-31, see {@code
   * FitExporter}): long before any recording.
   *
   * <p>Sensor fields are looked up by their profile name: the typed getters return Kotlin unsigned
   * types, whose mangled names Java cannot call.
   */
  public static void assertFitHasNoPersonalData(byte[] fit) {
    List<RecordMesg> records =
        new FitDecoder(fit).decode(new DecodeOptions()).getMessages().getRecordMesgs();

    assertFalse(records.isEmpty(), "the FIT course has no record");
    Instant recorded = Instant.parse("2000-01-01T00:00:00Z");
    for (RecordMesg record : records) {
      assertTrue(
          record.getTimestamp() == null
              || Instant.ofEpochMilli(record.getTimestamp().toEpochMilliseconds())
                  .isBefore(recorded),
          "a recorded timestamp survived: " + record.getTimestamp());
      for (String field : List.of("power", "heart_rate", "cadence", "temperature")) {
        assertNull(record.getField(field), field + " survived");
      }
    }
  }
}
