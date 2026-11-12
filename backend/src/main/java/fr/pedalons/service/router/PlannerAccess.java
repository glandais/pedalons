package fr.pedalons.service.router;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.service.limits.PlannerQuota;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.SecurityVerifier;
import fr.pedalons.service.team.TeamService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import org.jspecify.annotations.Nullable;

/** Who may use the route planner: the routing and the GPX import of its editor share the rule. */
@ApplicationScoped
public class PlannerAccess {

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject SecurityVerifier securityVerifier;

  @Inject TeamService teamService;

  @Inject PlannerQuota plannerQuota;

  /**
   * With a team, the caller must be allowed to create routes in it (the very rule of {@code
   * RouteService.createRoute}, through its {@code RouteAccessChecker}) and the team must have its
   * route planner on; without one, the domain's GPX planner must be on. The team is looked up in
   * the current domain only, so a slug of another domain is a 404 like anywhere else. Rights are
   * checked before the flag, so a non-member learns nothing about the team's settings.
   */
  public void check(@Nullable String teamSlug) {
    if (teamSlug == null || teamSlug.isBlank()) {
      if (!pedalonsContext.getDomain().isEnableGpxPlanner()) {
        throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
      }
      return;
    }
    securityVerifier.verifyAccess(EntityType.ROUTE, ActionType.CREATE, List.of(teamSlug));
    if (!teamService.getTeam(teamSlug).isEnableRoutePlanner()) {
      throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
    }
  }

  /**
   * The rule of {@link #check} for a route calculation, the one call billed by the routing provider,
   * plus the free plan's bounds (docs/LEDGER_*.md BILL-10): refused once the quota the save would
   * draw on is spent — the team's with a team, the caller's own without — and past the caller's
   * calculations of the day, whatever the plan. The import of a GPX into the editor and the relief
   * of straight lines call no provider and keep {@link #check} alone.
   *
   * @throws fr.pedalons.common.exception.ForbiddenException {@code PLANNER_QUOTA_REACHED}
   * @throws fr.pedalons.common.exception.TooManyRequestsException {@code
   *     ROUTING_DAILY_LIMIT_REACHED}
   */
  public void checkRouting(@Nullable String teamSlug) {
    check(teamSlug);
    if (teamSlug == null || teamSlug.isBlank()) {
      plannerQuota.requirePersonalRoom();
    } else {
      plannerQuota.requireTeamRoom(teamService.getTeam(teamSlug));
    }
    plannerQuota.admitRouting();
  }
}
