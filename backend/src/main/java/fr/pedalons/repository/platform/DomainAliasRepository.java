package fr.pedalons.repository.platform;

import fr.pedalons.domain.platform.DomainAlias;
import fr.pedalons.repository.common.BaseRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class DomainAliasRepository implements BaseRepository<DomainAlias> {

  public Optional<DomainAlias> findByHostname(String hostname) {
    return find("hostname = ?1 and active = true and deleted = false", hostname)
        .firstResultOptional();
  }

  public Optional<DomainAlias> findByIdOptional(Long id) {
    return find("id = ?1 and deleted = false", id).firstResultOptional();
  }

  public boolean existsByHostname(String hostname) {
    return count("hostname = ?1 and deleted = false", hostname) > 0;
  }

  public List<DomainAlias> listByDomain(Long domainId) {
    return list(
        "select da from DomainAlias da"
            + " left join fetch da.pinnedTeam"
            + " left join fetch da.domain"
            + " where da.domain.id = ?1 and da.deleted = false"
            + " order by da.hostname",
        domainId);
  }

  /** The active alias pinned on a team, if any — the site that team's members know. */
  public Optional<DomainAlias> findActiveByPinnedTeam(Long teamId) {
    return find(
            "pinnedTeam.id = ?1 and active = true and deleted = false order by createdAt", teamId)
        .firstResultOptional();
  }
}
