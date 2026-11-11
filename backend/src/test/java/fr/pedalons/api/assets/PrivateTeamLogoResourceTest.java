package fr.pedalons.api.assets;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.anyOf;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.startsWith;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.specification.RequestSpecification;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The logo of a private team ({@code team2}, {@code TEAM}) is downloadable by anyone exactly when
 * the team has {@code publicContentAllowed} — its content read by link embeds it — and the logo
 * only, never the rest of the about page (docs/LEDGER_*.md API-176). Without the flag the summary
 * embedded in that content carries no logo URL at all, so no client renders a broken image.
 *
 * <p>Also: the prefix of an asset URL follows the indexing rule, and the download endpoints ignore
 * it for authorization, so a URL issued under an older prefix keeps working.
 *
 * <p>user1 is admin of team2, user3 a member; user4 belongs to no team.
 */
@QuarkusTest
class PrivateTeamLogoResourceTest extends AbstractResourceTest {

  private static final String[] OUTSIDERS = {null, USER4};

  private Asset logo;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    // Public content of a private team, readable by link: created directly, as content published
    // while the flag was on.
    Instant soon = Instant.now().plus(7, ChronoUnit.DAYS);
    dataService.createRide(team2, user1, "Ride", "ride", soon, Visibility.PUBLIC);
    logo = dataService.attachTeamLogo(team2, user1);
  }

  private RequestSpecification as(@Nullable String user) {
    RequestSpecification spec = given();
    return user == null ? spec : spec.auth().oauth2(getAccessToken(user));
  }

  private static String download(String prefix, Team team, Asset asset) {
    return "/api/download/"
        + prefix
        + "/assets/"
        + team.getSlug()
        + "/"
        + TsidUtils.toString(asset.getId())
        + "/"
        + asset.getFileName();
  }

  @Test
  void theLogo_ofAFlaggedPrivateTeam_isDownloadableByAnyone() {
    dataService.setTeamPublicContentAllowed(team2, true);
    for (String caller : OUTSIDERS) {
      as(caller)
          .when()
          .get("/api/teams/" + team2Slug + "/rides/ride")
          .then()
          .statusCode(200)
          .body("team.accessible", equalTo(false))
          // The about page stays TEAM: the logo's URL keeps the noindex « team » prefix.
          .body("team.logoUrl", startsWith("/api/download/team/images/" + team2Slug + "/"));
      as(caller).when().get(download("team", team2, logo)).then().statusCode(200);
      // The prefix decides nothing about access.
      as(caller).when().get(download("public", team2, logo)).then().statusCode(200);
    }
    // A member, as before.
    as(USER3).when().get(download("team", team2, logo)).then().statusCode(200);
  }

  @Test
  void theLogo_ofAPrivateTeamWithoutTheFlag_staysClosed() {
    for (String caller : OUTSIDERS) {
      as(caller)
          .when()
          .get(download("team", team2, logo))
          .then()
          .statusCode(anyOf(equalTo(401), equalTo(403), equalTo(404)));
    }
    as(USER3).when().get(download("team", team2, logo)).then().statusCode(200);
  }

  /**
   * The flag decides, not the content: withdrawn, the logo closes again while the public ride
   * published under it still reads by link — and the ride's team summary then carries no logo.
   */
  @Test
  void theFlagWithdrawn_closesTheLogo_evenWithPublicContentLeft() {
    dataService.setTeamPublicContentAllowed(team2, true);
    dataService.setTeamPublicContentAllowed(team2, false);
    for (String caller : OUTSIDERS) {
      as(caller)
          .when()
          .get("/api/teams/" + team2Slug + "/rides/ride")
          .then()
          .statusCode(200)
          .body("team.accessible", equalTo(false))
          .body("team.logoUrl", nullValue());
      as(caller)
          .when()
          .get(download("team", team2, logo))
          .then()
          .statusCode(anyOf(equalTo(401), equalTo(403), equalTo(404)));
    }
    // A member still sees it on the same summary.
    as(USER3)
        .when()
        .get("/api/teams/" + team2Slug + "/rides/ride")
        .then()
        .statusCode(200)
        .body("team.logoUrl", startsWith("/api/download/team/images/"));
  }

  @Test
  void anotherAssetOfTheAboutPage_staysClosed_evenWithTheFlag() {
    dataService.setTeamPublicContentAllowed(team2, true);
    Asset photo = dataService.attachToAboutPage(team2, user1, AssetType.IMAGE, "photo.png");
    Asset file = dataService.attachToAboutPage(team2, user1, AssetType.ATTACHMENT, "file.gpx");
    for (String caller : OUTSIDERS) {
      for (Asset asset : new Asset[] {photo, file}) {
        as(caller)
            .when()
            .get(download("team", team2, asset))
            .then()
            .statusCode(anyOf(equalTo(401), equalTo(403), equalTo(404)));
      }
      // Nor the page itself.
      as(caller)
          .when()
          .get("/api/teams/" + team2Slug)
          .then()
          .statusCode(anyOf(equalTo(401), equalTo(403), equalTo(404)));
    }
  }

  /**
   * The public content of an unlisted team is not indexed, so its files and images get the
   * unlisted prefix; the URL issued before, under {@code public}, still downloads.
   */
  @Test
  void anUnlistedTeamsPublicContent_getsTheUnlistedPrefix_andOldUrlsStillWork() {
    Team unlisted =
        dataService.createTeam(user1, "Unlisted", "unlisted-team", Visibility.PUBLIC_UNLISTED);
    Ride ride =
        dataService.createRide(
            unlisted,
            user1,
            "Unlisted Ride",
            "unlisted-ride",
            Instant.now().plus(7, ChronoUnit.DAYS),
            Visibility.PUBLIC);
    Asset photo = dataService.attachAsset(ride, user1, AssetType.ATTACHMENT, "photo.png");

    given()
        .when()
        .get("/api/teams/" + unlisted.getSlug() + "/rides/unlisted-ride")
        .then()
        .statusCode(200)
        .body(
            "media.assets.attachments[0].url",
            startsWith("/api/download/public_unlisted/assets/" + unlisted.getSlug() + "/"))
        .body(
            "media.assets.attachments[0].imageUrl",
            startsWith("/api/download/public_unlisted/images/" + unlisted.getSlug() + "/"));
    given().when().get(download("public", unlisted, photo)).then().statusCode(200);
    given().when().get(download("public_unlisted", unlisted, photo)).then().statusCode(200);
  }
}
