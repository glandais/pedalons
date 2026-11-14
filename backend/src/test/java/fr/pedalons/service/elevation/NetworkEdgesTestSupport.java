package fr.pedalons.service.elevation;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.NetworkEdgesBackfillRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.surface.SurfaceRefreshService;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import jakarta.inject.Inject;
import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.file.Path;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;

/**
 * What the tests of the edges backfill and of its edges-only path share (docs/LEDGER_*.md API-198,
 * lot 1): a route that is HD at the current pipeline <b>without</b> edges, which is what the
 * backfill exists for. The fake answers api 1.6 while the route is made, then 1.7.
 */
abstract class NetworkEdgesTestSupport extends AbstractResourceTest {

  static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();

  @InjectMock MapThumbnailRenderer renderer;

  @Inject RouteService routeService;
  @Inject ElevationRefreshService service;
  @Inject ElevationRefreshWorker worker;
  @Inject NetworkEdgesBackfill backfill;
  @Inject NetworkEdgesBackfillRepository backfillRepository;
  @Inject ElevationRefreshRepository refreshRepository;
  @Inject RouteRepository routeRepository;
  @Inject AssetRepository assetRepository;
  @Inject GpxTrackRepository trackRepository;
  @Inject SurfaceRefreshService surfaceService;
  @Inject GpxPipeline gpxPipeline;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
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
    service.setAsyncHdEnabledForTest(true);
    // The pipeline is stamped only with the surface on (GpxProcessingService#hdPipeline)
    surfaceService.setEnabledForTest(true);
    backfill.setForTest(true, 30, true);
  }

  @AfterEach
  void restore() {
    service.setAsyncHdEnabledForTest(true);
    surfaceService.setEnabledForTest(false);
    gpxPipeline.setEdgesEnabledForTest(true);
    backfill.setForTest(false, 30, true);
  }

  RouteRequest request(String name) {
    return new RouteRequest(
        name,
        MediaDto.builder().markdown("Parcours").build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null);
  }

  RouteDto createRoute(String name) {
    queryContext.setUserForTest(user1);
    return routeService.createRoute(team1Slug, request(name), EXAMPLE);
  }

  RouteDto updateRoute(RouteDto route) {
    queryContext.setUserForTest(user1);
    return routeService.updateRoute(team1Slug, route.slug(), request("Boucle"), EXAMPLE);
  }

  static Long id(RouteDto route) {
    return TsidUtils.toLong(route.id());
  }

  void makeDue(RouteDto route) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            refreshRepository.update(
                "dueAt = ?1 where route.id = ?2", Instant.now().minusSeconds(1), id(route)));
  }

  ElevationRefresh refresh(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> refreshRepository.findByRouteId(id(route)).orElse(null));
  }

  ElevationState storedState(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> routeRepository.findById(id(route)).getElevationState());
  }

  Map<Long, NetworkEdgesDocument> edges(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> trackRepository.findNetworkEdges(id(route)));
  }

  long originalOf(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> assetRepository.findCurrentFileId(id(route), AssetType.ROUTE_ORIGINAL_GPX));
  }

  /**
   * A route that is HD at the current pipeline with no street edges: made while the service
   * answers api 1.6, which then goes back to 1.7.
   */
  RouteDto hdRouteWithoutEdges(String name) {
    FakeRouteDetailsClient.apiVersion = "1.6";
    RouteDto created = createRoute(name);
    makeDue(created);
    worker.processDue();
    FakeRouteDetailsClient.apiVersion = "1.7";
    FakeRouteDetailsClient.REQUESTS.clear();
    return created;
  }

  List<ElevationRefresh> backfillRows() {
    return QuarkusTransaction.requiringNew().call(() -> refreshRepository.list("backfill = true"));
  }
}
