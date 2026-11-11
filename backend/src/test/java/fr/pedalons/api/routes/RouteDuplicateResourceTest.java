package fr.pedalons.api.routes;

import static fr.pedalons.service.route.planner.PlannerStateFixtures.example;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.tag.Tag;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.AssetDto;
import fr.pedalons.dto.common.asset.AssetsDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteDuplicateRequest;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.request.WaypointRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TagTarget;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WaypointType;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.service.asset.AssetService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-178: {@code POST /routes/{slug}/duplicate} — a copy of a route in its own
 * team, under a new name, with every other attribute and a physical copy of its media.
 */
@QuarkusTest
class RouteDuplicateResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");
  private static final File IMAGE = new File("src/test/resources/image.png");

  @Inject EntityManager em;
  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;
  @Inject GpxTrackRepository trackRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  // ==================== helpers ====================

  private String uploadImage(String user, String assetType) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .multiPart("file", IMAGE, "image/png")
        .queryParam("assetType", assetType)
        .when()
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(201)
        .extract()
        .path("id");
  }

  private static AssetDto ref(String id) {
    return AssetDto.builder().id(id).fileName("image.png").contentType("image/png").url("").build();
  }

  private ValidatableResponse create(RouteRequest route, File gpx) {
    var spec =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("route", route, MediaType.APPLICATION_JSON);
    if (gpx != null) {
      spec = spec.multiPart("gpxFile", gpx, "application/gpx+xml");
    }
    return spec.when().post("/api/teams/" + team1Slug + "/routes").then();
  }

  /** A drawn route of team1, visibility {@code visibility}, with a planner state. */
  private String createDrawn(String name, Visibility visibility) {
    RouteRequest request =
        new RouteRequest(
            name,
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.GRAVEL,
            visibility,
            null,
            null,
            example());
    return create(request, null).statusCode(201).extract().path("slug");
  }

  private ValidatableResponse duplicate(String user, String slug, String name) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(new RouteDuplicateRequest(name))
        .when()
        .post("/api/teams/" + team1Slug + "/routes/" + slug + "/duplicate")
        .then();
  }

  private ValidatableResponse detail(String slug) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(200);
  }

  private ValidatableResponse plannerState(String slug) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug + "/planner-state")
        .then()
        .statusCode(200);
  }

  private Long routeId(String slug) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            em.createQuery("select r.id from Route r where r.slug = :slug", Long.class)
                .setParameter("slug", slug)
                .getSingleResult());
  }

  private List<Long> trackIds(Long routeId) {
    return QuarkusTransaction.requiringNew()
        .call(() -> trackRepository.findIdsByRouteIds(List.of(routeId)).get(routeId));
  }

  private String storageKey(String assetId) {
    return QuarkusTransaction.requiringNew()
        .call(() -> {
          Asset asset = assetRepository.findById(TsidUtils.toLong(assetId));
          return assetService.getAssetKey(asset.getTeam(), asset.getFileId());
        });
  }

  private Long fileId(String assetId) {
    return QuarkusTransaction.requiringNew()
        .call(() -> assetRepository.findById(TsidUtils.toLong(assetId)).getFileId());
  }

  // ==================== rights ====================

  @Test
  void anOrganizer_duplicates_201_withTheRequestedNameAndANewSlug() {
    String slug = createDrawn("Boucle des étangs", Visibility.PUBLIC);

    String copySlug =
        duplicate(USER2, slug, "Copie de Boucle des étangs")
            .statusCode(201)
            .body("name", equalTo("Copie de Boucle des étangs"))
            .body("slug", not(equalTo(slug)))
            .body("id", notNullValue())
            .extract()
            .path("slug");

    detail(copySlug).body("name", equalTo("Copie de Boucle des étangs"));
    // The source keeps its name.
    detail(slug).body("name", equalTo("Boucle des étangs"));
  }

  @Test
  void aMember_isRefused_403() {
    String slug = createDrawn("Boucle", Visibility.PUBLIC);

    duplicate(USER3, slug, "Copie de Boucle").statusCode(403);
  }

  @Test
  void anAnonymousCaller_isRefused_401() {
    String slug = createDrawn("Boucle", Visibility.PUBLIC);

    given()
        .contentType(MediaType.APPLICATION_JSON)
        .body(new RouteDuplicateRequest("Copie de Boucle"))
        .when()
        .post("/api/teams/" + team1Slug + "/routes/" + slug + "/duplicate")
        .then()
        .statusCode(401);
  }

  @Test
  void anOrganizerOfAnotherTeam_getsA404_onATeamRoute() {
    String slug = createDrawn("Boucle", Visibility.TEAM);
    Team other = dataService.createTeam(domain, user4, "Team 4", "team-4", Visibility.PUBLIC);
    dataService.addUserToTeam(user5, other, TeamRole.ORGANIZER);

    duplicate(USER4, slug, "Copie de Boucle").statusCode(404);
    duplicate(USER5, slug, "Copie de Boucle").statusCode(404);
  }

  @Test
  void anotherDomain_getsA404() {
    String slug = createDrawn("Boucle", Visibility.PUBLIC);
    Domain other = dataService.createDomain("other.localhost", "Other", "http://other.localhost");
    User otherUser = dataService.createUser(other, EMAIL2, "Organizer elsewhere");

    given()
        .header("X-Forwarded-Host", "other.localhost")
        .auth()
        .oauth2(jwtService.generateAccessToken(otherUser))
        .contentType(MediaType.APPLICATION_JSON)
        .body(new RouteDuplicateRequest("Copie de Boucle"))
        .when()
        .post("/api/teams/" + team1Slug + "/routes/" + slug + "/duplicate")
        .then()
        .statusCode(404);
  }

  @Test
  void aBlankName_is400() {
    String slug = createDrawn("Boucle", Visibility.PUBLIC);

    duplicate(USER2, slug, "   ").statusCode(400);
    duplicate(USER2, slug, "").statusCode(400);
  }

  // ==================== what is copied ====================

  @Test
  void theCopy_hasTheSourcesAttributes_plannerState_waypoints_andSurfaces() {
    Tag tag = dataService.createTag(team1, user1, TagTarget.ROUTE, "Gravel");
    // A waypoint where the track is: its start, read back from a route drawn the same way.
    String probe =
        create(
                new RouteRequest(
                    "Sonde",
                    MediaDto.builder().build(),
                    SurfaceType.GRAVEL,
                    Visibility.PUBLIC,
                    null,
                    null,
                    example()),
                null)
            .statusCode(201)
            .extract()
            .path("slug");
    ValidatableResponse probed = detail(probe);
    double lng = ((Number) probed.extract().path("start.coordinates[0]")).doubleValue();
    double lat = ((Number) probed.extract().path("start.coordinates[1]")).doubleValue();
    RouteRequest request =
        new RouteRequest(
            "Boucle",
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null,
            List.of(TsidUtils.toString(tag.getId())),
            example(),
            List.of(
                new WaypointRequest(
                    null,
                    new GeoPoint(lng, lat),
                    WaypointType.WATER,
                    "Fontaine",
                    "Au lavoir",
                    null,
                    null)));
    String slug = create(request, null).statusCode(201).extract().path("slug");
    Long sourceId = routeId(slug);
    Long sourceTrack = trackIds(sourceId).getFirst();
    TrackSurfaceDocument surfaces =
        new TrackSurfaceDocument(
            1,
            "ok",
            null,
            null,
            Instant.parse("2026-11-01T10:00:00Z"),
            "bicycle",
            1000.0,
            List.of(new SurfaceRange(0, 1000.0, "gravel")),
            List.of());
    QuarkusTransaction.requiringNew()
        .run(() -> trackRepository.updateSurfaces(sourceTrack, surfaces));

    String copySlug =
        duplicate(USER2, slug, "Copie de Boucle").statusCode(201).extract().path("slug");

    detail(copySlug)
        .body("surfaceType", equalTo("GRAVEL"))
        .body("visibility", equalTo("PUBLIC"))
        .body("tags", hasSize(1))
        .body("tags[0].id", equalTo(TsidUtils.toString(tag.getId())))
        .body("media.markdown", equalTo("Parcours"))
        .body("waypoints", hasSize(1))
        .body("waypoints[0].name", equalTo("Fontaine"))
        .body("waypoints[0].description", equalTo("Au lavoir"))
        .body("waypoints[0].type", equalTo("WATER"))
        .body("waypoints[0].origin", equalTo("AUTHOR"));

    PlannerState state = example();
    plannerState(copySlug)
        .body("state.profile", equalTo(state.profile().name()))
        .body("state.pieces.size()", equalTo(state.pieces().size()))
        .body("state.junctions.size()", equalTo(state.junctions().size()))
        .body("state.sources.size()", equalTo(state.sources().size()))
        .body("state.pieces[1].line", equalTo(state.pieces().get(1).line()));

    Long copyId = routeId(copySlug);
    assertNotEquals(sourceId, copyId);
    Map<Long, TrackSurfaceDocument> copied =
        QuarkusTransaction.requiringNew().call(() -> trackRepository.findSurfaces(copyId));
    assertEquals(1, copied.size());
    assertEquals(surfaces, copied.values().iterator().next());
    // The source's own rows are untouched.
    Map<Long, TrackSurfaceDocument> source =
        QuarkusTransaction.requiringNew().call(() -> trackRepository.findSurfaces(sourceId));
    assertEquals(surfaces, source.get(sourceTrack));
    detail(slug).body("waypoints", hasSize(1));
  }

  @Test
  void theMedia_areCopiedUnderNewFiles_andTheMarkdownIsRewritten() {
    String logo = uploadImage(USER1, "LOGO");
    String image = uploadImage(USER1, "IMAGE");
    String markdown = "Avant\n\n::asset{id=\"" + image + "\"}\n\nAprès";
    RouteRequest request =
        new RouteRequest(
            "Boucle illustrée",
            new MediaDto(
                markdown, AssetsDto.builder().logo(ref(logo)).images(List.of(ref(image))).build()),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null);
    String slug = create(request, EXAMPLE_GPX).statusCode(201).extract().path("slug");

    ValidatableResponse copy = duplicate(USER2, slug, "Copie de Boucle illustrée").statusCode(201);
    String copySlug = copy.extract().path("slug");
    ValidatableResponse copyDetail = detail(copySlug);
    String copyLogo = copyDetail.extract().path("media.assets.logo.id");
    String copyImage = copyDetail.extract().path("media.assets.images[0].id");
    String copyMarkdown = copyDetail.extract().path("media.markdown");

    assertNotNull(copyLogo);
    assertNotNull(copyImage);
    assertNotEquals(logo, copyLogo);
    assertNotEquals(image, copyImage);
    assertNotEquals(fileId(logo), fileId(copyLogo));
    assertNotEquals(fileId(image), fileId(copyImage));
    assertEquals("Avant\n\n::asset{id=\"" + copyImage + "\"}\n\nAprès", copyMarkdown);
    assertTrue(storageService.exists(storageKey(copyLogo)));
    assertTrue(storageService.exists(storageKey(copyImage)));

    // The source still holds its own.
    detail(slug)
        .body("media.assets.logo.id", equalTo(logo))
        .body("media.assets.images[0].id", equalTo(image))
        .body("media.markdown", containsString(image));
  }

  @Test
  void removingTheCopysMedia_thenDeletingIt_leavesTheSourcesFilesIntact() {
    String logo = uploadImage(USER1, "LOGO");
    String image = uploadImage(USER1, "IMAGE");
    String markdown = "::asset{id=\"" + image + "\"}";
    RouteRequest request =
        new RouteRequest(
            "Boucle illustrée",
            new MediaDto(
                markdown, AssetsDto.builder().logo(ref(logo)).images(List.of(ref(image))).build()),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null);
    String slug = create(request, EXAMPLE_GPX).statusCode(201).extract().path("slug");
    String logoKey = storageKey(logo);
    String imageKey = storageKey(image);

    String copySlug =
        duplicate(USER2, slug, "Copie de Boucle illustrée").statusCode(201).extract().path("slug");
    String copyLogo = detail(copySlug).extract().path("media.assets.logo.id");
    String copyLogoKey = storageKey(copyLogo);

    // The copy drops its media: orphan removal deletes the copy's files, and only those.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(
            "route",
            new RouteRequest(
                "Copie de Boucle illustrée",
                MediaDto.builder().build(),
                SurfaceType.ROAD,
                Visibility.PUBLIC,
                null),
            MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + copySlug)
        .then()
        .statusCode(200);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + copySlug)
        .then()
        .statusCode(204);

    assertFalse(storageService.exists(copyLogoKey));
    assertTrue(storageService.exists(logoKey));
    assertTrue(storageService.exists(imageKey));
    detail(slug)
        .body("media.assets.logo.id", equalTo(logo))
        .body("media.assets.images[0].id", equalTo(image));
    QuarkusTransaction.requiringNew()
        .run(() -> {
          Asset source = assetRepository.findById(TsidUtils.toLong(logo));
          assertNotNull(source);
          assertEquals(AssetType.LOGO, source.getType());
          assertEquals(routeId(slug), source.getTeamEntity().getId());
        });
  }
}
