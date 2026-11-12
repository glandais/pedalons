package fr.pedalons.service.gpx;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.GpxPrivacyAssertions;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.github.glandais.fit.FitUnits;
import io.github.glandais.fit.PathToFitJvm;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-182: the one-off rewrite of the FIT files whose records all share one
 * timestamp. Each test lets the pipeline store its files, then puts back under the FIT's key what
 * the writer produced before API-181: the library's own output for a path without a clock.
 */
@QuarkusTest
class FitClockBackfillTest extends AbstractBaseTest {

  @Inject FitClockBackfill backfill;
  @Inject GpxProcessingService gpxProcessingService;
  @Inject GpxPreviewService gpxPreviewService;
  @Inject AssetService assetService;
  @Inject AssetRepository assetRepository;
  @Inject StorageService storageService;
  @Inject PedalonsQueryContext context;
  @Inject DomainResolver domainResolver;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;

  private Route route;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    User user = dataService.createUser("admin@example.com", "Admin");
    Team team = dataService.createTeam(user, "Test Team", "test-team", Visibility.PUBLIC);
    route = dataService.createRoute(team, user, "route", Visibility.PUBLIC);
    route.getTracks().clear();
    dataService.updateRoute(route);
    context.setUserForTest(user);
    storageService.delete(FitClockBackfill.MARKER_KEY);
  }

  /** The bucket is shared by the whole test run: a marker left behind would skip every pass. */
  @AfterEach
  void removeMarker() {
    storageService.delete(FitClockBackfill.MARKER_KEY);
  }

  @Test
  void clockAll_rewritesARouteFitWhoseRecordsShareOneTimestamp_andOnlyOnce() throws Exception {
    gpxProcessingService.createTracks(
        route, gpxProcessingService.parseGpx(GpxPrivacyAssertions.activityGpx()));
    Map<AssetType, String> keys = routeKeys();
    putClocklessFitBack(keys.get(AssetType.ROUTE_FILTERED_GPX), keys.get(AssetType.ROUTE_FIT));
    byte[] filteredBefore = read(keys.get(AssetType.ROUTE_FILTERED_GPX));

    FitClockBackfill.Report report = backfill.clockAll();

    assertEquals(1, report.files(), report.toString());
    assertEquals(1, report.rewritten(), report.toString());
    assertEquals(0, report.failed(), report.toString());
    byte[] fit = read(keys.get(AssetType.ROUTE_FIT));
    assertFalse(FitClockBackfill.isClockless(fit));
    GpxPrivacyAssertions.assertFitHasNoPersonalData(fit);
    assertArrayEquals(filteredBefore, read(keys.get(AssetType.ROUTE_FILTERED_GPX)));
    assertRecordedSizesMatchStorage();

    FitClockBackfill.Report second = backfill.clockAll();
    assertEquals(0, second.rewritten(), "a FIT with a clock must be left alone");
    assertArrayEquals(fit, read(keys.get(AssetType.ROUTE_FIT)));
  }

  @Test
  void clockAll_doesNotTouchARouteImportedAfterTheFix() throws Exception {
    gpxProcessingService.createTracks(
        route, gpxProcessingService.parseGpx(GpxPrivacyAssertions.activityGpx()));
    byte[] fit = read(routeKeys().get(AssetType.ROUTE_FIT));

    FitClockBackfill.Report report = backfill.clockAll();

    assertEquals(1, report.files(), report.toString());
    assertEquals(0, report.rewritten(), report.toString());
    assertArrayEquals(fit, read(routeKeys().get(AssetType.ROUTE_FIT)));
  }

  @Test
  void clockAll_rewritesAPreviewFitWhoseRecordsShareOneTimestamp() throws Exception {
    GpxPreview preview =
        gpxPreviewService.create(GpxPrivacyAssertions.activityGpx(), "activity.gpx");
    Map<String, String> keys = gpxPreviewService.exportKeys(preview);
    putClocklessFitBack(keys.get("filtered.gpx"), keys.get("route.fit"));

    FitClockBackfill.Report report = backfill.clockAll();

    assertEquals(1, report.rewritten(), report.toString());
    assertEquals(0, report.failed(), report.toString());
    assertFalse(FitClockBackfill.isClockless(read(keys.get("route.fit"))));
  }

  @Test
  void runOnce_writesTheMarkerAfterACleanPass_andThenSkips() throws Exception {
    gpxProcessingService.createTracks(
        route, gpxProcessingService.parseGpx(GpxPrivacyAssertions.activityGpx()));
    Map<AssetType, String> keys = routeKeys();

    backfill.runOnce();
    assertTrue(storageService.exists(FitClockBackfill.MARKER_KEY));

    putClocklessFitBack(keys.get(AssetType.ROUTE_FILTERED_GPX), keys.get(AssetType.ROUTE_FIT));
    backfill.runOnce();
    assertTrue(
        FitClockBackfill.isClockless(read(keys.get(AssetType.ROUTE_FIT))),
        "with the marker in place the pass does not run");
  }

  // ==================== Helpers ====================

  /** What the writer stored before API-181: the same track, every record at the FIT epoch. */
  private void putClocklessFitBack(String filteredKey, String fitKey) throws Exception {
    String filtered = new String(read(filteredKey), StandardCharsets.UTF_8);
    byte[] clockless =
        PathToFitJvm.toFitBytes(
            GpxToPathJvm.tracksAsPaths(GpxParserJvm.parse(filtered)),
            "route",
            FitUnits.FIT_EPOCH_OFFSET_MS);
    assertTrue(FitClockBackfill.isClockless(clockless));
    storageService.store(
        fitKey, new ByteArrayInputStream(clockless), "application/vnd.ant.fit", clockless.length);
  }

  private Map<AssetType, String> routeKeys() {
    Map<AssetType, String> keys = new java.util.EnumMap<>(AssetType.class);
    for (Asset asset : route.getAssets()) {
      keys.put(asset.getType(), assetService.getAssetKey(asset.getTeam(), asset.getFileId()));
    }
    assertTrue(keys.containsKey(AssetType.ROUTE_FILTERED_GPX));
    assertTrue(keys.containsKey(AssetType.ROUTE_FIT));
    return keys;
  }

  /** docs/LEDGER_*.md API-7: a rewritten file's recorded size is that of the stored object. */
  private void assertRecordedSizesMatchStorage() {
    for (Asset asset : route.getAssets()) {
      Long recorded =
          QuarkusTransaction.requiringNew()
              .call(() -> assetRepository.findById(asset.getId()).getFileSize());
      assertEquals(
          storageService.size(assetService.getAssetKey(asset.getTeam(), asset.getFileId())),
          recorded,
          asset.getType().name());
    }
  }

  private byte[] read(String key) throws Exception {
    try (InputStream is = storageService.retrieve(key)) {
      return is.readAllBytes();
    }
  }
}
