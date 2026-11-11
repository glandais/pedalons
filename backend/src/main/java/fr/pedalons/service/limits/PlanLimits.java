package fr.pedalons.service.limits;

import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.TeamTier;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * The one door to the plan's caps (docs/LEDGER_*.md BILL-10): every check point asks here, none
 * knows the numbers or the tiers. The monetisation's entitlements resolver will replace this class
 * without touching the check points.
 *
 * <p>Caps only: a governance flag at false ({@code joinable}, {@code addMemberAllowed}, {@code
 * enableRoutePlanner}) closes a team whatever its tier.
 */
@ApplicationScoped
public class PlanLimits {

  @Inject LimitsConfig config;

  /** From the team alone, so no query: safe to call for every row of a page. */
  public TeamLimits forTeam(Team team) {
    if (team.getTier() == TeamTier.UNLOCKED) {
      return TeamLimits.UNLIMITED;
    }
    LimitsConfig.Free free = config.free();
    return new TeamLimits(free.memberLimit(), free.teamPlannerMonthly());
  }
}
