package fr.pedalons.service.common;

import fr.pedalons.enums.TeamRole;
import java.util.Collection;
import java.util.Map;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * Who the caller is to the teams of one page: their user id, whether they are a platform admin, and
 * their role in each team of the page they belong to. Resolved once per page by {@link
 * MemberNamesVisibility#callerRoles} — never per row (docs/LEDGER_*.md API-176) — and read by the
 * member-name rule (API-144) and by the permissions block of every entity on the page.
 *
 * <p>A platform admin's roles are not looked up: every rule they meet answers yes for them, as
 * {@code SecurityVerifier} does, so the map stays empty and costs no query.
 *
 * @param roles team id → the caller's real role; a team they do not belong to is absent
 */
public record CallerRoles(@Nullable Long userId, boolean platformAdmin, Map<Long, TeamRole> roles) {

  /** An anonymous caller: no user, no role anywhere. */
  public static final CallerRoles ANONYMOUS = new CallerRoles(null, false, Map.of());

  public CallerRoles {
    roles = Map.copyOf(roles);
  }

  /** The caller's real role in this team, null when they are not a member. */
  public @Nullable TeamRole roleIn(Long teamId) {
    return roles.get(teamId);
  }

  /**
   * Whether the caller may be told the names of this team's members, comment on its content and see
   * who takes part: {@code member || platformAdmin}, the rule of {@code CommentAccessChecker} and
   * {@link MemberNamesVisibility} (docs/LEDGER_*.md API-144).
   */
  public boolean seesMembers(Long teamId) {
    return userId != null && (platformAdmin || roles.containsKey(teamId));
  }

  /** The teams, among these, whose member names the caller may see. */
  public Set<Long> teamsWithNames(Collection<Long> teamIds) {
    if (userId == null) {
      return Set.of();
    }
    if (platformAdmin) {
      return Set.copyOf(teamIds);
    }
    return Set.copyOf(teamIds.stream().filter(roles::containsKey).toList());
  }
}
