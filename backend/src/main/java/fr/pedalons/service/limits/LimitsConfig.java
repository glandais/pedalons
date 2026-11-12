package fr.pedalons.service.limits;

import io.smallrye.config.ConfigMapping;
import io.smallrye.config.WithDefault;

/**
 * The caps of the free plan (docs/LEDGER_*.md BILL-10). Application configuration rather than
 * columns: changing a number is a redeploy, not a migration. Only {@link PlanLimits} reads it — the
 * rest of the code never knows the numbers.
 */
@ConfigMapping(prefix = "pedalons.limits")
public interface LimitsConfig {

  /** What a {@code FREE} team, or a user in no unlocked team, is held to. */
  Free free();

  /**
   * Route calculations one user may ask for per UTC day, whatever the plan: the bound of the
   * calculation without a save, which the monthly quotas do not reach.
   */
  @WithDefault("300")
  int routerDailyPerUser();

  interface Free {
    /** Members of a free team, pending invitations included. */
    @WithDefault("25")
    int memberLimit();

    /** Saves of a drawn route per calendar month, in the team's zone. */
    @WithDefault("20")
    int teamPlannerMonthly();

    /** Saves of a drawn track in the GPX tools per calendar month, for a user in no unlocked team. */
    @WithDefault("10")
    int personalPlannerMonthly();
  }
}
