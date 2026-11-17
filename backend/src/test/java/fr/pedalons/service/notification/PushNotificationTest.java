package fr.pedalons.service.notification;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.notification.NotificationDelivery;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.enums.PushPlatform;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.push.FcmClient;
import fr.pedalons.infrastructure.push.FcmException;
import fr.pedalons.util.NotificationTestData;
import fr.pedalons.util.PushDeviceTestData;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * The PUSH channel, from the fan-out that queues it to the purge of a token FCM has forgotten.
 *
 * <p>{@link FcmClient} is mocked: this is about the pipeline's behaviour, not about Google's wire
 * format. The one thing the mock decides is {@code isConfigured()}, which is exactly what makes the
 * channel available — without it no push delivery is created at all.
 */
@QuarkusTest
class PushNotificationTest extends AbstractResourceTest {

  private static final String TOKEN = "fcm-token-of-user3";

  @InjectMock FcmClient fcm;

  @Inject NotificationDispatchService dispatchService;
  @Inject NotificationDeliveryService deliveryService;
  @Inject NotificationTestData notifications;
  @Inject PushDeviceTestData devices;

  private final Instant nextWeek = Instant.now().plus(7, ChronoUnit.DAYS);

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    when(fcm.isConfigured()).thenReturn(true);
  }

  private void drain() {
    while (dispatchService.dispatchOne()) {
      // fan out everything queued
    }
  }

  private void publishRide() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new RideRequest(
                "Sortie du dimanche",
                MediaDto.builder().build(),
                wall(nextWeek),
                Status.PUBLISHED,
                Visibility.PUBLIC,
                null,
                null,
                null,
                null,
                List.of(new GroupRequest(null, "G1", null, null, null, null)),
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(201);
  }

  private NotificationDelivery pushDeliveryOfUser3() {
    List<NotificationDelivery> deliveries =
        notifications.deliveriesFor(user3).stream()
            .filter(d -> d.getChannel() == NotificationChannel.PUSH)
            .toList();
    assertEquals(1, deliveries.size(), "one push delivery for user3");
    return deliveries.getFirst();
  }

  @Test
  void configuredChannel_queuesAPushDelivery_andSendsToEveryDevice() throws Exception {
    devices.seed(user3, PushPlatform.ANDROID, TOKEN);
    devices.seed(user3, PushPlatform.IOS, TOKEN + "-ipad");
    publishRide();
    drain();

    assertEquals(NotificationDeliveryStatus.PENDING, pushDeliveryOfUser3().getStatus());

    deliveryService.sendDue(NotificationChannel.PUSH);

    assertEquals(NotificationDeliveryStatus.SENT, pushDeliveryOfUser3().getStatus());
    verify(fcm).send(eq(TOKEN), eq(PushPlatform.ANDROID), anyString(), anyString(), any(), any());
    verify(fcm)
        .send(eq(TOKEN + "-ipad"), eq(PushPlatform.IOS), anyString(), anyString(), any(), any());
  }

  /** What the app reads on a tap: the type it words itself, and the path to open. */
  @Test
  void theMessageCarriesTheTypeAndThePath() throws Exception {
    devices.seed(user3, PushPlatform.ANDROID, TOKEN);
    publishRide();
    drain();
    deliveryService.sendDue(NotificationChannel.PUSH);

    @SuppressWarnings("unchecked")
    ArgumentCaptor<Map> captor = ArgumentCaptor.forClass(Map.class);
    verify(fcm).send(eq(TOKEN), any(), anyString(), anyString(), captor.capture(), any());
    Map<?, ?> data = captor.getValue();
    assertEquals("RIDE_PUBLISHED", data.get("type"));
    assertEquals(team1Slug, data.get("teamSlug"));
    assertEquals("RIDE", data.get("subjectType"));
    assertTrue(
        data.get("path").toString().startsWith("/teams/" + team1Slug + "/rides/"),
        data.get("path").toString());
  }

  /** A provider holding the push for an offline phone drops it when the ride leaves (NOTIF-16). */
  @Test
  void theMessageExpiresAtTheRidesStart() throws Exception {
    devices.seed(user3, PushPlatform.ANDROID, TOKEN);
    publishRide();
    drain();
    deliveryService.sendDue(NotificationChannel.PUSH);

    ArgumentCaptor<Instant> captor = ArgumentCaptor.forClass(Instant.class);
    verify(fcm).send(eq(TOKEN), any(), anyString(), anyString(), any(), captor.capture());
    assertEquals(notifications.subjectDateTimesFor(user3).getFirst(), captor.getValue());
  }

  /** A push due after the ride left — retried, or queued while the sender was down — is dropped. */
  @Test
  void aPushDueAfterTheRendezvous_isSkipped_notSent() throws Exception {
    devices.seed(user3, PushPlatform.ANDROID, TOKEN);
    publishRide();
    drain();
    notifications.pastEveryRendezvous();

    deliveryService.sendDue(NotificationChannel.PUSH);

    assertEquals(NotificationDeliveryStatus.SKIPPED, pushDeliveryOfUser3().getStatus());
    verify(fcm, never()).send(anyString(), any(), anyString(), anyString(), any(), any());
  }

  /** The normal state of every member who only uses the web: nothing to send is not a failure. */
  @Test
  void noRegisteredDevice_isNotAFailure() throws Exception {
    publishRide();
    drain();
    deliveryService.sendDue(NotificationChannel.PUSH);

    assertEquals(NotificationDeliveryStatus.SENT, pushDeliveryOfUser3().getStatus());
    verify(fcm, never()).send(anyString(), any(), anyString(), anyString(), any(), any());
  }

  /** The table must not grow with tokens nobody can reach — and a dead token is not retried. */
  @Test
  void tokenFcmHasForgotten_isPurged_andNotRetried() throws Exception {
    devices.seed(user3, PushPlatform.ANDROID, TOKEN);
    doThrow(new FcmException("UNREGISTERED", true))
        .when(fcm)
        .send(anyString(), any(), anyString(), anyString(), any(), any());
    publishRide();
    drain();
    deliveryService.sendDue(NotificationChannel.PUSH);

    assertTrue(devices.of(user3).isEmpty(), "the dead token is gone");
    assertEquals(NotificationDeliveryStatus.SENT, pushDeliveryOfUser3().getStatus());
  }

  @Test
  void transientFailure_goesBackOnTheQueue_andKeepsTheDevice() throws Exception {
    devices.seed(user3, PushPlatform.ANDROID, TOKEN);
    doThrow(new FcmException("FCM returned 503", false))
        .when(fcm)
        .send(anyString(), any(), anyString(), anyString(), any(), any());
    publishRide();
    drain();
    deliveryService.sendDue(NotificationChannel.PUSH);

    NotificationDelivery delivery = pushDeliveryOfUser3();
    assertEquals(NotificationDeliveryStatus.PENDING, delivery.getStatus());
    assertEquals(1, delivery.getAttempts());
    assertEquals(1, devices.of(user3).size(), "a transient failure says nothing about the token");
  }

  /** §5 of the plan: an unavailable channel queues nothing, rather than piling rows up. */
  @Test
  void unconfiguredChannel_queuesNoPushDelivery() {
    when(fcm.isConfigured()).thenReturn(false);
    publishRide();
    drain();

    assertTrue(
        notifications.deliveriesFor(user3).stream()
            .noneMatch(d -> d.getChannel() == NotificationChannel.PUSH));
  }

  /** And it is only offered in the preferences once it can actually deliver. */
  @Test
  void theMatrixOffersPush_onlyWhenItIsConfigured() {
    assertTrue(availableChannels().contains("PUSH"));

    when(fcm.isConfigured()).thenReturn(false);
    assertFalse(availableChannels().contains("PUSH"));
  }

  private List<String> availableChannels() {
    return given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/notifications/preferences")
        .then()
        .statusCode(200)
        .extract()
        .path("channels");
  }
}
