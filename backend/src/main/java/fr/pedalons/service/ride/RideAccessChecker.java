package fr.pedalons.service.ride;

import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.service.security.AccessChecker;
import fr.pedalons.service.security.Context;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class RideAccessChecker implements AccessChecker {

  @Inject RideService rideService;
  @Inject PedalonsQueryContext pedalonsContext;

  @Override
  public EntityType getType() {
    return EntityType.RIDE;
  }

  @Override
  public boolean hasRights(ActionType action, List<Object> params) {

    Context context = pedalonsContext.getContext(params);
    Team team = context.team();
    User user = context.user();
    TeamRole teamRole = context.teamRole();

    // Check if rides are enabled for the team (also disabled when routes are disabled)
    if (team != null && !isEnabled(team) && action != ActionType.READ) {
      return false;
    }

    return switch (action) {
      case CREATE -> teamRole != null && teamRole.isOrganizer();
      case READ, UPDATE, DELETE -> {
        String slug = pedalonsContext.getParam(params, 1);
        if (slug == null || team == null) {
          yield false;
        }
        // find with SQL filters, throws 404 if not found
        // see TeamEntityRepository.getPedalonsQuery
        rideService.findBySlug(team, slug);
        if (action == ActionType.READ) {
          // filtering done via SQL
          yield true;
        } else {
          yield canWrite(team, teamRole);
        }
      }
      case JOIN, LEAVE -> {
        String slug = pedalonsContext.getParam(params, 1);
        if (slug == null || team == null) {
          yield false;
        }
        Ride ride = rideService.findBySlug(team, slug);
        yield canJoin(team, teamRole, ride);
      }
      case LIST, LIST_ALL_TEAMS -> false;
    };
  }

  /** Rides are on: a team without routes has no rides either. */
  /**
   * Whether the module is on for the team. The listing and detail queries hide the content of a
   * module that is off from everyone, platform admin included (docs/LEDGER_*.md API-176).
   */
  public static boolean isEnabled(Team team) {
    return team.isEnableRides() && team.isEnableRoutes();
  }

  /**
   * {@code UPDATE} and {@code DELETE} of a ride the caller can read: an organizer of its team, rides
   * on. The rule {@link #hasRights} applies and the permissions block of a ride reports
   * ({@code ContentPermissions}, docs/LEDGER_*.md API-176) — one method, so they cannot diverge.
   * The platform admin's bypass is {@code SecurityVerifier}'s, not this rule's.
   */
  public static boolean canWrite(Team team, @Nullable TeamRole teamRole) {
    return isEnabled(team) && teamRole != null && teamRole.isOrganizer();
  }

  /** {@code JOIN} and {@code LEAVE}: a member of the team, the ride published, rides on. */
  public static boolean canJoin(Team team, @Nullable TeamRole teamRole, Ride ride) {
    return isEnabled(team) && teamRole != null && ride.getStatus() == Status.PUBLISHED;
  }
}
