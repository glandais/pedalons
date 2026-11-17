package fr.pedalons.api.users;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.notification.NotificationChannels;
import fr.pedalons.util.NotificationTestData;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code GET /api/users/me/profile-summary}: the state lines of the profile overview. Fixture:
 * user1 administers team1 and team2; user4 belongs to no team and has nothing.
 *
 * <p>The notification channels are mocked so both server states can be checked in one class: the
 * test profile turns e-mail on and has no push credentials, so the real set is {@code [EMAIL]}.
 */
@QuarkusTest
class ProfileSummaryResourceTest extends AbstractResourceTest {

  private static final String PATH = "/api/users/me/profile-summary";

  @Inject NotificationTestData notifications;

  @InjectMock NotificationChannels channels;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    when(channels.available()).thenReturn(EnumSet.of(NotificationChannel.EMAIL));
  }

  private ValidatableResponse summary(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .when()
        .get(PATH)
        .then()
        .statusCode(200)
        .header("Cache-Control", "private, no-store");
  }

  @Test
  void anonymous_isRefused() {
    given().when().get(PATH).then().statusCode(401);
  }

  @Test
  void newAccount_hasEverythingEmpty() {
    summary(USER4)
        .body("$", not(hasKey("participations")))
        .body("teams", hasSize(0))
        .body("passkeyCount", equalTo(0))
        .body("pairedDevices", hasSize(0))
        .body("blockedUserCount", equalTo(0))
        .body("notifications.channels", equalTo(List.of("EMAIL")))
        // Several types go out by e-mail by default (cancellations, changes…).
        .body("notifications.enabledChannels", equalTo(List.of("EMAIL")))
        .body("notifications.emailDigest", equalTo(false));
  }

  @Test
  void summary_countsEachSubject() {
    dataService.addUserToTeam(
        user1,
        dataService.createTeam(user2, "Autre équipe", "autre-equipe", Visibility.PUBLIC),
        TeamRole.MEMBER);
    dataService.createPasskey(user1, "cred-1".getBytes(), "key-1".getBytes());
    dataService.createPasskey(user1, "cred-2".getBytes(), "key-2".getBytes());
    dataService.createPairedDevice(user1, "karoo");
    dataService.createBlock(user1, user2);
    dataService.createBlock(user1, user3);
    // Someone else's block and passkey do not leak into user1's counts.
    dataService.createBlock(user3, user2);
    dataService.createPasskey(user2, "cred-3".getBytes(), "key-3".getBytes());

    summary(USER1)
        .body("teams.name", equalTo(List.of("Autre équipe", "Team 1", "Team 2")))
        .body("teams.role", equalTo(List.of("MEMBER", "ADMIN", "ADMIN")))
        .body("teams[1].slug", equalTo(team1Slug))
        .body("passkeyCount", equalTo(2))
        .body("pairedDevices", hasSize(1))
        .body("pairedDevices[0].type", equalTo("KAROO"))
        .body("blockedUserCount", equalTo(2));
  }

  @Test
  void teams_ofAnotherDomain_areLeftOut() {
    var other = dataService.createDomain("other.test", "Other", "http://other.test");
    // user1 administers it, but it is not on this site.
    dataService.createTeam(other, user1, "Étrangère", "etrangere", Visibility.PUBLIC);

    summary(USER1).body("teams.name", equalTo(List.of("Team 1", "Team 2")));
  }

  @Test
  void deletedBlockedAccount_isNotCounted() {
    dataService.createBlock(user1, user2);
    dataService.createBlock(user1, user3);
    dataService.deleteUser(user3);

    summary(USER1).body("blockedUserCount", equalTo(1));
  }

  @Test
  void notifications_followTheUsersChoicesAndTheDigest() {
    when(channels.available())
        .thenReturn(EnumSet.of(NotificationChannel.EMAIL, NotificationChannel.PUSH));
    // Every type off by e-mail: the channel is no longer one the user receives anything on.
    for (NotificationType type : NotificationType.values()) {
      notifications.seedPreference(user1, type, NotificationChannel.EMAIL, false);
    }

    summary(USER1)
        .body("notifications.channels", equalTo(List.of("EMAIL", "PUSH")))
        .body("notifications.enabledChannels", equalTo(List.of("PUSH")));
  }

  @Test
  void emailDisabledOnTheServer_hidesEmailAndTheDigest() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body("{\"preferences\": [], \"emailDigest\": true}")
        .when()
        .put("/api/notifications/preferences")
        .then()
        .statusCode(200);
    summary(USER1).body("notifications.emailDigest", equalTo(true));

    when(channels.available()).thenReturn(Set.of());

    summary(USER1)
        .body("notifications.channels", hasSize(0))
        .body("notifications.enabledChannels", hasSize(0))
        .body("notifications.emailDigest", equalTo(false));
    // The preferences screen agrees: no e-mail column, so no digest switch either.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/notifications/preferences")
        .then()
        .statusCode(200)
        .body("channels", hasSize(0))
        .body("preferences", hasSize(0));
  }
}
