package fr.pedalons.infrastructure.gpx;

import fr.pedalons.enums.ElevationQuality;
import jakarta.inject.Qualifier;
import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Selects one of the two {@code ElevationProvider} beans of {@link VcyclistProducer}: {@code
 * @ElevationTier(ElevationQuality.FAST)} or {@code @ElevationTier(ElevationQuality.HD)}.
 */
@Qualifier
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.FIELD, ElementType.PARAMETER, ElementType.TYPE})
public @interface ElevationTier {

  ElevationQuality value();
}
