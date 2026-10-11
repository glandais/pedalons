package fr.pedalons.domain.route;

import io.github.glandais.engine.climb.ClimbPart;
import java.io.Serializable;

/**
 * A single gradient segment within a climb, stored as JSONB.
 *
 * <p>Field-for-field identical to gpx2web's {@code ClimbPart}, on purpose: freezing this shape is
 * what lets the GPX library be swapped without a Flyway migration and without touching a single
 * stored document. Distances are <b>relative to the climb start</b> and {@code grade} is a
 * <b>percentage</b>, exactly as gpx2web produced them — vcyclist uses absolute distances and
 * dimensionless ratios, and {@link #from} is the only place that conversion happens.
 *
 * <p>{@code ele} is the segment's elevation <em>gain</em> (end minus start), not an altitude:
 * gpx2web stored {@code endEle - startEle} there, and {@code ClimbPartDto} renders it as
 * "elevation gain".
 */
public record ClimbPartData(
    double startDist,
    double startEle,
    double endDist,
    double endEle,
    double dist,
    double ele,
    double grade)
    implements Serializable {

  /**
   * @param climbStartDist absolute distance of the climb start along the path, subtracted to get
   *     back to gpx2web's climb-relative frame
   */
  public static ClimbPartData from(ClimbPart part, double climbStartDist) {
    return new ClimbPartData(
        part.getStartDistanceM() - climbStartDist,
        part.getStartElevationM(),
        part.getEndDistanceM() - climbStartDist,
        part.getEndElevationM(),
        part.getLengthM(),
        part.getElevationGainM(),
        part.getGrade() * 100);
  }
}
