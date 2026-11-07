package fr.pedalons.service.notification;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.notification.NotificationDelivery;
import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.dto.comments.request.CommentRequest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.notifications.request.NotificationPreferenceUpdate;
import fr.pedalons.dto.notifications.request.NotificationPreferencesRequest;
import fr.pedalons.dto.notifications.request.NotificationTeamPreferenceUpdate;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.teams.request.TeamWebhookRequest;
import fr.pedalons.enums.NotificationChange;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.enums.NotificationEventStatus;
import fr.pedalons.enums.NotificationSubjectType;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.webhook.WebhookHttpClient;
import fr.pedalons.util.NotificationTestData;
import fr.pedalons.util.WallTimes;
import io.quarkus.mailer.Mail;
import io.quarkus.mailer.MockMailbox;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.net.URI;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Phase 5 of the notifications: the five new types, team mutes, the daily digest and the team
 * webhook. Same fixture as {@link NotificationPipelineTest}: team1 has user1 (admin), user2
 * (organizer) and user3 (member); user4 and user5 are outsiders.
 */
@QuarkusTest
class NotificationPhase5Test extends AbstractResourceTest {

  @Inject NotificationDispatchService dispatchService;
  @Inject NotificationDeliveryService deliveryService;
  @Inject NotificationDigestService digestService;
  @Inject TeamWebhookDeliveryService webhookDeliveryService;
  @Inject RideReminderScheduler reminderScheduler;
  @Inject NotificationTestData notifications;
  @Inject MockMailbox mailbox;

  @InjectMock WebhookHttpClient webhookHttp;

  private final Instant nextWeek = Instant.now().plus(7, ChronoUnit.DAYS);

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    mailbox.clear();
  }

  private void drain() {
    while (dispatchService.dispatchOne()) {
      // fan out everything queued
    }
  }

  private RideRequest ride(
      Status status, Instant dateTime, @Nullable String groupId, @Nullable String startPlaceId) {
    return new RideRequest(
        "Sortie du dimanche",
        MediaDto.builder().build(),
        wall(dateTime),
        status,
        Visibility.PUBLIC,
        null,
        startPlaceId,
        null,
        null,
        List.of(new GroupRequest(groupId, "G1", null, null, null, null)),
        null);
  }

  private void createRide(String token) {
    given()
        .auth()
        .oauth2(getAccessToken(token))
        .contentType("application/json")
        .body(ride(Status.PUBLISHED, nextWeek, null, null))
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(201);
  }

  private void updateRide(String slug, RideRequest request) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/rides/" + slug)
        .then()
        .statusCode(200);
  }

  private void putPreferences(String token, NotificationPreferencesRequest request) {
    given()
        .auth()
        .oauth2(getAccessToken(token))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/notifications/preferences")
        .then()
        .statusCode(200);
  }

  /** A published ride created by user1, user3 registered to its only group. */
  private record RegisteredRide(Ride ride, RideGroup group) {
    String groupId() {
      return TsidUtils.toString(group.getId());
    }
  }

  private RegisteredRide registeredRide(Instant when) {
    Ride ride = dataService.createRide(team1, user1, "Sortie", "sortie", when);
    RideGroup group = dataService.createRideGroup(user1, ride, "G1");
    dataService.createParticipation(group, user3);
    return new RegisteredRide(ride, group);
  }

  // ------------------------------------------------------------------ RIDE_REMINDER

  @Test
  void reminder_reachesRegisteredRiders_theDayBefore_once() {
    registeredRide(Instant.now().plus(22, ChronoUnit.HOURS));
    Ride later = dataService.createRide(team1, user1, "Plus tard", "plus-tard", nextWeek);
    dataService.createParticipation(dataService.createRideGroup(user1, later, "G1"), user3);

    assertEquals(1, reminderScheduler.queueReminders(Instant.now()));
    reminderScheduler.queueReminders(Instant.now()); // the next tick, same window
    drain();

    assertEquals(1, notifications.events().size());
    assertEquals(
        List.of(NotificationType.RIDE_REMINDER), notifications.notificationTypesFor(user3));
    assertTrue(notifications.notificationTypesFor(user2).isEmpty(), "not registered");
  }

  @Test
  void reminder_ofARideMovedSince_isSkipped() {
    RegisteredRide registered = registeredRide(Instant.now().plus(22, ChronoUnit.HOURS));
    reminderScheduler.queueReminders(Instant.now());
    updateRide(
        registered.ride().getSlug(), ride(Status.PUBLISHED, nextWeek, registered.groupId(), null));
    drain();

    assertFalse(notifications.notificationTypesFor(user3).contains(NotificationType.RIDE_REMINDER));
  }

  // ------------------------------------------------------------------ RIDE_GROUP_REMOVED

  /** The ride of {@code registered}, its only group replaced by a new one. */
  private RideRequest withNewGroupOnly() {
    return new RideRequest(
        "Sortie du dimanche",
        MediaDto.builder().build(),
        wall(nextWeek),
        Status.PUBLISHED,
        Visibility.PUBLIC,
        null,
        null,
        null,
        null,
        List.of(new GroupRequest(null, "G2", null, null, null, null)),
        null);
  }

  @Test
  void removingAGroup_tellsItsRiders_theirRegistrationWentWithIt() {
    RegisteredRide registered = registeredRide(nextWeek);
    updateRide(registered.ride().getSlug(), withNewGroupOnly());

    notifications.makeEventsDue();
    drain();

    assertEquals(
        List.of(NotificationType.RIDE_GROUP_REMOVED), notifications.notificationTypesFor(user3));
    assertTrue(notifications.notificationTypesFor(user1).isEmpty(), "the organiser who removed it");
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/notifications")
        .then()
        .statusCode(200)
        .body("items[0].type", equalTo("RIDE_GROUP_REMOVED"))
        .body("items[0].excerpt", equalTo("G1"));
  }

  @Test
  void removingAGroupNobodyJoined_notifiesNobody() {
    Ride ride = dataService.createRide(team1, user1, "Sortie", "sortie", nextWeek);
    dataService.createRideGroup(user1, ride, "G1");
    updateRide(ride.getSlug(), withNewGroupOnly());

    notifications.makeEventsDue();
    drain();

    assertTrue(
        notifications.events().stream()
            .noneMatch(event -> event.type() == NotificationType.RIDE_GROUP_REMOVED),
        String.valueOf(notifications.events()));
  }

  // ------------------------------------------------------------------ RIDE_UPDATED

  @Test
  void rideMoved_notifiesRegisteredRiders_afterTheDelay_withWhatChanged() {
    RegisteredRide registered = registeredRide(nextWeek);
    updateRide(
        registered.ride().getSlug(),
        ride(Status.PUBLISHED, nextWeek.plus(1, ChronoUnit.HOURS), registered.groupId(), null));

    drain();
    assertTrue(notifications.notificationTypesFor(user3).isEmpty(), "still waiting");

    notifications.makeEventsDue();
    drain();

    assertEquals(List.of(NotificationType.RIDE_UPDATED), notifications.notificationTypesFor(user3));
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/notifications")
        .then()
        .statusCode(200)
        .body("items[0].type", equalTo("RIDE_UPDATED"))
        .body("items[0].changes", contains(NotificationChange.DATE_TIME.name()));
  }

  @Test
  void editsInQuickSuccession_foldIntoOne_thatComparesFirstAndLast() {
    RegisteredRide registered = registeredRide(nextWeek);
    String place = TsidUtils.toString(dataService.createPlace(team1, user1, "Parking").getId());
    updateRide(
        registered.ride().getSlug(),
        ride(Status.PUBLISHED, nextWeek.plus(1, ChronoUnit.HOURS), registered.groupId(), null));
    updateRide(
        registered.ride().getSlug(),
        ride(Status.PUBLISHED, nextWeek.plus(1, ChronoUnit.HOURS), registered.groupId(), place));
    notifications.makeEventsDue();
    drain();

    assertEquals(1, notifications.events().size());
    NotificationEventEntry entry = notifications.eventEntries().getFirst();
    assertEquals(
        List.of(NotificationChange.DATE_TIME, NotificationChange.START_PLACE), entry.changeList());
    assertEquals(1, notifications.notificationTypesFor(user3).size());
  }

  @Test
  void editUndoneBeforeTheDelay_notifiesNobody() {
    RegisteredRide registered = registeredRide(nextWeek);
    updateRide(
        registered.ride().getSlug(),
        ride(Status.PUBLISHED, nextWeek.plus(1, ChronoUnit.HOURS), registered.groupId(), null));
    updateRide(
        registered.ride().getSlug(), ride(Status.PUBLISHED, nextWeek, registered.groupId(), null));
    notifications.makeEventsDue();
    drain();

    assertEquals(NotificationEventStatus.SKIPPED, notifications.events().getFirst().status());
    assertEquals(0, notifications.notificationCount());
  }

  @Test
  void aLaterEdit_afterTheFirstWentOut_notifiesAgain() {
    RegisteredRide registered = registeredRide(nextWeek);
    updateRide(
        registered.ride().getSlug(),
        ride(Status.PUBLISHED, nextWeek.plus(1, ChronoUnit.HOURS), registered.groupId(), null));
    notifications.makeEventsDue();
    drain();
    updateRide(
        registered.ride().getSlug(),
        ride(Status.PUBLISHED, nextWeek.plus(2, ChronoUnit.HOURS), registered.groupId(), null));
    notifications.makeEventsDue();
    drain();

    assertEquals(
        List.of(NotificationType.RIDE_UPDATED, NotificationType.RIDE_UPDATED),
        notifications.notificationTypesFor(user3));
  }

  // ------------------------------------------------------------------ RIDE_JOINED

  @Test
  void join_notifiesTheRideCreator_withTheGroupName() {
    Ride ride = dataService.createRide(team1, user1, "Sortie", "sortie", nextWeek);
    RideGroup group = dataService.createRideGroup(user1, ride, "Les rapides");
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post(
            "/api/teams/"
                + team1Slug
                + "/rides/sortie/groups/"
                + TsidUtils.toString(group.getId())
                + "/join")
        .then()
        .statusCode(201);
    drain();

    assertEquals(List.of(NotificationType.RIDE_JOINED), notifications.notificationTypesFor(user1));
    assertTrue(notifications.notificationTypesFor(user3).isEmpty(), "the rider themselves");
    assertEquals("Les rapides", notifications.eventEntries().getFirst().getExcerpt());
  }

  // ------------------------------------------------------------------ the rider's own start

  /** 08:00 a week from now, in the zone of a team that has none — on a whole second. */
  private static Instant atEight() {
    return LocalDate.now(WallTimes.DEFAULT_ZONE)
        .plusDays(7)
        .atTime(8, 0)
        .atZone(WallTimes.DEFAULT_ZONE)
        .toInstant();
  }

  /** The wall time of {@code instant} in that zone, as a group request carries it. */
  private static LocalTime timeOf(Instant instant) {
    return instant.atZone(WallTimes.DEFAULT_ZONE).toLocalTime();
  }

  /**
   * A published ride created by user1, at {@code when}: user3 in group A, which leaves with it,
   * user2 in group B, which leaves at {@code groupB}.
   */
  private record TwoGroups(Ride ride, RideGroup a, RideGroup b) {}

  private TwoGroups twoGroups(Instant when, Instant groupB) {
    Ride ride = dataService.createRide(team1, user1, "Sortie", "sortie", when);
    RideGroup a = dataService.createRideGroup(user1, ride, "A", 0);
    RideGroup b = dataService.createRideGroup(user1, ride, "B", 1);
    dataService.setRideGroupStart(b, groupB);
    dataService.createParticipation(a, user3);
    dataService.createParticipation(b, user2);
    return new TwoGroups(ride, a, b);
  }

  /** The ride of {@code groups}, at {@code when}, group B at {@code groupB}. */
  private static RideRequest twoGroupsRequest(
      TwoGroups groups, Status status, Instant when, LocalTime groupB) {
    return new RideRequest(
        "Sortie",
        MediaDto.builder().build(),
        wall(when),
        status,
        Visibility.PUBLIC,
        null,
        null,
        null,
        null,
        List.of(
            new GroupRequest(TsidUtils.toString(groups.a().getId()), "A", null, null, null, null),
            new GroupRequest(
                TsidUtils.toString(groups.b().getId()), "B", groupB, null, null, null)),
        null);
  }

  /** docs/LEDGER_*.md NOTIF-13: each rider is reminded of the time their own group leaves. */
  @Test
  void reminder_givesEachRiderTheStartOfTheirOwnGroup() {
    Instant rideStart = Instant.now().plus(22, ChronoUnit.HOURS).truncatedTo(ChronoUnit.SECONDS);
    Instant groupB = rideStart.plus(2, ChronoUnit.HOURS);
    twoGroups(rideStart, groupB);

    reminderScheduler.queueReminders(Instant.now());
    drain();

    assertEquals(
        List.of(NotificationType.RIDE_REMINDER), notifications.notificationTypesFor(user2));
    assertEquals(List.of(groupB), notifications.subjectDateTimesFor(user2));
    assertEquals(List.of(rideStart), notifications.subjectDateTimesFor(user3));
    // The event itself keeps the ride's date: what a rider of a group leaving with it reads.
    assertEquals(rideStart, notifications.eventEntries().getFirst().getSubjectDateTime());
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/notifications")
        .then()
        .statusCode(200)
        .body("items[0].subjectDateTime", equalTo(groupB.toString()));
  }

  /** The cancellation e-mail gives each rider their group's time, not the ride's. */
  @Test
  void cancellation_emailsEachRiderTheStartOfTheirOwnGroup() {
    Instant rideStart = atEight();
    Instant groupB = rideStart.plus(150, ChronoUnit.MINUTES); // 10h30
    TwoGroups groups = twoGroups(rideStart, groupB);

    updateRide(
        groups.ride().getSlug(),
        twoGroupsRequest(groups, Status.CANCELLED, rideStart, timeOf(groupB)));
    drain();
    deliveryService.sendDue(NotificationChannel.EMAIL);

    List<Mail> toB = mailbox.getMailsSentTo(EMAIL2);
    assertEquals(1, toB.size());
    assertTrue(toB.getFirst().getText().contains("10h30"), toB.getFirst().getText());
    assertFalse(toB.getFirst().getText().contains("08h00"), toB.getFirst().getText());
    List<Mail> toA = mailbox.getMailsSentTo(EMAIL3);
    assertEquals(1, toA.size());
    assertTrue(toA.getFirst().getText().contains("08h00"), toA.getFirst().getText());
  }

  /** The riders of a removed group are told the time that group was to leave. */
  @Test
  void removingAGroupWithItsOwnTime_givesItsRidersThatTime() {
    RegisteredRide registered = registeredRide(nextWeek);
    Instant groupStart = nextWeek.plus(90, ChronoUnit.MINUTES).truncatedTo(ChronoUnit.SECONDS);
    dataService.setRideGroupStart(registered.group(), groupStart);
    updateRide(registered.ride().getSlug(), withNewGroupOnly());

    notifications.makeEventsDue();
    drain();

    assertEquals(
        List.of(NotificationType.RIDE_GROUP_REMOVED), notifications.notificationTypesFor(user3));
    assertEquals(List.of(groupStart), notifications.subjectDateTimesFor(user3));
  }

  /** Whoever organises the ride hears when the group joined leaves. */
  @Test
  void join_givesTheStartOfTheGroupJoined() {
    Instant rideStart = nextWeek.truncatedTo(ChronoUnit.SECONDS);
    Ride ride = dataService.createRide(team1, user1, "Sortie", "sortie", rideStart);
    RideGroup group = dataService.createRideGroup(user1, ride, "Les tardifs");
    Instant groupStart = rideStart.plus(1, ChronoUnit.HOURS);
    dataService.setRideGroupStart(group, groupStart);
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post(
            "/api/teams/"
                + team1Slug
                + "/rides/sortie/groups/"
                + TsidUtils.toString(group.getId())
                + "/join")
        .then()
        .statusCode(201);
    drain();

    assertEquals(List.of(NotificationType.RIDE_JOINED), notifications.notificationTypesFor(user1));
    assertEquals(List.of(groupStart), notifications.subjectDateTimesFor(user1));
  }

  /**
   * A group's own time moved alone is a change for its riders — and for them only, with the new
   * time; the ride the team's webhook announced has not moved.
   */
  @Test
  void groupTimeMovedAlone_notifiesItsRidersOnly_withTheNewTime() throws Exception {
    when(webhookHttp.post(any(), anyString())).thenReturn(200);
    saveWebhook(USER1, "https://example.org/hook", 200);
    Instant rideStart = atEight();
    TwoGroups groups = twoGroups(rideStart, rideStart.plus(2, ChronoUnit.HOURS)); // B at 10h00
    Instant newGroupB = rideStart.plus(3, ChronoUnit.HOURS); // B at 11h00

    updateRide(
        groups.ride().getSlug(),
        twoGroupsRequest(groups, Status.PUBLISHED, rideStart, timeOf(newGroupB)));
    notifications.makeEventsDue();
    drain();

    assertEquals(List.of(NotificationType.RIDE_UPDATED), notifications.notificationTypesFor(user2));
    assertEquals(List.of(newGroupB), notifications.subjectDateTimesFor(user2));
    assertTrue(notifications.notificationTypesFor(user3).isEmpty(), "group A did not move");
    NotificationEventEntry entry = notifications.eventEntries().getFirst();
    assertEquals(List.of(NotificationChange.DATE_TIME), entry.changeList());
    assertTrue(notifications.webhookDeliveryStatuses().isEmpty(), "the ride itself did not move");
  }

  /**
   * The ride moved: the group leaving with it moved, a group with its own time did not — only the
   * first one's riders are told, with the ride's new time.
   */
  @Test
  void rideMoved_doesNotNotifyAGroupThatKeepsItsOwnTime() {
    Instant rideStart = atEight();
    Instant groupB = rideStart.plus(2, ChronoUnit.HOURS);
    TwoGroups groups = twoGroups(rideStart, groupB);
    Instant newRideStart = rideStart.plus(30, ChronoUnit.MINUTES);

    updateRide(
        groups.ride().getSlug(),
        twoGroupsRequest(groups, Status.PUBLISHED, newRideStart, timeOf(groupB)));
    notifications.makeEventsDue();
    drain();

    assertEquals(List.of(NotificationType.RIDE_UPDATED), notifications.notificationTypesFor(user3));
    assertEquals(List.of(newRideStart), notifications.subjectDateTimesFor(user3));
    assertTrue(notifications.notificationTypesFor(user2).isEmpty(), "group B leaves at 10h00");
  }

  // ------------------------------------------------------------------ COMMENT_ON_MY_PUBLICATION

  @Test
  void topLevelComment_notifiesTheAuthor_butAReplyDoesNotTellThemAgain() {
    Ride ride = dataService.createRide(team1, user1, "Sortie", "sortie", nextWeek);
    String rootId =
        given()
            .auth()
            .oauth2(getAccessToken(USER3))
            .contentType("application/json")
            .body(new CommentRequest("On part à quelle heure ?", null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides/" + ride.getSlug() + "/comments")
            .then()
            .statusCode(201)
            .extract()
            .path("id");
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(new CommentRequest("8h30", rootId))
        .when()
        .post("/api/teams/" + team1Slug + "/rides/" + ride.getSlug() + "/comments")
        .then()
        .statusCode(201);
    drain();

    assertEquals(
        List.of(NotificationType.COMMENT_ON_MY_PUBLICATION),
        notifications.notificationTypesFor(user1));
    assertEquals(
        List.of(NotificationType.COMMENT_REPLY), notifications.notificationTypesFor(user3));
  }

  /**
   * A stage's thread is its trip's (docs/LEDGER_*.md API-11): the trip's author is told, and the
   * notification opens the trip — a stage has no single-slug page.
   */
  @Test
  void topLevelCommentOnAStage_notifiesTheTripAuthor_andOpensTheTrip() {
    Trip trip = dataService.createTrip(team1, user1, "Voyage commente", nextWeek);
    TripStage stage = dataService.createTripStage(user2, trip, "Etape commentee");
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(new CommentRequest("On dort où ?", null))
        .when()
        .post("/api/teams/" + team1Slug + "/stages/" + stage.getSlug() + "/comments")
        .then()
        .statusCode(201);
    drain();

    assertEquals(
        List.of(NotificationType.COMMENT_ON_MY_PUBLICATION),
        notifications.notificationTypesFor(user1));
    assertTrue(notifications.notificationTypesFor(user2).isEmpty(), "the stage's creator");
    NotificationEventEntry event = notifications.eventEntries().getFirst();
    assertEquals(NotificationSubjectType.TRIP, event.getSubjectType());
    assertEquals(trip.getSlug(), event.getSubjectSlug());
    assertEquals("On dort où ?", event.getExcerpt());
  }

  // ------------------------------------------------------------------ TEAM_INVITATION

  @Test
  void invitation_reachesTheAccountOfTheAddress_andOpensTheTeamList() {
    dataService.markEmailVerified(user4);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(Map.of("email", EMAIL4))
        .when()
        .post("/api/teams/" + team1Slug + "/invitations")
        .then()
        .statusCode(201);
    drain();

    assertEquals(
        List.of(NotificationType.TEAM_INVITATION), notifications.notificationTypesFor(user4));
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/notifications")
        .then()
        .statusCode(200)
        .body("items[0].subjectType", equalTo(NotificationSubjectType.TEAM.name()))
        .body("items[0].subjectSlug", equalTo(team1Slug));
  }

  /** An unverified account may be someone else's claim on the address. */
  @Test
  void invitation_toAnUnverifiedAccount_notifiesNobody() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(Map.of("email", EMAIL4))
        .when()
        .post("/api/teams/" + team1Slug + "/invitations")
        .then()
        .statusCode(201);
    drain();

    assertEquals(0, notifications.notificationCount());
  }

  @Test
  void invitation_toAnAddressWithoutAccount_notifiesNobody() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(Map.of("email", "nobody-yet@example.com"))
        .when()
        .post("/api/teams/" + team1Slug + "/invitations")
        .then()
        .statusCode(201);
    drain();

    assertEquals(NotificationEventStatus.DONE, notifications.events().getFirst().status());
    assertEquals(0, notifications.notificationCount());
  }

  // ------------------------------------------------------------------ team mutes

  @Test
  void mutedTeam_silencesItsAnnouncements_butNotWhatConcernsTheMember() {
    putPreferences(
        USER3,
        new NotificationPreferencesRequest(
            List.of(), List.of(new NotificationTeamPreferenceUpdate(team1Slug, true)), null));
    createRide(USER1);
    RegisteredRide registered = registeredRide(nextWeek);
    updateRide(
        registered.ride().getSlug(), ride(Status.CANCELLED, nextWeek, registered.groupId(), null));
    drain();

    assertEquals(
        List.of(NotificationType.RIDE_CANCELLED), notifications.notificationTypesFor(user3));
    assertEquals(
        List.of(NotificationType.RIDE_PUBLISHED), notifications.notificationTypesFor(user2));
  }

  @Test
  void preferences_listTheMembersTeams_andRefuseSomeoneElses() {
    putPreferences(
        USER3,
        new NotificationPreferencesRequest(
            List.of(), List.of(new NotificationTeamPreferenceUpdate(team1Slug, true)), true));
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/notifications/preferences")
        .then()
        .statusCode(200)
        .body("teams.find { it.teamSlug == '" + team1Slug + "' }.muted", equalTo(true))
        .body("emailDigest", equalTo(true));

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(
            new NotificationPreferencesRequest(
                List.of(), List.of(new NotificationTeamPreferenceUpdate(team1Slug, true)), null))
        .when()
        .put("/api/notifications/preferences")
        .then()
        .statusCode(404);
  }

  // ------------------------------------------------------------------ daily digest

  @Test
  void digestReader_getsOneEmailAtDigestTime_butUrgentOnesAtOnce() {
    putPreferences(
        USER3,
        new NotificationPreferencesRequest(
            List.of(
                new NotificationPreferenceUpdate(
                    NotificationType.RIDE_PUBLISHED, NotificationChannel.EMAIL, true)),
            null,
            true));
    createRide(USER1);
    createRide(USER2);
    drain();

    List<NotificationDelivery> held = notifications.deliveriesFor(user3);
    assertEquals(2, held.size());
    assertTrue(held.stream().allMatch(NotificationDelivery::isDigest));
    assertTrue(held.getFirst().getNextAttemptAt().isAfter(Instant.now()));

    deliveryService.sendDue(NotificationChannel.EMAIL);
    assertTrue(mailbox.getMailsSentTo(EMAIL3).isEmpty(), "the ordinary sender leaves them");

    notifications.makeDeliveriesDue();
    assertEquals(1, digestService.sendDue());
    List<Mail> mails = mailbox.getMailsSentTo(EMAIL3);
    assertEquals(1, mails.size(), "one e-mail for both");
    assertTrue(mails.getFirst().getSubject().contains("2"), mails.getFirst().getSubject());
    assertTrue(
        notifications.deliveriesFor(user3).stream()
            .allMatch(d -> d.getStatus() == NotificationDeliveryStatus.SENT));

    // A cancellation cannot wait for tomorrow morning.
    mailbox.clear();
    RegisteredRide registered = registeredRide(nextWeek);
    updateRide(
        registered.ride().getSlug(), ride(Status.CANCELLED, nextWeek, registered.groupId(), null));
    drain();
    deliveryService.sendDue(NotificationChannel.EMAIL);
    assertEquals(1, mailbox.getMailsSentTo(EMAIL3).size());
  }

  // ------------------------------------------------------------------ team webhook

  private void saveWebhook(String token, @Nullable String url, int expectedStatus) {
    given()
        .auth()
        .oauth2(getAccessToken(token))
        .contentType("application/json")
        .body(new TeamWebhookRequest(url, "fr", true))
        .when()
        .put("/api/teams/" + team1Slug + "/webhook")
        .then()
        .statusCode(expectedStatus);
  }

  @Test
  void webhook_relaysAnnouncements_inTheFormatOfItsUrl() throws Exception {
    when(webhookHttp.post(any(), anyString())).thenReturn(200);
    saveWebhook(USER1, "https://hooks.slack.com/services/T0/B0/secretsecret", 200);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/webhook")
        .then()
        .statusCode(200)
        .body("configured", equalTo(true))
        .body("kind", equalTo("SLACK"))
        .body("maskedUrl", equalTo("https://hooks.slack.com/…cret"));

    createRide(USER2);
    drain();
    assertEquals(1, webhookDeliveryService.sendDue());

    assertEquals(List.of(NotificationDeliveryStatus.SENT), notifications.webhookDeliveryStatuses());
    verify(webhookHttp)
        .post(
            argThat((URI url) -> url.getHost().equals("hooks.slack.com")),
            argThat((String json) -> json.startsWith("{\"text\":\"*Nouvelle sortie")));
  }

  /**
   * The subject's zone is frozen at fan-out, carried by the generic payload, and named in the text
   * when it is not the team's — no reader's « chez vous » on a team channel (docs/LEDGER_*.md
   * API-60).
   */
  @Test
  void webhook_writesTheRideInItsZone_namedWhenNotTheTeams() throws Exception {
    when(webhookHttp.post(any(), anyString())).thenReturn(200);
    saveWebhook(USER1, "https://example.org/hook", 200);
    // A ride without a place takes its team's zone: Tokyo, then the team moves back to Paris.
    dataService.setTeamTimezone(team1, "Asia/Tokyo");
    createRide(USER2);
    drain();
    dataService.setTeamTimezone(team1, "Europe/Paris");

    NotificationEventEntry event =
        notifications.eventEntries().stream()
            .filter(e -> e.getType() == NotificationType.RIDE_PUBLISHED)
            .findFirst()
            .orElseThrow();
    assertEquals("Asia/Tokyo", event.getSubjectTimezone());

    assertEquals(1, webhookDeliveryService.sendDue());
    verify(webhookHttp)
        .post(
            any(),
            argThat(
                (String json) ->
                    json.contains("\"timezone\":\"Asia/Tokyo\"")
                        && json.contains(", heure de Tokyo")
                        && !json.contains("chez vous")));
  }

  @Test
  void webhook_ignoresPersonalTypes_andRejectedPostsAreNotRetried() throws Exception {
    when(webhookHttp.post(any(), anyString())).thenReturn(404);
    saveWebhook(USER1, "https://example.org/hook", 200);

    Ride ride = dataService.createRide(team1, user1, "Sortie", "sortie", nextWeek);
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(new CommentRequest("Super", null))
        .when()
        .post("/api/teams/" + team1Slug + "/rides/" + ride.getSlug() + "/comments")
        .then()
        .statusCode(201);
    drain();
    assertTrue(notifications.webhookDeliveryStatuses().isEmpty(), "a comment is not news");

    createRide(USER2);
    drain();
    webhookDeliveryService.sendDue();
    assertEquals(
        List.of(NotificationDeliveryStatus.FAILED), notifications.webhookDeliveryStatuses());
  }

  @Test
  void webhook_refusesLocalOrPlainHttpUrls_andNonAdministrators() throws Exception {
    saveWebhook(USER1, "http://hooks.slack.com/services/x", 400);
    saveWebhook(USER1, "https://localhost/hook", 400);
    saveWebhook(USER1, "https://169.254.169.254/latest/meta-data", 400);
    saveWebhook(USER1, "https://10.0.0.5/hook", 400);
    saveWebhook(USER1, null, 400); // no webhook yet, so a URL is required
    saveWebhook(USER3, "https://example.org/hook", 403);

    createRide(USER2);
    drain();
    assertTrue(notifications.webhookDeliveryStatuses().isEmpty());
    verify(webhookHttp, never()).post(any(), anyString());
  }
}
