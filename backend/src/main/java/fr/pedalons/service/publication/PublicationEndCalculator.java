package fr.pedalons.service.publication;

import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.service.weather.RideWeatherCalculator;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.jspecify.annotations.Nullable;

/**
 * When a ride or a trip is over — the one place that says it (docs/LEDGER_*.md API-85, plan {@code
 * docs/plans/archive/2026-10-06-team-agenda.md} §3.1).
 *
 * <ul>
 *   <li><b>Ride</b>: the latest of its groups, each one its departure (its stored {@code
 *       start_at}) plus the distance of its route (the
 *       group's, else the ride's) at its {@code averageSpeed}. A group with no speed or no route, and
 *       a ride with no group, take the departure plus {@link #DEFAULT_DURATION}.
 *   <li><b>Trip</b>: the same rule applied to its live stages — each stage's own end is stored too
 *       — the latest of them; a trip with no stage takes its departure plus {@link
 *       #DEFAULT_DURATION}.
 *   <li>Anything else (a post, a route…): no end, {@code null}.
 * </ul>
 *
 * <p>The value is stored ({@code team_entities.end_date_time}) so the lists can filter and sort on
 * it. That is its price: every write that changes a departure, a group, a stage or a route's length
 * — deleting or restoring the route included — must call {@link #refresh} — a forgotten one shows
 * an outing as past or upcoming by mistake. The callers are {@code RideService}, {@code
 * TripService}, {@code PublicationPublishScheduler}, {@code RouteService}, {@code
 * ModerationService} and {@code BiketeamMigrationService} (the last three through {@link
 * #refreshUsersOf}) and, through the first two, the biketeam import;
 * {@link PublicationEndBackfill} fills what an older backend left null.
 */
@ApplicationScoped
public class PublicationEndCalculator {

  /**
   * How long an outing lasts when nothing tells — a group with no speed or no route, a ride with no
   * group, a trip with no stage: 3 hours (decision of 6 October 2026, plan §7). Also what a reader
   * adds to {@code dateTime} when {@code endDateTime} is still null.
   */
  public static final Duration DEFAULT_DURATION = Duration.ofHours(3);

  @Inject EntityManager entityManager;

  /**
   * The end to read for any team entity: its stored end, else its departure plus {@link
   * #DEFAULT_DURATION} — the {@code coalesce} of the list queries, in Java.
   */
  public static Instant effectiveEnd(TeamEntity entity) {
    Instant end = entity.getEndDateTime();
    return end != null ? end : entity.getDateTime().plus(DEFAULT_DURATION);
  }

  /**
   * Computes and stores the end of a ride or a trip (and of the trip's live stages); does nothing
   * for any other entity. Writes only what changed, so a no-op refresh bumps no version.
   *
   * @return whether anything was written
   */
  public boolean refresh(TeamEntity entity) {
    return switch (entity) {
      case Ride ride -> set(ride, rideEnd(ride));
      case Trip trip -> {
        TripEnds ends = tripEnds(trip);
        boolean changed = false;
        for (Map.Entry<TripStage, Instant> stage : ends.stages().entrySet()) {
          changed |= set(stage.getKey(), stage.getValue());
        }
        changed |= set(trip, ends.end());
        yield changed;
      }
      default -> false;
    };
  }

  /**
   * Refreshes every ride and trip whose end depends on {@code route}: rides that point at it
   * directly or through a group, trips that have a stage on it. Called when the route's track (so
   * its distance) is replaced, and when the route is deleted or restored — a deleted route counts
   * as none (docs/LEDGER_*.md API-87). Deleted rides and trips too: an undelete brings them back as
   * they were.
   */
  public void refreshUsersOf(Route route) {
    List<Ride> rides =
        entityManager
            .createQuery(
                "select distinct r from Ride r where r.route.id = :routeId or exists (select 1"
                    + " from RideGroup g where g.ride.id = r.id and g.route.id = :routeId)",
                Ride.class)
            .setParameter("routeId", route.getId())
            .getResultList();
    rides.forEach(this::refresh);
    List<Trip> trips =
        entityManager
            .createQuery(
                "select distinct t from Trip t where exists (select 1 from TripStage s where"
                    + " s.trip.id = t.id and s.route.id = :routeId)",
                Trip.class)
            .setParameter("routeId", route.getId())
            .getResultList();
    trips.forEach(this::refresh);
  }

  /**
   * {@link #effectiveEnd} of several team entities by id, in one query — for a caller holding DTOs
   * rather than entities. An unknown id is absent from the map.
   */
  public Map<Long, Instant> effectiveEnds(Collection<Long> ids) {
    Map<Long, Instant> ends = new HashMap<>();
    if (ids.isEmpty()) {
      return ends;
    }
    List<Object[]> rows =
        entityManager
            .createQuery(
                "select te.id, te.endDateTime, te.dateTime from TeamEntity te where te.id in :ids",
                Object[].class)
            .setParameter("ids", ids)
            .getResultList();
    for (Object[] row : rows) {
      Instant end = (Instant) row[1];
      ends.put((Long) row[0], end != null ? end : ((Instant) row[2]).plus(DEFAULT_DURATION));
    }
    return ends;
  }

  /** The end of a ride, by the rule of the class comment. */
  public Instant rideEnd(Ride ride) {
    Instant departure = ride.getDateTime();
    List<RideGroup> groups = ride.getGroups();
    if (groups.isEmpty()) {
      return departure.plus(DEFAULT_DURATION);
    }
    // Each group from its stored start_at, the instant the weather and the devices read too
    // (docs/LEDGER_*.md API-60).
    Instant end = departure;
    for (RideGroup group : groups) {
      Instant start = group.getStartAt();
      Route route = live(group.getRoute());
      if (route == null) {
        route = live(ride.getRoute());
      }
      Instant groupEnd = legEnd(start, route, group.getAverageSpeed());
      if (groupEnd.isAfter(end)) {
        end = groupEnd;
      }
    }
    return end;
  }

  /**
   * The end of a trip and of each of its live stages.
   *
   * <p>The trip ends with the latest of its stages, not with the one sorted last: the two are the
   * same on any sensible trip, and the latest never shows a trip as over while one of its stages is
   * still ahead. The same reading as {@code TripDto.endDate}.
   */
  public TripEnds tripEnds(Trip trip) {
    Map<TripStage, Instant> stages = new LinkedHashMap<>();
    Instant end = null;
    for (TripStage stage : trip.getStages()) {
      if (stage.isDeleted()) {
        continue;
      }
      Instant stageEnd =
          legEnd(stage.getDateTime(), live(stage.getRoute()), stage.getAverageSpeed());
      stages.put(stage, stageEnd);
      if (end == null || stageEnd.isAfter(end)) {
        end = stageEnd;
      }
    }
    if (end == null) {
      end = trip.getDateTime().plus(DEFAULT_DURATION);
    } else if (end.isBefore(trip.getDateTime())) {
      end = trip.getDateTime();
    }
    return new TripEnds(end, stages);
  }

  /** A trip's end, and the end of each of its live stages. */
  public record TripEnds(Instant end, Map<TripStage, Instant> stages) {}

  /**
   * One leg — a group or a stage: its start plus its route's length at its speed, or plus {@link
   * #DEFAULT_DURATION} when either is missing.
   */
  static Instant legEnd(Instant start, @Nullable Route route, @Nullable Float averageSpeed) {
    Float distance = route != null ? route.getDistance() : null;
    if (distance == null || distance <= 0 || averageSpeed == null || averageSpeed <= 0) {
      return start.plus(DEFAULT_DURATION);
    }
    return RideWeatherCalculator.passage(start, distance, averageSpeed);
  }

  private static @Nullable Route live(@Nullable Route route) {
    return route == null || route.isDeleted() ? null : route;
  }

  private static boolean set(TeamEntity entity, Instant end) {
    if (Objects.equals(entity.getEndDateTime(), end)) {
      return false;
    }
    entity.setEndDateTime(end);
    return true;
  }
}
