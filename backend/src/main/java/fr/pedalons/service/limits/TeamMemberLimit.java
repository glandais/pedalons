package fr.pedalons.service.limits;

import fr.pedalons.common.exception.ConflictException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.TeamMemberLimitDetails;
import fr.pedalons.repository.team.TeamInvitationRepository;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * The member cap of a team's tier, enforced on the four ways in (docs/LEDGER_*.md BILL-10): joining,
 * an addition by an administrator, sending an invitation and accepting one. A cap only ever refuses
 * an <i>arrival</i>: a team brought back to the free plan with more members than the cap keeps them
 * all.
 *
 * <p>Each check locks the team row before counting, so two arrivals racing for the last place are
 * served one after the other. Must run inside the caller's transaction.
 *
 * <p>A platform admin is exempt, whoever's membership they create. The biketeam import does not come
 * through here at all.
 */
@ApplicationScoped
public class TeamMemberLimit {

  @Inject PlanLimits planLimits;

  @Inject TeamRepository teamRepository;

  @Inject UserTeamRepository userTeamRepository;

  @Inject TeamInvitationRepository invitationRepository;

  @Inject PedalonsQueryContext pedalonsContext;

  /**
   * One more member: a join, an addition, an accepted invitation. Pending invitations are not
   * counted — the one being accepted is among them, and an invitation sent under the cap may still
   * find the team full if others came in meanwhile.
   *
   * @throws ConflictException {@code TEAM_MEMBER_LIMIT_REACHED} when the members already reach the
   *     cap
   */
  public void requireRoomForMember(Team team) {
    Integer limit = lockedLimit(team);
    if (limit == null) {
      return;
    }
    requireBelow(limit, userTeamRepository.countActiveMembers(team.getId()));
  }

  /**
   * One more invitation to {@code email}: members and pending invitations together must stay below
   * the cap, so that every invitation sent can still be accepted. A live invitation to the same
   * address is not counted — the new one replaces it.
   *
   * @throws ConflictException {@code TEAM_MEMBER_LIMIT_REACHED} when they already reach the cap
   */
  public void requireRoomForInvitation(Team team, String email) {
    Integer limit = lockedLimit(team);
    if (limit == null) {
      return;
    }
    long members = userTeamRepository.countActiveMembers(team.getId());
    long pending = invitationRepository.countPendingByTeam(team.getId(), email);
    requireBelow(limit, members + pending);
  }

  /** The cap that applies, the team row locked when there is one; null when none applies. */
  private Integer lockedLimit(Team team) {
    if (pedalonsContext.isPlatformAdmin()) {
      return null;
    }
    Integer limit = planLimits.forTeam(team).memberLimit();
    if (limit != null) {
      teamRepository.lockForMembership(team.getId());
    }
    return limit;
  }

  private static void requireBelow(int limit, long current) {
    if (current >= limit) {
      throw new ConflictException(
          ErrorCode.TEAM_MEMBER_LIMIT_REACHED, new TeamMemberLimitDetails(limit, current), null);
    }
  }
}
