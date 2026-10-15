package fr.pedalons.repository.ridetemplate;

import fr.pedalons.common.LikePatterns;
import fr.pedalons.domain.ridetemplate.RideTemplate;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.query.PedalonsQuery;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class RideTemplateRepository implements BaseRepository<RideTemplate> {

  public Optional<RideTemplate> findByTeamAndSlug(Long teamId, String slug) {
    return find("team.id = ?1 AND slug = ?2", teamId, slug).firstResultOptional();
  }

  public boolean existsByTeamAndSlug(Long teamId, String slug) {
    return count("team.id = ?1 AND slug = ?2", teamId, slug) > 0;
  }

  public PedalonsPage<RideTemplate> findByTeam(
      Long teamId, @Nullable String search, int page, int size) {
    PedalonsQuery pedalonsQuery =
        new PedalonsQuery().and("team.id = :teamId", Map.of("teamId", teamId)).order("name ASC");

    if (search != null && !search.isBlank()) {
      pedalonsQuery.and(
          "LOWER(name) LIKE :search " + LikePatterns.ESCAPE,
          Map.of("search", LikePatterns.contains(search.toLowerCase())));
    }

    return getPage(pedalonsQuery, page, size);
  }

  /**
   * Raises the template's next number by one, in one statement so that two rides created at once
   * from it take two numbers. A template of another team, gone, or numbering nothing is left alone.
   */
  public void raiseNextNumber(Long teamId, Long templateId) {
    update(
        "nextNumber = nextNumber + 1 where id = ?1 and team.id = ?2 and nextNumber is not null",
        templateId,
        teamId);
  }

  /** Ride templates a user created, for the GDPR data export. */
  public List<RideTemplate> findByCreator(Long domainId, Long userId) {
    return list("createdBy.id = ?2 and team.domain.id = ?1 order by createdAt", domainId, userId);
  }
}
