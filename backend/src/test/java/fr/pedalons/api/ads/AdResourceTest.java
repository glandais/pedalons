package fr.pedalons.api.ads;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.ads.request.AdRequest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.Status;
import io.quarkus.test.junit.QuarkusTest;
import java.math.BigDecimal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AdResourceTest extends AbstractResourceTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private AdRequest createAdRequest(String name) {
    return new AdRequest(
        name,
        MediaDto.builder().markdown("Ad content").build(),
        Status.PUBLISHED,
        AdType.SALE,
        BigDecimal.valueOf(100),
        null,
        null,
        null);
  }

  private String createTestAd(String name) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(createAdRequest(name))
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  // ==================== Create Ad ====================

  @Test
  void createAd_asMember_shouldSucceed() {
    AdRequest request = createAdRequest("Member Ad");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(201)
        .body("name", equalTo("Member Ad"))
        .body("adType", equalTo("SALE"));
  }

  @Test
  void createAd_withoutAuth_shouldReturn401() {
    AdRequest request = createAdRequest("Unauth Ad");

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(401);
  }

  @Test
  void createAd_asNonMember_shouldReturn403() {
    AdRequest request = createAdRequest("NonMember Ad");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(403);
  }

  // ==================== Get Ad ====================

  @Test
  void getAd_asMember_shouldSucceed() {
    String adSlug = createTestAd("Public Ad");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds/" + adSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Public Ad"));
  }

  @Test
  void getAd_nonexistent_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds/nonexistent-ad")
        .then()
        .statusCode(404);
  }

  // ==================== Update Ad ====================

  @Test
  void updateAd_asCreator_shouldSucceed() {
    String adSlug = createTestAd("Original Ad");

    AdRequest request =
        new AdRequest(
            "Updated Ad",
            MediaDto.builder().markdown("Updated content").build(),
            Status.PUBLISHED,
            AdType.WANTED,
            BigDecimal.valueOf(200),
            null,
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/classifieds/" + adSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Ad"))
        .body("adType", equalTo("WANTED"));
  }

  @Test
  void updateAd_asNonCreatorMember_shouldReturn403() {
    String adSlug = createTestAd("Creator Ad");

    AdRequest request =
        new AdRequest(
            "Hacked",
            MediaDto.builder().build(),
            Status.DRAFT,
            AdType.SALE,
            null,
            null,
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/classifieds/" + adSlug)
        .then()
        .statusCode(403);
  }

  // ==================== Delete Ad ====================

  @Test
  void deleteAd_asCreator_shouldSucceed() {
    String adSlug = createTestAd("To Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/classifieds/" + adSlug)
        .then()
        .statusCode(204);

    // Verify ad is no longer accessible
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds/" + adSlug)
        .then()
        .statusCode(404);
  }

  @Test
  void deleteAd_asNonCreatorMember_shouldReturn403() {
    String adSlug = createTestAd("Protected Ad");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .delete("/api/teams/" + team1Slug + "/classifieds/" + adSlug)
        .then()
        .statusCode(403);
  }

  // ==================== Change Slug ====================

  @Test
  void changeSlug_asCreator_shouldSucceed() {
    String adSlug = createTestAd("Slug Change Ad");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("new-ad-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("new-ad-slug"));
  }

  @Test
  void changeSlug_asNonCreatorMember_shouldReturn403() {
    String adSlug = createTestAd("Protected Slug Ad");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(new SlugChangeRequest("hacked-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/slug")
        .then()
        .statusCode(403);
  }

  // ==================== List Ads ====================

  @Test
  void listAds_asMember_shouldSucceed() {
    createTestAd("List Ad 1");
    createTestAd("List Ad 2");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(200)
        .body("ads.size()", greaterThanOrEqualTo(2));
  }

  @Test
  void listAds_withFilters_shouldSucceed() {
    createTestAd("Filtered Ad");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("adType", "SALE")
        .queryParam("page", 0)
        .queryParam("size", 10)
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(200);
  }

  // ==================== Platform admin (ledger API-137) ====================

  /** Someone else's draft ad stays out of a platform admin's lists, as out of a team admin's. */
  private fr.pedalons.domain.ad.Ad[] draftAndLiveAds() {
    dataService.createPlatformAdminUser("root@example.com", "Root");
    fr.pedalons.domain.ad.Ad live = dataService.createAd(team1, user3, "Live Bike", AdType.SALE);
    fr.pedalons.domain.ad.Ad draft = dataService.createAd(team1, user3, "Draft Bike", AdType.SALE);
    dataService.setTeamEntityStatus(draft, Status.DRAFT);
    return new fr.pedalons.domain.ad.Ad[] {live, draft};
  }

  @Test
  void listAds_asPlatformAdmin_shouldNotReturnOthersDraftAds() {
    fr.pedalons.domain.ad.Ad[] ads = draftAndLiveAds();

    given()
        .auth()
        .oauth2(getAccessToken("root"))
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(200)
        .body("ads.slug", hasItem(ads[0].getSlug()))
        .body("ads.slug", not(hasItem(ads[1].getSlug())));
  }

  @Test
  void countAds_asPlatformAdmin_shouldNotCountOthersDraftAds() {
    draftAndLiveAds();

    given()
        .auth()
        .oauth2(getAccessToken("root"))
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds/count")
        .then()
        .statusCode(200)
        .body("total", equalTo(1));
  }

  @Test
  void getAd_asPlatformAdmin_othersDraft_isReadable() {
    fr.pedalons.domain.ad.Ad[] ads = draftAndLiveAds();

    given()
        .auth()
        .oauth2(getAccessToken("root"))
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds/" + ads[1].getSlug())
        .then()
        .statusCode(200)
        .body("slug", equalTo(ads[1].getSlug()));
  }
}
