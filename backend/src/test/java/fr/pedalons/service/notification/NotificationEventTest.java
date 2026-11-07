package fr.pedalons.service.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.enums.ReportTargetType;
import fr.pedalons.service.notification.event.CommentOnPublication;
import fr.pedalons.service.notification.event.CommentReplied;
import fr.pedalons.service.notification.event.ContentReported;
import fr.pedalons.service.notification.event.NotificationEvent;
import fr.pedalons.service.notification.event.PostPublished;
import fr.pedalons.service.notification.event.RideCancelled;
import fr.pedalons.service.notification.event.RideGroupRemoved;
import fr.pedalons.service.notification.event.RideJoined;
import fr.pedalons.service.notification.event.RidePublished;
import fr.pedalons.service.notification.event.RideReminder;
import fr.pedalons.service.notification.event.RideUpdated;
import fr.pedalons.service.notification.event.TeamInvited;
import fr.pedalons.service.notification.event.TripCancelled;
import fr.pedalons.service.notification.event.TripPublished;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * Every type has a record that says it is that type, and survives the trip through the payload
 * column. Plain unit test: an ObjectMapper with the java.time module stands in for Quarkus's.
 */
class NotificationEventTest {

  private static final Instant DATE = Instant.parse("2026-09-27T07:00:00Z");

  private final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());

  /** One event per type. Exhaustive: a type added without a sample does not compile. */
  private static NotificationEvent sample(NotificationType type) {
    return switch (type) {
      case RIDE_PUBLISHED -> new RidePublished(42);
      case RIDE_CANCELLED -> new RideCancelled(42);
      case TRIP_PUBLISHED -> new TripPublished(42);
      case TRIP_CANCELLED -> new TripCancelled(42);
      case POST_PUBLISHED -> new PostPublished(42);
      case COMMENT_REPLY -> new CommentReplied(42);
      case RIDE_REMINDER -> new RideReminder(42, DATE);
      case RIDE_UPDATED -> new RideUpdated(42, DATE, 7L, Map.of(5L, DATE.plusSeconds(3600)));
      case RIDE_GROUP_REMOVED ->
          new RideGroupRemoved(7, 42, "Groupe A", List.of(3L, 4L), DATE.plusSeconds(1800));
      case RIDE_JOINED -> new RideJoined(42);
      case COMMENT_ON_MY_PUBLICATION -> new CommentOnPublication(42);
      case TEAM_INVITATION -> new TeamInvited(42);
      case CONTENT_REPORTED -> new ContentReported(7, 3, ReportTargetType.COMMENT, 42);
    };
  }

  @Test
  void everyTypeRoundTripsThroughItsRecord() throws Exception {
    for (NotificationType type : NotificationType.values()) {
      NotificationEvent event = sample(type);
      Class<? extends NotificationEvent> recordClass = NotificationEvent.recordClass(type);

      assertEquals(recordClass, event.getClass());
      assertEquals(type, event.type());
      // A report is keyed by its team and its target, which the sample puts at team 3, COMMENT 42.
      String expectedPrefix =
          type == NotificationType.CONTENT_REPORTED
              ? type.name() + ":3:COMMENT:42"
              : type.name() + ":42";
      assertTrue(
          event.dedupKey().startsWith(expectedPrefix), recordClass + ": " + event.dedupKey());
      assertEquals(
          event,
          objectMapper.treeToValue(objectMapper.valueToTree(event), recordClass),
          "round trip of " + recordClass.getSimpleName());
    }
  }

  @Test
  void reminderKey_carriesTheDate_soAMovedRideIsRemindedAgain() {
    assertEquals(
        "RIDE_REMINDER:42:" + DATE.getEpochSecond(), new RideReminder(42, DATE).dedupKey());
  }

  @Test
  void updateWithoutStartPlace_roundTrips() throws Exception {
    RideUpdated event = new RideUpdated(42, DATE, null, null);
    assertEquals(
        event, objectMapper.treeToValue(objectMapper.valueToTree(event), RideUpdated.class));
  }

  /**
   * An event queued by the release before docs/LEDGER_*.md NOTIF-13 has neither the groups'
   * previous starts nor the removed group's start: it still reads, with them null — the resolver
   * then falls back on the ride's date.
   */
  @Test
  void payloadsOfThePreviousRelease_readWithTheGroupStartsNull() throws Exception {
    RideUpdated updated =
        objectMapper.readValue(
            "{\"rideId\":42,\"previousDateTime\":\"2026-09-27T07:00:00Z\","
                + "\"previousStartPlaceId\":7}",
            RideUpdated.class);
    assertEquals(new RideUpdated(42, DATE, 7L, null), updated);

    RideGroupRemoved removed =
        objectMapper.readValue(
            "{\"rideId\":7,\"groupId\":42,\"groupName\":\"Groupe A\",\"userIds\":[3,4]}",
            RideGroupRemoved.class);
    assertEquals(new RideGroupRemoved(7, 42, "Groupe A", List.of(3L, 4L), null), removed);
  }

  /** The groups' previous starts survive the payload column, keyed by group id. */
  @Test
  void updateWithGroupStarts_roundTrips() throws Exception {
    RideUpdated event =
        new RideUpdated(42, DATE, null, Map.of(5L, DATE, 6L, DATE.plusSeconds(5400)));
    assertEquals(
        event, objectMapper.treeToValue(objectMapper.valueToTree(event), RideUpdated.class));
  }

  /** Keyed by the target, not the report: a burst of reports on one comment makes one notice. */
  @Test
  void reportKey_isTheTarget_andCoalescesWhilePending() {
    ContentReported first = new ContentReported(1, 3, ReportTargetType.POST, 42);
    ContentReported second = new ContentReported(2, 3, ReportTargetType.POST, 42);

    assertEquals("CONTENT_REPORTED:3:POST:42", first.dedupKey());
    assertEquals(first.dedupKey(), second.dedupKey());
    assertTrue(first.coalescesWhilePending());
    assertFalse(NotificationType.CONTENT_REPORTED.isRelayedToTeamWebhook());
    assertTrue(NotificationType.CONTENT_REPORTED.isUrgent());
  }

  /** A member reported in two teams: each team's moderators must hear of it. */
  @Test
  void reportKey_includesTheTeam() {
    ContentReported inTeamA = new ContentReported(1, 3, ReportTargetType.MEMBER, 42);
    ContentReported inTeamB = new ContentReported(2, 4, ReportTargetType.MEMBER, 42);

    assertNotEquals(inTeamA.dedupKey(), inTeamB.dedupKey());
  }
}
