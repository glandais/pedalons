package fr.pedalons.dto.users.export;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.notification.Notification;
import fr.pedalons.domain.notification.NotificationDelivery;
import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.domain.notification.NotificationPreference;
import fr.pedalons.domain.notification.NotificationTeamMute;
import fr.pedalons.domain.notification.PushDevice;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * What the notification pipeline holds about the user: the inbox, the channels each entry went out
 * on, the preference overrides, the settings and muted teams, and the registered devices.
 */
public final class NotificationExport {

  private NotificationExport() {}

  /**
   * {@code notifications/inbox.json}. The snapshot the entry renders from, not a pre-rendered text
   * — the same fields the inbox itself reads. {@code subjectTimezone} is the zone the subject's
   * date reads in, frozen at fan-out (docs/LEDGER_*.md API-60); null on an entry from before it.
   */
  public record InboxEntry(
      String id,
      String type,
      Instant createdAt,
      @Nullable Instant readAt,
      @Nullable String teamName,
      @Nullable String subjectType,
      @Nullable String subjectName,
      @Nullable Instant subjectDateTime,
      @Nullable String subjectTimezone,
      @Nullable String actorName,
      @Nullable String excerpt,
      List<Delivery> deliveries) {

    public static InboxEntry from(Notification n, List<Delivery> deliveries) {
      NotificationEventEntry e = n.getEvent();
      return new InboxEntry(
          TsidUtils.toString(n.getId()),
          n.getType().name(),
          n.getCreatedAt(),
          n.getReadAt(),
          e.getTeamName(),
          e.getSubjectType() == null ? null : e.getSubjectType().name(),
          e.getSubjectName(),
          n.effectiveSubjectDateTime(),
          e.getSubjectTimezone(),
          e.getActorName(),
          e.getExcerpt(),
          deliveries);
    }
  }

  /** One channel an inbox entry was sent on, outside the application (e-mail, push). */
  public record Delivery(String channel, String status, int attempts, @Nullable Instant sentAt) {

    public static Delivery from(NotificationDelivery d) {
      return new Delivery(
          d.getChannel().name(), d.getStatus().name(), d.getAttempts(), d.getSentAt());
    }
  }

  /** {@code account/notification-preferences.json}. Only the cells the user changed. */
  public record Preference(String type, String channel, boolean enabled, Instant updatedAt) {

    public static Preference from(NotificationPreference p) {
      return new Preference(
          p.getType().name(), p.getChannel().name(), p.isEnabled(), p.getUpdatedAt());
    }
  }

  /**
   * {@code account/push-devices.json}. Omits {@code token}: it is the address a push is sent to, and
   * the file may travel unprotected.
   */
  public record PushDeviceEntry(
      String id,
      String platform,
      @Nullable String deviceName,
      @Nullable String appVersion,
      Instant createdAt,
      Instant lastSeenAt) {

    public static PushDeviceEntry from(PushDevice d) {
      return new PushDeviceEntry(
          TsidUtils.toString(d.getId()),
          d.getPlatform().name(),
          d.getDeviceName(),
          d.getAppVersion(),
          d.getCreatedAt(),
          d.getLastSeenAt());
    }
  }

  /**
   * {@code account/notification-settings.json}: the daily digest switch and the teams whose
   * announcements the user muted.
   */
  public record Settings(boolean emailDigest, List<MutedTeam> mutedTeams) {}

  public record MutedTeam(String teamName, Instant mutedAt) {

    public static MutedTeam from(NotificationTeamMute m) {
      return new MutedTeam(m.getTeam().getName(), m.getCreatedAt());
    }
  }
}
