package fr.pedalons.domain.route;

import io.github.glandais.engine.climb.Climb;
import java.io.Serializable;
import java.util.List;

/**
 * A detected climb, stored as JSONB.
 *
 * <p>Field-for-field identical to gpx2web's {@code Climb}, on purpose: freezing this shape is what
 * lets the GPX library be swapped without a Flyway migration, without rewriting a single stored
 * document and without moving the OpenAPI contract. {@code grade} and {@code climbingGrade} are
 * <b>percentages</b> and part distances are <b>relative to the climb start</b>, exactly as gpx2web
 * produced them.
 *
 * <p>vcyclist reports grades as dimensionless ratios and part distances as absolute distances along
 * the path. {@link #from} is the single place where both conversions happen — nothing downstream
 * knows about them.
 */
public record ClimbData(
    double startDist,
    double startEle,
    double endDist,
    double endEle,
    double dist,
    double elevation,
    double positiveElevation,
    double negativeElevation,
    double grade,
    double climbingGrade,
    List<ClimbPartData> parts)
    implements Serializable {

  public static ClimbData from(Climb climb) {
    double startDist = climb.getStartDistanceM();
    return new ClimbData(
        startDist,
        climb.getStartElevationM(),
        climb.getEndDistanceM(),
        climb.getEndElevationM(),
        climb.getLengthM(),
        climb.getElevationGainM(),
        climb.getPositiveElevationM(),
        climb.getNegativeElevationM(),
        climb.getAverageGrade() * 100,
        climb.getClimbingGrade() * 100,
        climb.getParts().stream().map(part -> ClimbPartData.from(part, startDist)).toList());
  }
}
