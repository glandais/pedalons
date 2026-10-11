package fr.pedalons.service.timezone;

import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.infrastructure.timezone.TimezoneService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

/**
 * The zone an event's wall times are read in (docs/LEDGER_*.md API-60, plan §4): that of the first
 * point its chain finds, else the team's. Never UTC.
 *
 * <table>
 *   <tr><th>Entity</th><th>Chain</th></tr>
 *   <tr><td>Ride</td><td>start place → first point of its route → team</td></tr>
 *   <tr><td>Stage</td><td>start place → first point of its route → the previous stage's zone →
 *       first point of the trip's route → team</td></tr>
 *   <tr><td>Trip</td><td>its first stage's zone → first point of its route → team</td></tr>
 *   <tr><td>Post, ad, route, page</td><td>team</td></tr>
 *   <tr><td>Ride group</td><td>its ride's</td></tr>
 * </table>
 *
 * <p>The {@code locate…} methods stop before the team: empty means the chain found no point, which
 * is what a change of the team's zone looks for (plan §9). Deleted routes and empty points are
 * skipped.
 *
 * <p>A group's departure is stored once, {@code RideGroup.startAt}, written by {@link #setStart}:
 * the weather, the devices, the stored end and the DTOs all start from that instant (plan §4,
 * « une seule source de fuseau par lieu »).
 */
@ApplicationScoped
public class EventTimezoneResolver {

  @Inject TimezoneService timezoneService;

  /** The team's zone; Paris should the stored value ever be unreadable. */
  public static ZoneId teamZone(Team team) {
    String id = team.getTimezone();
    return ZoneId.of(id != null ? id : Team.DEFAULT_TIMEZONE);
  }

  /** The zone of {@code point}, else the team's: the {@code GET …/timezone} answer. */
  public ZoneId resolve(Team team, @Nullable Point<G2D> point) {
    return locate(point).orElseGet(() -> teamZone(team));
  }

  /** The zone of the given coordinates, empty at sea or outside every zone. */
  public Optional<ZoneId> locate(double lat, double lon) {
    return timezoneService.findZoneId(lat, lon);
  }

  public Optional<ZoneId> locate(@Nullable Point<G2D> point) {
    Point<G2D> usable = usable(point);
    if (usable == null) {
      return Optional.empty();
    }
    G2D position = usable.getPosition();
    return locate(position.getLat(), position.getLon());
  }

  // ─── Rides ────────────────────────────────────────────────────────────────

  public Optional<ZoneId> locateRide(@Nullable Place start, @Nullable Route route) {
    return locatePlaceOrRoute(start, route);
  }

  public ZoneId ride(Team team, @Nullable Place start, @Nullable Route route) {
    return locateRide(start, route).orElseGet(() -> teamZone(team));
  }

  public ZoneId ride(Ride ride) {
    return ride(ride.getTeam(), ride.getStart(), ride.getRoute());
  }

  // ─── Trips and stages ─────────────────────────────────────────────────────

  /** What locates a stage on its own: its start place and its route. */
  public record StagePoints(@Nullable Place start, @Nullable Route route) {}

  /**
   * The located zone of each stage, in the given order — the order of the request, which is the
   * stage order. A stage its own points do not locate takes the previous stage's zone, the first
   * one the trip route's; empty when nothing before it located anything either.
   */
  public List<Optional<ZoneId>> locateStages(List<StagePoints> stages, @Nullable Route tripRoute) {
    List<Optional<ZoneId>> zones = new ArrayList<>(stages.size());
    Optional<ZoneId> previous = Optional.empty();
    for (StagePoints stage : stages) {
      Optional<ZoneId> zone = locatePlaceOrRoute(stage.start(), stage.route());
      if (zone.isEmpty()) {
        zone = previous;
      }
      if (zone.isEmpty()) {
        zone = locateRoute(tripRoute);
      }
      zones.add(zone);
      previous = zone;
    }
    return zones;
  }

  /** The trip's own located zone: its first stage's, else its route's. */
  public Optional<ZoneId> locateTrip(List<Optional<ZoneId>> stageZones, @Nullable Route tripRoute) {
    if (!stageZones.isEmpty() && stageZones.getFirst().isPresent()) {
      return stageZones.getFirst();
    }
    return locateRoute(tripRoute);
  }

  /** The live stages of a trip, in their order, with their located zones. */
  public Map<TripStage, Optional<ZoneId>> locateStages(Trip trip) {
    List<TripStage> stages =
        trip.getStages().stream()
            .filter(s -> !s.isDeleted())
            .sorted(Comparator.comparingInt(TripStage::getSortOrder))
            .toList();
    List<Optional<ZoneId>> zones =
        locateStages(
            stages.stream().map(s -> new StagePoints(s.getStartPlace(), s.getRoute())).toList(),
            trip.getRoute());
    Map<TripStage, Optional<ZoneId>> result = new LinkedHashMap<>();
    for (int i = 0; i < stages.size(); i++) {
      result.put(stages.get(i), zones.get(i));
    }
    return result;
  }

  // ─── Instants ─────────────────────────────────────────────────────────────

  /**
   * Sets when a group leaves from the wall time a request gives it: {@code time} on the ride's
   * local date in {@code zone}, the ride's start when it has none. Run on every save of the ride,
   * once its date and zone are final, so that a date change moves every group.
   */
  public static void setStart(
      RideGroup group, Instant rideDateTime, @Nullable LocalTime time, ZoneId zone) {
    setStart(group, rideDateTime, time, zone, 0);
  }

  /**
   * {@link #setStart(RideGroup, Instant, LocalTime, ZoneId)} for a group that leaves {@code
   * dayOffset} days after its ride's local date — see {@link #dayOffset}.
   */
  public static void setStart(
      RideGroup group,
      Instant rideDateTime,
      @Nullable LocalTime time,
      ZoneId zone,
      long dayOffset) {
    group.setStartAt(groupStart(rideDateTime, time, zone, dayOffset));
  }

  /**
   * A group's departure from its wall time: {@code time} on the ride's local date in {@code zone},
   * the ride's own instant when the group has none. A time in the spring gap moves forward by the
   * gap, one in the autumn overlap takes the earlier offset ({@link java.time.ZonedDateTime}).
   */
  public static Instant groupStart(Instant rideDateTime, @Nullable LocalTime time, ZoneId zone) {
    return groupStart(rideDateTime, time, zone, 0);
  }

  /**
   * {@link #groupStart(Instant, LocalTime, ZoneId)}, {@code dayOffset} days after the ride's local
   * date.
   */
  public static Instant groupStart(
      Instant rideDateTime, @Nullable LocalTime time, ZoneId zone, long dayOffset) {
    if (time == null) {
      return rideDateTime;
    }
    return rideDateTime
        .atZone(zone)
        .toLocalDate()
        .plusDays(dayOffset)
        .atTime(time)
        .atZone(zone)
        .toInstant();
  }

  /**
   * The group's own wall time, read back from its stored start: null when it leaves with the ride,
   * else its start in the ride's zone — what a client edits and sends back as {@code
   * GroupRequest.time}, which {@link #groupStart} turns into the same instant once given the
   * group's {@link #dayOffset}.
   */
  public static @Nullable LocalTime ownTime(Instant rideDateTime, Instant startAt, ZoneId zone) {
    return startAt.equals(rideDateTime) ? null : startAt.atZone(zone).toLocalTime();
  }

  /**
   * How many days after its ride's local date a group leaves, in the ride's zone: 0 for a group
   * entered through {@link #groupStart}, which always lands on the ride's date. Only a past ride
   * relabelled at constant instant by a change of the team's zone leaves a group on another date
   * (−1 or +1): {@link #ownTime} drops the date, so a save of the ride must put the time back on
   * this date, not on the ride's, or an unchanged save moves the group by 24 h
   * (docs/LEDGER_*.md API-101).
   */
  public static long dayOffset(Instant rideDateTime, Instant startAt, ZoneId zone) {
    return ChronoUnit.DAYS.between(
        rideDateTime.atZone(zone).toLocalDate(), startAt.atZone(zone).toLocalDate());
  }

  /**
   * The same wall time in another zone, as a change of the team's zone keeps it (plan §9). Same
   * resolution of gaps and overlaps as the entry of a wall time.
   */
  public static Instant sameWallTime(Instant instant, ZoneId from, ZoneId to) {
    return instant.atZone(from).toLocalDateTime().atZone(to).toInstant();
  }

  // ─── Points ───────────────────────────────────────────────────────────────

  private Optional<ZoneId> locatePlaceOrRoute(@Nullable Place place, @Nullable Route route) {
    Optional<ZoneId> zone = locate(place == null ? null : place.getGeometry());
    return zone.isPresent() ? zone : locateRoute(route);
  }

  private Optional<ZoneId> locateRoute(@Nullable Route route) {
    return route == null || route.isDeleted() ? Optional.empty() : locate(route.getStart());
  }

  private static @Nullable Point<G2D> usable(@Nullable Point<G2D> point) {
    return point == null || point.isEmpty() ? null : point;
  }
}
