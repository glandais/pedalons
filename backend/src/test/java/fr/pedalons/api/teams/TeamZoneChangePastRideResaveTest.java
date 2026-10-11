package fr.pedalons.api.teams;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.common.EventDateTime;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.teams.request.TeamRequest;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug reproduction (found by the formal model of the ride/group timezone round-trip — TLA+ model of
 * TeamTimezoneChange.rewriteRide + RideService.updateRide, "purelogic" subsystem): after a change
 * of the team's zone, a past ride is relabelled at constant instant and its groups are left
 * untouched (TeamTimezoneChange.rewriteRide returns before the group loop). When the new offset
 * carries a group across local midnight relative to its ride, the group's own wall time
 * (RideGroupDto.time = EventTimezoneResolver.ownTime, a LocalTime only) loses the day. Saving the
 * ride back unchanged then puts that time on the ride's local date (EventTimezoneResolver.setStart)
 * and moves the group by 24 h — contradicting plan §9 "past ride relabelled at constant instant, so
 * that its next save does not move it".
 */
@QuarkusTest
class TeamZoneChangePastRideResaveTest extends AbstractResourceTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setTeamModules(team1, true, true);
  }

  private void changeTeamZone(String zone) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new TeamRequest(
                "Team 1",
                MediaDto.builder().build(),
                Visibility.PUBLIC,
                true,
                true,
                true,
                true,
                true,
                false,
                null,
                null,
                zone))
        .when()
        .put("/api/teams/" + team1Slug)
        .then()
        .statusCode(200);
  }

  private static RideRequest request(LocalDateTime wallTime, List<GroupRequest> groups) {
    return new RideRequest(
        "Sortie",
        MediaDto.builder().build(),
        EventDateTime.local(wallTime),
        Status.PUBLISHED,
        Visibility.PUBLIC,
        null,
        null,
        null,
        null,
        groups,
        null);
  }

  private JsonPath getRide(String slug) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/" + slug)
        .then()
        .statusCode(200)
        .extract()
        .jsonPath();
  }

  private void putRide(String slug, RideRequest request) {
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

  /** Paris → Martinique: the group falls on the day after its ride, a re-save moves it −24 h. */
  @Test
  void pastRide_resavedUnchangedAfterZoneChange_keepsItsGroupDeparture_westward() {
    // Place-less past ride in the team's zone (Europe/Paris, UTC+2 in September):
    // ride 05:30 Paris = 03:30Z, group 06:30 Paris = 04:30Z.
    String slug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                request(
                    LocalDateTime.parse("2020-09-12T05:30:00"),
                    List.of(new GroupRequest(null, "Tôt", LocalTime.of(6, 30), null, null, null))))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");
    JsonPath before = getRide(slug);
    assertEquals("2020-09-12T03:30:00Z", before.getString("dateTime"));
    assertEquals("2020-09-12T04:30:00Z", before.getString("groups[0].startAt"));

    changeTeamZone("America/Martinique");

    // What a client reads: the ride at 2020-09-11 23:30 local, its group at 00:30 (no date).
    JsonPath ride = getRide(slug);
    assertEquals("America/Martinique", ride.getString("timezone"));
    assertEquals("2020-09-12T03:30:00Z", ride.getString("dateTime"));
    assertEquals("2020-09-12T04:30:00Z", ride.getString("groups[0].startAt"));
    resaveAsAClientWould(slug, ride);

    JsonPath after = getRide(slug);
    assertEquals("2020-09-12T03:30:00Z", after.getString("dateTime"));
    // Bug: becomes 2020-09-11T04:30:00Z, a day earlier and before the ride itself.
    assertEquals("2020-09-12T04:30:00Z", after.getString("groups[0].startAt"));
  }

  /** Paris → Tokyo: the group falls on the day before its ride, a re-save moves it +24 h. */
  @Test
  void pastRide_resavedUnchangedAfterZoneChange_keepsItsGroupDeparture_eastward() {
    // Place-less past ride in Europe/Paris (UTC+2): ride 17:30 Paris = 15:30Z, group 16:45 Paris =
    // 14:45Z. In Tokyo (UTC+9) the ride is 00:30 on 09-13 and the group 23:45 on 09-12.
    String slug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                request(
                    LocalDateTime.parse("2020-09-12T17:30:00"),
                    List.of(
                        new GroupRequest(null, "Avant", LocalTime.of(16, 45), null, null, null))))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");
    assertEquals("2020-09-12T14:45:00Z", getRide(slug).getString("groups[0].startAt"));

    changeTeamZone("Asia/Tokyo");

    JsonPath ride = getRide(slug);
    assertEquals("Asia/Tokyo", ride.getString("timezone"));
    resaveAsAClientWould(slug, ride);

    // Bug: becomes 2020-09-13T14:45:00Z (23:45 on the ride's Tokyo date), a day later.
    assertEquals("2020-09-12T14:45:00Z", getRide(slug).getString("groups[0].startAt"));
  }

  /** PUTs the ride back exactly as read: its wall time in its zone, each group's own time. */
  private void resaveAsAClientWould(String slug, JsonPath ride) {
    ZoneId zone = ZoneId.of(ride.getString("timezone"));
    LocalDateTime wallTime =
        Instant.parse(ride.getString("dateTime")).atZone(zone).toLocalDateTime();
    String time = ride.getString("groups[0].time");
    putRide(
        slug,
        request(
            wallTime,
            List.of(
                new GroupRequest(
                    ride.getString("groups[0].id"),
                    ride.getString("groups[0].name"),
                    time == null ? null : LocalTime.parse(time),
                    null,
                    null,
                    null))));
  }
}
