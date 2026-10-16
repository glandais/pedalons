package fr.pedalons.dto.weather.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.WeatherCondition;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.service.weather.RideWeatherSummary;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "A ride's weather on a card, at the meeting point, over the window from the departure to"
            + " the estimated arrival of the last group — or a trip stage's, over its checkpoints."
            + " Only OK, STALE and NOT_YET_AVAILABLE are ever sent; for NOT_YET_AVAILABLE only"
            + " status and availableFrom are set.")
@ValidateSchema
public record RideWeatherSummaryDto(
    @Schema(description = "OK, STALE or NOT_YET_AVAILABLE", required = true) WeatherStatus status,
    @Nullable
        @Schema(
            description =
                "For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure")
        Instant availableFrom,
    @Nullable @Schema(description = "WMO code at the departure hour") Integer weatherCode,
    @Nullable
        @Schema(
            description =
                "weatherCode folded into a condition, same table as WeatherConditionsDto.condition")
        WeatherCondition condition,
    @Nullable
        @Schema(
            description =
                "Whether the departure itself (not the round model hour read for it) is between"
                    + " sunrise and sunset")
        Boolean daylight,
    @Nullable @Schema(description = "Air temperature at the departure hour, °C") Double temperature,
    @Nullable @Schema(description = "Lowest temperature over the window, °C") Double temperatureMin,
    @Nullable @Schema(description = "Highest temperature over the window, °C")
        Double temperatureMax,
    @Nullable
        @Schema(
            description =
                "Highest probability of precipitation over the window, %. Absent when the model"
                    + " gives none.")
        Integer maxPrecipitationProbability,
    @Nullable @Schema(description = "Wind at the departure hour") WindDto wind,
    @Nullable
        @Schema(
            description =
                "The first hour of the window with rain likely (50 % or more). Its distance is"
                    + " absent on a ride's summary, present on a trip stage's (the checkpoint's)")
        WeatherRainAlertDto rainAlert,
    @Nullable
        @Schema(
            description =
                "IANA zone the times of this summary (rain alert) are read in, as rendezvous with"
                    + " no zone mention. Set on a trip's card, where it is its next stage's zone —"
                    + " not TripDto.timezone, the first stage's. Absent elsewhere: the owner's"
                    + " timezone (RideDto, TripStageDto) applies.")
        String timezone) {

  public static @Nullable RideWeatherSummaryDto fromNullable(@Nullable RideWeatherSummary summary) {
    return fromNullable(summary, null);
  }

  /** {@code timezone}: the zone of the summary's leg, when it is not its owner's (a trip's card). */
  public static @Nullable RideWeatherSummaryDto fromNullable(
      @Nullable RideWeatherSummary summary, @Nullable String timezone) {
    return summary == null
        ? null
        : new RideWeatherSummaryDto(
            summary.status(),
            summary.availableFrom(),
            summary.weatherCode(),
            summary.condition(),
            summary.daylight(),
            summary.temperature(),
            summary.temperatureMin(),
            summary.temperatureMax(),
            summary.maxPrecipitationProbability(),
            WindDto.fromNullable(summary.wind()),
            WeatherRainAlertDto.fromNullable(summary.rainAlert()),
            timezone);
  }
}
