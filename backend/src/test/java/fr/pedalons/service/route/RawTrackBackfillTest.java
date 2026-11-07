package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.RawTrackBackfillRepository.Candidate;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.route.RawTrackBackfill.Outcome;
import fr.pedalons.service.route.RawTrackBackfill.Read;
import fr.pedalons.service.route.RawTrackBackfill.Report;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.surface.SurfaceRefreshService;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import fr.pedalons.util.TestDataService.RawGeometry;
import io.agroal.api.AgroalDataSource;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.mockito.InjectSpy;
import jakarta.inject.Inject;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.Statement;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import software.amazon.awssdk.core.exception.SdkClientException;

/**
 * docs/LEDGER_*.md API-149 (phase D): the catch-up of the raw line of the tracks saved before it
 * existed. The "old" tracks are routes saved now whose raw line is nulled by a native update, as a
 * row written before V81 would be. No test reaches Stadia Maps: the surface requests are only
 * looked at in the queue.
 */
@QuarkusTest
class RawTrackBackfillTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();
  private static final Path TWO_TRACKS = new File("src/test/resources/two_tracks.gpx").toPath();

  @InjectMock MapThumbnailRenderer renderer;

  @Inject RouteService routeService;
  @Inject GpxProcessingService gpxProcessingService;
  @Inject RawTrackBackfill backfill;
  @Inject SurfaceRefreshService surfaceService;
  @InjectSpy GpxTrackRepository trackRepository;
  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @InjectSpy StorageService storageService;
  @Inject AgroalDataSource dataSource;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  private int routeCount;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    queryContext.setUserForTest(user1);
    routeCount = 0;
    try {
      doAnswer(
              invocation -> {
                File output = invocation.getArgument(0);
                ImageIO.write(new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB), "png", output);
                return null;
              })
          .when(renderer)
          .render(any(File.class), anyList(), anyString(), anyList());
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  @AfterEach
  void restoreSwitches() {
    backfill.setForTest(false, 50);
    surfaceService.setEnabledForTest(false);
  }

  // ------------------------------------------------------------------ helpers

  private void on() {
    backfill.setForTest(true, 100);
  }

  /** A route saved before V81: its tracks lose their raw line. */
  private Long oldRoute(Path gpx) {
    queryContext.setUserForTest(user1);
    routeCount++;
    Long id =
        TsidUtils.toLong(
            routeService
                .createRoute(
                    team1Slug,
                    new RouteRequest(
                        "Ancien " + routeCount,
                        MediaDto.builder().markdown("Parcours").build(),
                        SurfaceType.ROAD,
                        Visibility.PUBLIC,
                        null,
                        null,
                        null),
                    gpx)
                .id());
    sql("update gpx_tracks set raw_geometry = null where route_id = ?1", id);
    return id;
  }

  private void sql(String statement, Object... params) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              var query = trackRepository.getEntityManager().createNativeQuery(statement);
              for (int i = 0; i < params.length; i++) {
                query.setParameter(i + 1, params[i]);
              }
              query.executeUpdate();
            });
  }

  /** The number of points of every sanitized source track, as a save stores its raw line. */
  private List<Integer> sourceSizes(Path gpx) {
    return gpxProcessingService.rawTracks(gpxProcessingService.parseGpx(gpx)).paths().stream()
        .map(io.github.glandais.engine.path.Path::getSize)
        .toList();
  }

  private void assertRawOf(List<Integer> expected, Long routeId) {
    List<RawGeometry> raw = dataService.rawGeometries(routeId);
    assertEquals(expected.size(), raw.size(), "one raw geometry per track");
    for (int i = 0; i < raw.size(); i++) {
      assertEquals(expected.get(i), raw.get(i).points(), "every source point, track " + i);
      assertEquals(2, raw.get(i).dims(), "2D, no elevation, track " + i);
    }
  }

  private void assertNoRaw(Long routeId) {
    for (RawGeometry raw : dataService.rawGeometries(routeId)) {
      assertNull(raw.ewkb(), "no raw line written");
    }
  }

  private long originalFileId(Long routeId) {
    return QuarkusTransaction.requiringNew()
        .call(() -> assetRepository.findCurrentFileId(routeId, AssetType.ROUTE_ORIGINAL_GPX));
  }

  private Optional<String> skipReason(Long routeId) {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                trackRepository
                    .getEntityManager()
                    .createNativeQuery(
                        "select reason from raw_track_backfill_skip where route_id = ?1",
                        String.class)
                    .setParameter(1, routeId)
                    .getResultStream()
                    .findFirst());
  }

  private Candidate candidate(Long routeId) {
    return backfill.candidates(100).stream()
        .filter(c -> c.routeId().equals(routeId))
        .findFirst()
        .orElseThrow();
  }

  /**
   * A GPX of the stored points of {@code routeId}, with {@code between} points interpolated
   * between each two: with none, what the original of a route drawn in the planner is (its
   * simplified line); with some, a recording of the same way, denser than what the pipeline keeps.
   */
  private Path traceOf(Long routeId, int between) throws Exception {
    List<GpxTrack.TrackPoint> points =
        QuarkusTransaction.requiringNew()
            .call(() -> trackRepository.findPoints(routeId).getFirst().points());
    StringBuilder gpx =
        new StringBuilder(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                + "<gpx version=\"1.1\" creator=\"test\""
                + " xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><name>Trace</name><trkseg>\n");
    for (int i = 0; i < points.size(); i++) {
      GpxTrack.TrackPoint p = points.get(i);
      int steps = i + 1 < points.size() ? between + 1 : 1;
      for (int k = 0; k < steps; k++) {
        GpxTrack.TrackPoint q = i + 1 < points.size() ? points.get(i + 1) : p;
        double f = (double) k / (between + 1);
        gpx.append("<trkpt lat=\"")
            .append(p.lat() + f * (q.lat() - p.lat()))
            .append("\" lon=\"")
            .append(p.lng() + f * (q.lng() - p.lng()))
            .append("\"><ele>")
            .append(p.ele() + f * (q.ele() - p.ele()))
            .append("</ele></trkpt>\n");
      }
    }
    gpx.append("</trkseg></trk></gpx>\n");
    Path file = Files.createTempFile("trace-", ".gpx");
    file.toFile().deleteOnExit();
    Files.writeString(file, gpx, StandardCharsets.UTF_8);
    return file;
  }

  // ------------------------------------------------------------------ tests

  @Test
  void anOldRoute_getsItsRawLineBack_andASecondPassIsANoOp() {
    Long single = oldRoute(EXAMPLE);
    Long two = oldRoute(TWO_TRACKS);
    assertNoRaw(single);
    on();

    Report first = backfill.runOnce(Instant.now());

    assertEquals(new Report(2, 0), first);
    assertRawOf(sourceSizes(EXAMPLE), single);
    assertRawOf(sourceSizes(TWO_TRACKS), two);
    List<RawGeometry> before = dataService.rawGeometries(single);

    Report second = backfill.runOnce(Instant.now());

    assertEquals(new Report(0, 0), second);
    assertEquals(before, dataService.rawGeometries(single), "nothing rewritten");
    assertTrue(skipReason(single).isEmpty());
  }

  @Test
  void anOriginalReplacedBetweenTheReadAndTheWrite_isNotWritten() throws Exception {
    Long id = oldRoute(EXAMPLE);
    on();
    Candidate candidate = candidate(id);
    Read read = backfill.read(candidate);
    assertNotNull(read.lines());

    // A save of the previous release (no raw line) replaced the original meanwhile
    sql(
        "update assets set file_id = file_id + 1 where team_entity_id = ?1"
            + " and type = 'ROUTE_ORIGINAL_GPX'",
        id);

    assertEquals(Outcome.CHANGED, backfill.write(candidate, read.lines(), Instant.now()));
    assertNoRaw(id);
    assertTrue(skipReason(id).isEmpty(), "not given up: the next pass reads the new original");
  }

  @Test
  void anotherNumberOfTracks_isGivenUp_andNotRetried() {
    Long twoTracks = oldRoute(TWO_TRACKS);
    Long id = oldRoute(EXAMPLE);
    // Its original now holds two tracks, the route one
    sql(
        "update assets set file_id = ?1 where team_entity_id = ?2 and type = 'ROUTE_ORIGINAL_GPX'",
        originalFileId(twoTracks),
        id);
    sql("update team_entities set deleted = true where id = ?1", twoTracks);
    on();

    assertEquals(new Report(0, 1), backfill.runOnce(Instant.now()));
    assertEquals(Optional.of("TRACK_COUNT"), skipReason(id));
    assertNoRaw(id);

    assertEquals(new Report(0, 0), backfill.runOnce(Instant.now()), "never picked again");
  }

  @Test
  void anUnreadableOriginal_isGivenUp_andNotRetried() {
    Long id = oldRoute(EXAMPLE);
    byte[] garbage = "pas un GPX".getBytes(StandardCharsets.UTF_8);
    storageService.store(
        assetService.getAssetKey(team1.getId(), originalFileId(id)),
        new ByteArrayInputStream(garbage),
        "application/gpx+xml",
        garbage.length);
    on();

    assertEquals(new Report(0, 1), backfill.runOnce(Instant.now()));
    assertEquals(Optional.of("UNREADABLE"), skipReason(id));
    assertNoRaw(id);

    assertEquals(new Report(0, 0), backfill.runOnce(Instant.now()), "never picked again");
  }

  @Test
  void aMissingOriginal_isGivenUp() {
    Long id = oldRoute(EXAMPLE);
    storageService.delete(assetService.getAssetKey(team1.getId(), originalFileId(id)));
    on();

    assertEquals(new Report(0, 1), backfill.runOnce(Instant.now()));
    assertEquals(Optional.of("MISSING_ORIGINAL"), skipReason(id));
  }

  /**
   * API-150: a recompute reads the original, so a line denser than the stored points asks for
   * nothing: a previous release would write its own document over a newer one.
   */
  @Test
  void aDenserLine_queuesNothing() throws Exception {
    Long base = oldRoute(EXAMPLE);
    oldRoute(traceOf(base, 3));
    sql("delete from elevation_refresh");
    surfaceService.setEnabledForTest(true);
    on();

    assertEquals(new Report(2, 0), backfill.runOnce(Instant.now()));

    assertEquals(0, tableSize("surface_refresh"));
    assertEquals(0, tableSize("raw_track_resurface"));
    assertEquals(0, tableSize("elevation_refresh"));
  }

  private long tableSize(String table) {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                ((Number)
                        trackRepository
                            .getEntityManager()
                            .createNativeQuery("select count(*) from " + table)
                            .getSingleResult())
                    .longValue());
  }

  @Test
  void anUnreachableBucket_endsThePass_andGivesNothingUp() {
    Long id = oldRoute(EXAMPLE);
    on();
    doThrow(SdkClientException.create("bucket down")).when(storageService).retrieve(anyString());
    try {
      assertEquals(new Report(0, 0), backfill.runOnce(Instant.now()));
      assertEquals(new Report(0, 0), backfill.runOnce(Instant.now()));
    } finally {
      Mockito.reset(storageService);
    }
    assertTrue(skipReason(id).isEmpty(), "an outage costs passes, not routes");
    assertNoRaw(id);

    assertEquals(new Report(1, 0), backfill.runOnce(Instant.now()));
    assertRawOf(sourceSizes(EXAMPLE), id);
  }

  @Test
  void aWriteThatKeepsFailing_isGivenUpAfterAFewPasses() {
    Long id = oldRoute(EXAMPLE);
    on();
    doThrow(new IllegalStateException("lock timeout"))
        .when(trackRepository)
        .fillRawGeometry(any(), any());
    try {
      for (int i = 1; i < RawTrackBackfill.MAX_WRITE_FAILURES; i++) {
        assertEquals(new Report(0, 0), backfill.runOnce(Instant.now()), "pass " + i);
        assertTrue(skipReason(id).isEmpty(), "retried, pass " + i);
      }
      assertEquals(new Report(0, 1), backfill.runOnce(Instant.now()));
    } finally {
      Mockito.reset(trackRepository);
    }
    assertEquals(Optional.of("ERROR"), skipReason(id));
    assertNoRaw(id);
  }

  @Test
  void switchOff_doesNothing() {
    Long id = oldRoute(EXAMPLE);
    backfill.setForTest(false, 100);

    assertEquals(new Report(0, 0), backfill.runOnce(Instant.now()));
    assertNoRaw(id);
    assertTrue(skipReason(id).isEmpty());
  }

  @Test
  void aPassHeldByAnotherBackend_isSkipped() throws Exception {
    Long id = oldRoute(EXAMPLE);
    on();
    try (Connection other = dataSource.getConnection();
        Statement statement = other.createStatement()) {
      statement.execute("select pg_advisory_lock(hashtextextended('raw-track-backfill', 0))");
      try {
        assertEquals(new Report(0, 0), backfill.runOnce(Instant.now()));
        assertNoRaw(id);
      } finally {
        statement.execute("select pg_advisory_unlock(hashtextextended('raw-track-backfill', 0))");
      }
    }

    assertEquals(new Report(1, 0), backfill.runOnce(Instant.now()));
    assertRawOf(sourceSizes(EXAMPLE), id);
  }
}
