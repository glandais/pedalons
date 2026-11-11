package fr.pedalons.service.trip;

import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
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
public class TripAccessChecker implements AccessChecker {
  @Inject TripService tripService;
  @Inject PedalonsQueryContext pedalonsContext;

  @Override
  public EntityType getType() {
    return EntityType.TRIP;
  }

  @Override
  public boolean hasRights(ActionType action, List<Object> params) {

    Context context = pedalonsContext.getContext(params);
    Team team = context.team();
    User user = context.user();
    TeamRole teamRole = context.teamRole();

    // Check if trips are enabled for the team (also disabled when routes are disabled)
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
        tripService.findBySlug(team, slug);
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
        Trip trip = tripService.findBySlug(team, slug);
        yield canJoin(team, teamRole, trip);
      }
      case LIST, LIST_ALL_TEAMS -> false;
    };
  }

  /** Trips are on: a team without routes has no trips either. */
  /**
   * Whether the module is on for the team. The listing and detail queries hide the content of a
   * module that is off from everyone, platform admin included (docs/LEDGER_*.md API-176).
   */
  public static boolean isEnabled(Team team) {
    return team.isEnableTrips() && team.isEnableRoutes();
  }

  /**
   * {@code UPDATE} and {@code DELETE} of a trip the caller can read — its stages included, which
   * are written through it: an organizer of its team, trips on. Shared with the permissions block
   * ({@code ContentPermissions}, docs/LEDGER_*.md API-176); the platform admin's bypass is {@code
   * SecurityVerifier}'s.
   */
  public static boolean canWrite(Team team, @Nullable TeamRole teamRole) {
    return isEnabled(team) && teamRole != null && teamRole.isOrganizer();
  }

  /** {@code JOIN} and {@code LEAVE}: a member of the team, the trip published, trips on. */
  public static boolean canJoin(Team team, @Nullable TeamRole teamRole, Trip trip) {
    return isEnabled(team) && teamRole != null && trip.getStatus() == Status.PUBLISHED;
  }
}
