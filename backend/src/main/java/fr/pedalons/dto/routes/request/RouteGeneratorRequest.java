package fr.pedalons.dto.routes.request;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.CompassPoint;
import fr.pedalons.enums.RouteGeneratorType;
import fr.pedalons.enums.RouteGeneratorUnpaved;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.PositiveOrZero;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "What to ask the route generator for")
@ValidateSchema
public record RouteGeneratorRequest(
    @Nullable
        @Schema(description = "Start. Absent: the team's location (400 VALIDATION if it has none)")
        @Valid
        GeoPoint start,
    @Nullable
        @Schema(
            description =
                "End. Absent: a loop, the route ends where it starts. Present: a one-way route"
                    + " from start to end")
        @Valid
        GeoPoint end,
    @Nullable
        @Schema(
            description =
                "Wished direction, only used when the end is closer than half the distance (a"
                    + " loop included)")
        CompassPoint bearing,
    @Schema(description = "Wished distance in kilometres, 10 to 200", required = true)
        @DecimalMin("10")
        @DecimalMax("200")
        double distanceKm,
    @Nullable
        @Schema(
            description =
                "From the team's roads (0, only the roads the team rides) to discovery (1, no"
                    + " preference for them); rounded to the hundredth by the engine. Absent: 0.25")
        @DecimalMin("0")
        @DecimalMax("1")
        Double discovery,
    @Nullable @Schema(description = "What to ride. Absent: ROAD") RouteGeneratorType type,
    @Nullable
        @Schema(
            description =
                "Makes \"other proposals\" reproducible: the same seed gives the same routes."
                    + " Absent: 0")
        @PositiveOrZero
        Integer seed,
    @Nullable
        @Schema(
            description =
                "How much of the route to ride off pavement: LOW, USUAL or HIGH. Only for GRAVEL"
                    + " and MTB, ignored for ROAD. Absent: USUAL")
        RouteGeneratorUnpaved unpaved) {

  /** Without {@code unpaved}: the shape this record had before contract 16.2.0. */
  public RouteGeneratorRequest(
      @Nullable GeoPoint start,
      @Nullable GeoPoint end,
      @Nullable CompassPoint bearing,
      double distanceKm,
      @Nullable Double discovery,
      @Nullable RouteGeneratorType type,
      @Nullable Integer seed) {
    this(start, end, bearing, distanceKm, discovery, type, seed, null);
  }
}
