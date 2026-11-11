package fr.pedalons.service.team;

import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.security.AccessChecker;
import fr.pedalons.service.security.Context;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class TeamAccessChecker implements AccessChecker {

  @Inject PedalonsQueryContext pedalonsContext;

  @Override
  public EntityType getType() {
    return EntityType.TEAM;
  }

  @Override
  public boolean hasRights(ActionType action, List<Object> params) {
    // For CREATE and LIST, there's no team slug - get user context only
    if (action == ActionType.CREATE) {
      return pedalonsContext.getUserNullable() != null;
    }
    if (action == ActionType.LIST) {
      return true;
    }

    Context context = pedalonsContext.getContext(params);
    Team team = context.team();
    TeamRole teamRole = context.teamRole();

    return switch (action) {
      case CREATE, LIST -> true; // Handled above
      case READ -> team != null && canRead(team, teamRole);
      case UPDATE, DELETE -> teamRole == TeamRole.ADMIN;
      case LIST_ALL_TEAMS, JOIN, LEAVE -> false;
    };
  }

  /**
   * {@code READ} of a team — {@code GET team}, its dashboard, publications and tags: a team that is
   * not private, or a member of it. What {@code TeamPublicationDto.accessible} reports
   * (docs/LEDGER_*.md API-176), the platform admin's bypass being {@code SecurityVerifier}'s.
   */
  public static boolean canRead(Team team, @Nullable TeamRole teamRole) {
    return team.getVisibility() != Visibility.TEAM || teamRole != null;
  }
}
