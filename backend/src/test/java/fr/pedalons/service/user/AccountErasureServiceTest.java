package fr.pedalons.service.user;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.comment.Comment;
import fr.pedalons.domain.moderation.ContentReport;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.comments.response.CommentDto;
import fr.pedalons.dto.comments.response.CommentListResponse;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.users.response.AccountDeletionImpactDto;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.ReportReason;
import fr.pedalons.enums.ReportTargetType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.comment.CommentService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AccountErasureServiceTest extends AbstractBaseTest {

  @Inject AccountErasureService erasureService;
  @Inject UserService userService;
  @Inject CommentService commentService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;
  @Inject EntityManager em;

  private Domain domain;
  private Team team;
  private User leaver;
  private User stayer;
  private Post post;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    stayer = dataService.createUser("stayer@example.com", "Stayer");
    team = dataService.createTeam(stayer, "Team", "team", Visibility.PUBLIC);
    leaver = dataService.createUser("leaver@example.com", "Leaver");
    dataService.addUserToTeam(leaver, team, TeamRole.MEMBER);
    post = dataService.createPost(team, stayer, "Post", Instant.now(), Visibility.PUBLIC);
  }

  private void erase(User user) {
    erasureService.eraseById(user.getId());
  }

  private User reload(User user) {
    return QuarkusTransaction.requiringNew().call(() -> em.find(User.class, user.getId()));
  }

  private boolean isTeamDeleted(Team t) {
    return QuarkusTransaction.requiringNew().call(() -> em.find(Team.class, t.getId()).isDeleted());
  }

  private static List<String> slugs(List<TeamPublicationDto> teams) {
    return teams.stream().map(TeamPublicationDto::slug).toList();
  }

  private long count(String hql, Object param) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            em.createQuery(hql, Long.class).setParameter("p", param).getSingleResult().longValue());
  }

  private boolean commentExists(Comment comment) {
    return count("select count(c) from Comment c where c.id = :p", comment.getId()) == 1;
  }

  private List<CommentDto> listComments() {
    queryContext.setUserForTest(stayer);
    CommentListResponse response =
        commentService.listComments(team.getSlug(), post.getSlug(), EntityType.POST);
    return response.items();
  }

  // ==================== The account ====================

  @Nested
  class Account {

    @Test
    void anonymizesTheUserRow() {
      dataService.setUserPasswordHash(leaver, "hash");

      erase(leaver);

      User erased = reload(leaver);
      assertTrue(erased.isDeleted());
      assertTrue(AccountErasureService.isErased(erased));
      assertFalse(erased.getEmail().contains("leaver"));
      assertEquals(AccountErasureService.ERASED_DISPLAY_NAME, erased.getDisplayName());
      assertNull(erased.getPasswordHash());
      assertNull(erased.getAvatarUrl());
      assertFalse(erased.isEmailVerified());
    }

    /** uk_users_domain_email is not partial: the old address blocked any new sign-up. */
    @Test
    void freesTheEmailForANewAccount() {
      erase(leaver);

      User again = dataService.createUser("leaver@example.com", "Back again");

      assertNotEquals(leaver.getId(), again.getId());
    }

    @Test
    void deleteUserErasesImmediately() {
      queryContext.setUserForTest(leaver);

      userService.deleteUser();

      assertTrue(AccountErasureService.isErased(reload(leaver)));
    }

    /** The team keeps its members, so it must keep someone to run it. */
    @Test
    void deleteUserIsRefusedToTheSoleAdminOfATeamWithOtherMembers() {
      queryContext.setUserForTest(stayer);

      BusinessException refused = assertThrows(BusinessException.class, userService::deleteUser);

      assertEquals(ErrorCode.SOLE_TEAM_ADMIN, refused.getErrorCode());
      assertFalse(AccountErasureService.isErased(reload(stayer)));
    }

    @Test
    void deleteUserIsAllowedOnceAnotherAdminIsNamed() {
      User other = dataService.createUser("other@example.com", "Other");
      dataService.addUserToTeam(other, team, TeamRole.ADMIN);
      queryContext.setUserForTest(stayer);

      userService.deleteUser();

      assertTrue(AccountErasureService.isErased(reload(stayer)));
    }

    @Test
    void deleteUserIsAllowedToTheAdminOfATeamTheyAreAloneIn() {
      User solo = dataService.createUser("solo@example.com", "Solo");
      dataService.createTeam(solo, "Solo team", "solo-team", Visibility.PUBLIC);
      queryContext.setUserForTest(solo);

      userService.deleteUser();

      assertTrue(AccountErasureService.isErased(reload(solo)));
    }

    /** Nobody would be left in it: the team goes with the account, the others stay. */
    @Test
    void deleteUserDeletesTheTeamsTheyAdministerAlone() {
      User solo = dataService.createUser("solo@example.com", "Solo");
      Team soloTeam = dataService.createTeam(solo, "Solo team", "solo-team", Visibility.PUBLIC);
      dataService.addUserToTeam(solo, team, TeamRole.MEMBER);
      queryContext.setUserForTest(solo);

      userService.deleteUser();

      assertTrue(AccountErasureService.isErased(reload(solo)));
      assertTrue(isTeamDeleted(soloTeam));
      assertFalse(isTeamDeleted(team));
    }

    /** A team with other members still blocks, and the refusal deletes nothing — solo team too. */
    @Test
    void deleteUserRefusedToTheSoleAdminOfATeamWithOtherMembersDeletesNoTeam() {
      Team soloTeam = dataService.createTeam(stayer, "Solo team", "solo-team", Visibility.PUBLIC);
      queryContext.setUserForTest(stayer);

      BusinessException refused = assertThrows(BusinessException.class, userService::deleteUser);

      assertEquals(ErrorCode.SOLE_TEAM_ADMIN, refused.getErrorCode());
      assertFalse(AccountErasureService.isErased(reload(stayer)));
      assertFalse(isTeamDeleted(soloTeam));
      assertFalse(isTeamDeleted(team));
    }

    @Test
    void deletionImpactNamesTheBlockingAndTheDeletedTeams() {
      Team soloTeam = dataService.createTeam(stayer, "Solo team", "solo-team", Visibility.PUBLIC);
      queryContext.setUserForTest(stayer);

      AccountDeletionImpactDto impact = userService.getDeletionImpact();

      assertTrue(impact.blocked());
      assertEquals(List.of(team.getSlug()), slugs(impact.blockingTeams()));
      assertEquals(List.of(soloTeam.getSlug()), slugs(impact.deletedTeams()));
    }

    @Test
    void deletionImpactOfAPlainMemberIsEmpty() {
      queryContext.setUserForTest(leaver);

      AccountDeletionImpactDto impact = userService.getDeletionImpact();

      assertFalse(impact.blocked());
      assertTrue(impact.blockingTeams().isEmpty());
      assertTrue(impact.deletedTeams().isEmpty());
    }

    @Test
    void isIdempotent() {
      erase(leaver);
      String email = reload(leaver).getEmail();

      erase(leaver);

      assertEquals(email, reload(leaver).getEmail());
    }
  }

  // ==================== Rows owned by the user ====================

  @Nested
  class OwnedRows {

    @Test
    void deletesCredentialsAndMembershipsOfTheLeaverOnly() {
      for (User user : List.of(leaver, stayer)) {
        dataService.createAuthSession(
            user, "hash-" + user.getId(), Instant.now().plus(1, ChronoUnit.DAYS));
        dataService.createPasskey(user, ("cred-" + user.getId()).getBytes(), new byte[] {1, 2, 3});
        dataService.createGpsServiceConnection(user, GpsServiceType.GARMIN);
        dataService.createCalendarToken(user, "cal-" + user.getId());
      }

      erase(leaver);

      for (String entity :
          List.of("AuthSession", "Passkey", "GpsServiceConnection", "CalendarToken", "UserTeam")) {
        String hql = "select count(e) from " + entity + " e where e.user.id = :p";
        assertEquals(0, count(hql, leaver.getId()), entity + " of the leaver");
        assertEquals(1, count(hql, stayer.getId()), entity + " of the stayer");
      }
    }
  }

  // ==================== Registrations ====================

  @Nested
  class Registrations {

    @Test
    void deletesFutureRegistrationsAndKeepsPastOnes() {
      Ride past =
          dataService.createRide(
              team, stayer, "Past", "past", Instant.now().minus(7, ChronoUnit.DAYS));
      Ride future =
          dataService.createRide(
              team, stayer, "Future", "future", Instant.now().plus(7, ChronoUnit.DAYS));
      RideGroup pastGroup = dataService.createRideGroup(stayer, past, "A");
      RideGroup futureGroup = dataService.createRideGroup(stayer, future, "A");
      dataService.createParticipation(pastGroup, leaver);
      dataService.createParticipation(futureGroup, leaver);
      Trip pastTrip =
          dataService.createTrip(
              team, stayer, "Past trip", Instant.now().minus(7, ChronoUnit.DAYS));
      Trip futureTrip =
          dataService.createTrip(
              team, stayer, "Future trip", Instant.now().plus(7, ChronoUnit.DAYS));
      dataService.createTripParticipation(pastTrip, leaver);
      dataService.createTripParticipation(futureTrip, leaver);

      erase(leaver);

      assertEquals(
          1,
          count(
              "select count(p) from RideParticipation p where p.rideGroup.id = :p",
              pastGroup.getId()));
      assertEquals(
          0,
          count(
              "select count(p) from RideParticipation p where p.rideGroup.id = :p",
              futureGroup.getId()));
      assertEquals(
          1,
          count("select count(p) from TripParticipation p where p.trip.id = :p", pastTrip.getId()));
      assertEquals(
          0,
          count(
              "select count(p) from TripParticipation p where p.trip.id = :p", futureTrip.getId()));
    }

    /** Null is a leader's normal state: clients render nothing, never a fallback. */
    @Test
    void unsetsTheLeaderOfGroups() {
      Ride ride =
          dataService.createRide(
              team, stayer, "Ride", "ride", Instant.now().plus(7, ChronoUnit.DAYS));
      RideGroup group = dataService.createRideGroup(stayer, ride, "A");
      group.setLeader(leaver);
      dataService.updateRideGroup(group);

      erase(leaver);

      assertEquals(
          0,
          count(
              "select count(g) from RideGroup g where g.id = :p and g.leader is not null",
              group.getId()));
    }
  }

  // ==================== Ads ====================

  @Nested
  class Ads {

    @Test
    void softDeletesAndBlanksTheAds() {
      Ad ad = dataService.createAd(team, leaver, "Vélo de Leaver", AdType.SALE);
      dataService.setMarkdown(ad, "Appelez-moi");

      erase(leaver);

      Ad erased = QuarkusTransaction.requiringNew().call(() -> em.find(Ad.class, ad.getId()));
      assertTrue(erased.isDeleted());
      assertEquals(AccountErasureService.ERASED_AD_NAME, erased.getName());
      assertEquals("", erased.getMarkdown());
      assertNull(erased.getLocationDescription());
    }
  }

  // ==================== Comments ====================

  @Nested
  class Comments {

    @Test
    void deletesUnansweredCommentsAndReplies() {
      Comment unanswered = dataService.createComment(leaver, post, "Seul");
      Comment stayerRoot = dataService.createComment(stayer, post, "Question");
      Comment leaverReply = dataService.createReply(leaver, post, stayerRoot, "Réponse");

      erase(leaver);

      assertFalse(commentExists(unanswered));
      assertFalse(commentExists(leaverReply));
      assertTrue(commentExists(stayerRoot));
    }

    /** Deleting it would take the replies of others with it. */
    @Test
    void keepsAnAnsweredCommentAsATombstone() {
      Comment root = dataService.createComment(leaver, post, "Rendez-vous à 9h");
      Comment reply = dataService.createReply(stayer, post, root, "J'y serai");

      erase(leaver);

      assertTrue(commentExists(root));
      assertTrue(commentExists(reply));
      CommentDto dto = listComments().getFirst();
      assertTrue(dto.deleted());
      assertEquals("", dto.content());
      assertEquals(1, dto.replies().size());
      assertFalse(dto.replies().getFirst().deleted());
      assertEquals("J'y serai", dto.replies().getFirst().content());
    }

    @Test
    void deletesACommentAnsweredOnlyByItsOwnAuthor() {
      Comment root = dataService.createComment(leaver, post, "Monologue");
      dataService.createReply(leaver, post, root, "Suite");

      erase(leaver);

      assertFalse(commentExists(root));
    }

    /** The leaver's reply was all that kept an earlier-erased account's tombstone alive. */
    @Test
    void deletesATombstoneLeftWithoutReplies() {
      User earlier = dataService.createUser("earlier@example.com", "Earlier");
      dataService.addUserToTeam(earlier, team, TeamRole.MEMBER);
      Comment root = dataService.createComment(earlier, post, "Ancien fil");
      dataService.createReply(leaver, post, root, "Dernière réponse");
      erase(earlier);
      assertTrue(commentExists(root));

      erase(leaver);

      assertFalse(commentExists(root));
    }

    @Test
    void deletingTheLastReplyDeletesTheTombstone() {
      Comment root = dataService.createComment(leaver, post, "Rendez-vous à 9h");
      Comment reply = dataService.createReply(stayer, post, root, "J'y serai");
      erase(leaver);

      queryContext.setUserForTest(stayer);
      commentService.deleteComment(team.getSlug(), post.getSlug(), EntityType.POST, reply.getId());

      assertFalse(commentExists(root));
    }

    @Test
    void deletingAReplyLeavesALiveCommentAlone() {
      Comment root = dataService.createComment(stayer, post, "Question");
      Comment reply = dataService.createReply(stayer, post, root, "Précision");

      queryContext.setUserForTest(stayer);
      commentService.deleteComment(team.getSlug(), post.getSlug(), EntityType.POST, reply.getId());

      assertTrue(commentExists(root));
    }
  }

  // ==================== Moderation ====================

  @Nested
  class Moderation {

    @Test
    void deletesTheBlocksTheLeaverMadeOrReceived() {
      User other = dataService.createUser("other@example.com", "Other");
      dataService.createBlock(leaver, stayer);
      dataService.createBlock(stayer, leaver);
      dataService.createBlock(stayer, other);

      erase(leaver);

      assertFalse(dataService.isBlocked(leaver, stayer));
      assertFalse(dataService.isBlocked(stayer, leaver));
      assertTrue(dataService.isBlocked(stayer, other), "someone else's block stays");
    }

    /** Their excerpt is the leaver's own content. */
    @Test
    void deletesTheReportsAboutTheLeaver() {
      Comment comment = dataService.createComment(leaver, post, "Mon commentaire");
      dataService.createReport(
          team, stayer, ReportTargetType.COMMENT, comment.getId(), leaver, ReportReason.SPAM);
      dataService.createReport(
          team, stayer, ReportTargetType.MEMBER, leaver.getId(), leaver, ReportReason.HARASSMENT);

      erase(leaver);

      assertEquals(
          0,
          count("select count(r) from ContentReport r where r.targetUser.id = :p", leaver.getId()));
    }

    /** The report stays, for the decision it records — without the leaver's name. */
    @Test
    void keepsTheReportsTheLeaverFiled_withoutThem() {
      ContentReport filed =
          dataService.createReport(
              team, leaver, ReportTargetType.POST, post.getId(), stayer, ReportReason.SPAM);

      erase(leaver);

      assertEquals(
          1,
          count(
              "select count(r) from ContentReport r where r.id = :p and r.reporter is null",
              filed.getId()));
    }
  }

  // ==================== Catch-up ====================

  @Nested
  class CatchUp {

    /** Accounts flagged deleted before erasure existed. */
    @Test
    void erasesAccountsOnlyFlaggedDeleted() {
      dataService.deleteUser(leaver);
      assertEquals(List.of(leaver.getId()), erasureService.findPendingErasure());

      erasureService.eraseById(leaver.getId());

      assertTrue(AccountErasureService.isErased(reload(leaver)));
      assertTrue(erasureService.findPendingErasure().isEmpty());
    }

    @Test
    void ignoresActiveAccounts() {
      assertTrue(erasureService.findPendingErasure().isEmpty());
    }
  }
}
