package fr.pedalons.service.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.ContentPermissionsDto;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;

/**
 * The permissions block of every entity type, for every kind of caller, on every kind of team
 * (docs/LEDGER_*.md API-176, plan §4.5) — without a container. The expectations are written out
 * here from the plan's audit table (§2), not computed from the checkers' rules: {@code
 * ContentPermissionsConsistencyTest} is the one that compares the block with the checkers
 * themselves.
 */
class ContentPermissionsTest {

  private static final long TEAM_ID = 1L;
  private static final long AUTHOR_ID = 10L;
  private static final long CALLER_ID = 20L;

  private static final List<Visibility> ALL =
      List.of(Visibility.TEAM, Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC);
  private static final List<Visibility> TEAM_ONLY = List.of(Visibility.TEAM);

  /** The six callers of the plan's matrix. */
  enum Caller {
    ANONYMOUS(null),
    OUTSIDER(null),
    MEMBER(TeamRole.MEMBER),
    ORGANIZER(TeamRole.ORGANIZER),
    ADMIN(TeamRole.ADMIN),
    PLATFORM_ADMIN(null);

    final @Nullable TeamRole role;

    Caller(@Nullable TeamRole role) {
      this.role = role;
    }

    CallerRoles roles() {
      return switch (this) {
        case ANONYMOUS -> CallerRoles.ANONYMOUS;
        case OUTSIDER -> new CallerRoles(CALLER_ID, false, Map.of());
        case PLATFORM_ADMIN -> new CallerRoles(CALLER_ID, true, Map.of());
        default -> new CallerRoles(CALLER_ID, false, Map.of(TEAM_ID, role));
      };
    }

    boolean belongs() {
      return role != null || this == PLATFORM_ADMIN;
    }

    boolean organizes() {
      return this == ORGANIZER || this == ADMIN || this == PLATFORM_ADMIN;
    }

    boolean administers() {
      return this == ADMIN || this == PLATFORM_ADMIN;
    }
  }

  /** The four teams of the plan's matrix. */
  enum TeamKind {
    PUBLIC(Visibility.PUBLIC, false),
    UNLISTED(Visibility.PUBLIC_UNLISTED, false),
    PRIVATE_WITH_FLAG(Visibility.TEAM, true),
    PRIVATE(Visibility.TEAM, false);

    final Visibility visibility;
    final boolean flag;

    TeamKind(Visibility visibility, boolean flag) {
      this.visibility = visibility;
      this.flag = flag;
    }

    Team build() {
      Team team = new Team();
      team.setId(TEAM_ID);
      team.setVisibility(visibility);
      team.setPublicContentAllowed(flag);
      return team;
    }
  }

  private static User user(long id) {
    User user = new User();
    user.setId(id);
    return user;
  }

  /** One entity of each type, PUBLIC (an ad is TEAM by construction), published. */
  private static List<TeamEntity> entities(Team team) {
    User author = user(AUTHOR_ID);
    Instant soon = Instant.now().plusSeconds(86_400);
    Trip trip = new Trip(author, team, soon, "Trip", "trip", Visibility.PUBLIC);
    // With a group still to leave: a ride without one has nothing to join, and its detail says so.
    Ride ride = new Ride(author, team, soon, "Ride", "ride", Visibility.PUBLIC);
    ride.addGroup(new RideGroup(author, ride, "Group"));
    return List.of(
        ride,
        new Route(author, team, "Route", "route", Visibility.PUBLIC, SurfaceType.ROAD),
        new Post(author, team, soon, "Post", "post", Visibility.PUBLIC),
        trip,
        new TripStage(author, trip, "Stage", "stage"),
        TeamPage.createAdditionalPage(author, team, "Page", "page", Visibility.PUBLIC, 0),
        new Ad(author, team, soon, "Ad", "ad", AdType.SALE));
  }

  private static boolean expectedWrite(EntityType type, Caller caller) {
    return switch (type) {
      case TEAM_PAGE, AD -> caller.administers();
      default -> caller.organizes();
    };
  }

  private static @Nullable Boolean expectedMembersOnly(EntityType type, Caller caller) {
    return switch (type) {
      case RIDE, ROUTE, POST, TRIP, TRIP_STAGE -> caller.belongs();
      default -> null;
    };
  }

  private static @Nullable Boolean expectedRideOrTrip(EntityType type, Caller caller) {
    return type == EntityType.RIDE || type == EntityType.TRIP ? caller.belongs() : null;
  }

  private static @Nullable List<Visibility> expectedVisibilities(EntityType type, TeamKind kind) {
    return switch (type) {
      case TRIP_STAGE -> null;
      case AD -> TEAM_ONLY;
      default -> kind == TeamKind.PRIVATE ? TEAM_ONLY : ALL;
    };
  }

  @Test
  void theBlock_forEveryType_caller_andTeam() {
    for (TeamKind kind : TeamKind.values()) {
      for (Caller caller : Caller.values()) {
        ContentPermissions detail = ContentPermissions.forDetail(caller.roles());
        ContentPermissions list = ContentPermissions.forList(caller.roles());
        for (TeamEntity entity : entities(kind.build())) {
          EntityType type = entity.getEntityType();
          String where = type + " / " + caller + " / " + kind;
          ContentPermissionsDto block = detail.of(entity);

          assertEquals(expectedWrite(type, caller), block.canEdit(), "canEdit " + where);
          assertEquals(expectedWrite(type, caller), block.canDelete(), "canDelete " + where);
          assertEquals(
              expectedRideOrTrip(type, caller), block.canRegister(), "canRegister " + where);
          assertEquals(
              expectedMembersOnly(type, caller), block.canComment(), "canComment " + where);
          assertEquals(
              expectedRideOrTrip(type, caller),
              block.canSeeParticipants(),
              "canSeeParticipants " + where);
          assertEquals(
              expectedVisibilities(type, kind),
              block.allowedVisibilities(),
              "allowedVisibilities " + where);
          // Entity PUBLIC and published: only the team decides, and never for an ad.
          assertEquals(
              kind == TeamKind.PUBLIC && type != EntityType.AD,
              block.indexable(),
              "indexable " + where);

          // A list row: the same rights, no visibilities.
          ContentPermissionsDto row = list.of(entity);
          assertNull(row.allowedVisibilities(), "list allowedVisibilities " + where);
          assertEquals(block.canEdit(), row.canEdit(), "list canEdit " + where);
          assertEquals(block.canRegister(), row.canRegister(), "list canRegister " + where);
          assertEquals(block.indexable(), row.indexable(), "list indexable " + where);
        }
      }
    }
  }

  @Test
  void accessible_isTheRuleOfGetTeam() {
    for (TeamKind kind : TeamKind.values()) {
      Team team = kind.build();
      for (Caller caller : Caller.values()) {
        boolean expected = kind.visibility != Visibility.TEAM || caller.belongs();
        assertEquals(
            expected,
            ContentPermissions.forList(caller.roles()).teamAccessible(team),
            caller + " / " + kind);
      }
    }
  }

  @Test
  void anAd_isWritableByItsAuthor_whileAMember() {
    Team team = TeamKind.PUBLIC.build();
    Ad ad = new Ad(user(CALLER_ID), team, Instant.now(), "Ad", "ad", AdType.SALE);
    CallerRoles author = new CallerRoles(CALLER_ID, false, Map.of(TEAM_ID, TeamRole.MEMBER));
    assertTrue(ContentPermissions.forDetail(author).of(ad).canEdit());
    assertTrue(ContentPermissions.forDetail(author).of(ad).canDelete());
    // No longer a member: the ad is out of reach, like AdAccessChecker says.
    CallerRoles former = new CallerRoles(CALLER_ID, false, Map.of());
    assertFalse(ContentPermissions.forDetail(former).of(ad).canEdit());
  }

  @Test
  void aModuleSwitchedOff_closesTheWrites_butNotThePlatformAdmin() {
    Team team = TeamKind.PUBLIC.build();
    team.setEnableRides(false);
    Ride ride = new Ride(user(AUTHOR_ID), team, Instant.now(), "Ride", "ride", Visibility.PUBLIC);
    ContentPermissionsDto organizer = ContentPermissions.forDetail(Caller.ADMIN.roles()).of(ride);
    assertFalse(organizer.canEdit());
    assertFalse(organizer.canRegister());
    assertFalse(organizer.indexable());
    assertTrue(ContentPermissions.forDetail(Caller.PLATFORM_ADMIN.roles()).of(ride).canEdit());
  }

  @Test
  void aDraft_cannotBeJoined_evenByAPlatformAdmin() {
    Team team = TeamKind.PUBLIC.build();
    for (Status status : List.of(Status.DRAFT, Status.CANCELLED)) {
      Ride ride = new Ride(user(AUTHOR_ID), team, Instant.now(), "Ride", "ride", Visibility.PUBLIC);
      ride.setStatus(status);
      Trip trip = new Trip(user(AUTHOR_ID), team, Instant.now(), "Trip", "trip", Visibility.PUBLIC);
      trip.setStatus(status);
      for (Caller caller : Caller.values()) {
        ContentPermissions permissions = ContentPermissions.forDetail(caller.roles());
        assertEquals(false, permissions.of(ride).canRegister(), "ride " + status + caller);
        assertEquals(false, permissions.of(trip).canRegister(), "trip " + status + caller);
      }
    }
  }

  /**
   * On a detail, {@code canRegister} is what the join answers about timing: {@code RIDE_PAST} once
   * every group has left, {@code TRIP_FINISHED} once the last stage is over. A list row does not
   * look (it loads neither groups nor stages) and stays "member and published".
   */
  @Test
  void canRegister_onADetail_followsTheJoinsTiming_notOnAListRow() {
    Team team = TeamKind.PUBLIC.build();
    User author = user(AUTHOR_ID);
    Instant past = Instant.now().minusSeconds(3_600);
    Instant soon = Instant.now().plusSeconds(86_400);

    Ride left = new Ride(author, team, past, "Left", "left", Visibility.PUBLIC);
    left.addGroup(new RideGroup(author, left, "A"));
    left.addGroup(new RideGroup(author, left, "B"));

    // The first group has left, a later one is still open (docs/LEDGER_*.md API-170).
    Ride later = new Ride(author, team, past, "Later", "later", Visibility.PUBLIC);
    later.addGroup(new RideGroup(author, later, "Early"));
    RideGroup open = new RideGroup(author, later, "Late");
    open.setStartAt(soon);
    later.addGroup(open);

    Ride noGroup = new Ride(author, team, soon, "Empty", "empty", Visibility.PUBLIC);

    Trip finished = new Trip(author, team, past, "Done", "done", Visibility.PUBLIC);
    // Under way: started, its last stage still to ride.
    Trip underWay = new Trip(author, team, past, "Going", "going", Visibility.PUBLIC);
    TripStage last = new TripStage(author, underWay, "Last", "last");
    last.setDateTime(soon);
    underWay.getStages().add(last);

    for (Caller caller : List.of(Caller.MEMBER, Caller.ORGANIZER, Caller.PLATFORM_ADMIN)) {
      ContentPermissions detail = ContentPermissions.forDetail(caller.roles());
      ContentPermissions list = ContentPermissions.forList(caller.roles());
      assertEquals(false, detail.of(left).canRegister(), "every group left / " + caller);
      assertEquals(true, detail.of(later).canRegister(), "a later group open / " + caller);
      assertEquals(false, detail.of(noGroup).canRegister(), "no group / " + caller);
      assertEquals(false, detail.of(finished).canRegister(), "finished trip / " + caller);
      assertEquals(true, detail.of(underWay).canRegister(), "trip under way / " + caller);
      for (TeamEntity entity : List.of(left, later, noGroup, finished, underWay)) {
        assertEquals(
            true, list.of(entity).canRegister(), "list " + entity.getSlug() + " / " + caller);
      }
    }
    // Timing never opens what membership closes.
    for (Caller caller : List.of(Caller.ANONYMOUS, Caller.OUTSIDER)) {
      assertEquals(false, ContentPermissions.forDetail(caller.roles()).of(later).canRegister());
      assertEquals(false, ContentPermissions.forDetail(caller.roles()).of(underWay).canRegister());
    }
  }

  @Test
  void theAboutPage_isEditable_neverDeletable() {
    Team team = TeamKind.PUBLIC.build();
    TeamPage about = TeamPage.createAboutPage(user(AUTHOR_ID), team, Visibility.PUBLIC);
    ContentPermissionsDto block = ContentPermissions.forDetail(Caller.ADMIN.roles()).of(about);
    // Edited through PUT team, which never sets its visibility: no selector to offer.
    assertTrue(block.canEdit());
    assertFalse(block.canDelete());
    assertNull(block.allowedVisibilities());
  }

  @Test
  void indexable_followsTheSitemapRule() {
    Team team = TeamKind.PUBLIC.build();
    User author = user(AUTHOR_ID);
    ContentPermissions permissions = ContentPermissions.forDetail(Caller.ANONYMOUS.roles());

    Ride unlisted = new Ride(author, team, Instant.now(), "R", "r", Visibility.PUBLIC_UNLISTED);
    assertFalse(permissions.of(unlisted).indexable(), "an unlisted ride");

    Ride draft = new Ride(author, team, Instant.now(), "R", "r", Visibility.PUBLIC);
    draft.setStatus(Status.DRAFT);
    assertFalse(permissions.of(draft).indexable(), "a draft");

    Ride cancelled = new Ride(author, team, Instant.now(), "R", "r", Visibility.PUBLIC);
    cancelled.setStatus(Status.CANCELLED);
    assertTrue(permissions.of(cancelled).indexable(), "a cancelled ride stays in the sitemap");

    Ride hidden = new Ride(author, team, Instant.now(), "R", "r", Visibility.PUBLIC);
    hidden.setModerationHiddenAt(Instant.now());
    assertFalse(permissions.of(hidden).indexable(), "hidden by moderation");

    Ride deleted = new Ride(author, team, Instant.now(), "R", "r", Visibility.PUBLIC);
    deleted.setDeleted(true);
    assertFalse(permissions.of(deleted).indexable(), "deleted");

    Trip draftTrip = new Trip(author, team, Instant.now(), "T", "t", Visibility.PUBLIC);
    draftTrip.setStatus(Status.DRAFT);
    TripStage stage = new TripStage(author, draftTrip, "S", "s");
    assertFalse(permissions.of(stage).indexable(), "a stage carries its trip's answer");
  }

  @Test
  void theBlock_carriesNoRoleNorId() {
    // Every component is a boolean or the list of visibilities: nothing about who the caller is.
    for (var component : ContentPermissionsDto.class.getRecordComponents()) {
      Class<?> type = component.getType();
      assertTrue(
          type == boolean.class || type == Boolean.class || type == List.class,
          component.getName() + " is " + type);
    }
  }
}
