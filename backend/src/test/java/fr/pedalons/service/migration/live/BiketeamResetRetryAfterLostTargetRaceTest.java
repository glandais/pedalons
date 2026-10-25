package fr.pedalons.service.migration.live;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.migration.BiketeamMigrationJob;
import fr.pedalons.dto.migration.internal.BiketeamJobStatusDto;
import fr.pedalons.service.migration.live.snapshot.BiketeamSnapshot;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.mockito.InjectSpy;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import tools.jackson.databind.ObjectMapper;

/**
 * Bug found by the formal model of the live-migration worker (TLA+ spec of the job lifecycle:
 * {@code ensureLiveTargetTeam} and {@code setTargetTeam} as two separate atomic steps, with a crash
 * / transient failure / {@code JobLost} allowed between them).
 *
 * <p>A reset job whose attempt commits {@code ensureLiveTargetTeam} (T1 trashed as {@code
 * <slug>-reset-<jobTsid>}, T2 created at the biketeam slug, TEAM mapping → T2) but then fails in
 * {@code BiketeamMigrationJobService.setTargetTeam} (its own {@code requiringNew} transaction)
 * leaves {@code target_team_id} NULL. The next attempt no longer recognises T2 as the reset's own
 * result: {@code prepareTarget} decides to set T2 aside too, renaming it to the very same {@code
 * <slug>-reset-<jobTsid>} T1 already holds → {@code uk_teams_domain_slug} (which covers trashed
 * teams) on every attempt → the job ends FAILED INTERNAL_ERROR. When the migrated team had been
 * renamed on Pédalons, the slugs differ and the retry instead throws away T2 and creates a T3.
 *
 * <p>The interleaving is driven deterministically: a spy on the job service makes the first {@code
 * setTargetTeam} call throw (as a DB blip or a lost job would), then behaves normally.
 *
 * <p>Code: BiketeamLiveMigrationWorker#prepareTarget / #setAside, BiketeamMigrationService
 * #migrateTeamLive / #ensureLiveTargetTeam, BiketeamMigrationJobService#setTargetTeam.
 */
@QuarkusTest
class BiketeamResetRetryAfterLostTargetRaceTest extends AbstractResourceTest {

  static final String TEAM = "live-team";
  static final String SECRET_HEADER = "X-Biketeam-Migration-Secret";

  @Inject BiketeamLiveMigrationWorker worker;
  @InjectSpy BiketeamMigrationJobService jobService;
  @Inject BiketeamTestData biketeamData;
  @Inject ObjectMapper objectMapper;

  @BeforeEach
  void setUpTest() {
    setUp();
  }

  // ─── plumbing (same as BiketeamLiveMigrationTest) ─────────────────────────

  private static Path resource(String name) {
    try {
      return Path.of(
          BiketeamResetRetryAfterLostTargetRaceTest.class.getResource("/" + name).toURI());
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
            .replace("${IMAGE_MD5}", SnapshotBiketeamSource.md5Of(image));
    return objectMapper.readValue(json, BiketeamSnapshot.class);
  }

  private void exportFiles(String path, Path target) throws IOException {
    String name = path.contains("/files/gpx/") ? "example.gpx" : "image.png";
    try (InputStream in = Files.newInputStream(resource(name))) {
      Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
    }
  }

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
    return given()
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
        .extract()
        .path("jobId");
  }

  private BiketeamJobStatusDto runWorker(String jobId) throws IOException {
    BiketeamSnapshot snapshot = snapshot();
    Path tempDir = Files.createTempDirectory("biketeam-test-");
    assertTrue(
        worker.runOne(
            (ctx, heartbeat) -> new SnapshotBiketeamSource(snapshot, this::exportFiles, tempDir)));
    return jobService.status(jobId);
  }

  /** The first {@code setTargetTeam} fails after the team transaction committed; later ones work. */
  private void loseTheFirstSetTargetTeam() {
    Mockito.doThrow(new RuntimeException("transient: connection reset while recording the target"))
        .doCallRealMethod()
        .when(jobService)
        .setTargetTeam(any(), anyLong());
  }

  /** Attempt 1 created T2 at the biketeam slug, then lost the write of target_team_id. */
  private long runFirstAttemptLosingTheTarget(String jobId, long firstId) throws IOException {
    loseTheFirstSetTargetTeam();
    BiketeamJobStatusDto first = runWorker(jobId);
    assertEquals("QUEUED", first.status(), "attempt 1 is retried");
    assertNotNull(first.lastAttemptError());
    assertEquals(BiketeamMigrationJobService.INTERNAL_ERROR, first.lastAttemptError().code());

    BiketeamTestData.TeamView created = biketeamData.team(domain, TEAM);
    assertNotNull(created, "attempt 1 committed the new team before losing the target");
    assertFalse(created.deleted());
    assertNotEquals(firstId, created.id());
    assertTrue(biketeamData.teamMappedTo(TEAM, created.id()));
    return created.id();
  }

  // ─── the bug ──────────────────────────────────────────────────────────────

  @Test
  void resetRetriedAfterLosingItsTarget_resumesTheTeamItCreated_insteadOfFailingOnTheSetAsideSlug()
      throws IOException {
    BiketeamJobStatusDto initial = runWorker(confirmAndTrigger(USER4, TEAM, true, false));
    assertEquals("SUCCEEDED", initial.status(), () -> "error: " + initial.error());
    long firstId = biketeamData.team(domain, TEAM).id();

    String jobId = confirmAndTrigger(USER4, TEAM, true, true);
    long createdByAttempt1 = runFirstAttemptLosingTheTarget(jobId, firstId);
    BiketeamTestData.TeamView old = biketeamData.teamById(firstId);
    assertTrue(old.deleted());
    assertEquals(TEAM + "-reset-" + jobId, old.slug());

    // Attempt 2: on the current code it renames T2 to TEAM-reset-<jobId> too and violates
    // uk_teams_domain_slug — on this attempt and on every following one.
    biketeamData.dueNow(TsidUtils.toLong(jobId));
    BiketeamJobStatusDto second = runWorker(jobId);
    if (!"SUCCEEDED".equals(second.status())) {
      // Let the job exhaust its attempts so the failure shows its final state.
      biketeamData.dueNow(TsidUtils.toLong(jobId));
      BiketeamJobStatusDto third = runWorker(jobId);
      BiketeamMigrationJob job = biketeamData.findJobById(TsidUtils.toLong(jobId));
      throw new AssertionError(
          "The retry of the reset did not resume the team it created: attempt 2 "
              + second.status()
              + " ("
              + (second.lastAttemptError() == null ? null : second.lastAttemptError().message())
              + "), attempt 3 "
              + third.status()
              + " — "
              + job.getErrorCode()
              + ": "
              + job.getErrorMessage());
    }

    BiketeamTestData.TeamView live = biketeamData.team(domain, TEAM);
    assertNotNull(live);
    assertFalse(live.deleted());
    assertEquals(createdByAttempt1, live.id(), "the reset is not replayed on its own result");
    assertEquals(TEAM + "-reset-" + jobId, biketeamData.teamById(firstId).slug());
    assertTrue(biketeamData.teamMappedTo(TEAM, createdByAttempt1));
  }

  @Test
  void resetOfARenamedTeamRetriedAfterLosingItsTarget_doesNotThrowAwayTheTeamItCreated()
      throws IOException {
    BiketeamJobStatusDto initial = runWorker(confirmAndTrigger(USER4, TEAM, true, false));
    assertEquals("SUCCEEDED", initial.status(), () -> "error: " + initial.error());
    long firstId = biketeamData.team(domain, TEAM).id();
    biketeamData.renameTeam(firstId, "renamed-team");

    String jobId = confirmAndTrigger(USER4, TEAM, true, true);
    long createdByAttempt1 = runFirstAttemptLosingTheTarget(jobId, firstId);
    assertEquals("renamed-team-reset-" + jobId, biketeamData.teamById(firstId).slug());

    biketeamData.dueNow(TsidUtils.toLong(jobId));
    BiketeamJobStatusDto second = runWorker(jobId);
    assertEquals("SUCCEEDED", second.status(), () -> "error: " + second.error());

    // Today: T2 is trashed as live-team-reset-<jobId> and a T3 takes the slug.
    BiketeamTestData.TeamView t2 = biketeamData.teamById(createdByAttempt1);
    assertFalse(t2.deleted(), "the team the reset created is not reset again by its own retry");
    assertEquals(TEAM, t2.slug());
    assertEquals(createdByAttempt1, biketeamData.team(domain, TEAM).id());
  }
}
