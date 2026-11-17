package fr.pedalons.api.assets;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.startsWith;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.dto.common.asset.AssetDto;
import fr.pedalons.dto.common.asset.AssetsDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.posts.request.PostRequest;
import fr.pedalons.dto.posts.response.PostDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.asset.AssetRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.File;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AssetResourceTest extends AbstractResourceTest {

  @Inject AssetRepository assetRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private PostRequest createPostRequest(String name, AssetDto assetDto) {
    return createPostRequest(name, assetDto, Visibility.PUBLIC);
  }

  private PostRequest createPostRequest(String name, AssetDto assetDto, Visibility visibility) {
    return new PostRequest(
        name,
        MediaDto.builder()
            .markdown("Post content")
            .assets(AssetsDto.builder().attachments(List.of(assetDto)).build())
            .build(),
        wall(Instant.now().plus(7, ChronoUnit.DAYS)),
        Status.PUBLISHED,
        visibility,
        null,
        null,
        null);
  }

  private PostDto createTestPost(String name, AssetDto assetDto) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(createPostRequest(name, assetDto))
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201)
        .extract()
        .as(PostDto.class);
  }

  // ==================== Upload Tests ====================

  /**
   * docs/LEDGER_*.md SEC-42: an upload refused for its type leaves no copy behind in the backend's
   * temp directory (the test JVM is the backend's).
   */
  @Test
  void uploadAsset_refused_leavesNoTempCopy() throws Exception {
    java.util.Set<String> before = tempFiles("pedalons-assets");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", "photo.png", "not an image at all".getBytes(), "image/png")
        .when()
        .queryParam("assetType", "IMAGE")
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(
            org.hamcrest.Matchers.allOf(
                org.hamcrest.Matchers.greaterThanOrEqualTo(400),
                org.hamcrest.Matchers.lessThan(500)));

    java.util.Set<String> after = new java.util.HashSet<>(tempFiles("pedalons-assets"));
    after.removeAll(before);
    org.junit.jupiter.api.Assertions.assertTrue(after.isEmpty(), "left on disk: " + after);
  }

  /** The names in a backend temp directory of uploads, none when it does not exist yet. */
  private static java.util.Set<String> tempFiles(String directory) throws java.io.IOException {
    java.nio.file.Path dir = java.nio.file.Path.of(System.getProperty("java.io.tmpdir"), directory);
    if (!java.nio.file.Files.isDirectory(dir)) {
      return java.util.Set.of();
    }
    try (var files = java.nio.file.Files.list(dir)) {
      return files
          .map(f -> f.getFileName().toString())
          .collect(java.util.stream.Collectors.toSet());
    }
  }

  @Test
  void uploadAsset_asAdmin_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", gpxFile, "application/gpx+xml")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("url", containsString("/api/download/team/assets/" + team1Slug + "/"));
  }

  @Test
  void uploadAsset_asOrganizer_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .multiPart("file", gpxFile, "application/gpx+xml")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("url", containsString("/api/download/team/assets/" + team1Slug + "/"));
  }

  @Test
  void uploadAsset_asMember_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .multiPart("file", gpxFile, "application/gpx+xml")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("url", containsString("/api/download/team/assets/" + team1Slug + "/"));
  }

  @Test
  void uploadAsset_withoutAuth_shouldReturn401() {
    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .multiPart("file", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(401);
  }

  @Test
  void uploadAsset_asNonMember_shouldReturn403() {
    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .multiPart("file", gpxFile, "application/gpx+xml")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(403);
  }

  @Test
  void uploadAsset_toNonexistentTeam_shouldReturn404() {
    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", gpxFile, "application/gpx+xml")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/nonexistent-team/assets")
        .then()
        .statusCode(404);
  }

  @Test
  void uploadAsset_withoutFile_shouldReturn400() {
    File gpxFile = new File("src/test/resources/example.gpx");
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("wrongName", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(400);
  }

  @Test
  void uploadAsset_toPrivateTeam_shouldReturnTeamUrl() {
    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", gpxFile, "application/gpx+xml")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + team2Slug + "/assets")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("url", containsString("/api/download/team/assets/" + team2Slug + "/"));
  }

  // ==================== Download Public Asset Tests (team1 - PUBLIC) ====================
  // Note: Public team assets are accessible by everyone via the public endpoint

  @Test
  void downloadPublicAsset_withoutAuth_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    // Upload asset to public team
    AssetDto assetDto =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", gpxFile, "application/gpx+xml")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team1Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .as(AssetDto.class);

    // add asset to post
    PostDto postDto = createTestPost("post1", assetDto);

    String assetUrl = postDto.getMedia().assets().attachments().getFirst().url();

    // Download without auth should work for public team assets
    given().when().get(assetUrl).then().statusCode(200).contentType("application/gpx+xml");
  }

  /** docs/LEDGER_*.md SEC-1: an attachment that is not a raster image or a PDF is saved. */
  @Test
  void downloadAsset_aGpxIsSavedSandboxed_neverRenderedInPlace() {
    AssetDto assetDto =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", new File("src/test/resources/example.gpx"), "application/gpx+xml")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team1Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .as(AssetDto.class);
    createTestPost("post1", assetDto);

    given()
        .when()
        .get(assetDto.url())
        .then()
        .statusCode(200)
        .header("Content-Disposition", startsWith("attachment;"))
        .header("X-Content-Type-Options", equalTo("nosniff"))
        .header("Content-Security-Policy", containsString("sandbox"));
  }

  /**
   * docs/LEDGER_*.md SEC-1: an SVG stored before uploads refused them is served as a file to save,
   * sandboxed — it never runs in the application's origin.
   */
  @Test
  void downloadAsset_anSvgStoredBeforeTheFix_isSavedSandboxed() {
    Asset legacy = dataService.createAsset(team1, user1, AssetType.ATTACHMENT, "legacy.svg");
    QuarkusTransaction.requiringNew()
        .run(() -> assetRepository.findById(legacy.getId()).setContentType("image/svg+xml"));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(
            "/api/download/team/assets/"
                + team1Slug
                + "/"
                + TsidUtils.toString(legacy.getId())
                + "/legacy.svg")
        .then()
        .statusCode(200)
        .header("Content-Disposition", startsWith("attachment;"))
        .header("X-Content-Type-Options", equalTo("nosniff"))
        .header("Content-Security-Policy", containsString("sandbox"));
  }

  @Test
  void downloadPublicAsset_asMember_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    // Upload asset to public team
    AssetDto assetDto =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", gpxFile, "application/gpx+xml")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team1Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .as(AssetDto.class);

    // add asset to post
    createTestPost("post1", assetDto);

    String assetUrl = assetDto.url();

    // Download as member should work
    given().auth().oauth2(getAccessToken(USER3)).when().get(assetUrl).then().statusCode(200);
  }

  @Test
  void downloadPublicAsset_asNonMember_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    // Upload asset to public team
    AssetDto assetDto =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", gpxFile, "application/gpx+xml")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team1Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .as(AssetDto.class);

    // add asset to post
    createTestPost("post1", assetDto);

    String assetUrl = assetDto.url();
    // Download as non-member should work for public team assets
    given().auth().oauth2(getAccessToken(USER4)).when().get(assetUrl).then().statusCode(200);
  }

  // ==================== Download Team Asset Tests (team2 - TEAM/private) ====================

  @Test
  void downloadTeamAsset_asOwner_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    // Upload asset to private team
    String assetUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER3))
            .multiPart("file", gpxFile, "application/gpx+xml")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team2Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .path("url");

    // Download as organizer should work
    given()
        .redirects()
        .follow(false)
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get(assetUrl)
        .then()
        .contentType("application/gpx+xml")
        .statusCode(200);
  }

  @Test
  void downloadTeamAsset_withoutAuth_shouldReturnForbidden() {
    File gpxFile = new File("src/test/resources/example.gpx");

    // Upload asset to private team
    String assetUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", gpxFile, "application/gpx+xml")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team2Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .path("url");

    // Download without auth should return forbidden
    given().redirects().follow(false).when().get(assetUrl).then().statusCode(403);
  }

  @Test
  void downloadTeamAsset_asMember_shouldBeDenied() {
    File gpxFile = new File("src/test/resources/example.gpx");

    // Upload asset to private team
    String assetUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", gpxFile, "application/gpx+xml")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team2Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .path("url");

    // Download as member (not organizer) should be denied for orphan assets
    given()
        .redirects()
        .follow(false)
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get(assetUrl)
        .then()
        .statusCode(403);
  }

  @Test
  void downloadTeamAsset_asNonMember_shouldBeDenied() {
    File gpxFile = new File("src/test/resources/example.gpx");

    // Upload asset to private team
    String assetUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", gpxFile, "application/gpx+xml")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team2Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .path("url");

    // Download as non-member should be denied
    given().auth().oauth2(getAccessToken(USER4)).when().get(assetUrl).then().statusCode(403);
  }

  @Test
  void downloadAsset_nonexistent_shouldReturn403() {
    // Nonexistent assets return 403 to not leak information
    given()
        .when()
        .get(
            "/api/download/public/assets/" + team1Slug + "/" + TsidUtils.toString(1L) + "/file.gpx")
        .then()
        .statusCode(403);
  }

  // ==================== Image Upload Tests ====================

  /**
   * docs/LEDGER_*.md SEC-51: an asset held by content the caller cannot read is refused with the
   * same status as an asset that does not exist — before, the holder's 404 told them apart.
   */
  @Test
  void downloadAsset_heldByHiddenContent_answersLikeANonexistentOne() {
    AssetDto assetDto = uploadGpx(team1Slug);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(createPostRequest("team only", assetDto, Visibility.TEAM))
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201);

    given().auth().oauth2(getAccessToken(USER3)).when().get(assetDto.url()).then().statusCode(200);
    given()
        .redirects()
        .follow(false)
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get(assetDto.url())
        .then()
        .statusCode(403);
    given().redirects().follow(false).when().get(assetDto.url()).then().statusCode(403);
  }

  @Test
  void uploadImage_shouldReturnImageUrl() {
    File imageFile = new File("src/test/resources/image.png");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", imageFile, "image/png")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("fileName", notNullValue())
        .body("contentType", containsString("image/"))
        .body("url", containsString("/api/download/team/assets/"))
        .body("imageUrl", containsString("/api/download/team/images/" + team1Slug + "/"))
        .body("imageUrl", containsString("/{size}"));
  }

  @Test
  void uploadImage_shouldReturnDimensions() {
    File imageFile = new File("src/test/resources/image.png");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", imageFile, "image/png")
        .when()
        .queryParam("assetType", "IMAGE")
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(201)
        .body("imageDimensions", notNullValue())
        .body("imageDimensions.width", notNullValue())
        .body("imageDimensions.height", notNullValue());
  }

  @Test
  void uploadNonImage_shouldNotReturnImageUrl() {
    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", gpxFile, "application/gpx+xml")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + team1Slug + "/assets")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("imageUrl", org.hamcrest.Matchers.nullValue())
        .body("imageDimensions", org.hamcrest.Matchers.nullValue());
  }

  @Test
  void uploadImage_toPrivateTeam_shouldReturnTeamImageUrl() {
    File imageFile = new File("src/test/resources/image.png");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", imageFile, "image/png")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + team2Slug + "/assets")
        .then()
        .statusCode(201)
        .body("imageUrl", containsString("/api/download/team/images/" + team2Slug + "/"));
  }

  // ==================== Download Image Tests (resized via imgproxy) ====================
  // Note: Public team images are accessible by everyone via the public endpoint

  @Test
  void downloadPublicImage_withoutAuth_shouldSucceed() {
    File imageFile = new File("src/test/resources/image.png");

    // Upload image to public team
    AssetDto assetDto =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", imageFile, "image/png")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team1Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .as(AssetDto.class);

    // add asset to post
    PostDto postDto = createTestPost("post1", assetDto);

    String imageUrl = postDto.getMedia().assets().attachments().getFirst().imageUrl();

    // Replace {size} placeholder with actual size
    String resizedUrl = imageUrl.replace("{size}", "200");

    // Download without auth should work for public team images
    given()
        .header("Accept", "image/jpeg")
        .when()
        .get(resizedUrl)
        .then()
        .statusCode(200)
        .contentType(containsString("image/"));
  }

  @Test
  void downloadPublicImage_differentSizes_shouldSucceed() {
    File imageFile = new File("src/test/resources/image.png");

    // Upload image to public team
    AssetDto assetDto =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", imageFile, "image/png")
            .when()
            .queryParam("assetType", "IMAGE")
            .post("/api/teams/" + team1Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .as(AssetDto.class);

    // add asset to post
    PostDto postDto = createTestPost("post1", assetDto);

    String imageUrl = postDto.getMedia().assets().attachments().getFirst().imageUrl();
    // Test different sizes
    for (int size : new int[] {100, 200, 400, 800}) {
      String resizedUrl = imageUrl.replace("{size}", String.valueOf(size));
      given()
          .header("Accept", "image/jpeg")
          .when()
          .get(resizedUrl)
          .then()
          .statusCode(200)
          .contentType(containsString("image/"));
    }
  }

  @Test
  void downloadTeamImage_withoutAuth_shouldReturnForbidden() {
    File imageFile = new File("src/test/resources/image.png");

    // Upload image to private team
    String imageUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", imageFile, "image/png")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team2Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .path("imageUrl");

    String resizedUrl = imageUrl.replace("{size}", "200");

    // Download without auth should return forbidden
    given()
        .redirects()
        .follow(false)
        .header("Accept", "image/jpeg")
        .when()
        .get(resizedUrl)
        .then()
        .statusCode(403);
  }

  @Test
  void downloadTeamImage_asOwner_shouldSucceed() {
    File imageFile = new File("src/test/resources/image.png");

    // Upload image to private team
    String imageUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER3))
            .multiPart("file", imageFile, "image/png")
            .when()
            .queryParam("assetType", "ATTACHMENT")
            .post("/api/teams/" + team2Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .path("imageUrl");

    String resizedUrl = imageUrl.replace("{size}", "200");

    // Download as organizer should work
    given()
        .redirects()
        .follow(false)
        .auth()
        .oauth2(getAccessToken(USER3))
        .header("Accept", "image/jpeg")
        .when()
        .get(resizedUrl)
        .then()
        .statusCode(200)
        .contentType(containsString("image/"));
  }

  @Test
  void downloadTeamImage_asNonMember_shouldReturn403() {
    File imageFile = new File("src/test/resources/image.png");

    // Upload image to private team
    String imageUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("file", imageFile, "image/png")
            .when()
            .queryParam("assetType", "IMAGE")
            .post("/api/teams/" + team2Slug + "/assets")
            .then()
            .statusCode(201)
            .extract()
            .path("imageUrl");

    String resizedUrl = imageUrl.replace("{size}", "200");

    // Download as non-member should be denied
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .header("Accept", "image/jpeg")
        .when()
        .get(resizedUrl)
        .then()
        .statusCode(403);
  }

  @Test
  void downloadImage_nonexistent_shouldReturn403() {
    // Nonexistent assets return 403 to not leak information
    given()
        .header("Accept", "image/jpeg")
        .when()
        .get("/api/download/public/images/" + team1Slug + "/" + TsidUtils.toString(1L) + "/200")
        .then()
        .statusCode(403);
  }

  // ==================== Attaching (docs/LEDGER_*.md API-68) ====================

  private AssetDto uploadGpx(String teamSlug) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", new File("src/test/resources/example.gpx"), "application/gpx+xml")
        .when()
        .queryParam("assetType", "ATTACHMENT")
        .post("/api/teams/" + teamSlug + "/assets")
        .then()
        .statusCode(201)
        .extract()
        .as(AssetDto.class);
  }

  private void assertRefusedOnNewPost(String assetId) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(createPostRequest("second", AssetDto.builder().id(assetId).build()))
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(400)
        .body("code", equalTo("ASSET_NOT_AVAILABLE"))
        .body("errorDetails.type", equalTo("ASSET_NOT_AVAILABLE"))
        .body("errorDetails.assetId", equalTo(assetId))
        // Nothing of who holds it: only the type and the id cited.
        .body("errorDetails.size()", equalTo(2));
  }

  @Test
  void attachAsset_alreadyHeldByAnotherContent_shouldReturn400NamingTheId() {
    AssetDto assetDto = uploadGpx(team1Slug);
    PostDto first = createTestPost("first", assetDto);

    assertRefusedOnNewPost(assetDto.id());

    // The first post still holds it.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/posts/" + first.getSlug())
        .then()
        .statusCode(200)
        .body("media.assets.attachments[0].id", equalTo(assetDto.id()));
  }

  @Test
  void attachAsset_ofAnotherTeam_shouldReturnTheSame400() {
    AssetDto assetDto = uploadGpx(team2Slug);

    assertRefusedOnNewPost(assetDto.id());
  }

  @Test
  void attachAsset_unknown_shouldReturnTheSame400() {
    assertRefusedOnNewPost(TsidUtils.toString(1L));
  }

  @Test
  void attachAsset_reCitedByItsOwnContent_shouldSucceed() {
    AssetDto assetDto = uploadGpx(team1Slug);
    PostDto post = createTestPost("own", assetDto);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(createPostRequest("own", assetDto))
        .when()
        .put("/api/teams/" + team1Slug + "/posts/" + post.getSlug())
        .then()
        .statusCode(200)
        .body("media.assets.attachments[0].id", equalTo(assetDto.id()));
  }
}
