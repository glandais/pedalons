package fr.pedalons.api.posts;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.posts.request.PostRequest;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.specification.RequestSpecification;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class PostResourceTest extends AbstractResourceTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private PostRequest createPostRequest(String name) {
    return new PostRequest(
        name,
        MediaDto.builder().markdown("Post content").build(),
        wall(Instant.now().plus(7, ChronoUnit.DAYS)),
        Status.PUBLISHED,
        Visibility.PUBLIC,
        null,
        null,
        null);
  }

  private String createTestPost(String name) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(createPostRequest(name))
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  // ==================== Create Post Tests ====================

  @Test
  void createPost_asAdmin_shouldSucceed() {
    PostRequest request = createPostRequest("Admin Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201)
        .body("name", equalTo("Admin Post"))
        .body("media.markdown", equalTo("Post content"))
        .body("status", equalTo("PUBLISHED"))
        .body("visibility", equalTo("PUBLIC"));
  }

  @Test
  void createPost_asOrganizer_shouldSucceed() {
    PostRequest request = createPostRequest("Organizer Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201)
        .body("name", equalTo("Organizer Post"));
  }

  @Test
  void createPost_asMember_shouldBeDenied() {
    PostRequest request = createPostRequest("Member Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(403);
  }

  @Test
  void createPost_withoutAuth_shouldReturn401() {
    PostRequest request = createPostRequest("Unauth Post");

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(401);
  }

  @Test
  void createPost_asNonMember_shouldReturn403() {
    PostRequest request = createPostRequest("NonMember Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(403);
  }

  @Test
  void createPost_toNonexistentTeam_shouldReturn404() {
    PostRequest request = createPostRequest("Test Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/nonexistent-team/posts")
        .then()
        .statusCode(404);
  }

  @Test
  void createPost_withPublishAt_shouldSucceed() {
    PostRequest request =
        new PostRequest(
            "Scheduled Post",
            MediaDto.builder().markdown("Scheduled content").build(),
            wall(Instant.now().plus(14, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201)
        .body("name", equalTo("Scheduled Post"))
        .body("publishAt", notNullValue());
  }

  /** docs/LEDGER_*.md SEC-19: the markdown body is bounded, the bound itself is accepted. */
  @Test
  void createPost_markdownPastTheBound_shouldReturn400() {
    PostRequest atTheBound =
        new PostRequest(
            "Long Post",
            MediaDto.builder().markdown("a".repeat(MediaDto.MAX_MARKDOWN_LENGTH)).build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            null,
            null);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(atTheBound)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201);

    PostRequest pastTheBound =
        new PostRequest(
            "Too Long Post",
            MediaDto.builder().markdown("a".repeat(MediaDto.MAX_MARKDOWN_LENGTH + 1)).build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            null,
            null);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(pastTheBound)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(400)
        .body("code", equalTo("VALIDATION"))
        .body("errorDetails.fieldErrors.field", hasItem("markdown"));
  }

  // ==================== Get Post Tests ====================

  @Test
  void getPost_withoutAuth_shouldSucceed() {
    String postSlug = createTestPost("Public Post");

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(200)
        .body("slug", equalTo(postSlug))
        .body("name", equalTo("Public Post"));
  }

  @Test
  void getPost_asMember_shouldSucceed() {
    String postSlug = createTestPost("Member Get Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Member Get Post"));
  }

  @Test
  void getPost_asNonMember_shouldSucceed() {
    String postSlug = createTestPost("NonMember Get Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("NonMember Get Post"));
  }

  /**
   * A publication names its team's logo, the very URL the team detail serves (docs/LEDGER_*.md
   * API-2) — on the detail and on a list row alike, and nothing at all when the team has none.
   */
  @Test
  void getPost_carriesTheTeamLogo_sameAsTheTeamDetail() {
    String postSlug = createTestPost("Logo Post");

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(200)
        .body("team.logoUrl", nullValue());

    dataService.attachTeamLogo(team1, user1);
    String teamLogoUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get("/api/teams/" + team1Slug)
            .then()
            .statusCode(200)
            .extract()
            .path("logoUrl");
    org.junit.jupiter.api.Assertions.assertNotNull(
        teamLogoUrl, "the fixture logo must reach the team detail");

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(200)
        .body("team.logoUrl", equalTo(teamLogoUrl));
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/publications?type=POST&view=COMPACT")
        .then()
        .statusCode(200)
        .body("publications[0].team.logoUrl", equalTo(teamLogoUrl));
  }

  // ==================== Signature (docs/LEDGER_*.md API-6) ====================

  /** Created by the organizer (user2), signed as asked — null leaves it to the team. */
  private String createPostAsOrganizer(String name, @Nullable Boolean signedAsTeam) {
    PostRequest request =
        new PostRequest(
            name,
            MediaDto.builder().markdown("Post content").build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            signedAsTeam,
            null);
    return given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  private RequestSpecification as(@Nullable String user) {
    RequestSpecification spec = given();
    return user == null ? spec : spec.auth().oauth2(getAccessToken(user));
  }

  @Test
  void aPostSignedByItsAuthor_namesThemToTheMembersOnly() {
    // docs/LEDGER_*.md API-144 supersedes API-6 here: it used to name the author to everyone who
    // could read the post; a non-member now gets no name, the team renders instead.
    String slug = createPostAsOrganizer("Signed Post", false);
    String authorId = TsidUtils.toString(user2.getId());

    as(USER3)
        .when()
        .get("/api/teams/" + team1Slug + "/posts/" + slug)
        .then()
        .statusCode(200)
        .body("signedAsTeam", equalTo(false))
        .body("createdBy.id", equalTo(authorId))
        .body("createdBy.displayName", equalTo(user2.getDisplayName()));
    // Anonymous, and a person of no team: not named although the post is signed by its author
    for (String reader : new String[] {null, USER4}) {
      as(reader)
          .when()
          .get("/api/teams/" + team1Slug + "/posts/" + slug)
          .then()
          .statusCode(200)
          .body("signedAsTeam", equalTo(false))
          .body("$", not(hasKey("createdBy")));
    }
    as(USER3)
        .when()
        .get("/api/teams/" + team1Slug + "/publications?type=POST&view=COMPACT")
        .then()
        .statusCode(200)
        .body("publications[0].createdBy.id", equalTo(authorId));
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/publications?type=POST&view=COMPACT")
        .then()
        .statusCode(200)
        .body("publications[0]", not(hasKey("createdBy")));
  }

  @Test
  void aPostSignedByTheTeam_namesItsAuthorOnlyToTheAdminsAndToThemself() {
    // No value sent: the team's default, on unless the team turned it off
    String slug = createPostAsOrganizer("Team Post", null);
    String authorId = TsidUtils.toString(user2.getId());

    // Anonymous, a member, an outsider: the team signs, nobody is named
    for (String reader : new String[] {null, USER3, USER4}) {
      as(reader)
          .when()
          .get("/api/teams/" + team1Slug + "/posts/" + slug)
          .then()
          .statusCode(200)
          .body("signedAsTeam", equalTo(true))
          .body("$", not(hasKey("createdBy")));
    }
    // The team's admin and the author themself know who wrote it
    for (String reader : new String[] {USER1, USER2}) {
      as(reader)
          .when()
          .get("/api/teams/" + team1Slug + "/posts/" + slug)
          .then()
          .statusCode(200)
          .body("createdBy.id", equalTo(authorId));
    }
    // Same rule on a list row
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/publications?type=POST")
        .then()
        .statusCode(200)
        .body("publications[0]", not(hasKey("createdBy")));
    as(USER1)
        .when()
        .get("/api/teams/" + team1Slug + "/publications?type=POST")
        .then()
        .statusCode(200)
        .body("publications[0].createdBy.id", equalTo(authorId));
  }

  @Test
  void theTeamDefaultDecidesWhenThePostSaysNothing_andAnUpdateSayingNothingKeepsIt() {
    dataService.setPostsAsTeamByDefault(team1, false);
    String slug = createPostAsOrganizer("Default Post", null);
    as(null)
        .when()
        .get("/api/teams/" + team1Slug + "/posts/" + slug)
        .then()
        .body("signedAsTeam", equalTo(false));

    // Flipped explicitly, then an update that omits the field leaves it flipped
    PostRequest toTeam =
        new PostRequest(
            "Default Post",
            MediaDto.builder().markdown("Post content").build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            true,
            null);
    as(USER2)
        .contentType("application/json")
        .body(toTeam)
        .when()
        .put("/api/teams/" + team1Slug + "/posts/" + slug)
        .then()
        .statusCode(200)
        .body("signedAsTeam", equalTo(true));
    PostRequest silent =
        new PostRequest(
            "Default Post",
            MediaDto.builder().markdown("Post content").build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            null,
            null);
    as(USER2)
        .contentType("application/json")
        .body(silent)
        .when()
        .put("/api/teams/" + team1Slug + "/posts/" + slug)
        .then()
        .statusCode(200)
        .body("signedAsTeam", equalTo(true));
  }

  @Test
  void getPost_nonexistent_shouldReturn404() {
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/posts/nonexistent-post")
        .then()
        .statusCode(404);
  }

  @Test
  void getPost_toNonexistentTeam_shouldReturn404() {
    given().when().get("/api/teams/nonexistent-team/posts/some-post").then().statusCode(404);
  }

  // ==================== Update Post Tests ====================

  @Test
  void updatePost_asAdmin_shouldSucceed() {
    String postSlug = createTestPost("Original Post");

    PostRequest request =
        new PostRequest(
            "Updated Post",
            MediaDto.builder().markdown("Updated content").build(),
            wall(Instant.now().plus(14, ChronoUnit.DAYS)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Post"))
        .body("media.markdown", equalTo("Updated content"))
        .body("status", equalTo("PUBLISHED"));
  }

  @Test
  void updatePost_asOrganizer_shouldSucceed() {
    String postSlug = createTestPost("Organizer Update Post");

    PostRequest request =
        new PostRequest(
            "Updated by Organizer",
            MediaDto.builder().markdown("Organizer updated").build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated by Organizer"));
  }

  @Test
  void updatePost_asMember_shouldBeDenied() {
    String postSlug = createTestPost("Member Update Post");

    PostRequest request =
        new PostRequest(
            "Hacked by Member",
            MediaDto.builder().build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void updatePost_withoutAuth_shouldReturn401() {
    String postSlug = createTestPost("Unauth Update Post");

    PostRequest request =
        new PostRequest(
            "Unauthorized Update",
            MediaDto.builder().build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null);

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(401);
  }

  @Test
  void updatePost_asNonMember_shouldReturn403() {
    String postSlug = createTestPost("NonMember Update Post");

    PostRequest request =
        new PostRequest(
            "Hacked by NonMember",
            MediaDto.builder().build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void updatePost_nonexistent_shouldReturn404() {
    PostRequest request =
        new PostRequest(
            "Nonexistent",
            MediaDto.builder().build(),
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/posts/nonexistent-post")
        .then()
        .statusCode(404);
  }

  // ==================== Delete Post Tests ====================

  @Test
  void deletePost_asAdmin_shouldSucceed() {
    String postSlug = createTestPost("To Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(204);

    // Verify post is no longer accessible
    given().when().get("/api/teams/" + team1Slug + "/posts/" + postSlug).then().statusCode(404);
  }

  @Test
  void deletePost_asOrganizer_shouldSucceed() {
    String postSlug = createTestPost("Organizer Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(204);
  }

  @Test
  void deletePost_asMember_shouldBeDenied() {
    String postSlug = createTestPost("Member Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .delete("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void deletePost_withoutAuth_shouldReturn401() {
    String postSlug = createTestPost("Unauth Delete");

    given().when().delete("/api/teams/" + team1Slug + "/posts/" + postSlug).then().statusCode(401);
  }

  @Test
  void deletePost_asNonMember_shouldReturn403() {
    String postSlug = createTestPost("NonMember Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .delete("/api/teams/" + team1Slug + "/posts/" + postSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void deletePost_nonexistent_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/posts/nonexistent-post")
        .then()
        .statusCode(404);
  }

  // ==================== Change Slug Tests ====================

  @Test
  void changeSlug_asAdmin_shouldSucceed() {
    String postSlug = createTestPost("Slug Change Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("new-post-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/posts/" + postSlug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("new-post-slug"));
  }

  @Test
  void changeSlug_asOrganizer_shouldSucceed() {
    String postSlug = createTestPost("Organizer Slug Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(new SlugChangeRequest("organizer-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/posts/" + postSlug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("organizer-slug"));
  }

  @Test
  void changeSlug_asMember_shouldReturn403() {
    String postSlug = createTestPost("Member Slug Post");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(new SlugChangeRequest("hacked-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/posts/" + postSlug + "/slug")
        .then()
        .statusCode(403);
  }

  @Test
  void changeSlug_withoutAuth_shouldReturn401() {
    String postSlug = createTestPost("Unauth Slug Post");

    given()
        .contentType("application/json")
        .body(new SlugChangeRequest("unauth-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/posts/" + postSlug + "/slug")
        .then()
        .statusCode(401);
  }
}
