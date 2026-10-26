package fr.pedalons.repository.ride;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.rides.response.RideGroupSummaryDto;
import fr.pedalons.dto.rides.response.RideListSummary;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * Bulk-loads the group/participant summary a ride list row needs.
 *
 * <p>Rendering a page of rides used to walk {@code ride.getGroups() -> group.getParticipations() ->
 * participation.getUser()} for every row, purely to produce a participant count and a five-avatar
 * preview. Batch fetching kept the <em>query</em> count flat, but the <em>row</em> count was not: a
 * page of 30 rides with 50 participants each hydrated ~1500 {@code RideParticipation} entities plus
 * their users into the persistence context, only to throw away all but 150 of them.
 *
 * <p>These two queries return scalars instead. Nothing enters the persistence context, so the cost
 * of a list page stops tracking the popularity of the rides on it.
 */
@ApplicationScoped
public class RideSummaryRepository {

  /** How many participant avatars a list row previews. */
  private static final int TOP_PARTICIPANTS = 5;

  @Inject EntityManager entityManager;

  /**
   * Returns a summary per ride id. Ride ids with no groups are absent from the map — callers fall
   * back to {@link RideListSummary#EMPTY}.
   *
   * @param namedRideIds the rides whose team's member names the caller may see (docs/LEDGER_*.md
   *     API-144): the others get their counts and an empty {@code topParticipants}, and the
   *     participants query is skipped when none is named
   */
  public Map<Long, RideListSummary> loadListSummaries(
      Collection<Long> rideIds, Collection<Long> namedRideIds) {
    if (rideIds.isEmpty()) {
      return Map.of();
    }
    Map<Long, List<PublicUserDto>> topParticipants = loadTopParticipants(namedRideIds);

    Map<Long, int[]> counts = new HashMap<>();
    Map<Long, Boolean> full = new HashMap<>();
    // Sum of the capacities; a ride with one uncapped group has no overall limit, marked by -1.
    Map<Long, Integer> capacity = new HashMap<>();
    Map<Long, List<RideGroupSummaryDto>> groups = new HashMap<>();
    Map<Long, RideListSummary.RouteMetrics> firstGroupRoute = new HashMap<>();
    // Rows come in (ride, sortOrder) order: the first routed group met is the first in sort order.
    for (Object[] row : loadGroupRows(rideIds)) {
      Long rideId = (Long) row[0];
      Long groupId = (Long) row[1];
      Integer maxParticipants = (Integer) row[2];
      int participants = ((Number) row[3]).intValue();
      String routeSlug = (String) row[8];

      int[] rideCounts = counts.computeIfAbsent(rideId, k -> new int[2]);
      rideCounts[0]++;
      rideCounts[1] += participants;
      // A ride is full only when none of its groups can take anyone else. One uncapped group is
      // enough to keep the whole ride open.
      boolean groupFull = maxParticipants != null && participants >= maxParticipants;
      full.merge(rideId, groupFull, Boolean::logicalAnd);
      capacity.merge(
          rideId,
          maxParticipants != null ? maxParticipants : -1,
          RideSummaryRepository::addCapacity);

      Float distance = routeSlug != null ? (Float) row[9] : null;
      Float elevationGain = routeSlug != null ? (Float) row[10] : null;
      groups
          .computeIfAbsent(rideId, k -> new ArrayList<>())
          .add(
              new RideGroupSummaryDto(
                  TsidUtils.toString(groupId),
                  (String) row[4],
                  EventTimezoneResolver.ownTime(
                      (Instant) row[13], (Instant) row[5], ZoneId.of((String) row[12])),
                  (Instant) row[5],
                  (Float) row[6],
                  participants,
                  maxParticipants,
                  groupFull,
                  routeSlug,
                  distance,
                  elevationGain,
                  (Integer) row[7]));
      if (routeSlug != null) {
        firstGroupRoute.putIfAbsent(
            rideId,
            new RideListSummary.RouteMetrics(distance, elevationGain, (SurfaceType) row[11]));
      }
    }

    Map<Long, RideListSummary> summaries = new HashMap<>();
    counts.forEach(
        (rideId, rideCounts) ->
            summaries.put(
                rideId,
                new RideListSummary(
                    rideCounts[0],
                    rideCounts[1],
                    full.getOrDefault(rideId, false),
                    toMaxParticipants(capacity.get(rideId)),
                    topParticipants.getOrDefault(rideId, List.of()),
                    List.copyOf(groups.getOrDefault(rideId, List.of())),
                    firstGroupRoute.get(rideId))));
    return summaries;
  }

  private static int addCapacity(int a, int b) {
    return a < 0 || b < 0 ? -1 : a + b;
  }

  private static @Nullable Integer toMaxParticipants(@Nullable Integer capacity) {
    return capacity == null || capacity < 0 ? null : capacity;
  }

  /**
   * One row per group, in {@code (ride, sortOrder)} order: {@code (rideId, groupId,
   * maxParticipants, participantCount, name, startAt, averageSpeed, sortOrder, routeSlug, distance,
   * elevationGain, surfaceType, rideZone, rideDateTime)} — the route columns null when the group has
   * none.
   *
   * <p>One row per group rather than per ride is what makes {@code full} and {@code
   * maxParticipants} computable: capacity is a per-group property, so a per-ride aggregate cannot
   * express "every group is at capacity" without a second pass. It is also what the per-group
   * summaries of a list row need. Rides have a handful of groups, so the extra rows are free — and
   * it is still one query for the whole page. The count is a correlated scalar subquery, so no
   * {@code GROUP BY} has to list every selected column.
   */
  private List<Object[]> loadGroupRows(Collection<Long> rideIds) {
    return entityManager
        .createQuery(
            "select g.ride.id, g.id, g.maxParticipants,"
                + " (select count(p.id) from RideParticipation p where p.rideGroup.id = g.id),"
                + " g.name, g.startAt, g.averageSpeed, g.sortOrder,"
                + " r.slug, r.distance, r.elevationGain, r.surfaceType,"
                // docs/LEDGER_*.md API-60: what reads the group's own time back from its start —
                // an implicit join of this same statement, still one per page.
                + " g.ride.timezone, g.ride.dateTime"
                + " from RideGroup g left join g.route r"
                + " where g.ride.id in (:rideIds)"
                + " order by g.ride.id, g.sortOrder, g.id",
            Object[].class)
        .setParameter("rideIds", rideIds)
        .getResultList();
  }

  /**
   * The first {@link #TOP_PARTICIPANTS} distinct users to register for each ride, ordered by
   * registration time across all of the ride's groups — the same rule the entity walk applied.
   *
   * <p>Selected as scalars, so a ride with a thousand participants costs a thousand cheap rows
   * rather than a thousand managed entities plus their users.
   */
  private Map<Long, List<PublicUserDto>> loadTopParticipants(Collection<Long> rideIds) {
    if (rideIds.isEmpty()) {
      return Map.of();
    }
    List<Object[]> rows =
        entityManager
            .createQuery(
                "select g.ride.id, u.id, u.displayName, u.avatarUrl "
                    + "from RideParticipation p join p.rideGroup g join p.user u "
                    + "where g.ride.id in (:rideIds) "
                    + "order by p.registeredAt",
                Object[].class)
            .setParameter("rideIds", rideIds)
            .getResultList();

    Map<Long, List<PublicUserDto>> byRide = new LinkedHashMap<>();
    Map<Long, Set<Long>> seenUserIds = new HashMap<>();
    for (Object[] row : rows) {
      Long rideId = (Long) row[0];
      List<PublicUserDto> top = byRide.computeIfAbsent(rideId, k -> new ArrayList<>());
      if (top.size() >= TOP_PARTICIPANTS) {
        continue;
      }
      Long userId = (Long) row[1];
      // A user registered in two groups of the same ride still appears once.
      if (!seenUserIds.computeIfAbsent(rideId, k -> new HashSet<>()).add(userId)) {
        continue;
      }
      top.add(new PublicUserDto(TsidUtils.toString(userId), (String) row[2], (String) row[3]));
    }
    return byRide;
  }
}
