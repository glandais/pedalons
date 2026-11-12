package fr.pedalons.service.limits;

import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.TeamTier;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.jspecify.annotations.Nullable;

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

  @Inject UserTeamRepository userTeamRepository;

  @Inject PedalonsQueryContext pedalonsContext;

  /** From the team alone, so no query: safe to call for every row of a page. */
  public TeamLimits forTeam(Team team) {
    if (team.getTier() == TeamTier.UNLOCKED) {
      return TeamLimits.UNLIMITED;
    }
    LimitsConfig.Free free = config.free();
    return new TeamLimits(free.memberLimit(), free.teamPlannerMonthly());
  }

  /**
   * The saves of a drawn track a user may make per calendar month in the GPX tools: null — unlimited
   * — for a member, whatever the role, of an {@code UNLOCKED} team of the current domain. One query.
   */
  public @Nullable Integer personalPlannerQuota(long userId) {
    return personalPlannerQuota(userId, pedalonsContext.getDomainId());
  }

  /** As {@link #personalPlannerQuota(long)}, in the given domain. */
  public @Nullable Integer personalPlannerQuota(long userId, long domainId) {
    if (userTeamRepository.existsMembershipInTier(userId, domainId, TeamTier.UNLOCKED)) {
      return null;
    }
    return config.free().personalPlannerMonthly();
  }

  /** Route calculations one user may ask for per UTC day, whatever the plan. */
  public int routerDailyPerUser() {
    return config.routerDailyPerUser();
  }
}
