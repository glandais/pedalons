package fr.pedalons.repository.gps;

import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.enums.GpsServiceType;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class GpsServiceConnectionRepository implements PanacheRepository<GpsServiceConnection> {

  public Optional<GpsServiceConnection> findByUserAndService(
      Long userId, GpsServiceType serviceType) {
    return find("user.id = ?1 and serviceType = ?2", userId, serviceType).firstResultOptional();
  }

  public List<GpsServiceConnection> findByUser(Long userId) {
    return find("user.id = ?1", userId).list();
  }

  /**
   * The route sync stops for this connection until a reconnection (docs/LEDGER_*.md API-120). A
   * bulk update, not a version bump: the worker writes it while an endpoint may hold the entity.
   */
  public int markSyncReconnectRequired(Long connectionId, Instant now) {
    return update(
        "syncReconnectRequiredAt = ?2 where id = ?1 and syncReconnectRequiredAt is null",
        connectionId,
        now);
  }

  /**
   * A reconnection lifts every stop of the route sync: fresh tokens, a fresh consent. A bulk update
   * like the two that set them — the entity never writes these columns.
   */
  public int clearSyncBlocks(Long connectionId) {
    return update(
        "syncReconnectRequiredAt = null, syncPausedUntil = null where id = ?1", connectionId);
  }

  /** After a 429: no sync call for this connection before {@code until}. */
  public int pauseSync(Long connectionId, Instant until) {
    return update(
        "syncPausedUntil = ?2 where id = ?1"
            + " and (syncPausedUntil is null or syncPausedUntil < ?2)",
        connectionId,
        until);
  }
}
