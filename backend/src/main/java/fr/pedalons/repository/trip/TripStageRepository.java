package fr.pedalons.repository.trip;

import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.enums.Status;
import fr.pedalons.repository.common.BaseRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class TripStageRepository implements BaseRepository<TripStage> {

  public Optional<TripStage> findByIdAndTrip(Long stageId, Long tripId) {
    return find("id = ?1 and trip.id = ?2 and deleted = false", stageId, tripId)
        .firstResultOptional();
  }

  public Optional<TripStage> findBySlugAndTeam(String slug, Long teamId) {
    return find("slug = ?1 and team.id = ?2 and deleted = false", slug, teamId)
        .firstResultOptional();
  }

  /** Trip stages a user created, for the GDPR data export. */
  public List<TripStage> findByCreator(Long domainId, Long userId) {
    return list("createdBy.id = ?2 and team.domain.id = ?1 order by createdAt", domainId, userId);
  }

  /**
   * The weather planner's stages: live stages of published live trips, leaving within {@code [from,
   * to]} or under way at {@code from}, across all domains (the weather cache is global), in trip
   * then stage order.
   *
   * <p>Not over by {@code from} rather than leaving after it: a stage under way keeps its forecast to
   * its end (docs/LEDGER_*.md API-163), so its cells — a later group's included — stay fresh. The
   * end is the stored one; a row an older backend left without it counts until its departure only.
   */
  public List<TripStage> findForWeather(Instant from, Instant to) {
    return list(
        "from TripStage s where s.deleted = false and s.team.deleted = false"
            + " and s.trip.deleted = false and s.trip.status = ?1"
            + " and coalesce(s.endDateTime, s.dateTime) >= ?2 and s.dateTime <= ?3"
            + " order by s.trip.id, s.sortOrder, s.id",
        Status.PUBLISHED,
        from,
        to);
  }
}
