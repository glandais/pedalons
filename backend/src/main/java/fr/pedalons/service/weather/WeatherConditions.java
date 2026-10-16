package fr.pedalons.service.weather;

import fr.pedalons.enums.WeatherCondition;
import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * The forecast of one hour at one place. °C, %, mm.
 *
 * @param time the forecast hour used — the one nearest the moment asked about
 * @param daylight whether the moment asked about — not {@code time}, the round model hour — falls
 *     between sunrise and sunset there
 * @param precipitationProbability null when the model gives none
 */
public record WeatherConditions(
    Instant time,
    int weatherCode,
    WeatherCondition condition,
    boolean daylight,
    double temperature,
    double apparentTemperature,
    @Nullable Integer precipitationProbability,
    double precipitation,
    Wind wind) {}
