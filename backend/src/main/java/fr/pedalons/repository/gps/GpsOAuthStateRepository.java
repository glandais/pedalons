package fr.pedalons.repository.gps;

import fr.pedalons.domain.gps.GpsOAuthState;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class GpsOAuthStateRepository implements PanacheRepository<GpsOAuthState> {

  public Optional<GpsOAuthState> findValidByState(String state) {
    return find("state = ?1 and expiresAt > instant", state).firstResultOptional();
  }

  /** In-flight GPS OAuth handshakes for a user on a domain — for the GDPR data export. */
  public List<GpsOAuthState> findByUser(Long domainId, Long userId) {
    return list("user.id = ?2 and domainId = ?1 order by createdAt", domainId, userId);
  }

  public long deleteExpiredStates() {
    return delete("expiresAt < instant");
  }
}
