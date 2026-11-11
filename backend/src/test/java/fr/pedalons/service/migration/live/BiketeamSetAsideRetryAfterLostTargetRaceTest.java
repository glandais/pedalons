package fr.pedalons.service.migration.live;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;

import com.fasterxml.jackson.databind.ObjectMapper;
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

/**
 * The retry of a job that set a trashed team aside, after losing the write of its target — the
 * interleaving the formal model of the live-migration worker found a bug in (TLA+ spec of the job
 * lifecycle: {@code ensureLiveTargetTeam} and {@code setTargetTeam} as two separate atomic steps,
 * with a crash / transient failure / {@code JobLost} allowed between them).
 *
 * <p>The bug was the reset's (docs/LEDGER_*.md MIG-15): its retry reset the team its first attempt
 * had just created. The reset is gone (MIG-16), and with it the guard; what is left of the
 * scenario is the setting aside of a migrated team found in the Pédalons trash. An attempt commits
 * {@code ensureLiveTargetTeam} (T1 renamed {@code <slug>-reset-<jobTsid>} in the trash, T2 created
 * at the biketeam slug, TEAM mapping → T2, the confirming account ADMIN of T2) and then fails in
 * {@code BiketeamMigrationJobService.setTargetTeam} (its own {@code requiringNew} transaction),
 * leaving {@code target_team_id} NULL. The next attempt must find T2 through its mapping row —
 * EXISTING_MIGRATED — and carry on in it: nothing set aside twice, no third team.
 *
 * <p>The interleaving is driven deterministically: a spy on the job service makes the first {@code
 * setTargetTeam} call throw (as a DB blip or a lost job would), then behaves normally.
 *
 * <p>Code: BiketeamLiveMigrationWorker#prepareTarget / #setAside, BiketeamMigrationService
 * #migrateTeamLive / #ensureLiveTargetTeam, BiketeamMigrationJobService#setTargetTeam.
 */
@QuarkusTest
class BiketeamSetAsideRetryAfterLostTargetRaceTest extends AbstractResourceTest {

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
          BiketeamSetAsideRetryAfterLostTargetRaceTest.class.getResource("/" + name).toURI());
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

  private String confirmAndTrigger(String user, String teamId) {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request(teamId);
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
        .body(Map.of("requestId", req.requestId(), "grant", grant, "teamId", teamId))
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

  // ─── the scenario ─────────────────────────────────────────────────────────

  /**
   * @param renamedTo the slug the migrated team was given on Pédalons before it was trashed, or
   *     null when it kept the biketeam one
   */
  private void retryResumesTheTeamTheFirstAttemptCreated(String renamedTo) throws IOException {
    BiketeamJobStatusDto initial = runWorker(confirmAndTrigger(USER4, TEAM));
    assertEquals("SUCCEEDED", initial.status(), () -> "error: " + initial.error());
    long firstId = biketeamData.team(domain, TEAM).id();
    String trashedSlug = TEAM;
    if (renamedTo != null) {
      biketeamData.renameTeam(firstId, renamedTo);
      trashedSlug = renamedTo;
    }
    biketeamData.trashTeam(firstId);

    String jobId = confirmAndTrigger(USER4, TEAM);
    long createdByAttempt1 = runFirstAttemptLosingTheTarget(jobId, firstId);
    BiketeamTestData.TeamView old = biketeamData.teamById(firstId);
    assertTrue(old.deleted());
    assertEquals(trashedSlug + "-reset-" + jobId, old.slug());

    biketeamData.dueNow(TsidUtils.toLong(jobId));
    BiketeamJobStatusDto second = runWorker(jobId);
    if (!"SUCCEEDED".equals(second.status())) {
      BiketeamMigrationJob job = biketeamData.findJobById(TsidUtils.toLong(jobId));
      throw new AssertionError(
          "The retry did not resume the team its first attempt created: "
              + second.status()
              + " — "
              + job.getErrorCode()
              + ": "
              + job.getErrorMessage());
    }

    BiketeamTestData.TeamView live = biketeamData.team(domain, TEAM);
    assertNotNull(live);
    assertFalse(live.deleted());
    assertEquals(createdByAttempt1, live.id(), "the team of the first attempt, not a third one");
    assertEquals(trashedSlug + "-reset-" + jobId, biketeamData.teamById(firstId).slug());
    assertTrue(biketeamData.teamMappedTo(TEAM, createdByAttempt1));
    assertNotNull(second.targetTeam());
    assertEquals(TEAM, second.targetTeam().slug());
  }

  @Test
  void aJobThatSetATrashedTeamAside_retriedAfterLosingItsTarget_resumesTheTeamItCreated()
      throws IOException {
    retryResumesTheTeamTheFirstAttemptCreated(null);
  }

  @Test
  void aJobThatSetARenamedTrashedTeamAside_retriedAfterLosingItsTarget_resumesTheTeamItCreated()
      throws IOException {
    retryResumesTheTeamTheFirstAttemptCreated("renamed-team");
  }
}
