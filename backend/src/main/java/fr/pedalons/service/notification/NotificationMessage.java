package fr.pedalons.service.notification;

import fr.pedalons.enums.NotificationChange;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationSubjectType;
import fr.pedalons.enums.NotificationType;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * Everything a channel sender needs to deliver one notification, as plain values.
 *
 * <p>Holds no entity: senders run outside any transaction (a provider call must not hold a JDBC
 * connection), and a detached proxy there would fail on first touch.
 */
public record NotificationMessage(
    Long deliveryId,
    /** The inbox row this delivery mirrors — what a push hands the app so a tap can mark it read. */
    Long notificationId,
    /** Needed by a channel whose address is not on the user row: push resolves their devices. */
    Long recipientUserId,
    NotificationChannel channel,
    NotificationType type,
    String recipientEmail,
    String recipientName,
    @Nullable String recipientLanguage,
    /** The reader's own zone, null when they have none: the « chez vous » of a rendezvous. */
    @Nullable String recipientTimezone,
    @Nullable String actorName,
    String teamSlug,
    String teamName,
    NotificationSubjectType subjectType,
    String subjectSlug,
    String subjectName,
    @Nullable Instant subjectDateTime,
    /**
     * The zone the subject's rendezvous reads in, frozen with {@code subjectDateTime}; null on a row
     * fanned out before it was (docs/LEDGER_*.md API-60).
     */
    @Nullable String subjectTimezone,
    @Nullable String excerpt,
    String baseUrl,
    String siteName,
    /** What a {@code RIDE_UPDATED} says changed; empty for every other type. */
    List<NotificationChange> changes) {

  /** The page the notification opens, on the site of the recipient's team. */
  public String subjectUrl() {
    return baseUrl + NotificationLinks.subjectPath(subjectType, teamSlug, subjectSlug);
  }

  /** When delivering this stops being worth it; null when never — see {@link NotificationType#expiresAt}. */
  public @Nullable Instant expiresAt() {
    return type.expiresAt(subjectDateTime);
  }

  /** Past its {@link #expiresAt()}: a channel that is not a record of the past must not send it. */
  public boolean isExpired(Instant now) {
    Instant expiresAt = expiresAt();
    return expiresAt != null && !expiresAt.isAfter(now);
  }

  public String preferencesUrl() {
    return baseUrl + NotificationLinks.PREFERENCES_PATH;
  }
}
