package fr.pedalons.infrastructure.json;

import static java.lang.annotation.ElementType.FIELD;
import static java.lang.annotation.ElementType.METHOD;
import static java.lang.annotation.ElementType.PARAMETER;
import static java.lang.annotation.RetentionPolicy.RUNTIME;

import jakarta.inject.Qualifier;
import java.lang.annotation.Retention;
import java.lang.annotation.Target;

/**
 * The mapper that reads third-party answers (osm-route-details, biketeam, Open-Meteo, the GPS
 * services, FCM, GitHub), produced by {@link ExternalJsonMapper}.
 */
@Qualifier
@Retention(RUNTIME)
@Target({FIELD, METHOD, PARAMETER})
public @interface ExternalJson {}
