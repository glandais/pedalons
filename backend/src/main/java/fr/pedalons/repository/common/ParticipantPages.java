package fr.pedalons.repository.common;

import fr.pedalons.common.LikePatterns;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import jakarta.persistence.EntityManager;
import jakarta.persistence.TypedQuery;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * The paginated, searchable participant list shared by rides and trips (docs/LEDGER_*.md API-12).
 *
 * <p>Selects the users themselves rather than the participation rows, so a page hydrates one entity
 * per row — and orders by registration, the same order as the preview the details embed.
 */
public final class ParticipantPages {

  private ParticipantPages() {}

  /**
   * @param entity the participation entity, aliased {@code p} in {@code where}
   * @param where the clause that selects one ride, group or trip; the search is appended to it
   */
  public static PedalonsPage<User> find(
      EntityManager em,
      String entity,
      StringBuilder where,
      Map<String, Object> params,
      @Nullable String search,
      int page,
      int size) {
    if (search != null && !search.isBlank()) {
      where.append(" and lower(u.displayName) like :search ").append(LikePatterns.ESCAPE);
      params.put("search", LikePatterns.contains(search.trim().toLowerCase()));
    }
    String from = " from " + entity + " p join p.user u" + where;
    int pageSize = BaseRepository.effectivePageSize(size);

    TypedQuery<User> pageQuery =
        em.createQuery("select u" + from + " order by p.registeredAt, p.id", User.class);
    TypedQuery<Long> countQuery = em.createQuery("select count(p)" + from, Long.class);
    params.forEach((name, value) -> {
      pageQuery.setParameter(name, value);
      countQuery.setParameter(name, value);
    });
    java.util.List<User> users =
        pageQuery
            .setFirstResult(Math.max(page, 0) * pageSize)
            .setMaxResults(pageSize)
            .getResultList();
    return new PedalonsPage<>(users, countQuery.getSingleResult());
  }
}
