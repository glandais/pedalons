package fr.pedalons.service.notification;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.domain.notification.TeamWebhook;
import fr.pedalons.domain.notification.TeamWebhookDelivery;
import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.infrastructure.webhook.WebhookHttpClient;
import fr.pedalons.repository.notification.TeamWebhookDeliveryRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.net.URI;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Sends the team webhooks' queue — stage 3 for the one channel that is per event rather than per
 * recipient. Same sequence as {@link NotificationDeliveryService}: claim, load plain values, post
 * outside any transaction, mark.
 *
 * <p>What is retried differs: an endpoint that answers 4xx (other than 408 and 429) said no, and
 * saying it again would not change its mind; a URL refused by the address check never will be
 * accepted. Both fail at once. A 5xx, a timeout, a refused connection back off like any delivery.
 */
@ApplicationScoped
public class TeamWebhookDeliveryService {

  private static final Logger LOG = Logger.getLogger(TeamWebhookDeliveryService.class);

  @Inject TeamWebhookDeliveryRepository deliveryRepository;
  @Inject TeamWebhookMessages messages;
  @Inject WebhookHttpClient http;

  @ConfigProperty(name = "pedalons.notifications.delivery.batch-size", defaultValue = "50")
  int batchSize;

  @ConfigProperty(name = "pedalons.notifications.delivery.max-attempts", defaultValue = "5")
  int maxAttempts;

  @ConfigProperty(name = "pedalons.notifications.delivery.backoff-seconds", defaultValue = "60")
  int backoffSeconds;

  @ConfigProperty(name = "pedalons.notifications.stuck-after-minutes", defaultValue = "15")
  int stuckAfterMinutes;

  /** One post to make: already rendered, so nothing is read from an entity outside a transaction. */
  private record Post(long deliveryId, URI url, String json) {}

  /** The outcome of one post. {@code retry} only matters when it failed. */
  record Outcome(
      boolean success, boolean retry, @Nullable Integer statusCode, @Nullable String error) {}

  /** Sends one batch of due webhook deliveries. Returns how many were claimed. */
  public int sendDue() {
    Instant now = Instant.now();
    List<Long> ids =
        QuarkusTransaction.requiringNew()
            .call(() -> {
              List<Long> due = deliveryRepository.lockDue(now, batchSize);
              if (!due.isEmpty()) {
                deliveryRepository.markSending(due, now);
              }
              return due;
            });
    if (ids.isEmpty()) {
      return 0;
    }
    List<Post> posts = QuarkusTransaction.requiringNew().call(() -> load(ids));
    for (Post post : posts) {
      Outcome outcome = post(post.url(), post.json());
      if (!outcome.success()) {
        LOG.warnf(
            "Team webhook delivery %s failed: %s",
            TsidUtils.toString(post.deliveryId()), outcome.error());
      }
      mark(post.deliveryId(), outcome);
    }
    return ids.size();
  }

  /**
   * The rows whose webhook was switched off, whose team was deleted, or whose URL can no longer be
   * parsed, are marked {@code SKIPPED} here rather than sent.
   */
  private List<Post> load(List<Long> ids) {
    List<Post> posts = new ArrayList<>();
    for (TeamWebhookDelivery delivery : deliveryRepository.findWithContent(ids)) {
      TeamWebhook webhook = delivery.getWebhook();
      NotificationEventEntry event = delivery.getEvent();
      URI url = parse(webhook.getUrl());
      if (!webhook.isEnabled()
          || webhook.getTeam().isDeleted()
          || url == null
          || event.getTeamName() == null) {
        delivery.setStatus(NotificationDeliveryStatus.SKIPPED);
        continue;
      }
      posts.add(
          new Post(
              delivery.getId(),
              url,
              messages.forEvent(
                  event, url, webhook.getLanguage(), webhook.getTeam().getTimezone())));
    }
    return posts;
  }

  /** Posts one document and classifies the answer. Also what the "test" button uses. */
  Outcome post(URI url, String json) {
    try {
      int status = http.post(url, json);
      if (status >= 200 && status < 300) {
        return new Outcome(true, false, status, null);
      }
      boolean retry = status >= 500 || status == 408 || status == 429;
      return new Outcome(false, retry, status, "HTTP " + status);
    } catch (WebhookHttpClient.ForbiddenTargetException e) {
      return new Outcome(false, false, null, e.getMessage());
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return new Outcome(false, true, null, "Interrupted");
    } catch (Exception e) {
      return new Outcome(false, true, null, e.getClass().getSimpleName());
    }
  }

  void mark(long deliveryId, Outcome outcome) {
    QuarkusTransaction.requiringNew()
        .run(() -> {
          TeamWebhookDelivery delivery = deliveryRepository.findById(deliveryId);
          if (delivery == null) {
            return;
          }
          Instant now = Instant.now();
          NotificationDeliveryStatus status;
          if (outcome.success()) {
            status = NotificationDeliveryStatus.SENT;
            delivery.setSentAt(now);
            delivery.setErrorMessage(null);
          } else if (outcome.retry() && delivery.getAttempts() < maxAttempts) {
            status = NotificationDeliveryStatus.PENDING;
            delivery.setNextAttemptAt(
                now.plus(
                    NotificationDispatchService.backoff(backoffSeconds, delivery.getAttempts())));
            delivery.setErrorMessage(outcome.error());
          } else {
            status = NotificationDeliveryStatus.FAILED;
            delivery.setErrorMessage(outcome.error());
          }
          delivery.setStatus(status);
          TeamWebhook webhook = delivery.getWebhook();
          webhook.setLastStatus(status);
          webhook.setLastError(outcome.error());
          webhook.setLastAttemptAt(now);
        });
  }

  @Transactional
  public int recoverStuck() {
    return deliveryRepository.resetStuck(
        Instant.now().minus(stuckAfterMinutes, ChronoUnit.MINUTES), maxAttempts);
  }

  static @Nullable URI parse(String url) {
    try {
      return URI.create(url);
    } catch (IllegalArgumentException e) {
      return null;
    }
  }
}
