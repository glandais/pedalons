package fr.pedalons.util;

import fr.pedalons.domain.notification.Notification;
import fr.pedalons.domain.notification.NotificationDelivery;
import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.domain.notification.NotificationPreference;
import fr.pedalons.domain.notification.TeamWebhookDelivery;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.enums.NotificationEventStatus;
import fr.pedalons.enums.NotificationSubjectType;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.repository.notification.NotificationDeliveryRepository;
import fr.pedalons.repository.notification.NotificationEventRepository;
import fr.pedalons.repository.notification.NotificationPreferenceRepository;
import fr.pedalons.repository.notification.NotificationRepository;
import fr.pedalons.repository.notification.TeamWebhookDeliveryRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.notification.event.RidePublished;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import tools.jackson.databind.ObjectMapper;

/** Reads and seeds the notification tables for tests, each call in its own transaction. */
@ApplicationScoped
public class NotificationTestData {

  @Inject NotificationEventRepository eventRepository;
  @Inject NotificationRepository notificationRepository;
  @Inject NotificationDeliveryRepository deliveryRepository;
  @Inject NotificationPreferenceRepository preferenceRepository;
  @Inject TeamWebhookDeliveryRepository webhookDeliveryRepository;
  @Inject UserTeamRepository userTeamRepository;
  @Inject ObjectMapper objectMapper;

  /** A notification as the dispatcher sees it: type, status, and who it went to. */
  public record EventView(NotificationType type, NotificationEventStatus status, String dedupKey) {}

  @Transactional
  public List<EventView> events() {
    return eventRepository.listAll().stream()
        .map(e -> new EventView(e.getType(), e.getStatus(), e.getDedupKey()))
        .toList();
  }

  @Transactional
  public List<NotificationType> notificationTypesFor(User user) {
    return notificationRepository.list("recipient.id", user.getId()).stream()
        .map(Notification::getType)
        .toList();
  }

  @Transactional
  public long notificationCount() {
    return notificationRepository.count();
  }

  @Transactional
  public List<NotificationDelivery> deliveriesFor(User user) {
    return deliveryRepository.list("notification.recipient.id", user.getId());
  }

  /**
   * Seeds {@code count} fanned-out notifications for one recipient, bypassing the pipeline — for
   * the inbox tests, which are about reading, not producing.
   */
  @Transactional
  public List<Notification> seedInbox(User recipient, Team team, int count) {
    Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
    List<Notification> seeded = new ArrayList<>();
    for (int i = 0; i < count; i++) {
      NotificationEventEntry event = new NotificationEventEntry();
      event.setDomainId(team.getDomain().getId());
      event.setType(NotificationType.RIDE_PUBLISHED);
      event.setStatus(NotificationEventStatus.DONE);
      event.setDedupKey("seed:" + recipient.getId() + ":" + i + ":" + System.nanoTime());
      event.setPayload(objectMapper.valueToTree(new RidePublished(i)));
      event.setTeamId(team.getId());
      event.setCreatedAt(now.minusSeconds(count - i));
      event.setNextAttemptAt(event.getCreatedAt());
      event.setProcessedAt(now);
      event.setActorName("Seeder");
      event.setTeamSlug(team.getSlug());
      event.setTeamName(team.getName());
      event.setSubjectType(NotificationSubjectType.RIDE);
      event.setSubjectSlug("ride-" + i);
      event.setSubjectName("Ride " + i);
      event.setSubjectDateTime(now.plus(1, ChronoUnit.DAYS));
      // Frozen at fan-out with the subject's date (docs/LEDGER_*.md API-60): a placeless ride's.
      event.setSubjectTimezone(team.getTimezone());
      event.setBaseUrl("http://localhost:5173");
      event.setSiteName("Pedalons");
      eventRepository.persist(event);
      Notification notification = new Notification(event, recipient, now.minusSeconds(count - i));
      notificationRepository.persist(notification);
      seeded.add(notification);
    }
    return seeded;
  }

  /** Queues one delivery of an already seeded notification, as the fan-out would. */
  @Transactional
  public void seedDelivery(Notification notification, NotificationChannel channel) {
    deliveryRepository.persist(
        new NotificationDelivery(
            notificationRepository.findById(notification.getId()), channel, Instant.now()));
  }

  @Transactional
  public void seedPreference(
      User user, NotificationType type, NotificationChannel channel, boolean enabled) {
    preferenceRepository.persist(new NotificationPreference(user, type, channel, enabled));
  }

  @Transactional
  public long preferenceCount(User user) {
    return preferenceRepository.count("user.id", user.getId());
  }

  @Transactional
  public void removeFromTeam(User user, Team team) {
    userTeamRepository.delete("user.id = ?1 and team.id = ?2", user.getId(), team.getId());
  }

  /** The events themselves, detached — for the queue fields {@link #events()} leaves out. */
  @Transactional
  public List<NotificationEventEntry> eventEntries() {
    return eventRepository.listAll();
  }

  /** Queues an event whose payload cannot be read back, so that every attempt at it fails. */
  @Transactional
  public void queueUnreadableEvent(Team team) {
    eventRepository.insertIfAbsent(
        team.getDomain().getId(),
        NotificationType.RIDE_PUBLISHED,
        "unreadable:" + System.nanoTime(),
        "{\"rideId\": \"not a number\"}",
        null,
        team.getId(),
        Instant.now());
  }

  /** Skips the backoff: every pending event becomes due now. */
  @Transactional
  public void makeEventsDue() {
    eventRepository.update("nextAttemptAt = ?1", Instant.now());
  }

  /** As a worker that died mid-claim leaves them: in progress, long ago. */
  @Transactional
  public void backdateEventClaims() {
    eventRepository.update("startedAt = ?1", Instant.now().minus(1, ChronoUnit.HOURS));
  }

  /** As a worker that died mid-send leaves them: SENDING since long ago, after {@code attempts}. */
  @Transactional
  public void strandDeliveries(User user, int attempts) {
    deliveryRepository.update(
        "status = ?1, attempts = ?2, lastAttemptAt = ?3 where notification.id in"
            + " (select n.id from Notification n where n.recipient.id = ?4)",
        NotificationDeliveryStatus.SENDING,
        attempts,
        Instant.now().minus(1, ChronoUnit.HOURS),
        user.getId());
  }

  @Transactional
  public void backdateEvents(int days) {
    eventRepository.update("createdAt = ?1", Instant.now().minus(days, ChronoUnit.DAYS));
  }

  /** Skips the digest wait: every pending delivery becomes due now. */
  @Transactional
  public void makeDeliveriesDue() {
    deliveryRepository.update("nextAttemptAt = ?1", Instant.now());
  }

  /** The statuses of the team webhook queue, in creation order. */
  @Transactional
  public List<NotificationDeliveryStatus> webhookDeliveryStatuses() {
    return webhookDeliveryRepository.list("order by createdAt").stream()
        .map(TeamWebhookDelivery::getStatus)
        .toList();
  }
}
