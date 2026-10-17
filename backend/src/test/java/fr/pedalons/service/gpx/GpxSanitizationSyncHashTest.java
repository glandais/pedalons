package fr.pedalons.service.gpx;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.gps.sync.GpsRouteSyncPlanner;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.GpsSyncTestData;
import fr.pedalons.util.GpxPrivacyAssertions;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.nio.file.Files;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-128 / API-44 (D4): of the two things that rewrite a GPX file under its
 * existing asset row, only the track edit makes GPS sync send the route again — the sanitisation
 * backfill leaves the fingerprint alone, or deploying it would re-push every synced route.
 */
@QuarkusTest
class GpxSanitizationSyncHashTest extends AbstractResourceTest {

  @Inject DomainResolver domainResolver;

  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsSyncTestData sync;
  @Inject GpxSanitizationBackfill backfill;
  @Inject RouteService routeService;
  @Inject PedalonsQueryContext queryContext;
  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;

  private Instant now;
  private Ride ride;
  private Route route;
  private GpsServiceConnection connection;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    ride =
        dataService.createRide(
            team1, user1, "Sortie du jeudi", "jeudi", now.plus(2, ChronoUnit.DAYS));
    route = sync.routeWithGpx(ride, user1, "Boucle des étangs");
    dataService.setRideRoute(ride, route);
    var group = dataService.createRideGroup(user1, ride, "Groupe A", 0);
    dataService.createParticipation(group, user3);
    connection = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    storageService.delete(GpxSanitizationBackfill.MARKER_KEY);
  }

  /** The bucket is shared by the whole test run: a marker left behind would skip every pass. */
  @AfterEach
  void removeMarker() {
    storageService.delete(GpxSanitizationBackfill.MARKER_KEY);
  }

  private String desiredHash() {
    return sync.row(connection.getId(), ride.getId()).orElseThrow().getDesiredHash();
  }

  private Asset filteredGpx() {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                assetRepository
                    .find(
                        "teamEntity.id = ?1 and type = ?2",
                        route.getId(),
                        AssetType.ROUTE_FILTERED_GPX)
                    .firstResult());
  }

  @Test
  void sanitizationBackfill_rewritingTheFileInPlace_doesNotChangeTheHash() throws Exception {
    queryContext.setUserForTest(user1);
    routeService.updateRoute(
        team1Slug,
        route.getSlug(),
        new RouteRequest(
            route.getName(),
            MediaDto.builder().build(),
            SurfaceType.ROAD,
            route.getVisibility(),
            null),
        new File("src/test/resources/example.gpx").toPath());
    planner.plan(now);
    String afterEdit = desiredHash();

    // As an older upload left it: the raw activity under the row's current key.
    byte[] raw = Files.readAllBytes(GpxPrivacyAssertions.activityGpx());
    String key = assetService.getAssetKey(team1, filteredGpx().getFileId());
    storageService.store(key, new ByteArrayInputStream(raw), "application/gpx+xml", raw.length);

    GpxSanitizationBackfill.Report report = backfill.sanitizeAll();
    assertTrue(report.rewritten() >= 1, report.toString());

    planner.plan(now);
    assertEquals(afterEdit, desiredHash());
  }
}
