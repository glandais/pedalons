package fr.pedalons.service.common;

import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.dto.common.ContentPermissionsDto;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.common.TeamEntityRepository;
import fr.pedalons.service.ad.AdAccessChecker;
import fr.pedalons.service.comment.CommentAccessChecker;
import fr.pedalons.service.page.TeamPageAccessChecker;
import fr.pedalons.service.post.PostAccessChecker;
import fr.pedalons.service.ride.RideAccessChecker;
import fr.pedalons.service.route.RouteAccessChecker;
import fr.pedalons.service.team.TeamAccessChecker;
import fr.pedalons.service.trip.TripAccessChecker;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * The caller's rights on the entities of one page, or of one detail (docs/LEDGER_*.md API-176,
 * decision D7): the {@code permissions} block of each entity DTO and the {@code accessible} flag of
 * its embedded team.
 *
 * <p>Costs nothing: every answer is read off the entity in hand and a {@link CallerRoles} resolved
 * once for the page by {@link MemberNamesVisibility#callerRoles} — the lookup the member names
 * already make, never a query per row.
 *
 * <p>Never a rule of its own. Each field asks the static rule its access checker applies ({@code
 * RideAccessChecker.canWrite}, {@code TeamAccessChecker.canRead}…), and the platform admin's
 * bypass is {@code SecurityVerifier}'s: a platform admin may do everything the checkers guard. The
 * visibilities come from {@link ContentVisibilityRules}, the one rule the writes validate against;
 * {@code indexable} from {@link TeamEntityRepository#isIndexable}, the mirror of the sitemap's
 * query. {@code ContentPermissionsConsistencyTest} fails if the block and a checker diverge.
 *
 * <p>Deliberate departures from the bare checker verdict:
 *
 * <ul>
 *   <li>{@code canRegister} also requires the entity to be published for a platform admin, as both
 *       joins do for everyone ({@code RideService.joinGroup} under its lock, {@code
 *       TripService.joinTrip}): the block and the server agree for every caller.
 *   <li>On a detail, {@code canRegister} also says what the join would answer about timing: false
 *       once every group of the ride has left ({@code RIDE_PAST}, {@link Ride#hasGroupStillToLeave}
 *       over {@code RideGroup.hasLeft}) or the trip is over ({@code TRIP_FINISHED}, {@link
 *       Trip#isFinished}) — the very tests the joins apply. A list row does not load the groups or
 *       the stages (per page, never per row), so there it stays "member and published" and may say
 *       true where the detail says false. Capacity is never counted: a full group still refuses.
 *   <li>The about page cannot be deleted ({@code TeamPageService.deletePage}) and has no
 *       visibility to choose: no endpoint sets it. Its {@code canEdit} means editing it through
 *       {@code PUT team} — {@code TeamAccessChecker.UPDATE}, the same admin rule as {@code
 *       TeamPageAccessChecker.canWrite}.
 * </ul>
 */
public final class ContentPermissions {

  private final CallerRoles caller;

  /**
   * A detail, not a list row: the block carries {@code allowedVisibilities}, and {@code
   * canRegister} reads the groups' starts or the stages' dates, which a detail has loaded.
   */
  private final boolean detail;

  /**
   * The routes of the details at hand that a ride or a trip that is not {@code TEAM} uses, as
   * {@link RouteVisibilityCompatibility#routesInNonTeamUse} found them: their {@code
   * allowedVisibilities} leave {@code TEAM} out (docs/LEDGER_*.md API-176, plan §4.4). Empty unless
   * a route detail asked for it.
   */
  private final Set<Long> routesInNonTeamUse;

  private ContentPermissions(CallerRoles caller, boolean detail, Set<Long> routesInNonTeamUse) {
    this.caller = caller;
    this.detail = detail;
    this.routesInNonTeamUse = routesInNonTeamUse;
  }

  /** For a detail, an editor's starting point: the block carries {@code allowedVisibilities}. */
  public static ContentPermissions forDetail(CallerRoles caller) {
    return new ContentPermissions(caller, true, Set.of());
  }

  /** For list rows and embedded summaries: no {@code allowedVisibilities}. */
  public static ContentPermissions forList(CallerRoles caller) {
    return new ContentPermissions(caller, false, Set.of());
  }

  /**
   * The same detail block, knowing which routes are used by a ride or a trip that is not {@code
   * TEAM} — {@link RouteVisibilityCompatibility#routesInNonTeamUse} over the route details at hand,
   * once for all of them. Without it, a route detail would offer {@code TEAM} where the save
   * refuses it.
   */
  public ContentPermissions withRoutesInNonTeamUse(Set<Long> routeIds) {
    return new ContentPermissions(caller, detail, Set.copyOf(routeIds));
  }

  /** The same caller, for the summaries a detail embeds (a stage's route, say). */
  public ContentPermissions embedded() {
    return detail ? new ContentPermissions(caller, false, Set.of()) : this;
  }

  public CallerRoles caller() {
    return caller;
  }

  /**
   * Whether {@code GET team} would answer this caller: {@code TeamAccessChecker.READ}, platform
   * admin included. A client only loads the team when this is true.
   */
  public boolean teamAccessible(Team team) {
    return caller.platformAdmin() || TeamAccessChecker.canRead(team, caller.roleIn(team.getId()));
  }

  /** The permissions block of {@code entity}, which the caller can read. */
  public ContentPermissionsDto of(TeamEntity entity) {
    Team team = entity.getTeam();
    @Nullable TeamRole role = caller.roleIn(team.getId());
    boolean admin = caller.platformAdmin();
    boolean members = admin || CommentAccessChecker.canComment(role);
    boolean indexable = TeamEntityRepository.isIndexable(entity);
    return switch (entity) {
      case Ride ride -> {
        boolean write = admin || RideAccessChecker.canWrite(team, role);
        boolean register =
            (admin
                    // The join finds no ride of a module that is off, whoever asks.
                    ? RideAccessChecker.isEnabled(team) && ride.getStatus() == Status.PUBLISHED
                    : RideAccessChecker.canJoin(team, role, ride))
                && (!detail || ride.hasGroupStillToLeave(Instant.now()));
        yield new ContentPermissionsDto(
            write, write, register, members, members, visibilities(entity), indexable);
      }
      case Trip trip -> {
        boolean write = admin || TripAccessChecker.canWrite(team, role);
        boolean register =
            (admin
                    ? TripAccessChecker.isEnabled(team) && trip.getStatus() == Status.PUBLISHED
                    : TripAccessChecker.canJoin(team, role, trip))
                && (!detail || !trip.isFinished(Instant.now()));
        yield new ContentPermissionsDto(
            write, write, register, members, members, visibilities(entity), indexable);
      }
      case TripStage stage -> {
        // Written through its trip (TripAccessChecker.UPDATE): the stage's own checker grants READ
        // only, and no endpoint asks it for more. No visibility of its own: it has its trip's.
        boolean write = admin || TripAccessChecker.canWrite(team, role);
        yield new ContentPermissionsDto(write, write, null, members, null, null, indexable);
      }
      case Route route -> {
        boolean write = admin || RouteAccessChecker.canWrite(team, role);
        // The public usages only for an editor: they may be drafts or hidden rides a reader cannot
        // see, whose presence a missing TEAM would give away (docs/LEDGER_*.md API-176).
        yield new ContentPermissionsDto(
            write,
            write,
            null,
            members,
            null,
            write ? visibilities(route) : teamVisibilities(route),
            indexable);
      }
      case Post post -> {
        boolean write = admin || PostAccessChecker.canWrite(team, role);
        yield new ContentPermissionsDto(
            write, write, null, members, null, visibilities(post), indexable);
      }
      case TeamPage page -> {
        boolean write = admin || TeamPageAccessChecker.canWrite(role);
        // The about page is written through PUT team, which never changes its visibility.
        boolean about = page.isAboutPage();
        yield new ContentPermissionsDto(
            write, write && !about, null, null, null, about ? null : visibilities(page), indexable);
      }
      case Ad ad -> {
        boolean write = admin || AdAccessChecker.canWrite(team, role, ad, caller.userId());
        yield new ContentPermissionsDto(
            write, write, null, null, null, visibilities(ad), indexable);
      }
      default ->
          throw new IllegalArgumentException(entity.getEntityType() + " has no permissions block");
    };
  }

  /**
   * The team's list for this type, less {@code TEAM} for a route used by a ride or a trip that is
   * not {@code TEAM} ({@link RouteVisibilityCompatibility#allowedForRoute}, docs/LEDGER_*.md
   * API-176 §4.4). A detail only: a list row has no editor behind it.
   */
  private @Nullable List<Visibility> teamVisibilities(TeamEntity entity) {
    return detail
        ? ContentVisibilityRules.accepted(entity.getTeam(), entity.getEntityType())
        : null;
  }

  private @Nullable List<Visibility> visibilities(TeamEntity entity) {
    if (!detail) {
      return null;
    }
    List<Visibility> accepted =
        ContentVisibilityRules.accepted(entity.getTeam(), entity.getEntityType());
    if (!(entity instanceof Route)) {
      return accepted;
    }
    // Set.of/Set.copyOf throw on contains(null): a route not persisted yet has no id, and nothing
    // uses it.
    Long id = entity.getId();
    return RouteVisibilityCompatibility.allowedForRoute(
        accepted, id != null && routesInNonTeamUse.contains(id));
  }
}
