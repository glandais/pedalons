package fr.pedalons.repository.trip;

import fr.pedalons.domain.trip.Trip;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamEntityType;
import fr.pedalons.repository.common.TeamEntityQueryBasic;
import fr.pedalons.repository.common.TeamEntityRepository;
import fr.pedalons.repository.query.PedalonsQuery;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class TripRepository implements TeamEntityRepository<Trip, TeamEntityQueryBasic> {
  @Override
  public TeamEntityType getEntityType() {
    return TeamEntityType.TRIP;
  }

  @Override
  public EntityType getAllEntityType() {
    return EntityType.TRIP;
  }

  @Override
  public TeamEntityQueryBasic getQuerySlug(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      String slug,
      boolean includeDeleted,
      boolean platformAdmin) {
    return TeamEntityQueryBasic.builder()
        .domainId(domainId)
        .teamIds(Set.of(teamId))
        .userId(userId)
        .slug(slug)
        .includeDeleted(includeDeleted)
        .platformAdmin(platformAdmin)
        .build();
  }

  @Override
  public TeamEntityQueryBasic getQueryId(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      Long id,
      boolean includeDeleted,
      boolean platformAdmin) {
    return TeamEntityQueryBasic.builder()
        .domainId(domainId)
        .teamIds(Set.of(teamId))
        .userId(userId)
        .id(id)
        .includeDeleted(includeDeleted)
        .platformAdmin(platformAdmin)
        .build();
  }

  /**
   * Find the trips that reference a route, either directly ({@code trip.route}) or through one of
   * their stages ({@code stage.route}). The {@code query} carries the domain/visibility filters, so
   * only trips the caller may see are returned. Each trip yields at most one row, so the result is
   * already deduplicated.
   */
  public List<Trip> findByRouteId(TeamEntityQueryBasic query, Long routeId) {
    QueryShape shape = new QueryShape("te", getEntityType().getTypeName() + " te", true);
    PedalonsQuery pedalonsQuery = getPedalonsQuery(query, true, shape);
    pedalonsQuery.and(
        "(te.route.id = :routeId OR EXISTS "
            + "(select 1 from TripStage s "
            + "where s.trip = te and s.deleted = false and s.route.id = :routeId))",
        Map.of("routeId", routeId));
    return findAll(pedalonsQuery);
  }

  /**
   * The weather planner's trips without any live stage — each is one leg, its own route at its own
   * time: published live trips leaving within {@code [from, to]} or under way at {@code from},
   * across all domains (the weather cache is global). Not over rather than leaving after, as
   * {@code TripStageRepository#findForWeather} (docs/LEDGER_*.md API-170).
   */
  public List<Trip> findStagelessForWeather(Instant from, Instant to) {
    return list(
        "from Trip t where t.status = ?1 and t.deleted = false and t.team.deleted = false"
            + " and coalesce(t.endDateTime, t.dateTime) >= ?2 and t.dateTime <= ?3"
            + " and not exists (select 1 from TripStage s where s.trip = t and s.deleted = false)",
        Status.PUBLISHED,
        from,
        to);
  }
}
