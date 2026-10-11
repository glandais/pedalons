package fr.pedalons.service.notification;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.domain.common.Publication;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Status;
import fr.pedalons.repository.notification.NotificationEventRepository;
import fr.pedalons.service.notification.event.NotificationEvent;
import fr.pedalons.service.notification.event.PostPublished;
import fr.pedalons.service.notification.event.RideCancelled;
import fr.pedalons.service.notification.event.RidePublished;
import fr.pedalons.service.notification.event.TripCancelled;
import fr.pedalons.service.notification.event.TripPublished;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.util.function.Supplier;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Stage 1 of the notification pipeline: queues a typed event in {@code notification_events}.
 *
 * <p>{@code MANDATORY}: the whole point is that the event commits or rolls back with the change that
 * caused it, so calling this outside a transaction is a bug worth failing loudly on. It only
 * inserts — recipients, texts and sending all happen later, off the request.
 */
@ApplicationScoped
public class NotificationPublisher {

  private static final Logger LOG = Logger.getLogger(NotificationPublisher.class);

  /**
   * Insert, lock the waiting row, insert again: a claim in between gives the key back, so the
   * second insert normally wins.
   */
  private static final int MAX_FOLD_ATTEMPTS = 3;

  /**
   * Set while a bulk job replays history through the ordinary services. A thread flag rather than a
   * request-scoped bean: {@code PublicationPublishScheduler} publishes with no request context
   * active, and the jobs that need silence run on a single thread.
   */
  private static final ThreadLocal<Boolean> SILENCED = ThreadLocal.withInitial(() -> false);

  @Inject NotificationEventRepository eventRepository;
  @Inject ObjectMapper objectMapper;

  /**
   * Runs {@code work} without queuing any notification on this thread.
   *
   * <p>For imports, which create years of rides, trips and posts through the same services members
   * use: without this, the biketeam migration would announce every future ride and every post of
   * every club it brings over.
   */
  public <T> T silently(Supplier<T> work) {
    boolean previous = SILENCED.get();
    SILENCED.set(true);
    try {
      return work.get();
    } finally {
      SILENCED.set(previous);
    }
  }

  @Transactional(Transactional.TxType.MANDATORY)
  public void publish(NotificationEvent event, Team team, @Nullable User actor) {
    publish(event, team, actor, Duration.ZERO);
  }

  /**
   * Queues an event that will not be fanned out before {@code delay} has passed. For a type that
   * coalesces while pending, the delay is the window in which further edits fold into it.
   */
  @Transactional(Transactional.TxType.MANDATORY)
  public void publish(NotificationEvent event, Team team, @Nullable User actor, Duration delay) {
    if (SILENCED.get()) {
      return;
    }
    String payload;
    try {
      payload = objectMapper.writeValueAsString(event);
    } catch (JsonProcessingException e) {
      // A record of longs cannot fail to serialize; if it ever does, that is a programming error.
      throw new IllegalStateException("Cannot serialize " + event, e);
    }
    Instant now = Instant.now();
    for (int attempt = 1; ; attempt++) {
      boolean queued =
          eventRepository.insertIfAbsent(
              team.getDomain().getId(),
              event.type(),
              event.dedupKey(),
              payload,
              actor != null ? actor.getId() : null,
              team.getId(),
              now,
              now.plus(delay));
      if (queued) {
        return;
      }
      if (!event.coalescesWhilePending()) {
        LOG.debugf("Notification %s already queued once, not again", event.dedupKey());
        return;
      }
      // Folded into a waiting event only if it still waits, and held until this change commits:
      // otherwise the dispatcher could read the subject before it and announce the old state.
      // docs/LEDGER_*.md NOTIF-10.
      if (eventRepository.lockPending(event.dedupKey())) {
        LOG.debugf("Notification %s folded into the pending one", event.dedupKey());
        return;
      }
      if (attempt == MAX_FOLD_ATTEMPTS) {
        // A key held by a row in progress, as the previous release claims them — for the minute a
        // rolling deploy lasts.
        LOG.warnf("Notification %s neither queued nor folded", event.dedupKey());
        return;
      }
    }
  }

  /**
   * Maps a publication's status transition to its event, if it has one. The single place that
   * knows which transitions notify, called from the three publication services and from {@code
   * PublicationPublishScheduler}.
   *
   * @param before the status before the change, or null for a creation
   */
  @Transactional(Transactional.TxType.MANDATORY)
  public void publicationStatusChanged(
      Publication publication, @Nullable Status before, @Nullable User actor) {
    Status after = publication.getStatus();
    if (after == before) {
      return;
    }
    NotificationEvent event =
        switch (after) {
          case PUBLISHED -> published(publication);
          // Only what members could see can be cancelled on them: a draft cancelled, or a
          // publication created already cancelled, had no audience.
          case CANCELLED -> before == Status.PUBLISHED ? cancelled(publication) : null;
          case DRAFT -> null;
        };
    if (event != null) {
      publish(event, publication.getTeam(), actor);
    }
  }

  private static @Nullable NotificationEvent published(Publication publication) {
    return switch (publication) {
      case Ride ride -> new RidePublished(ride.getId());
      case Trip trip -> new TripPublished(trip.getId());
      case Post post -> new PostPublished(post.getId());
      default -> null;
    };
  }

  private static @Nullable NotificationEvent cancelled(Publication publication) {
    return switch (publication) {
      case Ride ride -> new RideCancelled(ride.getId());
      case Trip trip -> new TripCancelled(trip.getId());
      default -> null;
    };
  }
}
