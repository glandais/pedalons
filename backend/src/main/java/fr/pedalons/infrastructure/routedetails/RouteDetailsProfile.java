package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.annotation.JsonValue;
import java.util.Locale;

/**
 * {@code options.profile} (api 1.5). {@code FAST}: Mapterhorn only, its own admission queue, a few
 * seconds at most — for the save of a track. {@code FULL}: IGN LiDAR HD in France, bridge decks in
 * the surface model, heuristics, up to the service's 90 s budget — the background worker only, never
 * during an HTTP request.
 */
public enum RouteDetailsProfile {
  FAST,
  FULL;

  /** The wire value. */
  @JsonValue
  public String value() {
    return name().toLowerCase(Locale.ROOT);
  }
}
