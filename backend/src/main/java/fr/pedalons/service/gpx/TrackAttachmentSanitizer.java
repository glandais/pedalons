package fr.pedalons.service.gpx;

import com.garmin.fit.CoursePointMesg;
import com.garmin.fit.DecodeOptions;
import com.garmin.fit.DecodeResult;
import com.garmin.fit.FitDecoder;
import com.garmin.fit.RecordMesg;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.gpx.FitExporter;
import fr.pedalons.service.route.GpxSanitizer;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.github.glandais.engine.gpx.GpxTrack;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.gpx.GpxWaypoint;
import io.github.glandais.engine.gpx.GpxWriterJvm;
import jakarta.enterprise.context.ApplicationScoped;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Cleans a GPX or FIT file attached to content as a plain attachment, the way a route's files are
 * cleaned at import: only the tracks (position, altitude) and the waypoints (position, name)
 * survive (docs/LEDGER_*.md API-49 for GPX, API-55 for FIT, after API-44).
 *
 * <p>An attachment is a file offered for download, not a route: nothing is resampled, simplified or
 * re-elevated, the track keeps every point it had. What goes is what {@link GpxSanitizer} drops —
 * timestamps, heart rate, cadence, power, temperature — and what the parser never keeps (author,
 * e-mail, device, descriptions).
 *
 * <p><b>A FIT comes back as a FIT course.</b> An activity recorded by a device is decoded, reduced
 * to its positioned records, and written again by the exporter that produces every route's {@code
 * route.fit} ({@link FitExporter}): laps, sessions, device information, HRV and every other message
 * of the activity are gone. The file still loads on a GPS device, as a course to follow. Its course
 * points are gone too: vcyclist's FIT writer has no course point, so a FIT holding nothing else is
 * refused as empty.
 *
 * <p>Both writers are deterministic — the FIT one dates every record at the FIT epoch, the date
 * that means "no clock" — so a file is clean exactly when its rewrite gives it back byte for byte.
 */
@ApplicationScoped
public class TrackAttachmentSanitizer {

  /** The content type {@code FileTypeDetector} gives a {@code .gpx} file. */
  public static final String GPX_CONTENT_TYPE = "application/gpx+xml";

  /** The content type {@code FileTypeDetector} gives a {@code .fit} file. */
  public static final String FIT_CONTENT_TYPE = "application/vnd.ant.fit";

  /** FIT positions are in semicircles: 2^31 of them make 180 degrees. */
  private static final double SEMICIRCLES_TO_DEGREES = 180.0 / 2_147_483_648.0;

  /** Course name of a rewritten FIT: the source's could name the member or the ride. */
  private static final String FIT_NAME = "track";

  /** Whether an asset of this type and content type is a track file to clean before storing. */
  public static boolean applies(AssetType type, String contentType) {
    return type == AssetType.ATTACHMENT
        && (GPX_CONTENT_TYPE.equals(contentType) || FIT_CONTENT_TYPE.equals(contentType));
  }

  /**
   * The cleaned serialization of {@code raw}, in the same format.
   *
   * @param contentType {@link #GPX_CONTENT_TYPE} or {@link #FIT_CONTENT_TYPE}
   * @throws BusinessException {@link ErrorCode#GPX_FAILURE} when the file is not a readable GPX or
   *     FIT, {@link ErrorCode#GPX_EMPTY} when it holds nothing the rewrite can keep — storing it
   *     would then keep nothing of what the member attached
   */
  public byte[] sanitize(byte[] raw, String contentType) {
    if (FIT_CONTENT_TYPE.equals(contentType)) {
      GpxDocument doc = GpxSanitizer.sanitize(readFit(raw));
      // FitExporter refuses with GPX_EMPTY when no track has a point.
      return FitExporter.toFitBytes(GpxToPathJvm.tracksAsPaths(doc), FIT_NAME);
    }
    GpxDocument doc = GpxSanitizer.sanitize(readGpx(raw));
    boolean noPoint = doc.getTracks().stream().allMatch(t -> t.getPoints().isEmpty());
    if (noPoint && doc.getWaypoints().isEmpty()) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    try {
      return GpxWriterJvm.write(doc).getBytes(StandardCharsets.UTF_8);
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /** Whether {@code raw} needs no rewrite: {@link #sanitize} would give it back as it is. */
  public boolean isClean(byte[] raw, String contentType) {
    return Arrays.equals(raw, sanitize(raw, contentType));
  }

  /** UTF-8 first, ISO-8859-1 as a fallback, as for an imported route's GPX. */
  private static GpxDocument readGpx(byte[] raw) {
    String text;
    try {
      text = StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(raw)).toString();
    } catch (CharacterCodingException e) {
      text = new String(raw, StandardCharsets.ISO_8859_1);
    }
    try {
      return GpxParserJvm.parse(text);
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /**
   * The positioned records of a FIT file as one track, and its course points as waypoints. Nothing
   * else of the file is read: what the result is built from is exactly what the course keeps.
   */
  private static GpxDocument readFit(byte[] raw) {
    DecodeResult result;
    try {
      result = new FitDecoder(raw).decode(new DecodeOptions());
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    if (!result.isSuccess()) {
      throw new BusinessException(ErrorCode.GPX_FAILURE);
    }

    List<GpxTrackPoint> points = new ArrayList<>();
    for (RecordMesg record : result.getMessages().getRecordMesgs()) {
      Integer lat = record.getPositionLat();
      Integer lon = record.getPositionLong();
      if (lat == null || lon == null) {
        continue;
      }
      Double altitude =
          record.getEnhancedAltitude() != null
              ? record.getEnhancedAltitude()
              : record.getAltitude();
      points.add(
          GpxModelJvm.trackPoint(
              lat * SEMICIRCLES_TO_DEGREES, lon * SEMICIRCLES_TO_DEGREES, altitude));
    }
    List<GpxTrack> tracks =
        points.isEmpty() ? List.of() : List.of(GpxModelJvm.track(points, FIT_NAME));
    List<GpxWaypoint> waypoints = new ArrayList<>();
    for (CoursePointMesg coursePoint : result.getMessages().getCoursePointMesgs()) {
      Integer lat = coursePoint.getPositionLat();
      Integer lon = coursePoint.getPositionLong();
      if (lat != null && lon != null) {
        String name = coursePoint.getName();
        waypoints.add(
            GpxModelJvm.waypoint(
                lat * SEMICIRCLES_TO_DEGREES,
                lon * SEMICIRCLES_TO_DEGREES,
                null,
                name != null ? name : ""));
      }
    }
    return GpxModelJvm.document(tracks, FIT_NAME, waypoints);
  }
}
