package fr.pedalons.dto.gpx.request;

import fr.pedalons.dto.common.EventDateTime;
import org.jspecify.annotations.Nullable;

/**
 * What a save of a GPX preview says about its departure date and its average speed
 * (docs/LEDGER_*.md API-153). Each of the two is independent: left out, it stays; given, it is
 * replaced; cleared, it is removed.
 *
 * @param departure the wall time at the start of the track, no offset
 * @param averageSpeed km/h
 */
public record PreviewDepartureEdit(
    @Nullable EventDateTime departure,
    boolean clearDeparture,
    @Nullable Float averageSpeed,
    boolean clearAverageSpeed) {

  /** Nothing said: the date follows the track, the speed stays. */
  public static final PreviewDepartureEdit KEEP =
      new PreviewDepartureEdit(null, false, null, false);

  /** A creation, or a save that gives values and clears nothing. */
  public static PreviewDepartureEdit of(
      @Nullable EventDateTime departure, @Nullable Float averageSpeed) {
    return new PreviewDepartureEdit(departure, false, averageSpeed, false);
  }

  /** A value and its removal at the same time. */
  public boolean isContradictory() {
    return (departure != null && clearDeparture) || (averageSpeed != null && clearAverageSpeed);
  }
}
