package fr.pedalons.dto.weather.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.RelativeWind;
import fr.pedalons.enums.WeatherCheckpointKind;
import fr.pedalons.service.weather.WeatherCheckpoint;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "A forecast point along a leg, about every 15 km plus the finish. Deliberately carries no"
            + " coordinates: place it by distance on the route geometry the client may read.")
@ValidateSchema
public record WeatherCheckpointDto(
    @Schema(description = "Position of the point on the leg, 0 for the start", required = true)
        int index,
    @Schema(description = "Where the point stands on the leg", required = true)
        WeatherCheckpointKind kind,
    @Schema(
            description =
                "Distance from the start of the leg's route, metres: its tracks laid end to end in"
                    + " the order of their ids, without counting the gap between the end of one"
                    + " track and the start of the next. To place the point on the geometry, add"
                    + " up the lengths of the previous tracks: the 4th coordinate of a track"
                    + " geometry restarts at 0 on each track.",
            required = true)
        double distance,
    @Nullable @Schema(description = "Elevation of the point, metres, from the track")
        Double elevation,
    @Schema(description = "Estimated passage, from the leg's start time and speed", required = true)
        Instant time,
    @Nullable
        @Schema(
            description =
                "The forecast at the passage. Absent when nothing is in cache for that place yet.")
        WeatherConditionsDto weather,
    @Nullable
        @Schema(
            description =
                "How the rider meets the wind on the stretch that starts here (for the finish, the"
                    + " stretch that ends here). Absent without weather.")
        RelativeWind relativeWind,
    @Nullable
        @Schema(
            description =
                "Mean head component of the wind on that stretch, km/h, signed: positive against"
                    + " the rider, negative behind")
        Double headwind,
    @Nullable
        @Schema(
            description =
                "Direction the wind blows TOWARDS, relative to the direction of travel, degrees"
                    + " clockwise: 0 = from behind (pushing), 90 = from the left, 180 = in the"
                    + " face. Draw the arrow pointing forward, then rotate it by this angle.")
        Double relativeWindAngle) {

  public static WeatherCheckpointDto from(WeatherCheckpoint checkpoint) {
    return new WeatherCheckpointDto(
        checkpoint.index(),
        checkpoint.kind(),
        checkpoint.distance(),
        checkpoint.elevation(),
        checkpoint.time(),
        WeatherConditionsDto.fromNullable(checkpoint.weather()),
        checkpoint.relativeWind(),
        checkpoint.headwind(),
        checkpoint.relativeWindAngle());
  }
}
