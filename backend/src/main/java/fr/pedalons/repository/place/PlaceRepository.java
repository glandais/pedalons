package fr.pedalons.repository.place;

import fr.pedalons.common.LikePatterns;
import fr.pedalons.domain.place.Place;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.query.OrClause;
import fr.pedalons.repository.query.PedalonsQuery;
import fr.pedalons.repository.query.SimpleClause;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@ApplicationScoped
public class PlaceRepository implements BaseRepository<Place> {

  public Optional<Place> findByIdAndTeam(Long id, Long teamId) {
    return find("id = ?1 AND team.id = ?2", id, teamId).firstResultOptional();
  }

  public PedalonsPage<Place> findByTeam(
      Long teamId, int page, int size, String search, boolean filterStart, boolean filterEnd) {
    PedalonsQuery pedalonsQuery =
        new PedalonsQuery()
            .and("team.id = :teamId", Map.of("teamId", teamId))
            // Name order, then the id: without an ORDER BY, offset pagination may repeat or skip
            // a place between two pages.
            .order("lower(name) asc, id asc");
    if (search != null && !search.isBlank()) {
      String searchParam = LikePatterns.contains(search.toLowerCase());
      OrClause orClause = new OrClause();
      orClause.add(
          new SimpleClause(
              "LOWER(name) LIKE :search " + LikePatterns.ESCAPE, Map.of("search", searchParam)));
      orClause.add(
          new SimpleClause(
              "LOWER(address) LIKE :search " + LikePatterns.ESCAPE, Map.of("search", searchParam)));
      pedalonsQuery.and(orClause);
    }
    if (filterStart) {
      pedalonsQuery.and("startPlace = true", Map.of());
    }
    if (filterEnd) {
      pedalonsQuery.and("endPlace = true", Map.of());
    }
    return getPage(pedalonsQuery, page, size);
  }

  /** Places a user created, for the GDPR data export. */
  public List<Place> findByCreator(Long domainId, Long userId) {
    return list("createdBy.id = ?2 and team.domain.id = ?1 order by createdAt", domainId, userId);
  }
}
