package fr.pedalons.dto.weather.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.WeatherCondition;
import fr.pedalons.service.weather.WeatherConditions;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "The forecast of one hour at one place")
@ValidateSchema
public record WeatherConditionsDto(
    @Schema(
            description = "The forecast hour used: the one nearest the moment asked about",
            required = true)
        Instant time,
    @Schema(
            description =
                "WMO weather interpretation code, as the model gives it. condition is its folding;"
                    + " a client reads condition, this is for the curious.",
            required = true)
        int weatherCode,
    @Schema(
            description =
                "weatherCode folded into what a rider decides on. WMO code → condition: 0 CLEAR;"
                    + " 1 MOSTLY_CLEAR; 2 PARTLY_CLOUDY; 3 OVERCAST; 45, 48 FOG; 51, 53, 55"
                    + " DRIZZLE; 56, 57, 66, 67 FREEZING_RAIN; 61, 63 RAIN; 65 HEAVY_RAIN; 71, 73,"
                    + " 75, 77, 85, 86 SNOW; 80, 81, 82 SHOWERS; 95, 96, 99 THUNDERSTORM; any other"
                    + " OVERCAST. A client meeting a value it does not know shows a plain cloud.",
            required = true)
        WeatherCondition condition,
    @Schema(
            description =
                "Whether the moment asked about (the departure, the checkpoint's passage) falls"
                    + " between sunrise and sunset at that place — not time, the round model hour."
                    + " Picks the day or night icon",
            required = true)
        boolean daylight,
    @Schema(description = "Air temperature at 2 m, °C", required = true) double temperature,
    @Schema(description = "Felt temperature (wind chill, humidity), °C", required = true)
        double apparentTemperature,
    @Nullable
        @Schema(
            description =
                "Probability of precipitation, % (0–100). Absent when the model gives" + " none.")
        Integer precipitationProbability,
    @Schema(description = "Precipitation over the hour (rain, showers, snow), mm", required = true)
        double precipitation,
    @Schema(description = "Wind of that hour", required = true) WindDto wind) {

  public static WeatherConditionsDto from(WeatherConditions conditions) {
    return new WeatherConditionsDto(
        conditions.time(),
        conditions.weatherCode(),
        conditions.condition(),
        conditions.daylight(),
        conditions.temperature(),
        conditions.apparentTemperature(),
        conditions.precipitationProbability(),
        conditions.precipitation(),
        WindDto.from(conditions.wind()));
  }

  public static @Nullable WeatherConditionsDto fromNullable(
      @Nullable WeatherConditions conditions) {
    return conditions == null ? null : from(conditions);
  }
}
