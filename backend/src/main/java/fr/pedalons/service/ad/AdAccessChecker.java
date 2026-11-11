package fr.pedalons.service.ad;

import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.service.security.AccessChecker;
import fr.pedalons.service.security.Context;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class AdAccessChecker implements AccessChecker {
  @Inject AdService adService;
  @Inject PedalonsQueryContext pedalonsContext;

  @Override
  public EntityType getType() {
    return EntityType.AD;
  }

  @Override
  public boolean hasRights(ActionType action, List<Object> params) {

    Context context = pedalonsContext.getContext(params);
    Team team = context.team();
    User user = context.user();
    TeamRole teamRole = context.teamRole();

    if (team == null || user == null || teamRole == null) {
      // only members can see ads
      return false;
    }
    if (!team.isEnableAds()) {
      return false;
    }
    return switch (action) {
      case LIST, CREATE -> true;
      case READ, UPDATE, DELETE -> {
        String slug = pedalonsContext.getParam(params, 1);
        if (slug == null) {
          yield false;
        }
        // find with SQL filters, throws 404 if not found
        // see TeamEntityRepository.getPedalonsQuery
        Ad ad = adService.findBySlug(team, slug);
        if (action == ActionType.READ) {
          // filtering done via SQL
          yield true;
        } else {
          yield canWrite(team, teamRole, ad, user.getId());
        }
      }
      case LIST_ALL_TEAMS, JOIN, LEAVE -> false;
    };
  }

  /**
   * {@code UPDATE} and {@code DELETE} of an ad the caller can read: ads on, and an admin of its team
   * or its author while still a member. Shared with the permissions block ({@code
   * ContentPermissions}, docs/LEDGER_*.md API-176); the platform admin's bypass is {@code
   * SecurityVerifier}'s.
   */
  public static boolean canWrite(
      Team team, @Nullable TeamRole teamRole, Ad ad, @Nullable Long userId) {
    return team.isEnableAds()
        && teamRole != null
        && userId != null
        && (teamRole.isAdmin() || ad.getCreatedBy().getId().equals(userId));
  }
}
