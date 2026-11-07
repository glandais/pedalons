package fr.pedalons.service.weather;

import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.repository.gpx.PreviewWeatherRow;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.service.weather.RideWeatherCalculator.LegInput;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

/**
 * Works out where and when a ride is ridden: its departure point and, per group, the leg — start,
 * speed, forecast points. Shared by the planner, which turns it into cells to fetch, and by the
 * detail read, which turns it into weather: the two must agree on every point, or the read asks for
 * cells nobody fetched.
 *
 * <p>Reads only: the ride's groups and routes (already in the session, or batch-fetched), one query
 * for the track ids of all the routes, and the route samples from their cache.
 */
@ApplicationScoped
public class RideWeatherPlans {

  @Inject GpxTrackRepository gpxTrackRepository;
  @Inject RouteSampleLookup routeSampleLookup;

  /**
   * A ride, located.
   *
   * @param departure null when the ride has no point at all ({@code NO_LOCATION})
   * @param legs one per group, each starting at the group's stored {@code start_at}
   *     (docs/LEDGER_*.md API-60)
   */
  public record RidePlan(
      long rideId, Instant departureTime, @Nullable Departure departure, List<LegInput> legs) {

    /** The earliest start among the ride and its legs. */
    public Instant earliest() {
      Instant earliest = departureTime;
      for (LegInput leg : legs) {
        if (leg.start().isBefore(earliest)) {
          earliest = leg.start();
        }
      }
      return earliest;
    }

    /** The latest estimated arrival — the ride's own time when no leg has a route. */
    public Instant lastArrival() {
      Instant latest = departureTime;
      for (LegInput leg : legs) {
        if (leg.arrival().isAfter(latest)) {
          latest = leg.arrival();
        }
      }
      return latest;
    }
  }

  /** The departure point; {@link #cell()} has no elevation band. */
  public record Departure(double lat, double lon) {
    public CellKey cell() {
      return CellKey.of(lat, lon);
    }
  }

  /**
   * A dated GPX preview as a plan, the type the planner and the read already exploit: one leg
   * without group, from its departure instant, at its average speed (else the default one). The
   * only place the speed of a preview is read, so the planner and the read agree on every passage.
   * {@code rideId} carries the preview id, which neither of them reads.
   */
  public RidePlan plan(PreviewWeatherRow preview) {
    RouteSamples samples = routeSampleLookup.previewSamples(preview.id(), preview.revision());
    RouteSamples usable = samples.isEmpty() ? null : samples;
    Departure departure =
        usable == null
            ? null
            : new Departure(usable.samples().getFirst().lat(), usable.samples().getFirst().lon());
    Instant start = Objects.requireNonNull(preview.departureAt());
    LegInput leg =
        new LegInput(null, start, RideWeatherCalculator.speed(preview.averageSpeed()), usable);
    return new RidePlan(preview.id(), start, departure, List.of(leg));
  }

  /** The plans of several dated previews. */
  public List<RidePlan> previewPlans(Collection<PreviewWeatherRow> previews) {
    return previews.stream().map(this::plan).toList();
  }

  public RidePlan plan(Ride ride) {
    return plans(List.of(ride)).getFirst();
  }

  /** The plans of several rides, with one track-id query for all their routes. */
  public List<RidePlan> plans(Collection<Ride> rides) {
    Set<Long> routeIds = new HashSet<>();
    for (Ride ride : rides) {
      for (Route route : routes(ride)) {
        routeIds.add(route.getId());
      }
    }
    Map<Long, List<Long>> trackIds = gpxTrackRepository.findIdsByRouteIds(routeIds);
    List<RidePlan> plans = new ArrayList<>(rides.size());
    for (Ride ride : rides) {
      plans.add(plan(ride, trackIds));
    }
    return plans;
  }

  private RidePlan plan(Ride ride, Map<Long, List<Long>> trackIds) {
    Departure departure = departure(ride);
    List<LegInput> legs = new ArrayList<>();
    List<RideGroup> groups = sortedGroups(ride);
    if (groups.isEmpty()) {
      legs.add(
          new LegInput(
              null,
              ride.getDateTime(),
              RideWeatherCalculator.speed(null),
              samples(live(ride.getRoute()), trackIds)));
    } else {
      for (RideGroup group : groups) {
        Route route = live(group.getRoute());
        if (route == null) {
          route = live(ride.getRoute());
        }
        legs.add(
            new LegInput(
                group.getId(),
                group.getStartAt(),
                RideWeatherCalculator.speed(group.getAverageSpeed()),
                samples(route, trackIds)));
      }
    }
    return new RidePlan(ride.getId(), ride.getDateTime(), departure, List.copyOf(legs));
  }

  /**
   * The meeting point, else the start of the ride's route, else the start of the first group's
   * route — deleted routes skipped. Kept in step with the SQL of {@code
   * WeatherHourlyRepository#findRideWindowHours}. It only locates the weather cell: no zone is read
   * from it, a group leaves at its stored {@code start_at} (docs/LEDGER_*.md API-60).
   */
  static @Nullable Departure departure(Ride ride) {
    Place start = ride.getStart();
    Departure point = start == null ? null : point(start.getGeometry());
    if (point != null) {
      return point;
    }
    Route route = live(ride.getRoute());
    point = route == null ? null : point(route.getStart());
    if (point != null) {
      return point;
    }
    for (RideGroup group : sortedGroups(ride)) {
      Route groupRoute = live(group.getRoute());
      if (groupRoute != null && groupRoute.getStart() != null) {
        return point(groupRoute.getStart());
      }
    }
    return null;
  }

  /**
   * The departure the list can tell without loading the groups: the meeting point or the ride's
   * route. A ride located only through a group's route returns null here.
   */
  static @Nullable Departure departureWithoutGroups(Ride ride) {
    Place start = ride.getStart();
    Departure point = start == null ? null : point(start.getGeometry());
    if (point != null) {
      return point;
    }
    Route route = live(ride.getRoute());
    return route == null ? null : point(route.getStart());
  }

  private static List<RideGroup> sortedGroups(Ride ride) {
    return ride.getGroups().stream()
        .sorted(
            Comparator.comparingInt(RideGroup::getSortOrder)
                .thenComparing(RideGroup::getId, Comparator.nullsLast(Comparator.naturalOrder())))
        .toList();
  }

  private static List<Route> routes(Ride ride) {
    List<Route> routes = new ArrayList<>();
    Route rideRoute = live(ride.getRoute());
    if (rideRoute != null) {
      routes.add(rideRoute);
    }
    for (RideGroup group : ride.getGroups()) {
      Route route = live(group.getRoute());
      if (route != null) {
        routes.add(route);
      }
    }
    return routes;
  }

  @Nullable RouteSamples samples(@Nullable Route route, Map<Long, List<Long>> trackIds) {
    if (route == null) {
      return null;
    }
    List<Long> ids = trackIds.getOrDefault(route.getId(), List.of());
    if (ids.isEmpty()) {
      return null;
    }
    RouteSamples samples = routeSampleLookup.samples(List.copyOf(ids));
    return samples.isEmpty() ? null : samples;
  }

  static @Nullable Route live(@Nullable Route route) {
    return route == null || route.isDeleted() ? null : route;
  }

  private static @Nullable Departure point(@Nullable Point<G2D> geometry) {
    if (geometry == null || geometry.isEmpty()) {
      return null;
    }
    G2D position = geometry.getPosition();
    return new Departure(position.getLat(), position.getLon());
  }
}
