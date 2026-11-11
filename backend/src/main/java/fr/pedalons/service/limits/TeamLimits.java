package fr.pedalons.service.limits;

import org.jspecify.annotations.Nullable;

/**
 * The caps a team is held to; null is unlimited.
 *
 * @param memberLimit members, pending invitations included
 * @param plannerMonthly saves of a drawn route per calendar month, in the team's zone
 */
public record TeamLimits(@Nullable Integer memberLimit, @Nullable Integer plannerMonthly) {

  public static final TeamLimits UNLIMITED = new TeamLimits(null, null);
}
