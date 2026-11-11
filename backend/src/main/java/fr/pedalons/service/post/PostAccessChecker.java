package fr.pedalons.service.post;

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
public class PostAccessChecker implements AccessChecker {

  @Inject PostService postService;
  @Inject PedalonsQueryContext pedalonsContext;

  @Override
  public EntityType getType() {
    return EntityType.POST;
  }

  @Override
  public boolean hasRights(ActionType action, List<Object> params) {

    Context context = pedalonsContext.getContext(params);
    Team team = context.team();
    User user = context.user();
    TeamRole teamRole = context.teamRole();

    // Check if posts are enabled for the team
    if (team != null && !team.isEnablePosts() && action != ActionType.READ) {
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
        postService.findBySlug(team, slug);
        if (action == ActionType.READ) {
          // filtering done via SQL
          yield true;
        } else {
          yield canWrite(team, teamRole);
        }
      }
      case LIST, LIST_ALL_TEAMS, LEAVE, JOIN -> false;
    };
  }

  /**
   * {@code UPDATE} and {@code DELETE} of a post the caller can read: an organizer of its team,
   * posts on. Shared with the permissions block ({@code ContentPermissions}, docs/LEDGER_*.md
   * API-176); the platform admin's bypass is {@code SecurityVerifier}'s.
   */
  public static boolean canWrite(Team team, @Nullable TeamRole teamRole) {
    return team.isEnablePosts() && teamRole != null && teamRole.isOrganizer();
  }
}
