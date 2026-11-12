package fr.pedalons.repository.limits;

import fr.pedalons.domain.limits.PlannerSave;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;

@ApplicationScoped
public class PlannerSaveRepository implements PanacheRepository<PlannerSave> {

  /** The saves of a team since {@code since}. */
  public long countTeamSince(Long teamId, Instant since) {
    return count("teamId = ?1 and savedAt >= ?2", teamId, since);
  }

  /** The saves of a user in the GPX tools (no team) since {@code since}, in their domain. */
  public long countPersonalSince(Long domainId, Long userId, Instant since) {
    return count(
        "domainId = ?1 and userId = ?2 and teamId is null and savedAt >= ?3",
        domainId,
        userId,
        since);
  }

  /**
   * Takes the transaction-scoped advisory lock of one quota, waiting for whoever holds it: the count
   * and the insert of two concurrent saves are then served one after the other. Released when the
   * caller's transaction ends.
   */
  public void lockUntilEndOfTransaction(String key) {
    getEntityManager()
        .createNativeQuery("select 1 from pg_advisory_xact_lock(hashtextextended(:key, 0))")
        .setParameter("key", key)
        .getSingleResult();
  }

  /** Deletes the rows saved before {@code before}; idempotent. */
  public long purgeBefore(Instant before) {
    return delete("savedAt < ?1", before);
  }
}
