package fr.pedalons.service.notification.event;

import fr.pedalons.enums.NotificationType;
import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * The date or meeting point of a published ride changed. Carries the state <em>before</em> the
 * change: the resolver compares it with the ride as it is by then, so an edit undone before the
 * dispatch notifies nobody, and several edits in a row notify once, of their net effect.
 *
 * <p>Keyed by the ride alone, and that key is only held while the event waits — see {@link
 * #coalescesWhilePending()}. The first edit's row wins the {@code ON CONFLICT DO NOTHING}, so the
 * state it carries is the one before the whole series.
 */
public record RideUpdated(
    long rideId, Instant previousDateTime, @Nullable Long previousStartPlaceId)
    implements NotificationEvent {

  @Override
  public NotificationType type() {
    return NotificationType.RIDE_UPDATED;
  }

  @Override
  public String dedupKey() {
    return type().name() + ":" + rideId;
  }
}
