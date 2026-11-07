package fr.pedalons.service.notification.event;

import fr.pedalons.enums.NotificationType;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * A group was removed from a published ride while riders were registered to it: their
 * registrations went with it. Unlike the other records it carries more than an identifier — by the
 * time the dispatcher reads it the group and its registrations are gone, so the group's name and
 * who was registered have to travel with the event.
 *
 * <p>{@code groupStartAt} is when the group was to leave — the time its riders had registered for,
 * which the notification gives them (docs/LEDGER_*.md NOTIF-13). Null on an event queued by a
 * release that did not carry it: the notification then gives the ride's date.
 */
public record RideGroupRemoved(
    long rideId, long groupId, String groupName, List<Long> userIds, @Nullable Instant groupStartAt)
    implements NotificationEvent {

  @Override
  public NotificationType type() {
    return NotificationType.RIDE_GROUP_REMOVED;
  }

  @Override
  public String dedupKey() {
    return type().name() + ":" + groupId;
  }
}
