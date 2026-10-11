package fr.pedalons.dto.routes.response;

import fr.pedalons.domain.route.ClimbPartData;
import fr.pedalons.dto.validation.ValidateSchema;
import java.math.BigDecimal;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * Climb part DTO for a single gradient segment within a climb.
 */
@Schema(description = "Climb part information")
@ValidateSchema
public record ClimbPartDto(
    @Schema(description = "Start distance from route start in meters", required = true)
        Integer startDistance,
    @Schema(description = "End distance from route start in meters", required = true)
        Integer endDistance,
    @Schema(description = "Elevation gain in meters", required = true) Integer elevationGain,
    @Schema(description = "Gradient percentage", required = true) BigDecimal grade) {
  /**
   * Part distances from the climb library are relative to the climb start; {@code climbStartDist}
   * (the climb's own start distance from the route start) shifts them into route-absolute meters so
   * they share the same frame as track points and {@link ClimbDto} distances.
   */
  public static ClimbPartDto from(ClimbPartData part, double climbStartDist) {
    return new ClimbPartDto(
        (int) Math.round(climbStartDist + part.startDist()),
        (int) Math.round(climbStartDist + part.endDist()),
        (int) Math.round(part.ele()),
        BigDecimal.valueOf(part.grade()));
  }
}
