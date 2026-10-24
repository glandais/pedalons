package fr.pedalons.repository.team;

import fr.pedalons.domain.common.SearchClause;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.TeamSortBy;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.query.OrClause;
import fr.pedalons.repository.query.PedalonsQuery;
import fr.pedalons.repository.query.SimpleClause;
import fr.pedalons.service.team.request.MinRole;
import fr.pedalons.service.team.response.TeamAndRole;
import io.quarkus.hibernate.orm.panache.PanacheQuery;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.jspecify.annotations.Nullable;

@Slf4j
@ApplicationScoped
public class TeamRepository implements BaseRepository<Team> {

  public Optional<Team> findBySlugAndDomain(Long domainId, String slug) {
    return find("domain.id = ?1 and slug = ?2 and deleted = false", domainId, slug)
        .firstResultOptional();
  }

  /**
   * The team holding {@code slug} in the domain, trashed ones included: {@code uk_teams_domain_slug}
   * spans deleted teams too, so a trashed team still blocks its slug. For the biketeam migration,
   * which must tell a free slug from one a trashed team still holds.
   */
  public Optional<Team> findBySlugAndDomainIncludingDeleted(Long domainId, String slug) {
    return find("domain.id = ?1 and slug = ?2", domainId, slug).firstResultOptional();
  }

  /**
   * Whether a trashed team of the domain has a slug ending with {@code suffix}. For the biketeam
   * migration, whose set-aside slug ends with the job's id: a set-aside team is always trashed in
   * the transaction that renames it, so a live team renamed by hand cannot pass for one.
   */
  public boolean existsTrashedBySlugSuffixAndDomain(Long domainId, String suffix) {
    return count("domain.id = ?1 and deleted = true and slug like ?2", domainId, "%" + suffix) > 0;
  }

  public Optional<Team> findActiveById(Long id) {
    return find("id = ?1 and deleted = false", id).firstResultOptional();
  }

  /**
   * Whether {@code slug} is taken in this domain, soft-deleted teams included: {@code
   * uk_teams_domain_slug} covers them, and a platform admin can restore one with its slug.
   */
  public boolean existsBySlugAndDomain(Long domainId, String slug) {
    return count("domain.id = ?1 and slug = ?2", domainId, slug) > 0;
  }

  public boolean existsByDomain(Long domainId) {
    return count("domain.id = ?1 and deleted = false", domainId) > 0;
  }

  /**
   * The single active team of a single-team domain (at most one can exist there). Ordered by id for
   * a deterministic result should stale data leave more than one.
   */
  public Optional<Team> findFirstByDomain(Long domainId) {
    return find("domain.id = ?1 and deleted = false order by id", domainId).firstResultOptional();
  }

  public PedalonsPage<TeamAndRole> find(TeamQuery teamQuery) {
    return find(teamQuery, true);
  }

  /**
   * A PUBLIC_UNLISTED team is reachable by its URL but must never surface in a listing, so the
   * visibility clause is stricter when {@code list} is true.
   */
  private PedalonsPage<TeamAndRole> find(TeamQuery teamQuery, boolean list) {
    PedalonsQuery pedalonsQuery =
        new PedalonsQuery(
                "select t, ut.role,(SELECT COUNT(ut3) FROM UserTeam ut3 WHERE ut3.team.id ="
                    + " t.id) from Team t left join UserTeam ut on ut.team.id ="
                    + " t.id AND ut.user.id = :userId WHERE")
            .and("t.domain.id = :domainId", Map.of("domainId", teamQuery.domainId()))
            // Never a trashed team, platform admin included (docs/LEDGER_*.md API-137): restoring
            // one is the administration console's job (AdminTeamService), which has its own query.
            .and("t.deleted = false", Map.of())
            .order(orderClause(teamQuery));
    if (teamQuery.pinnedTeamId() != null) {
      // A pinned alias host lists only its team, even for platform admins — a site scope like
      // domain.
      pedalonsQuery.and("t.id = :pinnedTeamId", Map.of("pinnedTeamId", teamQuery.pinnedTeamId()));
    }
    if (teamQuery.joinable() != null) {
      // Team discovery: "which teams can I ask to join?". ANDed with the visibility clauses below,
      // never in place of them — a team that is invisible to the caller stays invisible whatever
      // its joinable flag says.
      pedalonsQuery.and("t.joinable = :joinable", Map.of("joinable", teamQuery.joinable()));
    }
    pedalonsQuery.addParam("userId", teamQuery.userId());
    if (teamQuery.id() != null) {
      pedalonsQuery.and("t.id = :id", Map.of("id", teamQuery.id()));
    }
    pedalonsQuery =
        SearchClause.addSearch(
            pedalonsQuery, Set.of("t.name", "t.aboutPage.markdown"), teamQuery.search());
    if (teamQuery.userId() != null) {
      MinRole minRole = teamQuery.minRole();
      if (minRole != null) {
        // "My teams": the caller's real memberships, whoever they are. A platform admin is a
        // member of the teams they joined, not of every team (docs/LEDGER_*.md API-137).
        pedalonsQuery.and("ut.role in (:userRoles)", Map.of("userRoles", minRole.acceptedRoles()));
      } else if (!teamQuery.platformAdmin()) {
        OrClause or = new OrClause();

        or.add(visibleTeam(list));
        or.add(new SimpleClause("ut IS NOT NULL", Map.of()));

        pedalonsQuery.and(or);
      }
      // Otherwise a platform admin's directory: every live team of the domain, private and
      // unlisted ones included.
    } else {
      pedalonsQuery.and(visibleTeam(list));
    }
    String stringQuery = pedalonsQuery.getStringQuery();
    Map<String, @Nullable Object> params = pedalonsQuery.getParams();
    log.debug("{} {}", stringQuery, params);
    PanacheQuery<TeamAndRole> panacheQuery = find(stringQuery, params).project(TeamAndRole.class);
    return getPage(panacheQuery, teamQuery.page(), teamQuery.size());
  }

  /**
   * The requested key, then the team id in the same direction: two teams with the same name or the
   * same member count must still come back in one fixed order, or offset pagination repeats one and
   * skips the other.
   */
  private static String orderClause(TeamQuery teamQuery) {
    TeamSortBy sortBy = teamQuery.sortBy();
    if (sortBy == null) {
      return "t.name asc, t.id asc";
    }
    String dir =
        (teamQuery.sortDir() != null ? teamQuery.sortDir() : SortDirection.DESC)
            .name()
            .toLowerCase();
    return sortBy.getField() + " " + dir + ", t.id " + dir;
  }

  private static SimpleClause visibleTeam(boolean list) {
    return list
        ? new SimpleClause("t.visibility = :visibility", Map.of("visibility", Visibility.PUBLIC))
        : new SimpleClause("t.visibility <> :visibility", Map.of("visibility", Visibility.TEAM));
  }

  public Optional<TeamAndRole> findOne(
      Long domainId, Long id, @Nullable Long userId, boolean platformAdmin) {
    PedalonsPage<TeamAndRole> page =
        find(
            TeamQuery.builder()
                .domainId(domainId)
                .userId(userId)
                .id(id)
                .page(0)
                .size(1)
                .platformAdmin(platformAdmin)
                .build(),
            false);
    if (page.items().isEmpty()) {
      return Optional.empty();
    } else {
      return Optional.of(page.items().getFirst());
    }
  }

  /** Teams a user created, for the GDPR data export. */
  public List<Team> findByCreator(Long domainId, Long userId) {
    return list("domain.id = ?1 and createdBy.id = ?2 order by createdAt", domainId, userId);
  }
}
