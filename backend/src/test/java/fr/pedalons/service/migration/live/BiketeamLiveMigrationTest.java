package fr.pedalons.service.migration.live;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.migration.BiketeamMigrationJob;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.migration.internal.BiketeamJobStatusDto;
import fr.pedalons.enums.BiketeamMigrationStatus;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.service.migration.BiketeamMigrationService;
import fr.pedalons.service.migration.live.snapshot.BiketeamFileFetcher;
import fr.pedalons.service.migration.live.snapshot.BiketeamSnapshot;
import fr.pedalons.service.route.GpxPipeline;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The live migration end to end, minus the network: a request confirmed and triggered through the
 * real endpoints, then the worker run on a fixture snapshot ({@code biketeam/snapshot.json}) whose
 * files come from the test resources instead of biketeam's export API.
 */
@QuarkusTest
class BiketeamLiveMigrationTest extends AbstractResourceTest {

  static final String TEAM = "live-team";
  static final String SECRET_HEADER = "X-Biketeam-Migration-Secret";

  @Inject BiketeamLiveMigrationWorker worker;
  @Inject BiketeamMigrationJobService jobService;
  @Inject BiketeamTestData biketeamData;
  @Inject ObjectMapper objectMapper;

  /** Every path the fake export was asked for, in order. */
  final List<String> downloads = new ArrayList<>();

  /** What the fake export serves files with — {@link #exportFiles} unless a test swaps it. */
  BiketeamFileFetcher fetcher;

  /** The biketeam team id the fixture snapshot is rewritten to. */
  String snapshotTeamId;

  /** Rewrites the fixture snapshot's JSON before it is read — the identity unless a test swaps it. */
  java.util.function.UnaryOperator<String> snapshotEdit;

  /** {@code targetTeamSlug} of the last trigger's answer. */
  String lastTriggerSlug;

  @BeforeEach
  void setUpTest() {
    setUp();
    downloads.clear();
    fetcher = this::exportFiles;
    snapshotTeamId = TEAM;
    snapshotEdit = json -> json;
  }

  // ─── plumbing ─────────────────────────────────────────────────────────────

  private static Path resource(String name) {
    try {
      return Path.of(BiketeamLiveMigrationTest.class.getResource("/" + name).toURI());
    } catch (URISyntaxException e) {
      throw new IllegalStateException(e);
    }
  }

  private BiketeamSnapshot snapshot() throws IOException {
    Path gpx = resource("example.gpx");
    Path image = resource("image.png");
    String json =
        Files.readString(resource("biketeam/snapshot.json"), StandardCharsets.UTF_8)
            .replace("${GPX_SIZE}", Long.toString(Files.size(gpx)))
            .replace("${GPX_MD5}", SnapshotBiketeamSource.md5Of(gpx))
            .replace("${IMAGE_SIZE}", Long.toString(Files.size(image)))
            .replace("${IMAGE_MD5}", SnapshotBiketeamSource.md5Of(image))
            // The team id and the file paths under it.
            .replace(TEAM, snapshotTeamId);
    return objectMapper.readValue(snapshotEdit.apply(json), BiketeamSnapshot.class);
  }

  /** The export's file endpoint, served from the test resources. */
  private void exportFiles(String path, Path target) throws IOException {
    downloads.add(path);
    String name = path.contains("/files/gpx/") ? "example.gpx" : "image.png";
    try (InputStream in = Files.newInputStream(resource(name))) {
      Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
    }
  }

  /** Confirms as {@code user} and triggers, as biketeam would; returns the job id. */
  private String confirmAndTrigger(String user, String teamId, boolean dryRun, boolean reset) {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request(teamId, dryRun, reset);
    String redirectUrl =
        given()
            .auth()
            .oauth2(getAccessToken(user))
            .contentType(ContentType.JSON)
            .body(Map.of("requestToken", req.token()))
            .when()
            .post("/api/biketeam-migration/confirm")
            .then()
            .statusCode(200)
            .extract()
            .path("redirectUrl");
    String grant = redirectUrl.substring(redirectUrl.indexOf("&grant=") + "&grant=".length());
    io.restassured.response.ExtractableResponse<?> triggered =
        given()
            .header(SECRET_HEADER, BiketeamTestTokens.TRIGGER_SECRET)
            .contentType(ContentType.JSON)
            .body(
                Map.of(
                    "requestId", req.requestId(),
                    "grant", grant,
                    "teamId", teamId,
                    "dryRun", dryRun,
                    "reset", reset))
            .when()
            .post("/api/internal/biketeam-migration/jobs")
            .then()
            .statusCode(202)
            .extract();
    lastTriggerSlug = triggered.path("targetTeamSlug");
    return triggered.path("jobId");
  }

  /** Runs the queued job on the fixture and returns its status as biketeam would read it. */
  private BiketeamJobStatusDto runWorker(String jobId) throws IOException {
    BiketeamSnapshot snapshot = snapshot();
    Path tempDir = Files.createTempDirectory("biketeam-test-");
    BiketeamFileFetcher files = fetcher;
    assertTrue(
        worker.runOne((ctx, heartbeat) -> new SnapshotBiketeamSource(snapshot, files, tempDir)));
    assertFalse(Files.exists(tempDir), "the source cleans its download directory");
    return jobService.status(jobId);
  }

  private BiketeamJobStatusDto migrate(String user, boolean dryRun, boolean reset)
      throws IOException {
    return runWorker(confirmAndTrigger(user, TEAM, dryRun, reset));
  }

  // ─── the first run ────────────────────────────────────────────────────────

  @Test
  void firstRun_createsTheTeam_withTheConfirmingUserAsAdminAndAuthor_andNoPeople()
      throws IOException {
    long usersBefore = biketeamData.countUsers();

    BiketeamJobStatusDto status = migrate(USER4, true, false);

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    assertEquals("DONE", status.progress().phase());
    assertNull(status.error());
    assertNull(status.lastAttemptError());
    BiketeamTestData.TeamView team = biketeamData.team(domain, TEAM);
    assertNotNull(team);
    assertFalse(team.deleted());
    assertEquals("Live Team", team.name());
    assertEquals(user4.getId(), team.createdById());
    assertEquals(TeamRole.ADMIN, biketeamData.roleOf(user4, team.id()));
    assertEquals(0, biketeamData.countCreatedByOtherThan(team.id(), user4.getId()));
    // Settings a migrated team starts with; joinable because the fixture team is PUBLIC.
    assertEquals(
        new BiketeamTestData.TeamFlags(true, true, true, true), biketeamData.flagsOf(team.id()));

    // No people: no user, no comment, no participation.
    assertEquals(usersBefore, biketeamData.countUsers());
    assertEquals(0, biketeamData.countComments());
    assertEquals(0, biketeamData.countParticipations());

    assertEquals(1, biketeamData.countLive(Route.class, team.id()));
    assertEquals(1, biketeamData.countLive(Ride.class, team.id()));
    assertEquals(1, biketeamData.countLive(Trip.class, team.id()));
    assertEquals(1, biketeamData.countLive(Post.class, team.id()));
    assertTrue(biketeamData.teamPageNames(team.id()).contains("FAQ"));
    // The trip's notes page (/trips/{id}/notes) ends its description.
    assertTrue(
        biketeamData
            .tripMarkdown(team.id(), "Tour 2025")
            .startsWith("Deux jours\n\n## Notes\n\nPrévoir un **gilet**.\nGîte réservé."));

    // The diagonal wind biketeam writes as NORTH_EAST is no longer lost.
    assertEquals(WindDirection.NORTH_EAST, biketeamData.windOf(team.id(), "Boucle du littoral"));

    assertEquals(2, status.counts().routes().total());
    assertEquals(1, status.counts().routes().migrated());
    assertEquals(1, status.counts().routes().skipped());
    assertEquals(2, status.counts().rides().total());
    assertEquals(1, status.counts().rides().skipped());
    assertEquals(2, status.counts().publications().total());
    assertEquals(2, status.counts().tripStages().migrated());
    assertEquals(2, status.counts().teamPages().migrated());
    assertEquals(1, status.counts().images().migrated(), "the logo");
  }

  @Test
  void rideGroups_keepBiketeamsOrder_withNoLeader_andDatesReadInTheTeamZone() throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();

    BiketeamTestData.RideView ride = biketeamData.ride(teamId, "Sortie du 12");
    // Biketeam displays groups by meeting time, then name: Z (08:00) before A (09:30).
    assertEquals(
        List.of("Z", "A"), ride.groups().stream().map(BiketeamTestData.GroupView::name).toList());
    // Z meets when the ride does (the earliest meeting time): it leaves with the ride, which is
    // all its stored start says (docs/LEDGER_*.md API-60). A keeps its own time.
    assertNull(ride.groups().get(0).time());
    assertEquals(LocalTime.of(9, 30), ride.groups().get(1).time());
    // RideGroupDto.leader: null, never derived from createdBy.
    ride.groups().forEach(g -> assertNull(g.leaderId(), g.name()));
    // 2025-04-12 08:00 in Indian/Reunion (UTC+4), not in Paris.
    assertEquals(Instant.parse("2025-04-12T04:00:00Z"), ride.dateTime());

    List<BiketeamTestData.StageView> stages = biketeamData.stages(teamId, "Tour 2025");
    assertEquals(2, stages.size());
    // First stage: the trip's meeting time; later ones: 8:00. Read in the stage's zone, not the
    // team's (docs/LEDGER_*.md API-60): stage 1's route starts in France, so Paris (UTC+2);
    // stage 2, with neither place nor route, takes the previous stage's.
    assertEquals(Instant.parse("2025-07-01T05:30:00Z"), stages.get(0).dateTime());
    assertEquals(Instant.parse("2025-07-02T06:00:00Z"), stages.get(1).dateTime());
  }

  /** The import goes through the same creation as the API: every end is stored (API-85). */
  @Test
  void importedRidesAndTrips_haveTheirEndStored() throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();

    BiketeamTestData.EndView ride = biketeamData.rideEnd(teamId, "Sortie du 12");
    assertNotNull(ride.stored());
    assertEquals(ride.computed(), ride.stored());

    BiketeamTestData.EndView trip = biketeamData.tripEnd(teamId, "Tour 2025");
    assertNotNull(trip.stored());
    assertEquals(trip.computed(), trip.stored());
    // The second stage leaves on 2025-07-02 04:00 UTC: the trip cannot end before it.
    assertTrue(trip.stored().isAfter(Instant.parse("2025-07-02T04:00:00Z")));
  }

  @Test
  void urlMap_pointsAtTheFrenchRoutes_ofTheDomainBaseUrl() throws IOException {
    BiketeamJobStatusDto status = migrate(USER4, true, false);

    Map<String, Map<String, String>> urls = status.urlMap();
    assertNotNull(urls);
    String base = domain.getBaseUrl() + "/equipes/" + TEAM;
    assertEquals(base, urls.get("TEAM").get(TEAM));
    assertEquals(base + "/a-propos", urls.get("TEAM_ABOUT").get(TEAM));
    assertEquals(base + "/pages/faq", urls.get("TEAM_FAQ").get(TEAM));
    assertEquals(base + "/parcours", urls.get("ROUTES_LIST").get(TEAM));
    assertTrue(urls.get("ROUTE").get("map-1").startsWith(base + "/parcours/"));
    assertFalse(urls.get("ROUTE").containsKey("map-2"), "deleted on biketeam");
    assertTrue(urls.get("RIDE").get("ride-1").startsWith(base + "/sorties/"));
    assertFalse(urls.get("RIDE").containsKey("ride-2"));
    assertTrue(urls.get("TRIP").get("trip-1").startsWith(base + "/voyages/"));
    assertTrue(urls.get("TRIP_STAGE").get("stage-2").contains("/etapes/"));
    assertTrue(urls.get("POST").get("pub-1").startsWith(base + "/articles/"));
    assertNotNull(status.targetTeam());
    assertEquals(base, status.targetTeam().url());
  }

  // ─── replay, reset, conflicts ─────────────────────────────────────────────

  @Test
  void replay_duplicatesNothing_andDownloadsNoUnchangedFile() throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();
    String tripMarkdown = biketeamData.tripMarkdown(teamId, "Tour 2025");
    assertTrue(downloads.stream().anyMatch(p -> p.contains("/files/gpx/map-1")));
    downloads.clear();

    BiketeamJobStatusDto replay = migrate(USER4, false, false);

    assertEquals("SUCCEEDED", replay.status(), () -> "error: " + replay.error());
    assertEquals(teamId, biketeamData.team(domain, TEAM).id(), "same team");
    assertEquals(1, biketeamData.countLive(Route.class, teamId));
    assertEquals(1, biketeamData.countLive(Ride.class, teamId));
    assertEquals(1, biketeamData.countLive(Trip.class, teamId));
    assertEquals(1, biketeamData.countLive(Post.class, teamId));
    assertEquals(2, biketeamData.stages(teamId, "Tour 2025").size());
    assertEquals(
        tripMarkdown,
        biketeamData.tripMarkdown(teamId, "Tour 2025"),
        "the notes section is rebuilt, not appended again");
    assertEquals(List.of(), downloads, "same GPX fingerprint, logo already mapped");
    assertTrue(
        biketeamData.mappingRows(TEAM).size() > 5, "live mapping rows carry biketeam_team_id");
  }

  @Test
  void replay_rebuildsInPlace_aRouteAnEarlierGpxPipelineBuilt() throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();
    String current = biketeamData.routeFingerprint("map-1");
    assertNotNull(current);
    assertTrue(current.endsWith("@p" + GpxPipeline.VERSION), current);
    long routeId =
        biketeamData.mappingRows(TEAM).stream()
            .filter(m -> m.getEntityType().equals(BiketeamMigrationService.T_ROUTE))
            .findFirst()
            .orElseThrow()
            .getTriblyId();
    // What the code before the pipeline version recorded: the bare "<size>:<md5>".
    biketeamData.setRouteFingerprint("map-1", current.substring(0, current.indexOf('@')));
    downloads.clear();

    BiketeamJobStatusDto replay = migrate(USER4, false, false);

    assertEquals("SUCCEEDED", replay.status(), () -> "error: " + replay.error());
    assertTrue(
        downloads.stream().anyMatch(p -> p.contains("/files/gpx/map-1")),
        "the GPX is fetched again to be rebuilt");
    assertEquals(1, biketeamData.countLive(Route.class, teamId));
    assertEquals(
        routeId,
        biketeamData.mappingRows(TEAM).stream()
            .filter(m -> m.getEntityType().equals(BiketeamMigrationService.T_ROUTE))
            .findFirst()
            .orElseThrow()
            .getTriblyId(),
        "rebuilt in place, not recreated");
    assertEquals(current, biketeamData.routeFingerprint("map-1"));

    downloads.clear();
    migrate(USER4, false, false);
    assertEquals(List.of(), downloads, "rebuilt once, then up to date again");
  }

  @Test
  void reset_trashesTheMigratedTeam_freesItsSlug_andRecreatesIt() throws IOException {
    migrate(USER4, true, false);
    long firstId = biketeamData.team(domain, TEAM).id();

    String jobId = confirmAndTrigger(USER4, TEAM, true, true);
    BiketeamJobStatusDto status = runWorker(jobId);

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    BiketeamTestData.TeamView old = biketeamData.teamById(firstId);
    assertTrue(old.deleted());
    assertEquals(TEAM + "-reset-" + jobId, old.slug());
    BiketeamTestData.TeamView fresh = biketeamData.team(domain, TEAM);
    assertNotEquals(firstId, fresh.id());
    assertFalse(fresh.deleted());
    assertEquals(1, biketeamData.countLive(Route.class, fresh.id()));
    assertTrue(
        downloads.stream().filter(p -> p.contains("/files/gpx/map-1")).count() >= 2,
        "the recreated team rebuilds its routes");
  }

  @Test
  void aNativeTeamTakingTheSlugMeanwhile_failsTheJob_andIsLeftIntact() throws IOException {
    String jobId = confirmAndTrigger(USER4, TEAM, true, false);
    // Between the confirmation and the run, someone creates a Pédalons team at that slug.
    Team nativeTeam = dataService.createTeam(domain, user5, "Native", TEAM, Visibility.PUBLIC);

    BiketeamJobStatusDto status = runWorker(jobId);

    assertEquals("FAILED", status.status());
    assertEquals("BIKETEAM_SLUG_CONFLICT", status.error().code());
    assertNull(status.urlMap());
    BiketeamTestData.TeamView after = biketeamData.teamById(nativeTeam.getId());
    assertEquals("Native", after.name());
    assertEquals(TEAM, after.slug());
    assertFalse(after.deleted());
    assertEquals(0, biketeamData.countLive(Route.class, nativeTeam.getId()));
    BiketeamMigrationJob job = biketeamData.findJobById(TsidUtils.toLong(jobId));
    assertEquals(BiketeamMigrationStatus.FAILED, job.getStatus());
  }

  // ─── a migrated team renamed on Pédalons ──────────────────────────────────

  private io.restassured.response.ValidatableResponse preview(String user, String teamId) {
    return preview(user, teamId, false);
  }

  private io.restassured.response.ValidatableResponse preview(
      String user, String teamId, boolean reset) {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request(teamId, false, reset);
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(ContentType.JSON)
        .body(Map.of("requestToken", req.token()))
        .when()
        .post("/api/biketeam-migration/preview")
        .then();
  }

  @Test
  void aMigratedTeamRenamedOnPedalons_isStillThatTeam_andIsReplayedInPlace() throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();
    biketeamData.renameTeam(teamId, "renamed-team");

    preview(USER4, TEAM)
        .statusCode(200)
        .body("targetState", equalTo("EXISTING_MIGRATED"))
        .body("targetTeamSlug", equalTo("renamed-team"))
        .body("confirmable", equalTo(true));

    BiketeamJobStatusDto replay = migrate(USER4, false, false);

    assertEquals("SUCCEEDED", replay.status(), () -> "error: " + replay.error());
    assertNull(biketeamData.team(domain, TEAM), "no second team at the biketeam id");
    assertEquals(1, biketeamData.countTeamsCreatedBy(user4));
    assertEquals(1, biketeamData.countLive(Route.class, teamId));
    assertEquals(1, biketeamData.countLive(Ride.class, teamId));
    assertNotNull(replay.targetTeam());
    assertEquals("renamed-team", replay.targetTeam().slug());
    assertEquals(
        domain.getBaseUrl() + "/equipes/renamed-team", replay.urlMap().get("TEAM").get(TEAM));
  }

  @Test
  void aMigratedTeamRenamedOnPedalons_cannotBeReplayedNorResetByANonAdmin() throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();
    biketeamData.renameTeam(teamId, "renamed-team");

    preview(USER5, TEAM)
        .statusCode(200)
        .body("targetState", equalTo("EXISTING_MIGRATED"))
        .body("blockReason", equalTo("NOT_TEAM_ADMIN"));
    BiketeamTestTokens.Request reset = BiketeamTestTokens.request(TEAM, false, true);
    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType(ContentType.JSON)
        .body(Map.of("requestToken", reset.token()))
        .when()
        .post("/api/biketeam-migration/confirm")
        .then()
        .statusCode(403)
        .body("code", equalTo("BIKETEAM_NOT_TEAM_ADMIN"));
    assertFalse(biketeamData.teamById(teamId).deleted());
    assertNull(biketeamData.team(domain, TEAM));
  }

  @Test
  void resetOfARenamedMigratedTeam_setsItAside_andRecreatesAtTheBiketeamSlug() throws IOException {
    migrate(USER4, true, false);
    long firstId = biketeamData.team(domain, TEAM).id();
    biketeamData.renameTeam(firstId, "renamed-team");

    String jobId = confirmAndTrigger(USER4, TEAM, true, true);
    BiketeamJobStatusDto status = runWorker(jobId);

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    BiketeamTestData.TeamView old = biketeamData.teamById(firstId);
    assertTrue(old.deleted());
    assertEquals("renamed-team-reset-" + jobId, old.slug());
    BiketeamTestData.TeamView fresh = biketeamData.team(domain, TEAM);
    assertNotNull(fresh);
    assertNotEquals(firstId, fresh.id());
    assertEquals(1, biketeamData.countLive(Route.class, fresh.id()));
  }

  // ─── reset of a renamed team whose slug a native team took ────────────────

  @Test
  void resetOfARenamedMigratedTeam_whenANativeTeamHoldsTheBiketeamSlug_isBlocked_andTrashesNothing()
      throws IOException {
    snapshotTeamId = "club_x";
    runWorker(confirmAndTrigger(USER4, "club_x", true, false));
    long migratedId = biketeamData.team(domain, "club-x").id();
    biketeamData.renameTeam(migratedId, "club-x-lyon");
    Team nativeTeam = dataService.createTeam(domain, user5, "Native", "club-x", Visibility.PUBLIC);

    // Blocked from the preview on: the reset would recreate the team at club-x.
    preview(USER4, "club_x", true)
        .statusCode(200)
        .body("targetState", equalTo("SLUG_CONFLICT"))
        .body("targetTeamSlug", equalTo("club-x"))
        .body("blockReason", equalTo("SLUG_CONFLICT"))
        .body("confirmable", equalTo(false));
    BiketeamTestTokens.Request reset = BiketeamTestTokens.request("club_x", true, true);
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType(ContentType.JSON)
        .body(Map.of("requestToken", reset.token()))
        .when()
        .post("/api/biketeam-migration/confirm")
        .then()
        .statusCode(409)
        .body("code", equalTo("BIKETEAM_SLUG_CONFLICT"));
    // A replay without reset stays possible: it reuses club-x-lyon.
    preview(USER4, "club_x", false)
        .statusCode(200)
        .body("targetState", equalTo("EXISTING_MIGRATED"))
        .body("confirmable", equalTo(true));

    BiketeamTestData.TeamView migrated = biketeamData.teamById(migratedId);
    assertFalse(migrated.deleted(), "nothing in the trash");
    assertEquals("club-x-lyon", migrated.slug());
    assertTrue(biketeamData.teamMappedTo("club_x", migratedId), "mapping kept");
    assertFalse(biketeamData.teamById(nativeTeam.getId()).deleted());
  }

  @Test
  void
      resetOfARenamedMigratedTeam_whenANativeTeamTakesTheSlugAfterTheConfirmation_failsTheJob_andTrashesNothing()
          throws IOException {
    snapshotTeamId = "club_x";
    runWorker(confirmAndTrigger(USER4, "club_x", true, false));
    long migratedId = biketeamData.team(domain, "club-x").id();
    biketeamData.renameTeam(migratedId, "club-x-lyon");
    String jobId = confirmAndTrigger(USER4, "club_x", true, true);
    // Between the confirmation and the run.
    Team nativeTeam = dataService.createTeam(domain, user5, "Native", "club-x", Visibility.PUBLIC);

    BiketeamJobStatusDto status = runWorker(jobId);

    assertEquals("FAILED", status.status());
    assertEquals("BIKETEAM_SLUG_CONFLICT", status.error().code());
    BiketeamTestData.TeamView migrated = biketeamData.teamById(migratedId);
    assertFalse(migrated.deleted(), "the only copy is not left in the trash");
    assertEquals("club-x-lyon", migrated.slug());
    assertTrue(biketeamData.teamMappedTo("club_x", migratedId), "mapping kept");
    assertEquals(1, biketeamData.countLive(Route.class, migratedId));
    BiketeamTestData.TeamView after = biketeamData.teamById(nativeTeam.getId());
    assertFalse(after.deleted());
    assertEquals("club-x", after.slug());
    assertEquals(0, biketeamData.countLive(Route.class, nativeTeam.getId()));
  }

  // ─── the trigger answers the slug the job lands on ────────────────────────

  @Test
  void trigger_answersTheTargetSlug_normalised_orThatOfTheRenamedTeam_orTheBiketeamOneOnReset()
      throws IOException {
    snapshotTeamId = "club_x";
    runWorker(confirmAndTrigger(USER4, "club_x", true, false));
    assertEquals("club-x", lastTriggerSlug, "normalised, not the biketeam id");
    long migratedId = biketeamData.team(domain, "club-x").id();
    biketeamData.renameTeam(migratedId, "club-x-lyon");

    BiketeamJobStatusDto replay = runWorker(confirmAndTrigger(USER4, "club_x", false, false));
    assertEquals("club-x-lyon", lastTriggerSlug, "the migrated team, where it was renamed to");
    assertEquals("club-x-lyon", replay.targetTeam().slug());

    runWorker(confirmAndTrigger(USER4, "club_x", false, true));
    assertEquals("club-x", lastTriggerSlug, "a reset recreates the team at the biketeam slug");
  }

  // ─── content trashed on Pédalons ──────────────────────────────────────────

  @Test
  void contentTrashedOnPedalons_isRecreatedByAReplay_andNoGroupPointsAtATrashedRoute()
      throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();
    List<Long> trashedRoutes = biketeamData.trashAll(Route.class, teamId);
    List<Long> trashedPosts = biketeamData.trashAll(Post.class, teamId);
    List<Long> trashedRides = biketeamData.trashAll(Ride.class, teamId);
    assertEquals(1, trashedRoutes.size());
    assertEquals(1, trashedPosts.size());
    assertEquals(1, trashedRides.size());

    BiketeamJobStatusDto replay = migrate(USER4, false, false);

    assertEquals("SUCCEEDED", replay.status(), () -> "error: " + replay.error());
    assertEquals(0, replay.counts().routes().failed(), () -> "warnings: " + replay.warnings());
    assertEquals(0, replay.counts().publications().failed());
    assertEquals(0, replay.counts().rides().failed());
    // Biketeam is authoritative for the content: what was trashed here is created again.
    List<Long> routes = biketeamData.liveIds(Route.class, teamId);
    assertEquals(1, routes.size());
    assertFalse(trashedRoutes.contains(routes.get(0)), "a new route, not the trashed one");
    assertEquals(1, biketeamData.countLive(Post.class, teamId));
    assertFalse(trashedPosts.contains(biketeamData.liveIds(Post.class, teamId).get(0)));
    assertEquals(1, biketeamData.countLive(Ride.class, teamId));
    // The group of the recreated ride follows the recreated route, not the trashed one.
    BiketeamTestData.GroupRoute groupRoute = biketeamData.groupRoute(teamId, "Sortie du 12", "Z");
    assertNotNull(groupRoute);
    assertEquals(routes.get(0), groupRoute.id());
    assertFalse(groupRoute.deleted());
    assertTrue(
        replay.urlMap().get("ROUTE").get("map-1").startsWith(domain.getBaseUrl() + "/equipes/"));

    // And the replay after that reuses them: nothing more is created.
    BiketeamJobStatusDto again = migrate(USER4, false, false);
    assertEquals("SUCCEEDED", again.status(), () -> "error: " + again.error());
    assertEquals(routes, biketeamData.liveIds(Route.class, teamId));
  }

  // ─── replay keeps the Pédalons settings ───────────────────────────────────

  @Test
  void replay_keepsThePedalonsVisibilityAndJoinability_andContentFollowsTheTeam()
      throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();
    // Biketeam says PUBLIC; the team's admin has since made it members-only on Pédalons.
    assertEquals(Visibility.PUBLIC, biketeamData.settingsOf(teamId).visibility());
    biketeamData.setSettings(teamId, Visibility.TEAM, false);

    BiketeamJobStatusDto replay = migrate(USER4, false, false);

    assertEquals("SUCCEEDED", replay.status(), () -> "error: " + replay.error());
    assertEquals(
        new BiketeamTestData.TeamSettings(Visibility.TEAM, false), biketeamData.settingsOf(teamId));
    List<Visibility> content = biketeamData.contentVisibilities(teamId);
    assertFalse(content.isEmpty());
    content.forEach(v -> assertEquals(Visibility.TEAM, v));
  }

  @Test
  void replayByAPlatformAdmin_doesNotMakeThemAMember() throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();
    User admin = dataService.createPlatformAdminUser("godmode@example.com", "God Mode");

    BiketeamJobStatusDto replay = migrate("godmode", false, false);

    assertEquals("SUCCEEDED", replay.status(), () -> "error: " + replay.error());
    assertNull(biketeamData.roleOf(admin, teamId), "no membership for a platform admin");
    assertEquals(TeamRole.ADMIN, biketeamData.roleOf(user4, teamId));
  }

  // ─── slug normalisation ───────────────────────────────────────────────────

  @Test
  void aBiketeamIdThatIsNotAPedalonsSlug_isNormalised_andStaysTheMappingKey() throws IOException {
    snapshotTeamId = "live__team.x";

    preview(USER4, snapshotTeamId)
        .statusCode(200)
        .body("targetState", equalTo("NEW"))
        .body("targetTeamSlug", equalTo("live-team-x"));
    BiketeamJobStatusDto status = runWorker(confirmAndTrigger(USER4, snapshotTeamId, true, false));

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    BiketeamTestData.TeamView team = biketeamData.team(domain, "live-team-x");
    assertNotNull(team);
    assertTrue(
        biketeamData.mappingRows(snapshotTeamId).stream()
            .anyMatch(
                m ->
                    m.getEntityType().equals("TEAM")
                        && m.getBiketeamId().equals(snapshotTeamId)
                        && m.getTriblyId() == team.id()));
    assertEquals(
        domain.getBaseUrl() + "/equipes/live-team-x",
        status.urlMap().get("TEAM").get(snapshotTeamId));

    // Replayed: found through the mapping, not duplicated.
    BiketeamJobStatusDto replay = runWorker(confirmAndTrigger(USER4, snapshotTeamId, false, false));
    assertEquals("SUCCEEDED", replay.status(), () -> "error: " + replay.error());
    assertEquals(1, biketeamData.countTeamsCreatedBy(user4));
  }

  @Test
  void aNativeTeamAtTheNormalisedSlug_isASlugConflict() {
    Team nativeTeam = dataService.createTeam(domain, user5, "Native", "club-x", Visibility.PUBLIC);

    preview(USER4, "club_x")
        .statusCode(200)
        .body("targetState", equalTo("SLUG_CONFLICT"))
        .body("targetTeamSlug", equalTo("club-x"))
        .body("blockReason", equalTo("SLUG_CONFLICT"));
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("club_x", true, false);
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType(ContentType.JSON)
        .body(Map.of("requestToken", req.token()))
        .when()
        .post("/api/biketeam-migration/confirm")
        .then()
        .statusCode(409)
        .body("code", equalTo("BIKETEAM_SLUG_CONFLICT"));
    assertFalse(biketeamData.teamById(nativeTeam.getId()).deleted());
  }

  // ─── the export failing mid-job ───────────────────────────────────────────

  @Test
  void theExportBecomingUnreachableDuringAFile_retriesTheJob_neverSucceedsIncomplete()
      throws IOException {
    fetcher =
        (path, target) -> {
          if (path.contains("/files/gpx/")) {
            throw new BiketeamExportException(
                BiketeamExportException.Kind.UNAVAILABLE, "Download of " + path + " answered 502");
          }
          exportFiles(path, target);
        };
    String jobId = confirmAndTrigger(USER4, TEAM, true, false);

    BiketeamJobStatusDto status = runWorker(jobId);

    assertEquals("QUEUED", status.status(), "back in the queue for another attempt");
    assertNull(status.urlMap());
    BiketeamMigrationJob job = biketeamData.findJobById(TsidUtils.toLong(jobId));
    assertEquals(1, job.getAttempts());
    assertTrue(job.getNextAttemptAt().isAfter(Instant.now()));
    assertTrue(job.getErrorMessage().contains("502"), job.getErrorMessage());

    // Between two attempts, biketeam sees why the last one failed — `error` stays for the end.
    assertNull(status.error());
    assertNotNull(status.lastAttemptError());
    assertEquals("EXPORT_UNAVAILABLE", status.lastAttemptError().code());
    assertTrue(status.lastAttemptError().message().contains("502"));
    given()
        .header(SECRET_HEADER, BiketeamTestTokens.TRIGGER_SECRET)
        .when()
        .get("/api/internal/biketeam-migration/jobs/" + jobId)
        .then()
        .statusCode(200)
        .body("status", equalTo("QUEUED"))
        .body("error", org.hamcrest.Matchers.nullValue())
        .body("lastAttemptError.code", equalTo("EXPORT_UNAVAILABLE"));

    // The next attempt succeeds: nothing of the failed one is left.
    fetcher = this::exportFiles;
    biketeamData.dueNow(TsidUtils.toLong(jobId));
    BiketeamJobStatusDto retried = runWorker(jobId);
    assertEquals("SUCCEEDED", retried.status(), () -> "error: " + retried.error());
    assertEquals(2, retried.attempt());
    assertNull(retried.error());
    assertNull(retried.lastAttemptError());
  }

  @Test
  void aFileMissingOnBiketeam_isAWarningOnItsElement_andTheJobSucceeds() throws IOException {
    fetcher =
        (path, target) -> {
          if (path.contains("/files/gpx/")) {
            throw new fr.pedalons.service.migration.SourceFileUnavailableException(
                "No file at " + path + " (FILE_NOT_FOUND)");
          }
          exportFiles(path, target);
        };

    BiketeamJobStatusDto status = migrate(USER4, true, false);

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    assertTrue(
        status.warnings().stream()
            .anyMatch(
                w ->
                    w.entityType().equals("ROUTE")
                        && w.biketeamId().equals("map-1")
                        && w.code().equals("FILE_DOWNLOAD_FAILED")),
        () -> "warnings: " + status.warnings());
  }

  @Test
  void aTripWithAStageAfterItsEndDate_isAWarning_andIsMigratedAsIs() throws IOException {
    String stage2 = "{ \"id\": \"stage-2\", \"date\": \"2025-07-02\"";
    snapshotEdit =
        json -> {
          assertTrue(json.contains(stage2), "the fixture's second stage moved");
          return json.replace(stage2, "{ \"id\": \"stage-2\", \"date\": \"2025-07-05\"");
        };

    BiketeamJobStatusDto status = migrate(USER4, true, false);

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    assertEquals(2, status.counts().tripStages().migrated());
    assertTrue(
        status.warnings().stream()
            .anyMatch(
                w ->
                    w.entityType().equals("TRIP")
                        && w.biketeamId().equals("trip-1")
                        && w.code().equals("TRIP_STAGES_OUTSIDE_DATES")
                        && w.message().contains("2025-07-01 to 2025-07-02")
                        && w.message().contains("'Étape 2' (2025-07-05)")),
        () -> "warnings: " + status.warnings());
  }

  @Test
  void tripsWithinTheirDates_warnNothing() throws IOException {
    BiketeamJobStatusDto status = migrate(USER4, true, false);

    assertTrue(
        status.warnings().stream().noneMatch(w -> w.code().equals("TRIP_STAGES_OUTSIDE_DATES")),
        () -> "warnings: " + status.warnings());
  }

  // ─── route tags (docs/LEDGER_*.md MIG-14, docs/plans/archive/2026-10-01-tags.md §7) ─────

  static final String FIXTURE_TAGS = "\"tags\": [\"littoral\"]";

  /** Rewrites the tags of the fixture's route {@code map-1} to {@code tagsJson}. */
  private void routeTagsInSnapshot(String tagsJson) {
    snapshotEdit =
        json -> {
          assertTrue(json.contains(FIXTURE_TAGS), "the fixture's route tags moved");
          return json.replace(FIXTURE_TAGS, "\"tags\": " + tagsJson);
        };
  }

  @Test
  void routeTags_becomeGrayRouteTags_mergedByCase_withTheFirstSpellingKept() throws IOException {
    routeTagsInSnapshot("[\" Littoral \", \"gravel\", \"LITTORAL\", \"  \", \"Gravel\"]");

    BiketeamJobStatusDto status = migrate(USER4, true, false);

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    long teamId = biketeamData.team(domain, TEAM).id();
    assertEquals(
        List.of(
            new BiketeamTestData.TagView("gravel", "GRAY"),
            new BiketeamTestData.TagView("Littoral", "GRAY")),
        biketeamData.routeTags(teamId));
    assertEquals(
        List.of("gravel", "Littoral"), biketeamData.routeTagLabels(teamId, "Boucle du littoral"));
    assertTrue(
        status.warnings().stream().noneMatch(w -> w.code().equals("TAGS_TRUNCATED")),
        () -> "warnings: " + status.warnings());
  }

  @Test
  void routeTags_replay_duplicatesNothing_andReplacesTheRoutesSet() throws IOException {
    migrate(USER4, true, false);
    long teamId = biketeamData.team(domain, TEAM).id();
    assertEquals(List.of("littoral"), biketeamData.routeTagLabels(teamId, "Boucle du littoral"));

    // Another spelling of the same tag, and a new one.
    routeTagsInSnapshot("[\"LITTORAL\", \"Côte Est\"]");
    migrate(USER4, false, false);

    assertEquals(
        List.of(
            new BiketeamTestData.TagView("Côte Est", "GRAY"),
            new BiketeamTestData.TagView("littoral", "GRAY")),
        biketeamData.routeTags(teamId));
    assertEquals(
        List.of("Côte Est", "littoral"), biketeamData.routeTagLabels(teamId, "Boucle du littoral"));

    // Gone on biketeam: off the route, still in the team's vocabulary.
    routeTagsInSnapshot("[\"Côte Est\"]");
    migrate(USER4, false, false);

    assertEquals(List.of("Côte Est"), biketeamData.routeTagLabels(teamId, "Boucle du littoral"));
    assertEquals(2, biketeamData.routeTags(teamId).size());
  }

  @Test
  void routeTags_beyond10OrLongerThan32_keepTheFirstOnes_cutOnCodePoints_andWarn()
      throws IOException {
    String longLabel = "Une très longue étiquette de parcours biketeam";
    // 33 code points, the 32nd a surrogate pair: the cut keeps it whole, never half of it.
    String emojiLabel = "v".repeat(31) + "\uD83D\uDEB4\uD83D\uDEB4";
    List<String> labels = new ArrayList<>();
    labels.add(longLabel);
    labels.add(emojiLabel);
    for (int i = 1; i <= 11; i++) {
      labels.add("T" + i);
    }
    routeTagsInSnapshot(objectMapper.writeValueAsString(labels));

    BiketeamJobStatusDto status = migrate(USER4, true, false);

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    assertEquals(1, status.counts().routes().migrated());
    long teamId = biketeamData.team(domain, TEAM).id();
    List<String> onRoute = biketeamData.routeTagLabels(teamId, "Boucle du littoral");
    assertEquals(10, onRoute.size(), () -> "tags: " + onRoute);
    String cut = longLabel.substring(0, 32).strip();
    assertTrue(onRoute.contains(cut), () -> "tags: " + onRoute);
    String emojiCut = "v".repeat(31) + "\uD83D\uDEB4";
    assertTrue(onRoute.contains(emojiCut), () -> "tags: " + onRoute);
    assertTrue(onRoute.contains("T8"));
    assertFalse(onRoute.contains("T9"));
    assertFalse(onRoute.contains("T10"));
    assertFalse(onRoute.contains("T11"));
    assertTrue(
        status.warnings().stream()
            .anyMatch(
                w ->
                    w.entityType().equals("ROUTE")
                        && w.biketeamId().equals("map-1")
                        && w.code().equals("TAGS_TRUNCATED")
                        && w.message().contains(cut)
                        && w.message().contains(emojiCut + "'")
                        && w.message().contains("T9")
                        && w.message().contains("T10")
                        && w.message().contains("T11")),
        () -> "warnings: " + status.warnings());
  }

  @Test
  void routeTags_whenTheTeamHas100RouteTags_aNewLabelIsDropped_anExistingOneStillApplies()
      throws IOException {
    migrate(USER4, true, false);
    BiketeamTestData.TeamView view = biketeamData.team(domain, TEAM);
    Team team = dataService.findTeamBySlug(domain, view.slug());
    for (int i = 1; i < fr.pedalons.service.tag.TagService.MAX_TAGS_PER_TEAM_AND_TYPE; i++) {
      dataService.createTag(team, user4, fr.pedalons.enums.TagTarget.ROUTE, "Existant " + i);
    }

    routeTagsInSnapshot("[\"Nouveau\", \"Littoral\", \"existant 7\"]");
    BiketeamJobStatusDto status = migrate(USER4, false, false);

    assertEquals("SUCCEEDED", status.status(), () -> "error: " + status.error());
    assertEquals(
        List.of("Existant 7", "littoral"),
        biketeamData.routeTagLabels(view.id(), "Boucle du littoral"));
    assertEquals(100, biketeamData.routeTags(view.id()).size());
    assertTrue(
        status.warnings().stream()
            .anyMatch(w -> w.code().equals("TAGS_TRUNCATED") && w.message().contains("'Nouveau'")),
        () -> "warnings: " + status.warnings());
  }

  // ─── recovery of stuck jobs ───────────────────────────────────────────────

  @Test
  void recoverStuck_requeuesOrFailsTheSilentJobs_inBulk_andLeavesTheLiveOneAlone() {
    Instant longAgo = Instant.now().minus(Duration.ofHours(1));
    long requeued = biketeamData.createActiveJob(domain, user4, "stuck-a").getId();
    long neverBeat = biketeamData.createActiveJob(domain, user4, "stuck-b").getId();
    long exhausted = biketeamData.createActiveJob(domain, user4, "stuck-c").getId();
    long alive = biketeamData.createActiveJob(domain, user4, "alive").getId();
    biketeamData.markRunning(requeued, 1, longAgo);
    biketeamData.markRunning(neverBeat, 2, null);
    biketeamData.markRunning(exhausted, 3, longAgo);
    biketeamData.markRunning(alive, 1, Instant.now());
    LiveJobContext staleRun = jobService.loadContext(requeued);
    long versionBefore = biketeamData.findJobById(requeued).getVersion();

    jobService.recoverStuck();

    BiketeamMigrationJob a = biketeamData.findJobById(requeued);
    assertEquals(BiketeamMigrationStatus.QUEUED, a.getStatus());
    assertFalse(a.getNextAttemptAt().isAfter(Instant.now()), "runnable right away");
    assertEquals(1, a.getAttempts(), "counted when claimed, not when requeued");
    assertTrue(a.getVersion() > versionBefore, "a stale copy of the row cannot be written back");
    assertEquals(BiketeamMigrationStatus.QUEUED, biketeamData.findJobById(neverBeat).getStatus());
    BiketeamMigrationJob c = biketeamData.findJobById(exhausted);
    assertEquals(BiketeamMigrationStatus.FAILED, c.getStatus());
    assertEquals(BiketeamMigrationJobService.WORKER_LOST, c.getErrorCode());
    assertNotNull(c.getFinishedAt());
    BiketeamJobStatusDto requeuedStatus = jobService.status(TsidUtils.toString(requeued));
    assertNull(requeuedStatus.error(), "not final: attempts remain");
    assertEquals(BiketeamMigrationJobService.WORKER_LOST, requeuedStatus.lastAttemptError().code());
    BiketeamJobStatusDto failedStatus = jobService.status(TsidUtils.toString(exhausted));
    assertEquals(BiketeamMigrationJobService.WORKER_LOST, failedStatus.error().code());
    assertNull(failedStatus.lastAttemptError(), "a FAILED job carries its reason in error");
    assertNull(jobService.status(TsidUtils.toString(alive)).lastAttemptError());
    assertEquals(BiketeamMigrationStatus.RUNNING, biketeamData.findJobById(alive).getStatus());

    // The worker of the requeued attempt, still going, can no longer write.
    assertThrows(
        BiketeamJobLostException.class,
        () ->
            jobService.recordProgress(
                staleRun, jobService.toJson(Map.of()), jobService.toJson(Map.of())));
  }
}
