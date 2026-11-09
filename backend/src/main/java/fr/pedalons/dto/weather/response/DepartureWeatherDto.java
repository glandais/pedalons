package fr.pedalons.dto.weather.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.service.weather.DepartureWeather;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "The weather at the departure point when the ride, or a trip stage, leaves")
@ValidateSchema
public record DepartureWeatherDto(
    @Schema(
            description =
                "State of the departure forecast. conditions is present for OK and STALE only.",
            required = true)
        WeatherStatus status,
    @Nullable @Schema(description = "The forecast of the departure hour, for OK and STALE")
        WeatherConditionsDto conditions,
    @Nullable @Schema(description = "Sunrise at the meeting point, on the departure's local date")
        Instant sunrise,
    @Nullable @Schema(description = "Sunset at the meeting point, on the departure's local date")
        Instant sunset,
    @Nullable @Schema(description = "When the forecast of the meeting point was last fetched")
        Instant fetchedAt) {

  public static DepartureWeatherDto from(DepartureWeather departure) {
    return new DepartureWeatherDto(
        departure.status(),
        WeatherConditionsDto.fromNullable(departure.conditions()),
        departure.sunrise(),
        departure.sunset(),
        departure.fetchedAt());
  }
}
