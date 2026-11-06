package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.annotation.JsonValue;
import java.util.Locale;

/**
 * {@code options.sections}: the parts of the answer to return ({@code points[]}, {@code
 * segments[]}, {@code summary}). The typology runs anyway, it carries the structures the elevation
 * corrects: leaving {@code TYPOLOGY} out only shortens the answer.
 */
public enum RouteDetailsSection {
  ELEVATION,
  TYPOLOGY,
  SUMMARY;

  /** The wire value. */
  @JsonValue
  public String value() {
    return name().toLowerCase(Locale.ROOT);
  }
}
