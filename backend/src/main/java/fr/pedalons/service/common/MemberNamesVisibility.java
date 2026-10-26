package fr.pedalons.service.common;

import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Collection;
import java.util.Set;

/**
 * Who may be told the names of a team's members (docs/LEDGER_*.md API-144).
 *
 * <p>The rule: <b>the names of a team's members never reach someone who is not a member of that
 * team</b> — an anonymous visitor, a person of no team, a member of another team. A non-member gets
 * the counts, never a name, an avatar or a user id. "May see names" is the same {@code member ||
 * platformAdmin} rule as the comments, the member directory and the dashboard.
 *
 * <p>Costs a page, not a row: an anonymous caller and a platform administrator cost no query, any
 * other caller one {@code findMemberTeamIds} for the whole page. A list that needs the answer in
 * several places should compute {@link #teamsWithNames} once and reuse the set.
 */
@ApplicationScoped
public class MemberNamesVisibility {

  @Inject UserTeamRepository userTeamRepository;

  @Inject PedalonsQueryContext pedalonsContext;

  /** The teams, among these, whose member names the caller may see. At most one query. */
  public Set<Long> teamsWithNames(Collection<Long> teamIds) {
    Long userId = pedalonsContext.getUserIdNullable();
    if (userId == null || teamIds.isEmpty()) {
      return Set.of();
    }
    if (pedalonsContext.isPlatformAdmin()) {
      return Set.copyOf(teamIds);
    }
    return userTeamRepository.findMemberTeamIds(userId, pedalonsContext.getDomainId(), teamIds);
  }

  /** Whether the caller may see the names of this one team's members — the detail path. */
  public boolean canSeeNames(Long teamId) {
    return !teamsWithNames(Set.of(teamId)).isEmpty();
  }
}
