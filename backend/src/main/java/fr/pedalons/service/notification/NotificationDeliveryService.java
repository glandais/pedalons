package fr.pedalons.service.notification;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.notification.Notification;
import fr.pedalons.domain.notification.NotificationDelivery;
import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.repository.notification.NotificationDeliveryRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Stage 3 of the notification pipeline: sends the due deliveries of one channel.
 *
 * <p>Claim (short transaction) → load plain values (short transaction) → send with no transaction
 * open → mark each result (short transaction). A provider call never holds a JDBC connection.
 *
 * <p>At least once, not exactly once: a send that succeeds and whose marking then fails is sent
 * again after {@code stuck-after-minutes}. For a notification, a rare duplicate beats a silent loss.
 */
@ApplicationScoped
public class NotificationDeliveryService {

  private static final Logger LOG = Logger.getLogger(NotificationDeliveryService.class);

  @Inject NotificationDeliveryRepository deliveryRepository;
  @Inject NotificationChannels channels;

  @ConfigProperty(name = "pedalons.notifications.delivery.batch-size", defaultValue = "50")
  int batchSize;

  @ConfigProperty(name = "pedalons.notifications.delivery.max-attempts", defaultValue = "5")
  int maxAttempts;

  /** Through the CDI proxy, where the field itself reads 0. */
  int maxAttempts() {
    return maxAttempts;
  }

  @ConfigProperty(name = "pedalons.notifications.delivery.backoff-seconds", defaultValue = "60")
  int backoffSeconds;

  @ConfigProperty(name = "pedalons.notifications.stuck-after-minutes", defaultValue = "15")
  int stuckAfterMinutes;

  private record Batch(List<NotificationMessage> messages, List<Long> skipped) {}

  /** Sends one batch of due deliveries on {@code channel}. Returns how many were claimed. */
  public int sendDue(NotificationChannel channel) {
    Optional<NotificationChannelSender> sender = channels.sender(channel);
    if (sender.isEmpty()) {
      return 0;
    }
    Instant now = Instant.now();
    List<Long> ids =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  List<Long> due = deliveryRepository.lockDue(channel, now, batchSize);
                  if (!due.isEmpty()) {
                    deliveryRepository.markSending(due, now);
                  }
                  return due;
                });
    if (ids.isEmpty()) {
      return 0;
    }

    Batch batch = QuarkusTransaction.requiringNew().call(() -> load(ids));
    batch.skipped().forEach(id -> mark(id, NotificationDeliveryStatus.SKIPPED, null));
    for (NotificationMessage message : batch.messages()) {
      try {
        sender.get().send(message);
        mark(message.deliveryId(), NotificationDeliveryStatus.SENT, null);
      } catch (Exception e) {
        LOG.warnf(
            e,
            "Notification delivery %s on %s failed",
            TsidUtils.toString(message.deliveryId()),
            channel);
        mark(message.deliveryId(), NotificationDeliveryStatus.PENDING, e);
      }
    }
    return ids.size();
  }

  private Batch load(List<Long> ids) {
    List<NotificationMessage> messages = new ArrayList<>();
    List<Long> skipped = new ArrayList<>();
    for (NotificationDelivery delivery : deliveryRepository.findWithContent(ids)) {
      NotificationMessage message = toMessage(delivery);
      if (message == null) {
        skipped.add(delivery.getId());
      } else {
        messages.add(message);
      }
    }
    return new Batch(messages, skipped);
  }

  /** Null when there is nothing left to send to: the recipient was deleted since the fan-out. */
  static @Nullable NotificationMessage toMessage(NotificationDelivery delivery) {
    Notification notification = delivery.getNotification();
    NotificationEventEntry event = notification.getEvent();
    User recipient = notification.getRecipient();
    if (recipient.isDeleted()
        || event.getTeamSlug() == null
        || event.getTeamName() == null
        || event.getSubjectType() == null
        || event.getSubjectSlug() == null
        || event.getSubjectName() == null
        || event.getBaseUrl() == null
        || event.getSiteName() == null) {
      return null;
    }
    return new NotificationMessage(
        delivery.getId(),
        notification.getId(),
        recipient.getId(),
        delivery.getChannel(),
        notification.getType(),
        recipient.getEmail(),
        recipient.getDisplayName(),
        recipient.getLanguage(),
        recipient.getTimezone(),
        event.getActorName(),
        event.getTeamSlug(),
        event.getTeamName(),
        event.getSubjectType(),
        event.getSubjectSlug(),
        event.getSubjectName(),
        // The recipient's own start, their group's (docs/LEDGER_*.md NOTIF-13).
        notification.effectiveSubjectDateTime(),
        event.getSubjectTimezone(),
        event.getExcerpt(),
        event.getBaseUrl(),
        event.getSiteName(),
        event.changeList());
  }

  /**
   * Records the outcome of one delivery. {@code PENDING} with a cause means "failed, retry":
   * exponential backoff from {@code backoff-seconds}, capped, until {@code max-attempts}.
   */
  void mark(long deliveryId, NotificationDeliveryStatus status, @Nullable Exception cause) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              NotificationDelivery delivery = deliveryRepository.findById(deliveryId);
              if (delivery == null) {
                return;
              }
              Instant now = Instant.now();
              if (status == NotificationDeliveryStatus.PENDING) {
                delivery.setErrorMessage(
                    cause == null ? null : NotificationDispatchService.truncate(cause.toString()));
                if (delivery.getAttempts() >= maxAttempts) {
                  delivery.setStatus(NotificationDeliveryStatus.FAILED);
                } else {
                  delivery.setStatus(NotificationDeliveryStatus.PENDING);
                  delivery.setNextAttemptAt(
                      now.plus(
                          NotificationDispatchService.backoff(
                              backoffSeconds, delivery.getAttempts())));
                }
                return;
              }
              delivery.setStatus(status);
              delivery.setErrorMessage(null);
              if (status == NotificationDeliveryStatus.SENT) {
                delivery.setSentAt(now);
              }
            });
  }

  /**
   * Puts back on the queue the deliveries a crash left in SENDING, and fails those that had no
   * attempt left.
   */
  @Transactional
  public int recoverStuck() {
    return deliveryRepository.resetStuck(
        Instant.now().minus(stuckAfterMinutes, ChronoUnit.MINUTES), maxAttempts);
  }
}
