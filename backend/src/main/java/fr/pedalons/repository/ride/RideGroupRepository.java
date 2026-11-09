package fr.pedalons.repository.ride;

import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class RideGroupRepository implements BaseRepository<RideGroup> {

  public Optional<RideGroup> findByIdAndRide(Long groupId, Long rideId) {
    return find("id = ?1 and ride.id = ?2", groupId, rideId).firstResultOptional();
  }

  /** A group's name and start: what an agenda row says of the group the caller joined. */
  public record NameAndStart(String name, Instant startAt) {}

  /**
   * The names and starts of a set of groups, in one query.
   *
   * <p>Naming the group a user joined would otherwise mean reaching for {@code ride.getGroups()},
   * which loads every group and — through {@code getCurrentParticipants} — every participation of
   * every ride on the page. This projects the three scalars needed and hydrates nothing.
   *
   * <p>Group ids handed in here always come from the caller's own participations, themselves
   * restricted to rides a {@code PedalonsQuery} already returned, so this answers about nothing the
   * caller could not already see.
   *
   * @return group id → name and start, only for the ids that exist
   */
  public Map<Long, NameAndStart> findNamesAndStartsByIds(Collection<Long> groupIds) {
    if (groupIds.isEmpty()) {
      return Map.of();
    }
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select g.id, g.name, g.startAt from RideGroup g where g.id in (:ids)",
                Object[].class)
            .setParameter("ids", groupIds)
            .getResultList();
    Map<Long, NameAndStart> groups = new HashMap<>(rows.size());
    for (Object[] row : rows) {
      groups.put((Long) row[0], new NameAndStart((String) row[1], (Instant) row[2]));
    }
    return groups;
  }

  /**
   * The scalars a {@code RideGroupDto} needs, for a set of groups, in one query.
   *
   * <p>Used for the group the caller joined on each row of a publication list (docs/LEDGER_*.md
   * API-4). Loading the {@code RideGroup} entities instead would hydrate one group per row plus its
   * (eager) route — the entity budget of the {@code …QueryCountTest} classes would see it. This
   * projects the group, its route's figures and its leader through left joins and hydrates nothing.
   *
   * <p>The ids come from the caller's own participations among rides a {@code PedalonsQuery}
   * already returned: this widens nothing.
   */
  public List<GroupRow> findGroupRows(Collection<Long> groupIds) {
    if (groupIds.isEmpty()) {
      return List.of();
    }
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select g.id, g.ride.id, g.name, g.startAt, g.averageSpeed, g.maxParticipants,"
                    + " g.sortOrder, r.id, r.slug, r.distance, r.elevationGain,"
                    + " l.id, l.displayName, l.avatarUrl,"
                    // What reads the group's own time back from its start (docs/LEDGER_*.md
                    // API-60): an implicit join of this one statement.
                    + " g.ride.dateTime, g.ride.timezone"
                    + " from RideGroup g left join g.route r left join g.leader l"
                    + " where g.id in (:ids)",
                Object[].class)
            .setParameter("ids", groupIds)
            .getResultList();
    return rows.stream()
        .map(row ->
            new GroupRow(
                (Long) row[0],
                (Long) row[1],
                (String) row[2],
                EventTimezoneResolver.ownTime(
                    (Instant) row[14], (Instant) row[3], ZoneId.of((String) row[15])),
                (Float) row[4],
                (Integer) row[5],
                (Integer) row[6],
                (Long) row[7],
                (String) row[8],
                (Float) row[9],
                (Float) row[10],
                (Long) row[11],
                (String) row[12],
                (String) row[13],
                (Instant) row[3]))
        .toList();
  }

  /**
   * One group as {@link #findGroupRows} projects it; the route and leader parts may be null. {@code
   * time} is the group's own wall time, read back from {@code startAt}.
   */
  public record GroupRow(
      Long id,
      Long rideId,
      String name,
      @Nullable LocalTime time,
      @Nullable Float averageSpeed,
      @Nullable Integer maxParticipants,
      int sortOrder,
      @Nullable Long routeId,
      @Nullable String routeSlug,
      @Nullable Float distance,
      @Nullable Float elevationGain,
      @Nullable Long leaderId,
      @Nullable String leaderDisplayName,
      @Nullable String leaderAvatarUrl,
      Instant startAt) {}

  /** Ride groups a user created, for the GDPR data export. */
  public List<RideGroup> findByCreator(Long domainId, Long userId) {
    return list(
        "createdBy.id = ?2 and ride.team.domain.id = ?1 order by createdAt", domainId, userId);
  }
}
