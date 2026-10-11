package fr.pedalons.service.notification;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.notification.Notification;
import fr.pedalons.domain.notification.NotificationDelivery;
import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.domain.notification.NotificationPreference;
import fr.pedalons.domain.notification.TeamWebhookDelivery;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationEventStatus;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.repository.notification.NotificationDeliveryRepository;
import fr.pedalons.repository.notification.NotificationEventRepository;
import fr.pedalons.repository.notification.NotificationPreferenceRepository;
import fr.pedalons.repository.notification.NotificationRepository;
import fr.pedalons.repository.notification.NotificationSettingsRepository;
import fr.pedalons.repository.notification.NotificationTeamMuteRepository;
import fr.pedalons.repository.notification.TeamWebhookDeliveryRepository;
import fr.pedalons.repository.notification.TeamWebhookRepository;
import fr.pedalons.repository.platform.DomainAliasRepository;
import fr.pedalons.repository.platform.DomainRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.notification.NotificationRecipientResolver.Resolution;
import fr.pedalons.service.notification.event.NotificationEvent;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.hibernate.Session;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Stage 2 of the notification pipeline: turns one queued event into one inbox row per recipient
 * and one delivery row per recipient and enabled out-of-app channel.
 *
 * <p>The claim and the fan-out are separate transactions, as in {@code UserExportService}: the row
 * lock is held for the claim only. The fan-out is one transaction, so an event is either fully
 * fanned out or not at all — never half a team notified and the other half retried into
 * duplicates. {@code uk_notifications_event_recipient} backs that up.
 */
@ApplicationScoped
public class NotificationDispatchService {

  private static final Logger LOG = Logger.getLogger(NotificationDispatchService.class);

  private static final Duration MAX_BACKOFF = Duration.ofHours(6);

  /** Announcements signed by the team, whoever published. */
  private static final Set<NotificationType> PUBLISHED_TYPES =
      Set.of(
          NotificationType.RIDE_PUBLISHED,
          NotificationType.TRIP_PUBLISHED,
          NotificationType.POST_PUBLISHED);

  /** When the daily digest leaves, in the recipient's time zone. */
  static final LocalTime DIGEST_TIME = LocalTime.of(7, 0);

  @Inject NotificationEventRepository eventRepository;
  @Inject NotificationRepository notificationRepository;
  @Inject NotificationDeliveryRepository deliveryRepository;
  @Inject NotificationPreferenceRepository preferenceRepository;
  @Inject NotificationTeamMuteRepository teamMuteRepository;
  @Inject NotificationSettingsRepository settingsRepository;
  @Inject TeamWebhookRepository webhookRepository;
  @Inject TeamWebhookDeliveryRepository webhookDeliveryRepository;
  @Inject NotificationRecipientResolver resolver;
  @Inject NotificationChannels channels;
  @Inject UserRepository userRepository;
  @Inject DomainRepository domainRepository;
  @Inject DomainAliasRepository domainAliasRepository;
  @Inject ObjectMapper objectMapper;

  @ConfigProperty(name = "pedalons.notifications.max-attempts", defaultValue = "3")
  int maxAttempts;

  /** Through the CDI proxy, where the field itself reads 0. */
  int maxAttempts() {
    return maxAttempts;
  }

  @ConfigProperty(name = "pedalons.notifications.backoff-seconds", defaultValue = "60")
  int backoffSeconds;

  @ConfigProperty(name = "pedalons.notifications.stuck-after-minutes", defaultValue = "15")
  int stuckAfterMinutes;

  /**
   * Claims and fans out at most one pending event. Returns whether one was claimed, so the
   * scheduler can drain a backlog within a tick.
   *
   * <p>No {@code @Transactional}: each step opens its own.
   */
  public boolean dispatchOne() {
    Optional<Long> claimed = claimNextPending();
    if (claimed.isEmpty()) {
      return false;
    }
    long eventId = claimed.get();
    try {
      QuarkusTransaction.requiringNew()
          .call(
              () -> {
                fanOut(eventId);
                return null;
              });
    } catch (Exception e) {
      LOG.errorf(e, "Notification event %s failed", TsidUtils.toString(eventId));
      markFailed(eventId, e);
    }
    return true;
  }

  Optional<Long> claimNextPending() {
    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              Long id = eventRepository.findNextDueIdSkipLocked(Instant.now());
              if (id == null) {
                return Optional.<Long>empty();
              }
              if (!eventRepository.claim(id, Instant.now())) {
                return Optional.<Long>empty();
              }
              NotificationEventEntry entry = eventRepository.findById(id);
              if (entry.getType().coalescesWhilePending()) {
                // Done waiting as of now, not as of the fan-out's commit: the fan-out is about to
                // read the subject, so an edit made from here on must queue an event of its own
                // rather than fold into this one and go unannounced (docs/LEDGER_*.md NOTIF-10).
                releaseDedupKey(entry);
              }
              return Optional.of(id);
            });
  }

  void fanOut(long eventId) throws Exception {
    NotificationEventEntry entry = eventRepository.findById(eventId);
    NotificationEvent event =
        objectMapper.treeToValue(
            entry.getPayload(), NotificationEvent.recordClass(entry.getType()));
    Instant now = Instant.now();

    Optional<Resolution> resolution = resolver.resolve(event);
    if (resolution.isEmpty()) {
      LOG.debugf("Notification %s skipped: no longer relevant", entry.getDedupKey());
      entry.setStatus(NotificationEventStatus.SKIPPED);
      entry.setProcessedAt(now);
      releaseDedupKey(entry);
      return;
    }
    snapshot(entry, resolution.get());

    List<User> recipients = recipients(resolution.get().recipients(), entry);
    if (entry.getType().isBroadcast() && !recipients.isEmpty()) {
      Set<Long> muted =
          teamMuteRepository.findMutedUserIds(
              resolution.get().team().getId(), recipients.stream().map(User::getId).toList());
      recipients.removeIf(user -> muted.contains(user.getId()));
    }
    Set<NotificationChannel> available = channels.available();
    Map<Long, Map<NotificationChannel, Boolean>> overrides =
        available.isEmpty() || recipients.isEmpty()
            ? Map.of()
            : overrides(entry.getType(), recipients);
    Set<Long> digestReaders =
        available.contains(NotificationChannel.EMAIL)
                && !entry.getType().isUrgent()
                && !recipients.isEmpty()
            ? settingsRepository.findDigestUserIds(recipients.stream().map(User::getId).toList())
            : Set.of();

    // Notifications first, deliveries after: two runs of same-table inserts batch; interleaving
    // them would flush a batch of one at every switch.
    notificationRepository.getEntityManager().unwrap(Session.class).setJdbcBatchSize(100);
    List<Notification> notifications = new ArrayList<>(recipients.size());
    for (User recipient : recipients) {
      Notification notification = new Notification(entry, recipient, now);
      notificationRepository.persist(notification);
      notifications.add(notification);
    }
    int deliveries = 0;
    for (Notification notification : notifications) {
      User recipient = notification.getRecipient();
      Map<NotificationChannel, Boolean> userOverrides =
          overrides.getOrDefault(recipient.getId(), Map.of());
      for (NotificationChannel channel : available) {
        boolean enabled =
            userOverrides.getOrDefault(channel, entry.getType().isEnabledByDefault(channel));
        if (enabled) {
          NotificationDelivery delivery = new NotificationDelivery(notification, channel, now);
          if (channel == NotificationChannel.EMAIL && digestReaders.contains(recipient.getId())) {
            delivery.setDigest(true);
            delivery.setNextAttemptAt(nextDigest(now, recipient.getTimezone()));
          }
          deliveryRepository.persist(delivery);
          deliveries++;
        }
      }
    }
    boolean relayed = queueWebhook(entry, resolution.get(), now);

    entry.setStatus(NotificationEventStatus.DONE);
    entry.setProcessedAt(now);
    entry.setErrorMessage(null);
    if (event.coalescesWhilePending()) {
      // Already given back at the claim; kept for a row claimed by the previous release.
      releaseDedupKey(entry);
    }
    LOG.infof(
        "Notification %s: %d recipient(s), %d delivery(ies)%s",
        entry.getDedupKey(), notifications.size(), deliveries, relayed ? ", team webhook" : "");
  }

  /**
   * Queues the event for the team's webhook, when the type is one a team channel wants to read and
   * the team has an enabled webhook. Independent of the recipients: a ride published in a team whose
   * members all muted it is still news in its chat.
   */
  private boolean queueWebhook(NotificationEventEntry entry, Resolution resolution, Instant now) {
    if (!entry.getType().isRelayedToTeamWebhook()) {
      return false;
    }
    return webhookRepository
        .findByTeam(resolution.team().getId())
        .filter(webhook -> webhook.isEnabled())
        .map(
            webhook -> {
              webhookDeliveryRepository.persist(new TeamWebhookDelivery(entry, webhook, now));
              return true;
            })
        .orElse(false);
  }

  /** The next {@link #DIGEST_TIME} strictly after {@code now}, in the recipient's time zone. */
  static Instant nextDigest(Instant now, @Nullable String timezone) {
    ZonedDateTime local = now.atZone(NotificationTexts.zone(timezone));
    ZonedDateTime next = local.with(DIGEST_TIME);
    if (!next.isAfter(local)) {
      next = next.plusDays(1).with(DIGEST_TIME);
    }
    return next.toInstant();
  }

  /**
   * The resolver's audience minus the actor — nobody is notified of what they did themselves — and
   * minus duplicates, in a stable order.
   */
  private static List<User> recipients(List<User> candidates, NotificationEventEntry entry) {
    Map<Long, User> byId = new LinkedHashMap<>();
    for (User user : candidates) {
      if (!user.isDeleted() && !user.getId().equals(entry.getActorId())) {
        byId.putIfAbsent(user.getId(), user);
      }
    }
    return new ArrayList<>(byId.values());
  }

  private Map<Long, Map<NotificationChannel, Boolean>> overrides(
      NotificationType type, List<User> recipients) {
    Map<Long, Map<NotificationChannel, Boolean>> overrides = new HashMap<>();
    for (NotificationPreference preference :
        preferenceRepository.findByTypeAndUsers(
            type, recipients.stream().map(User::getId).toList())) {
      overrides
          .computeIfAbsent(
              preference.getUser().getId(), k -> new EnumMap<>(NotificationChannel.class))
          .put(preference.getChannel(), preference.isEnabled());
    }
    return overrides;
  }

  /**
   * Freezes what the notification says and where its links go. The site is resolved from the team
   * — its pinned alias if it has an active one, else the domain — not from whichever host the
   * organiser happened to publish from.
   */
  private void snapshot(NotificationEventEntry entry, Resolution resolution) {
    Team team = resolution.team();
    entry.setTeamSlug(team.getSlug());
    entry.setTeamName(team.getName());
    entry.setSubjectType(resolution.subjectType());
    entry.setSubjectSlug(resolution.subjectSlug());
    entry.setSubjectName(resolution.subjectName());
    entry.setSubjectDateTime(resolution.subjectDateTime());
    entry.setSubjectTimezone(resolution.subjectTimezone());
    entry.setExcerpt(resolution.excerpt());
    entry.setChangeList(resolution.changes());
    // A publication speaks for the team: the API never names its author, so neither does its
    // announcement. The actor id stays — it still keeps the publisher out of the audience.
    if (entry.getActorId() != null && !PUBLISHED_TYPES.contains(entry.getType())) {
      User actor = userRepository.findById(entry.getActorId());
      entry.setActorName(actor != null ? actor.getDisplayName() : null);
    }
    domainAliasRepository
        .findActiveByPinnedTeam(team.getId())
        .ifPresentOrElse(
            alias -> {
              entry.setBaseUrl(alias.getBaseUrl());
              entry.setSiteName(alias.getName());
            },
            () -> {
              Domain domain = domainRepository.findById(entry.getDomainId());
              entry.setBaseUrl(domain.getBaseUrl());
              entry.setSiteName(domain.getName());
            });
  }

  void markFailed(long eventId, Exception cause) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              NotificationEventEntry entry = eventRepository.findById(eventId);
              if (entry == null) {
                return;
              }
              entry.setErrorMessage(truncate(cause.toString()));
              // Below the ceiling it goes back on the queue, after a backoff: retried within the
              // same tick, a transient fault would burn every attempt in milliseconds.
              requeueOrFail(
                  entry, Instant.now().plus(backoff(backoffSeconds, entry.getAttempts())));
            });
  }

  /** Puts back on the queue the events a crash left in PROCESSING. */
  @Transactional
  public int recoverStuck() {
    Instant now = Instant.now();
    List<NotificationEventEntry> stuck =
        eventRepository.findStuck(now.minus(stuckAfterMinutes, ChronoUnit.MINUTES));
    for (NotificationEventEntry entry : stuck) {
      requeueOrFail(entry, now);
    }
    return stuck.size();
  }

  private void requeueOrFail(NotificationEventEntry entry, Instant nextAttemptAt) {
    if (entry.getAttempts() >= maxAttempts) {
      entry.setStatus(NotificationEventStatus.FAILED);
      releaseDedupKey(entry);
    } else {
      entry.setStatus(NotificationEventStatus.PENDING);
      entry.setNextAttemptAt(nextAttemptAt);
    }
  }

  /**
   * "Notify once" is about notifications sent. An event that notified nobody gives its key back, so
   * the same change made again later — a ride published for real after a false start — is queued.
   */
  private static void releaseDedupKey(NotificationEventEntry entry) {
    String suffix = "#" + TsidUtils.toString(entry.getId());
    if (!entry.getDedupKey().endsWith(suffix)) {
      entry.setDedupKey(entry.getDedupKey() + suffix);
    }
  }

  /** Exponential from {@code baseSeconds}, doubling per attempt already made, capped. */
  static Duration backoff(int baseSeconds, int attempts) {
    Duration delay =
        Duration.ofSeconds(baseSeconds).multipliedBy(1L << Math.clamp(attempts - 1, 0, 20));
    return delay.compareTo(MAX_BACKOFF) > 0 ? MAX_BACKOFF : delay;
  }

  static String truncate(String message) {
    return message.length() <= 500 ? message : message.substring(0, 500);
  }
}
