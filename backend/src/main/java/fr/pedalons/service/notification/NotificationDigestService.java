package fr.pedalons.service.notification;

import fr.pedalons.domain.notification.NotificationDelivery;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.infrastructure.email.EmailService;
import fr.pedalons.repository.notification.NotificationDeliveryRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.jboss.logging.Logger;

/**
 * Sends the daily digests: every due {@code digest} e-mail delivery of one recipient, as one
 * message.
 *
 * <p>The ordinary sender never touches these rows. The fan-out made them due at the recipient's
 * next digest time; this service claims them per recipient, with the same claim → load → send
 * outside any transaction → mark sequence as {@link NotificationDeliveryService}. A digest either
 * leaves whole or is retried whole: its rows share one outcome.
 */
@ApplicationScoped
public class NotificationDigestService {

  private static final Logger LOG = Logger.getLogger(NotificationDigestService.class);

  /** Recipients handled per tick at most, so one tick never runs for long. */
  private static final int RECIPIENTS_PER_TICK = 50;

  @Inject NotificationDeliveryRepository deliveryRepository;
  @Inject NotificationDeliveryService deliveryService;
  @Inject NotificationChannels channels;
  @Inject NotificationTexts texts;
  @Inject EmailService emailService;

  private record Digest(List<NotificationMessage> messages, List<Long> skipped) {}

  /** Returns how many digests were sent. */
  public int sendDue() {
    if (channels.sender(NotificationChannel.EMAIL).isEmpty()) {
      return 0;
    }
    Instant now = Instant.now();
    List<Long> recipients =
        QuarkusTransaction.requiringNew()
            .call(() -> deliveryRepository.findDueDigestRecipients(now, RECIPIENTS_PER_TICK));
    int sent = 0;
    for (Long recipientId : recipients) {
      if (sendOne(recipientId, now)) {
        sent++;
      }
    }
    return sent;
  }

  boolean sendOne(Long recipientId, Instant now) {
    List<Long> ids =
        QuarkusTransaction.requiringNew()
            .call(() -> {
              List<Long> due = deliveryRepository.lockDueDigest(recipientId, now);
              if (!due.isEmpty()) {
                deliveryRepository.markSending(due, now);
              }
              return due;
            });
    if (ids.isEmpty()) {
      return false; // another worker took them
    }
    Digest digest = QuarkusTransaction.requiringNew().call(() -> load(ids));
    digest
        .skipped()
        .forEach(id -> deliveryService.mark(id, NotificationDeliveryStatus.SKIPPED, null));
    List<NotificationMessage> messages = digest.messages();
    if (messages.isEmpty()) {
      return false;
    }
    try {
      send(messages);
      messages.forEach(
          m -> deliveryService.mark(m.deliveryId(), NotificationDeliveryStatus.SENT, null));
      return true;
    } catch (Exception e) {
      LOG.warnf(e, "Notification digest for %s failed", recipientId);
      messages.forEach(
          m -> deliveryService.mark(m.deliveryId(), NotificationDeliveryStatus.PENDING, e));
      return false;
    }
  }

  private Digest load(List<Long> ids) {
    List<NotificationMessage> messages = new ArrayList<>();
    List<Long> skipped = new ArrayList<>();
    for (NotificationDelivery delivery : deliveryRepository.findWithContent(ids)) {
      NotificationMessage message = NotificationDeliveryService.toMessage(delivery);
      if (message == null) {
        skipped.add(delivery.getId());
      } else {
        messages.add(message);
      }
    }
    // Oldest first: the digest reads as the day went.
    messages.sort((a, b) -> Long.compare(a.notificationId(), b.notificationId()));
    return new Digest(messages, skipped);
  }

  /**
   * One e-mail. The site named and linked is the first item's: a member of two clubs on two aliases
   * gets one digest, not one per site.
   */
  private void send(List<NotificationMessage> messages) {
    NotificationMessage first = messages.getFirst();
    List<Map<String, Object>> items = new ArrayList<>();
    List<String> headings = new ArrayList<>();
    for (NotificationMessage message : messages) {
      NotificationTexts.Rendered rendered = texts.render(message);
      Map<String, Object> item = new HashMap<>();
      // The heading, not the title: a ride is named with its date, and a digest is read the next
      // morning, so nothing in it may say « demain » (docs/LEDGER_*.md NOTIF-14).
      item.put("title", rendered.heading());
      headings.add(rendered.heading());
      item.put("body", rendered.body());
      item.put("ctaLabel", rendered.cta());
      item.put("ctaUrl", message.subjectUrl());
      items.add(item);
    }
    String language = first.recipientLanguage();
    emailService.sendEmail(
        first.recipientEmail(),
        EmailService.NOTIFICATION_DIGEST,
        NotificationTexts.language(language),
        Map.of(
            "appName", first.siteName(),
            "recipientName", first.recipientName(),
            "subject", texts.digestText(language, "subject", messages.size()),
            "title", texts.digestText(language, "title", messages.size()),
            "intro", texts.digestText(language, "intro", messages.size()),
            "items", items,
            // The preview a mail client shows beside the subject: what the digest holds, by date
            // and name.
            "preheader", String.join(" | ", headings),
            "preferencesUrl", first.preferencesUrl()));
  }
}
