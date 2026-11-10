package fr.pedalons.dto.weather.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.service.weather.RideWeatherCalculator;
import fr.pedalons.service.weather.WeatherLeg;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "The weather along one ridden route: a group of a ride, or a stage of a trip. Passages are"
            + " estimated from startTime at averageSpeed.")
@ValidateSchema
public record WeatherLegDto(
    @Nullable
        @Schema(
            description =
                "The ride group (TSID). Absent for a ride without groups — the leg rides the ride's"
                    + " own route — and for a trip's legs, which TripStageWeatherDto.stageId"
                    + " names.")
        String groupId,
    @Schema(
            description =
                "State of this leg's forecast. NO_LOCATION when the leg has no route to sample:"
                    + " then no checkpoint, no segment. NOT_YET_AVAILABLE when it leaves beyond the"
                    + " seven-day horizon: checkpoints and times without weather, and"
                    + " availableFrom. OUT_OF_RANGE for a trip stage already over (its estimated"
                    + " end passed): nothing to show.",
            required = true)
        WeatherStatus status,
    @Nullable
        @Schema(
            description =
                "For NOT_YET_AVAILABLE: when this leg's forecast opens, seven days before it"
                    + " leaves")
        Instant availableFrom,
    @Schema(description = "When the leg leaves", required = true) Instant startTime,
    @Schema(description = "Speed used for the passages, km/h", required = true) double averageSpeed,
    @Schema(
            description =
                "Whether averageSpeed is the 25 km/h default, the group or stage having none — to"
                    + " be said on screen",
            required = true)
        boolean speedIsDefault,
    @Schema(description = "Length of the leg's route, metres", required = true) double distance,
    @Schema(description = "Estimated arrival", required = true) Instant arrivalTime,
    @Nullable @Schema(description = "The oldest fetch among the forecasts this leg reads")
        Instant fetchedAt,
    @Schema(description = "Forecast points, start to finish", required = true)
        List<WeatherCheckpointDto> checkpoints,
    @Schema(
            description = "The wind stretch by stretch, from one checkpoint to the next",
            required = true)
        List<WindSegmentDto> segments,
    @Schema(description = "Distance ridden against, across and with the wind", required = true)
        WindExposureDto windExposure,
    @Nullable
        @Schema(
            description =
                "The leg's dominant wind: circular mean of the directions, mean speed, highest"
                    + " gust")
        WindDto prevailingWind,
    @Nullable @Schema(description = "The first checkpoint where rain becomes likely, if any")
        WeatherRainAlertDto rainAlert,
    @Nullable
        @Schema(
            description =
                "The leg's weather in one line, for its card: the first checkpoint's hour, the"
                    + " extremes over the checkpoints, the rain alert — as"
                    + " TripStageWeatherDto.summary for a stage. Present when status is OK, STALE"
                    + " or NOT_YET_AVAILABLE (then status and availableFrom only).")
        RideWeatherSummaryDto summary,
    @Nullable
        @Schema(
            description =
                "For a ride's leg: the weather at the ride's meeting point when this group leaves"
                    + " (startTime), sunrise and sunset included — RideWeatherDto.departure is the"
                    + " same at the ride's own time. Same states: conditions for OK and STALE only,"
                    + " UNAVAILABLE when the cache has no hour near the group's start,"
                    + " NOT_YET_AVAILABLE when the group leaves beyond the horizon. Absent on a"
                    + " trip's legs, whose departure TripStageWeatherDto.departure carries.")
        DepartureWeatherDto departure) {

  public static WeatherLegDto from(WeatherLeg leg) {
    return new WeatherLegDto(
        leg.groupId() != null ? TsidUtils.toString(leg.groupId()) : null,
        leg.status(),
        leg.availableFrom(),
        leg.startTime(),
        leg.averageSpeed(),
        leg.speedIsDefault(),
        leg.distance(),
        leg.arrivalTime(),
        leg.fetchedAt(),
        leg.checkpoints().stream().map(WeatherCheckpointDto::from).toList(),
        leg.segments().stream().map(WindSegmentDto::from).toList(),
        WindExposureDto.from(leg.windExposure()),
        WindDto.fromNullable(leg.prevailingWind()),
        WeatherRainAlertDto.fromNullable(leg.rainAlert()),
        RideWeatherSummaryDto.fromNullable(RideWeatherCalculator.legSummary(leg)),
        leg.departure() != null ? DepartureWeatherDto.from(leg.departure()) : null);
  }
}
