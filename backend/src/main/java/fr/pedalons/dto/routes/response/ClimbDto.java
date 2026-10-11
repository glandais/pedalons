package fr.pedalons.dto.routes.response;

import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.ClimbPartData;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.ClimbCategory;
import java.math.BigDecimal;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * Climb DTO for climb segments.
 */
@Schema(description = "Climb segment information")
@ValidateSchema
public record ClimbDto(
    @Schema(description = "Start distance from route start in meters", required = true)
        Integer startDistance,
    @Schema(description = "End distance from route start in meters", required = true)
        Integer endDistance,
    @Schema(description = "Elevation gain in meters", required = true) Integer elevationGain,
    @Schema(description = "Average gradient percentage", required = true)
        BigDecimal averageGradient,
    @Schema(description = "Maximum gradient percentage", required = true) BigDecimal maxGradient,
    @Nullable @Schema(description = "Climb category (HC, 1, 2, 3, 4)") ClimbCategory category,
    @Schema(description = "Gradient segments making up the climb", required = true)
        List<ClimbPartDto> parts,
    @Nullable
        @Schema(
            description =
                "Name of the climb: the route waypoint lying near its top (within 300 m), as the"
                    + " route's author named it in the GPX. Null when no waypoint marks the summit"
                    + " — clients then number the climb (\"Climb N\"). Never a geocoded guess.")
        String name) {
  /** A climb with no name — what a track without waypoints yields. */
  public static ClimbDto from(ClimbData climb) {
    return from(climb, null);
  }

  /**
   * @param name the climb's name, from {@code ClimbNaming} (docs/LEDGER_*.md API-10), or {@code
   *     null}
   */
  public static ClimbDto from(ClimbData climb, @Nullable String name) {

    return new ClimbDto(
        (int) Math.round(climb.startDist()),
        (int) Math.round(climb.endDist()),
        (int) Math.round(climb.positiveElevation()),
        BigDecimal.valueOf(climb.grade()),
        BigDecimal.valueOf(getMaxGrade(climb)),
        categorizeClimb(climb),
        climb.parts().stream().map(part -> ClimbPartDto.from(part, climb.startDist())).toList(),
        name);
  }

  /**
   * Categorize climb based on elevation gain and average gradient.
   * <p>
   * Categories:
   * - HC (Hors Catégorie): > 1500m elevation or (> 1000m and > 8% grade)
   * - CAT1: 800-1500m elevation
   * - CAT2: 500-800m elevation
   * - CAT3: 300-500m elevation
   * - CAT4: < 300m elevation
   */
  private static ClimbCategory categorizeClimb(ClimbData climb) {
    int elevationGain = (int) Math.round(climb.positiveElevation());
    double avgGrade = climb.grade();

    if (elevationGain > 1500 || (elevationGain > 1000 && avgGrade > 8.0)) {
      return ClimbCategory.HC;
    } else if (elevationGain > 800) {
      return ClimbCategory.CAT1;
    } else if (elevationGain > 500) {
      return ClimbCategory.CAT2;
    } else if (elevationGain > 300) {
      return ClimbCategory.CAT3;
    } else {
      return ClimbCategory.CAT4;
    }
  }

  private static double getMaxGrade(ClimbData climb) {
    if (climb.parts().isEmpty()) {
      return climb.grade();
    }
    return climb.parts().stream().mapToDouble(ClimbPartData::grade).max().orElse(climb.grade());
  }
}
