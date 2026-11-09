package fr.pedalons.service.notification;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.notification.PushDevice;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.PushPlatform;
import fr.pedalons.infrastructure.push.FcmClient;
import fr.pedalons.infrastructure.push.FcmException;
import fr.pedalons.repository.notification.PushDeviceRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.jboss.logging.Logger;

/**
 * The {@link NotificationChannel#PUSH} channel: one FCM message per registered device of the
 * recipient.
 *
 * <p>Off unless a service account is configured — see {@link FcmClient#isConfigured()}. Until then
 * the channel is unavailable, so the fan-out queues no push delivery and the preferences screen
 * offers no switch that would do nothing.
 */
@ApplicationScoped
public class PushNotificationSender implements NotificationChannelSender {

  private static final Logger LOG = Logger.getLogger(PushNotificationSender.class);

  @Inject FcmClient fcm;
  @Inject PushDeviceRepository deviceRepository;
  @Inject NotificationTexts texts;

  /** A device's address, read inside a short transaction and used outside every transaction. */
  private record Target(String token, PushPlatform platform) {}

  @Override
  public NotificationChannel channel() {
    return NotificationChannel.PUSH;
  }

  @Override
  public boolean isEnabled() {
    return fcm.isConfigured();
  }

  @Override
  public void send(NotificationMessage message) throws Exception {
    List<Target> targets =
        QuarkusTransaction.requiringNew()
            .call(() ->
                deviceRepository.findByUser(message.recipientUserId()).stream()
                    .map(PushNotificationSender::target)
                    .toList());
    if (targets.isEmpty()) {
      // Not a failure: the member simply has no device registered, which is the normal state for
      // everyone on the web. Throwing here would retry until the delivery gave up as FAILED.
      LOG.debugf("Push delivery %s: no registered device", message.deliveryId());
      return;
    }

    NotificationTexts.Rendered rendered = texts.render(message);
    Map<String, String> data = data(message);
    List<String> dead = new ArrayList<>();
    int sent = 0;
    Exception retryable = null;
    for (Target target : targets) {
      try {
        fcm.send(target.token(), target.platform(), rendered.title(), rendered.body(), data);
        sent++;
      } catch (FcmException e) {
        if (e.tokenInvalid()) {
          dead.add(target.token());
        } else {
          retryable = e;
        }
      }
    }
    purge(dead);

    // A token FCM refuses for good is not a reason to retry — the row is gone, and the next attempt
    // would find the same nothing. Only a transient failure, with nothing delivered, goes back on
    // the queue: had one device succeeded, retrying would push it twice.
    if (sent == 0 && retryable != null) {
      throw retryable;
    }
  }

  private void purge(List<String> tokens) {
    if (tokens.isEmpty()) {
      return;
    }
    long removed =
        QuarkusTransaction.requiringNew().call(() -> deviceRepository.deleteByTokens(tokens));
    LOG.infof("Purged %d push device(s) FCM no longer knows", removed);
  }

  private static Target target(PushDevice device) {
    return new Target(device.getToken(), device.getPlatform());
  }

  /**
   * What the app reads when the member taps the notification: the type it words itself, the inbox
   * row to mark read, and the in-app path to open — the same path the e-mail links to, so a route
   * renamed in {@code contracts/routes.yaml} moves both at once.
   */
  private static Map<String, String> data(NotificationMessage message) {
    Map<String, String> data = new LinkedHashMap<>();
    data.put("type", message.type().name());
    data.put("notificationId", TsidUtils.toString(message.notificationId()));
    data.put("teamSlug", message.teamSlug());
    data.put("subjectType", message.subjectType().name());
    data.put("subjectSlug", message.subjectSlug());
    data.put(
        "path",
        NotificationLinks.subjectPath(
            message.subjectType(), message.teamSlug(), message.subjectSlug()));
    return data;
  }
}
