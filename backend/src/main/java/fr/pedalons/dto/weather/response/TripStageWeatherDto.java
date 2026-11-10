package fr.pedalons.dto.weather.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.service.weather.RideWeatherCalculator;
import fr.pedalons.service.weather.TripWeather;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "One stage of a trip: its weather in one line, and along its route")
@ValidateSchema
public record TripStageWeatherDto(
    @Nullable
        @Schema(
            description =
                "The stage (TSID), as TripStageDto.id. Absent for the single leg of a trip"
                    + " without stages, which rides the trip's own route at its own time.")
        String stageId,
    @Nullable
        @Schema(
            description =
                "The stage's weather in one line, for its card: the first checkpoint's hour, the"
                    + " extremes over the checkpoints, the rain alert. Present when leg.status is"
                    + " OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only).")
        RideWeatherSummaryDto summary,
    @Schema(
            description =
                "The stage's route, at its estimated passages (stage speed, else 25 km/h)",
            required = true)
        WeatherLegDto leg,
    @Schema(
            description =
                "The weather when the stage leaves, at its first forecast point: conditions,"
                    + " sunrise and sunset, as RideWeatherDto.departure for a ride. OUT_OF_RANGE"
                    + " once the stage is over (its estimated end passed), NO_LOCATION without a"
                    + " route, NOT_YET_AVAILABLE beyond the horizon.",
            required = true)
        DepartureWeatherDto departure) {

  public static TripStageWeatherDto from(TripWeather.StageLeg stage) {
    return new TripStageWeatherDto(
        stage.stageId() != null ? TsidUtils.toString(stage.stageId()) : null,
        RideWeatherSummaryDto.fromNullable(RideWeatherCalculator.legSummary(stage.leg())),
        WeatherLegDto.from(stage.leg()),
        DepartureWeatherDto.from(stage.departure()));
  }
}
