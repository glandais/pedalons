package fr.pedalons.service.thumbnail;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md OPS-71, API-223: the catch-up that redraws the thumbnails drawn before {@link
 * MapThumbnailRenderer#VERSION}. The renderer is replaced by one that writes a real 1×1 PNG, or
 * fails while {@code failing} is set. The thumbnails of the "old" entities are the dummy files of
 * {@code attachAsset}, their version null as before the column.
 */
@QuarkusTest
class ThumbnailBackfillTest extends AbstractResourceTest {

  @InjectMock MapThumbnailRenderer renderer;

  @Inject ThumbnailBackfill backfill;
  @Inject EntityManager entityManager;

  private final AtomicBoolean failing = new AtomicBoolean();
  private int count;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    failing.set(false);
    count = 0;
    try {
      doAnswer(
              invocation -> {
                if (failing.get()) {
                  throw new IOException("tileserver down");
                }
                File output = invocation.getArgument(0);
                ImageIO.write(new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB), "png", output);
                return null;
              })
          .when(renderer)
          .render(any(File.class), anyList(), anyString(), anyList());
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
    backfill.setForTest(true, 300);
  }

  @AfterEach
  void restoreSwitches() {
    backfill.setForTest(false, 300);
  }

  // ------------------------------------------------------------------ helpers

  /** A route drawn by the previous release: both thumbnails, no version. */
  private Route oldRoute() {
    count++;
    Route route = dataService.createRoute(team1, user1, "Ancien " + count);
    dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "thumbnail-light.png");
    dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_DARK, "thumbnail-dark.png");
    return route;
  }

  private void sql(String statement, Object... params) {
    QuarkusTransaction.requiringNew()
        .run(() -> {
          var query = entityManager.createNativeQuery(statement);
          for (int i = 0; i < params.length; i++) {
            query.setParameter(i + 1, params[i]);
          }
          query.executeUpdate();
        });
  }

  /** {version, attempts, retry_at} of an entity. */
  private Object[] state(Long id) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            (Object[])
                entityManager
                    .createNativeQuery(
                        "select thumbnail_version, thumbnail_attempts, thumbnail_retry_at"
                            + " from team_entities where id = ?1")
                    .setParameter(1, id)
                    .getSingleResult());
  }

  /** Asset id to file id of the thumbnails of an entity. */
  private Map<Long, Long> files(Long id) {
    return QuarkusTransaction.requiringNew()
        .call(() -> {
          Map<Long, Long> files = new LinkedHashMap<>();
          for (Object row :
              entityManager
                  .createNativeQuery(
                      "select id, file_id from assets where team_entity_id = ?1 order by id")
                  .setParameter(1, id)
                  .getResultList()) {
            Object[] r = (Object[]) row;
            files.put(((Number) r[0]).longValue(), ((Number) r[1]).longValue());
          }
          return files;
        });
  }

  private void assertStamped(Long id) {
    Object[] state = state(id);
    assertEquals(MapThumbnailRenderer.VERSION, ((Number) state[0]).intValue());
    assertEquals(0, ((Number) state[1]).intValue());
    assertNull(state[2]);
  }

  private void verifyRenders(int count) throws Exception {
    verify(renderer, times(count)).render(any(File.class), anyList(), anyString(), anyList());
  }

  // ------------------------------------------------------------------ tests

  @Test
  void anOwnerWithoutVersion_isRedrawnAndStamped_keepingItsAssetRows() throws Exception {
    Long id = oldRoute().getId();
    assertNull(state(id)[0]);
    Map<Long, Long> before = files(id);
    assertEquals(2, before.size());

    assertEquals(1, backfill.pass(Instant.now()));

    verifyRenders(2);
    assertStamped(id);
    Map<Long, Long> after = files(id);
    assertEquals(before.keySet(), after.keySet(), "same asset rows, URLs unchanged");
    before.forEach((asset, file) -> assertNotEquals(file, after.get(asset), "new file"));
    // Nothing left to do
    clearInvocations(renderer);
    assertEquals(0, backfill.pass(Instant.now()));
    verifyRenders(0);
  }

  @Test
  void anUpToDateOwner_isSkipped() throws Exception {
    Long id = oldRoute().getId();
    sql(
        "update team_entities set thumbnail_version = ?1 where id = ?2",
        (short) MapThumbnailRenderer.VERSION,
        id);
    Map<Long, Long> before = files(id);

    assertEquals(0, backfill.pass(Instant.now()));

    verifyRenders(0);
    assertEquals(before, files(id));
  }

  @Test
  void aFailedRender_keepsTheOldThumbnails_countsAnAttempt_andEndsThePass() throws Exception {
    backfill.setForTest(true, 600);
    Long first = oldRoute().getId();
    Long second = oldRoute().getId();
    Map<Long, Long> firstBefore = files(first);
    Map<Long, Long> secondBefore = files(second);
    failing.set(true);

    assertEquals(0, backfill.pass(Instant.now()));

    // The most recent first, and the pass stopped there: the other was not even tried
    verifyRenders(1);
    assertEquals(firstBefore, files(first), "same files");
    assertEquals(secondBefore, files(second));
    Object[] failed = state(second);
    assertNull(failed[0]);
    assertEquals(1, ((Number) failed[1]).intValue());
    assertNotNull(failed[2]);
    assertEquals(0, ((Number) state(first)[1]).intValue());
  }

  @Test
  void anOwnerWaitingForARetry_isSkippedUntilItsTime() throws Exception {
    Long id = oldRoute().getId();
    failing.set(true);
    Instant now = Instant.now();
    assertEquals(0, backfill.pass(now));
    verifyRenders(1);
    clearInvocations(renderer);
    failing.set(false);

    // The first retry is due in 15 minutes
    assertEquals(0, backfill.pass(now.plus(Duration.ofMinutes(5))));
    verifyRenders(0);

    assertEquals(1, backfill.pass(now.plus(Duration.ofMinutes(20))));
    verifyRenders(2);
    assertStamped(id);
  }

  @Test
  void anOwnerAfterFiveFailures_isGivenUp() throws Exception {
    Long id = oldRoute().getId();
    sql("update team_entities set thumbnail_attempts = ?1 where id = ?2", (short) 5, id);
    Map<Long, Long> before = files(id);

    assertEquals(0, backfill.pass(Instant.now().plus(Duration.ofDays(2))));

    verifyRenders(0);
    assertEquals(before, files(id));
  }

  @Test
  void aPass_redrawsAtMostAMinutesShareOfTheHourlyCap() throws Exception {
    // 60 an hour is one a minute
    backfill.setForTest(true, 60);
    Long first = oldRoute().getId();
    Long second = oldRoute().getId();

    assertEquals(1, backfill.pass(Instant.now()));
    // The most recent one
    assertStamped(second);
    assertNull(state(first)[0]);

    assertEquals(1, backfill.pass(Instant.now()));
    assertStamped(first);
  }

  @Test
  void whenDisabled_nothingIsRedrawn() throws Exception {
    Long id = oldRoute().getId();
    backfill.setForTest(false, 300);

    assertEquals(0, backfill.pass(Instant.now()));

    verifyRenders(0);
    assertNull(state(id)[0]);
  }

  @Test
  void aDeletedEntity_orOneOfADeletedTeam_isSkipped() throws Exception {
    Long deleted = oldRoute().getId();
    sql("update team_entities set deleted = true where id = ?1", deleted);
    Long inDeletedTeam = oldRoute().getId();
    sql("update teams set deleted = true where id = ?1", team1.getId());

    assertEquals(0, backfill.pass(Instant.now()));

    verifyRenders(0);
    assertNull(state(deleted)[0]);
    assertNull(state(inDeletedTeam)[0]);
  }

  @Test
  void anOwnerWithoutThumbnails_isNotACandidate() throws Exception {
    dataService.createRoute(team1, user1, "Sans vignette");

    assertEquals(0, backfill.pass(Instant.now()));

    verifyRenders(0);
  }

  @Test
  void theSavePath_stampsTheVersion() throws Exception {
    backfill.setForTest(false, 300);
    Route route = dataService.createRoute(team1, user1, "Parcours");
    Instant nextWeek = Instant.now().plus(7, ChronoUnit.DAYS);
    RideRequest request =
        new RideRequest(
            "Sortie",
            MediaDto.builder().build(),
            wall(nextWeek),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            route.getSlug(),
            null,
            null,
            null,
            List.of(new GroupRequest(null, "G1", null, null, null, null)),
            null);

    String slug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(request)
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    verifyRenders(2);
    Long rideId =
        QuarkusTransaction.requiringNew()
            .call(() ->
                ((Number)
                        entityManager
                            .createNativeQuery(
                                "select id from team_entities where slug = ?1 and team_id = ?2")
                            .setParameter(1, slug)
                            .setParameter(2, team1.getId())
                            .getSingleResult())
                    .longValue());
    assertStamped(rideId);
  }
}
