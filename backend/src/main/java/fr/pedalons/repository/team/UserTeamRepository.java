package fr.pedalons.repository.team;

import fr.pedalons.common.LikePatterns;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.enums.MemberSortBy;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.TeamTier;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.query.OrClause;
import fr.pedalons.repository.query.PedalonsQuery;
import fr.pedalons.repository.query.SimpleClause;
import fr.pedalons.service.migration.BiketeamMigrationService;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class UserTeamRepository implements BaseRepository<UserTeam> {

  public List<UserTeam> findByUserId(Long userId) {
    return find("user.id = ?1 and user.deleted = false and team.deleted = false", userId).list();
  }

  /**
   * The user's live teams on one domain, team loaded in the same query, in name order — the profile
   * overview's « Mes équipes ». One query whatever the number of teams.
   */
  public List<UserTeam> findByUserAndDomainWithTeam(Long userId, Long domainId) {
    return getEntityManager()
        .createQuery(
            "select ut from UserTeam ut join fetch ut.team t"
                + " where ut.user.id = :userId and t.domain.id = :domainId and t.deleted = false"
                + " order by lower(t.name), t.id",
            UserTeam.class)
        .setParameter("userId", userId)
        .setParameter("domainId", domainId)
        .getResultList();
  }

  /**
   * @param searchEmail whether {@code search} may also match a member's e-mail address. Only ever
   *     true for an administrator. The address is in no response, but a query that matches on it
   *     turns this endpoint into an oracle: type any address, see whether a row comes back. That is
   *     what the caller is being denied here, not the sight of the member.
   */
  public PedalonsPage<UserTeam> findByTeam(
      Long teamId, int page, int size, String search, TeamRole role, boolean searchEmail) {
    return findByTeam(teamId, page, size, search, role, searchEmail, null, null);
  }

  /**
   * @param sortBy null keeps the previous, unspecified order; otherwise the membership id ends the
   *     key so pages never overlap
   * @param sortDir null is descending — newest first for {@link MemberSortBy#JOINED_AT}
   */
  public PedalonsPage<UserTeam> findByTeam(
      Long teamId,
      int page,
      int size,
      @Nullable String search,
      @Nullable TeamRole role,
      boolean searchEmail,
      @Nullable MemberSortBy sortBy,
      @Nullable SortDirection sortDir) {
    PedalonsQuery pedalonsQuery =
        new PedalonsQuery()
            .and("team.id = :teamId", Map.of("teamId", teamId))
            .and("user.deleted = false", Map.of())
            .and("team.deleted = false", Map.of());
    if (search != null && !search.isBlank()) {
      String searchParam = LikePatterns.contains(search.toLowerCase());
      OrClause orClause = new OrClause();
      orClause.add(
          new SimpleClause(
              "LOWER(user.displayName) LIKE :search " + LikePatterns.ESCAPE,
              Map.of("search", searchParam)));
      if (searchEmail) {
        orClause.add(
            new SimpleClause(
                "LOWER(user.email) LIKE :search " + LikePatterns.ESCAPE,
                Map.of("search", searchParam)));
      }
      pedalonsQuery.and(orClause);
    }
    if (role != null) {
      pedalonsQuery.and("role = :role", Map.of("role", role));
    }
    if (sortBy != null) {
      String dir = (sortDir != null ? sortDir : SortDirection.DESC).name().toLowerCase();
      pedalonsQuery.order(sortBy.getField() + " " + dir + ", id " + dir);
    }
    return getPage(pedalonsQuery, page, size);
  }

  /**
   * Returns the number of non-deleted teams where the given user holds an ADMIN role within the
   * specified domain. Used to enforce the {@code MAX_ADMIN_TEAMS_PER_USER} creation limit for
   * non-platform-admin users.
   */
  public long countAdminTeamsByUserAndDomain(Long userId, Long domainId) {
    return getEntityManager()
        .createQuery(
            "SELECT COUNT(ut) FROM UserTeam ut "
                + "JOIN ut.team t "
                + "WHERE ut.user.id = :userId AND t.domain.id = :domainId "
                + "AND ut.role = :role "
                + "AND t.deleted = false",
            Long.class)
        .setParameter("userId", userId)
        .setParameter("domainId", domainId)
        .setParameter("role", TeamRole.ADMIN)
        .getSingleResult();
  }

  /**
   * The live teams this user is the only admin of while other members remain — the teams the
   * erasure of their account would leave with members and nobody to run them. Ordered by name, for
   * a list the member reads.
   */
  public List<Team> findTeamsLeftWithoutAdmin(Long userId, Long domainId) {
    return getEntityManager()
        .createQuery(
            "SELECT t FROM UserTeam ut JOIN ut.team t "
                + "WHERE ut.user.id = :userId AND ut.role = :admin AND t.deleted = false "
                + "AND t.domain.id = :domainId "
                + "AND NOT EXISTS (SELECT 1 FROM UserTeam o WHERE o.team = t "
                + "  AND o.user.id <> :userId AND o.role = :admin AND o.user.deleted = false) "
                + "AND EXISTS (SELECT 1 FROM UserTeam m WHERE m.team = t "
                + "  AND m.user.id <> :userId AND m.user.deleted = false) "
                + "ORDER BY t.name",
            Team.class)
        .setParameter("userId", userId)
        .setParameter("domainId", domainId)
        .setParameter("admin", TeamRole.ADMIN)
        .getResultList();
  }

  /**
   * The live teams this user administers and is the only live member of — the teams the erasure of
   * their account deletes with it, since nobody would be left in them. Ordered by name.
   */
  public List<Team> findTeamsAdministeredAlone(Long userId, Long domainId) {
    return getEntityManager()
        .createQuery(
            "SELECT t FROM UserTeam ut JOIN ut.team t "
                + "WHERE ut.user.id = :userId AND ut.role = :admin AND t.deleted = false "
                + "AND t.domain.id = :domainId "
                + "AND NOT EXISTS (SELECT 1 FROM UserTeam m WHERE m.team = t "
                + "  AND m.user.id <> :userId AND m.user.deleted = false) "
                + "ORDER BY t.name",
            Team.class)
        .setParameter("userId", userId)
        .setParameter("domainId", domainId)
        .setParameter("admin", TeamRole.ADMIN)
        .getResultList();
  }

  /**
   * The live teams this user is the only admin of — whether or not others belong to them — that
   * came from biketeam: a {@code TEAM} row of {@code biketeam_migration_map} points at them (live
   * migration or legacy import alike). Their old biketeam addresses redirect to them, so the
   * erasure of the account must not trash them. One query for all the user's teams. Ordered by name.
   */
  public List<Team> findMigratedTeamsAdministeredAlone(Long userId, Long domainId) {
    return getEntityManager()
        .createQuery(
            "SELECT t FROM UserTeam ut JOIN ut.team t "
                + "WHERE ut.user.id = :userId AND ut.role = :admin AND t.deleted = false "
                + "AND t.domain.id = :domainId "
                + "AND NOT EXISTS (SELECT 1 FROM UserTeam o WHERE o.team = t "
                + "  AND o.user.id <> :userId AND o.role = :admin AND o.user.deleted = false) "
                + "AND EXISTS (SELECT 1 FROM BiketeamMigrationMap bm "
                + "  WHERE bm.entityType = :teamType AND bm.triblyId = t.id) "
                + "ORDER BY t.name",
            Team.class)
        .setParameter("userId", userId)
        .setParameter("domainId", domainId)
        .setParameter("admin", TeamRole.ADMIN)
        .setParameter("teamType", BiketeamMigrationService.T_TEAM)
        .getResultList();
  }

  public long countAdminsByTeam(Long teamId) {
    return count(
        "team.id = ?1 and role = ?2 and " + "team.deleted = false and user.deleted = false",
        teamId,
        TeamRole.ADMIN);
  }

  /**
   * The team's live members, whatever their role — what the free plan's member cap is compared to
   * (docs/LEDGER_*.md BILL-10). An account soft-deleted since is not one: its membership no longer
   * shows in any roster.
   */
  public long countActiveMembers(Long teamId) {
    return count("team.id = ?1 and user.deleted = false", teamId);
  }

  /**
   * Whether the user is a member, whatever their role, of a live team of {@code tier} in the domain
   * — for the personal planner quota, which a member of an unlocked team does not have
   * (docs/LEDGER_*.md BILL-10).
   */
  public boolean existsMembershipInTier(Long userId, Long domainId, TeamTier tier) {
    return count(
            "user.id = ?1 and team.domain.id = ?2 and team.tier = ?3 and team.deleted = false",
            userId,
            domainId,
            tier)
        > 0;
  }

  public Optional<UserTeam> findByUserAndTeam(Long userId, Long teamId) {
    return getEntityManager()
        .createQuery(
            "SELECT ut FROM UserTeam ut "
                + "JOIN ut.team t "
                + "JOIN ut.user u "
                + "WHERE ut.user.id = :userId AND t.id = :teamId "
                + "AND t.deleted = false "
                + "AND u.deleted = false",
            UserTeam.class)
        .setParameter("userId", userId)
        .setParameter("teamId", teamId)
        .getResultStream()
        .findFirst();
  }

  /**
   * The user's role in each of these teams they belong to — one query for a whole page, same
   * live-only rules as {@link #findMemberTeamIds}. A team the user is not a member of is absent.
   * What a page's permissions block and its member names both read (docs/LEDGER_*.md API-176): the
   * key set is exactly {@link #findMemberTeamIds}, so one query answers both.
   */
  public Map<Long, TeamRole> findMemberRoles(Long userId, Long domainId, Collection<Long> teamIds) {
    if (teamIds.isEmpty()) {
      return Map.of();
    }
    Map<Long, TeamRole> roles = new java.util.HashMap<>();
    for (Object[] row :
        getEntityManager()
            .createQuery(
                "SELECT t.id, ut.role FROM UserTeam ut "
                    + "JOIN ut.team t "
                    + "JOIN ut.user u "
                    + "WHERE ut.user.id = :userId AND t.id IN (:teamIds) "
                    + "AND t.domain.id = :domainId "
                    + "AND t.deleted = false "
                    + "AND u.deleted = false",
                Object[].class)
            .setParameter("userId", userId)
            .setParameter("teamIds", teamIds)
            .setParameter("domainId", domainId)
            .getResultList()) {
      roles.put((Long) row[0], (TeamRole) row[1]);
    }
    return roles;
  }

  /**
   * Which of these teams the user is a member of — one query for a whole page.
   *
   * <p>Same rule as {@link #findByUserAndTeam} (any role counts, neither side soft-deleted), asked
   * for many teams at once. A page of publications spans a handful of teams at most, so a per-row
   * {@code findByUserAndTeam} would be a per-row round-trip for an answer that repeats.
   *
   * @param domainId re-stated rather than inferred from the ids: this is the clause that keeps a
   *     membership in one domain from vouching for a team in another
   */
  public Set<Long> findMemberTeamIds(Long userId, Long domainId, Collection<Long> teamIds) {
    if (teamIds.isEmpty()) {
      return Set.of();
    }
    return new HashSet<>(
        getEntityManager()
            .createQuery(
                "SELECT t.id FROM UserTeam ut "
                    + "JOIN ut.team t "
                    + "JOIN ut.user u "
                    + "WHERE ut.user.id = :userId AND t.id IN (:teamIds) "
                    + "AND t.domain.id = :domainId "
                    + "AND t.deleted = false "
                    + "AND u.deleted = false",
                Long.class)
            .setParameter("userId", userId)
            .setParameter("teamIds", teamIds)
            .setParameter("domainId", domainId)
            .getResultList());
  }

  /**
   * Which of these teams the user administers — one query for a whole page, same live-only rules as
   * {@link #findMemberTeamIds}. docs/LEDGER_*.md API-6: an administrator sees who wrote a post
   * signed by the team.
   */
  public Set<Long> findAdminTeamIds(Long userId, Long domainId, Collection<Long> teamIds) {
    if (teamIds.isEmpty()) {
      return Set.of();
    }
    return new HashSet<>(
        getEntityManager()
            .createQuery(
                "SELECT t.id FROM UserTeam ut "
                    + "JOIN ut.team t "
                    + "JOIN ut.user u "
                    + "WHERE ut.user.id = :userId AND t.id IN (:teamIds) "
                    + "AND ut.role = :role "
                    + "AND t.domain.id = :domainId "
                    + "AND t.deleted = false "
                    + "AND u.deleted = false",
                Long.class)
            .setParameter("userId", userId)
            .setParameter("teamIds", teamIds)
            .setParameter("role", TeamRole.ADMIN)
            .setParameter("domainId", domainId)
            .getResultList());
  }

  /**
   * Every live member of a team, users loaded in the same query — the audience of a "published"
   * notification. Unpaginated on purpose: the caller fans out to all of them.
   */
  public List<User> findActiveMemberUsers(Long teamId) {
    return getEntityManager()
        .createQuery(
            "select u from UserTeam ut join ut.user u"
                + " where ut.team.id = :teamId and u.deleted = false",
            User.class)
        .setParameter("teamId", teamId)
        .getResultList();
  }

  /**
   * The live organizers and administrators of a team, users loaded in the same query — who hears of
   * a report filed in it.
   */
  public List<UserTeam> findModerators(Long teamId) {
    return getEntityManager()
        .createQuery(
            "select ut from UserTeam ut join fetch ut.user u"
                + " where ut.team.id = :teamId and u.deleted = false and ut.role in (:roles)",
            UserTeam.class)
        .setParameter("teamId", teamId)
        .setParameter("roles", List.of(TeamRole.ORGANIZER, TeamRole.ADMIN))
        .getResultList();
  }
}
