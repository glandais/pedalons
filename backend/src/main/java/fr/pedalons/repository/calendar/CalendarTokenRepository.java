package fr.pedalons.repository.calendar;

import fr.pedalons.domain.calendar.CalendarToken;
import fr.pedalons.repository.common.BaseRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.Optional;

@ApplicationScoped
public class CalendarTokenRepository implements BaseRepository<CalendarToken> {

  public Optional<CalendarToken> findByToken(String token) {
    return find("token = ?1", token).firstResultOptional();
  }

  public Optional<CalendarToken> findByUserId(Long userId) {
    return find("user.id = ?1", userId).firstResultOptional();
  }

  /**
   * Records a fetch without writing the versioned row: two calendar apps polling the same feed at
   * once must not fail on the optimistic lock.
   */
  public int markUsed(Long tokenId) {
    return update("lastUsedAt = instant where id = ?1", tokenId);
  }

  /** Tokens silent since {@code cutoff}: dead already, deleted for good (docs/LEDGER_*.md SEC-17). */
  public long deleteInactiveSince(Instant cutoff) {
    return delete("coalesce(lastUsedAt, createdAt) < ?1", cutoff);
  }
}
