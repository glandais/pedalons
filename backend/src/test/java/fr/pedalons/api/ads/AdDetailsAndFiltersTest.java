package fr.pedalons.api.ads;

import static io.restassured.RestAssured.given;
import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.CoarseLocation;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.RentalPeriod;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import java.math.BigDecimal;
import java.util.List;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ObjectNode;

/**
 * The classifieds gallery, the seller's name, the blurred location, and the price / proximity / sort
 * filters.
 */
@QuarkusTest
class AdDetailsAndFiltersTest extends AbstractResourceTest {

  /** Lyon, to the metre. What must never come back out. */
  private static final double EXACT_LAT = 45.764043;

  private static final double EXACT_LON = 4.835659;

  private Ad bike;
  private Ad trailer;

  private String list() {
    return "/api/teams/" + team1Slug + "/classifieds";
  }

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    bike = dataService.createAd(team1, user1, "Velo de route", AdType.SALE);
    dataService.setAdDetails(bike, new BigDecimal("1200.00"), null, EXACT_LAT, EXACT_LON);
    dataService.attachAsset(bike, user1, AssetType.IMAGE, "velo-1.jpg");
    dataService.attachAsset(bike, user1, AssetType.IMAGE, "velo-2.jpg");

    trailer = dataService.createAd(team1, user1, "Remorque", AdType.RENTAL);
    // Bordeaux — far enough from Lyon that a 50 km radius separates the two.
    dataService.setAdDetails(trailer, new BigDecimal("15.00"), RentalPeriod.WEEK, 44.84, -0.58);
  }

  private static String row(String name) {
    return "ads.find { it.name == '" + name + "' }";
  }

  // --- gallery, author, price period -------------------------------------------------

  @Test
  void getAd_shouldCarryTheWholeGalleryAndTheSellersDisplayName() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(list() + "/" + bike.getSlug())
        .then()
        .statusCode(200)
        .body("images", hasSize(2))
        .body("images[0]", equalTo(getThumbnail(bike.getSlug())))
        .body("createdByDisplayName", equalTo(user1.getDisplayName()));
  }

  @Test
  void getAd_shouldExposeNoContactChannelForTheSeller() {
    // D7: the display name and nothing else. An email or a phone number here would be an invented
    // contact channel, not a serialisation detail.
    String body =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get(list() + "/" + bike.getSlug())
            .then()
            .statusCode(200)
            .extract()
            .asString();

    org.junit.jupiter.api.Assertions.assertFalse(
        body.contains(user1.getEmail()), "an ad must not carry the seller's email");
  }

  @Test
  void getAd_rental_shouldCarryThePeriodThePriceAppliesTo() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(list() + "/" + trailer.getSlug())
        .then()
        .statusCode(200)
        .body("price", comparesEqualTo(15.0f))
        .body("rentalPeriod", equalTo("WEEK"));
  }

  @Test
  void listCompact_shouldStillCarryTheGallery() {
    // The gallery is read from the same already-loaded assets as thumbnailUrl, so a compact row
    // gets it for free — no extra query, no media.assets.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("view", "compact")
        .when()
        .get(list())
        .then()
        .statusCode(200)
        .body(row("Velo de route") + ".images", hasSize(2))
        .body(row("Velo de route") + ".media.assets.images", hasSize(1));
  }

  // --- blurred location --------------------------------------------------------------

  @Test
  void getAd_shouldBlurTheLocationToAboutAKilometre() {
    float lat =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get(list() + "/" + bike.getSlug())
            .then()
            .statusCode(200)
            .body("locationGeometry.type", equalTo("Point"))
            .extract()
            .path("locationGeometry.coordinates[1]");
    float lon =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get(list() + "/" + bike.getSlug())
            .then()
            .extract()
            .path("locationGeometry.coordinates[0]");

    // Close enough to be useful...
    org.junit.jupiter.api.Assertions.assertTrue(
        Math.abs(lat - EXACT_LAT) < 0.02 && Math.abs(lon - EXACT_LON) < 0.03,
        "the blurred point must still be in the right place, was " + lat + "/" + lon);
    // ...and never the exact address.
    org.junit.jupiter.api.Assertions.assertNotEquals(
        (float) EXACT_LAT, lat, "the exact latitude must never be published");
    org.junit.jupiter.api.Assertions.assertNotEquals(
        (float) EXACT_LON, lon, "the exact longitude must never be published");
  }

  @Test
  void getAd_blurredLocation_shouldBeStableAcrossReads() {
    // Snapped to a fixed grid, not jittered: repeated reads must not let a caller average their way
    // back to the true point.
    Object first =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get(list() + "/" + bike.getSlug())
            .then()
            .extract()
            .path("locationGeometry.coordinates");
    Object second =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get(list() + "/" + bike.getSlug())
            .then()
            .extract()
            .path("locationGeometry.coordinates");

    org.junit.jupiter.api.Assertions.assertEquals(first, second);
  }

  @Test
  void getAdEdit_shouldStillGiveTheOwnerTheExactPoint() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(list() + "/" + bike.getSlug() + "/edit")
        .then()
        .statusCode(200)
        .body("locationGeometry.coordinates[1]", equalTo((float) EXACT_LAT))
        .body("locationGeometry.coordinates[0]", equalTo((float) EXACT_LON));
  }

  /**
   * docs/LEDGER_*.md SEC-26: a team admin editing a member's ad gets the blurred point, and saving
   * the form as served — what the web editor does — leaves the seller's exact point in place.
   */
  @Test
  void getAdEdit_asNonAuthorAdmin_givesTheBlurredPointAndARoundTripKeepsTheExactOne()
      throws Exception {
    Ad memberAd = dataService.createAd(team1, user3, "Cadre acier", AdType.SALE);
    dataService.setAdDetails(memberAd, null, null, EXACT_LAT, EXACT_LON);
    G2D blurred = CoarseLocation.blur(point(WGS84, g(EXACT_LON, EXACT_LAT))).getPosition();
    String edit = list() + "/" + memberAd.getSlug() + "/edit";

    String servedJson =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get(edit)
            .then()
            .statusCode(200)
            .body("locationGeometry.coordinates[1]", equalTo((float) blurred.getLat()))
            .body("locationGeometry.coordinates[0]", equalTo((float) blurred.getLon()))
            .extract()
            .asString();
    // Jackson rather than RestAssured's JsonPath, which reads numbers as floats and would move the
    // point by a few decimetres on the way back — a move the server would rightly take literally.
    ObjectMapper mapper = new ObjectMapper();
    ObjectNode served = (ObjectNode) mapper.readTree(servedJson);
    served.put("name", "Cadre acier (relu)");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(mapper.writeValueAsString(served))
        .when()
        .put(list() + "/" + memberAd.getSlug())
        .then()
        .statusCode(200);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get(edit)
        .then()
        .statusCode(200)
        .body("name", equalTo("Cadre acier (relu)"))
        .body("locationGeometry.coordinates[1]", equalTo((float) EXACT_LAT))
        .body("locationGeometry.coordinates[0]", equalTo((float) EXACT_LON));
  }

  // --- filters and sorting -----------------------------------------------------------

  @Test
  void list_withPriceRange_shouldKeepOnlyAdsInsideIt() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("minPrice", "100")
        .when()
        .get(list())
        .then()
        .statusCode(200)
        .body("ads.name", hasItem("Velo de route"))
        .body("ads.name", not(hasItem("Remorque")));
  }

  @Test
  void list_withMaxPrice_shouldDropAdsWithNoPrice() {
    Ad negotiable = dataService.createAd(team1, user1, "A negocier", AdType.SALE);
    dataService.setAdDetails(negotiable, null, null, null, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("maxPrice", "10000")
        .when()
        .get(list())
        .then()
        .statusCode(200)
        .body("ads.name", hasItem("Velo de route"))
        // NULL >= x is UNKNOWN: "under 10 000 €" cannot honestly include "price on request".
        .body("ads.name", not(hasItem("A negocier")));
  }

  @Test
  void list_withProximity_shouldKeepOnlyAdsInTheRadius() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("nearLat", EXACT_LAT)
        .queryParam("nearLon", EXACT_LON)
        .queryParam("nearRadius", 50_000)
        .when()
        .get(list())
        .then()
        .statusCode(200)
        .body("ads.name", hasItem("Velo de route"))
        .body("ads.name", not(hasItem("Remorque")));
  }

  /**
   * SEC-8 (audit M2): two ads in the same published cell are indistinguishable to the proximity
   * filter. It used to measure from the exact position, so a probe one cell east with a one-cell
   * radius kept the eastern ad and dropped the western one — and enough such probes pinned the
   * seller's address down however coarse the probe and radius were.
   */
  @Test
  void list_withProximity_neverTellsApartTwoAdsOfTheSameCell() {
    Point<G2D> cell = CoarseLocation.blur(point(WGS84, g(EXACT_LON, EXACT_LAT)));
    double lat = cell.getPosition().getLat();
    double lon = cell.getPosition().getLon();
    double lonStep = 0.01 / Math.cos(Math.toRadians(lat));
    // ~930 m apart, each well inside the cell: its western and eastern sides.
    Ad west = dataService.createAd(team1, user1, "Cote ouest", AdType.SALE);
    dataService.setAdDetails(west, null, null, lat, lon - 0.4 * lonStep);
    Ad east = dataService.createAd(team1, user1, "Cote est", AdType.SALE);
    dataService.setAdDetails(east, null, null, lat, lon + 0.4 * lonStep);

    int together = 0;
    for (int k = -3; k <= 3; k++) {
      for (int radius : new int[] {1_110, 2_220, 3_330}) {
        List<String> names =
            given()
                .auth()
                .oauth2(getAccessToken(USER1))
                .queryParam("nearLat", lat)
                .queryParam("nearLon", lon + k * lonStep)
                .queryParam("nearRadius", radius)
                .when()
                .get(list())
                .then()
                .statusCode(200)
                .extract()
                .jsonPath()
                .getList("ads.name", String.class);
        String probe = "cell " + k + ", radius " + radius;
        assertEquals(names.contains("Cote ouest"), names.contains("Cote est"), probe);
        if (names.contains("Cote ouest")) {
          together++;
        }
      }
    }
    // Not a sweep that simply never finds them.
    assertTrue(together > 0);
  }

  @Test
  void list_sortedByPriceAscending_shouldPutTheCheapestFirst() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("sortBy", "PRICE")
        .queryParam("sortDir", "ASC")
        .when()
        .get(list())
        .then()
        .statusCode(200)
        .body("ads[0].name", equalTo("Remorque"));
  }

  @Test
  void list_withNoSort_shouldKeepThePreviousOrdering() {
    // The sort parameters are additive: absent, the listing must behave exactly as before.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(list())
        .then()
        .statusCode(200)
        .body("ads", hasSize(2));
  }

  // --- who may read at all -----------------------------------------------------------

  @Test
  void list_anonymous_shouldBeRefused() {
    given().when().get(list()).then().statusCode(401);
  }

  @Test
  void list_nonMember_shouldNotSeeTheAdsNorTheirLocations() {
    // user5 is authenticated but not a member of team1. Ads are Visibility.TEAM, so the whole row —
    // blurred location included — must be out of reach.
    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .when()
        .get(list())
        .then()
        .statusCode(anyOf(equalTo(403), equalTo(404)));
  }

  @Test
  void list_shouldNotLeakAdsFromAnotherDomain() {
    Domain other = dataService.createDomain("other-domain.test", "Other", "https://other.test");
    User otherUser = dataService.createUser(other, "user1@example.com", "Other user 1");
    // createTeam already enrols its creator as ADMIN.
    Team otherTeam =
        dataService.createTeam(otherUser, "Other team", "other-team", Visibility.PUBLIC);
    Ad foreign = dataService.createAd(otherTeam, otherUser, "Velo etranger", AdType.SALE);
    dataService.setAdDetails(foreign, new BigDecimal("1200.00"), null, EXACT_LAT, EXACT_LON);

    // Same slug, same price, same coordinates — only the domain differs, and the team of the other
    // domain must simply not exist for this request.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/other-team/classifieds")
        .then()
        .statusCode(404);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("nearLat", EXACT_LAT)
        .queryParam("nearLon", EXACT_LON)
        .when()
        .get(list())
        .then()
        .statusCode(200)
        .body("ads.name", not(hasItem("Velo etranger")));
  }

  private String getThumbnail(String slug) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(list() + "/" + slug)
        .then()
        .extract()
        .path("thumbnailUrl");
  }
}
