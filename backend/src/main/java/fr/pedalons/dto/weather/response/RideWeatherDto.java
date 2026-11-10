package fr.pedalons.dto.weather.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.service.weather.RideWeather;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "A ride's weather, for its detail page: the meeting point at departure, then one leg per"
            + " group. Read from the server's cache only — the forecast is refreshed in the"
            + " background, never on request.")
@ValidateSchema
public record RideWeatherDto(
    @Schema(
            description =
                "Overall state. OK and STALE (shown, flagged as old) carry the forecast;"
                    + " NOT_YET_AVAILABLE comes with availableFrom; UNAVAILABLE (nothing in cache"
                    + " yet, or the provider failing) offers to retry; NO_LOCATION is worth a word"
                    + " to the organisers only; OUT_OF_RANGE (over — its last group back, the"
                    + " ride's estimated end —, cancelled) shows nothing. A ride that has left but"
                    + " whose groups are still out, or still to leave, keeps its forecast.",
            required = true)
        WeatherStatus status,
    @Nullable
        @Schema(
            description =
                "For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure")
        Instant availableFrom,
    @Nullable @Schema(description = "The oldest fetch among the forecasts read") Instant fetchedAt,
    @Schema(
            description =
                "The meeting point when the ride leaves (its dateTime). Each leg carries its own,"
                    + " at the group's start.",
            required = true)
        DepartureWeatherDto departure,
    @Schema(
            description =
                "One per group, in group order; a single one without groupId for a ride without"
                    + " groups. Empty for OUT_OF_RANGE, NO_LOCATION and NOT_YET_AVAILABLE.",
            required = true)
        List<WeatherLegDto> legs,
    @Schema(description = "The credit the forecast's licence asks for", required = true)
        WeatherAttributionDto attribution) {

  public static RideWeatherDto from(RideWeather weather, WeatherAttributionDto attribution) {
    return new RideWeatherDto(
        weather.status(),
        weather.availableFrom(),
        weather.fetchedAt(),
        DepartureWeatherDto.from(weather.departure()),
        weather.legs().stream().map(WeatherLegDto::from).toList(),
        attribution);
  }
}
