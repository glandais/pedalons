package fr.pedalons.service.weather;

import fr.pedalons.enums.CompassPoint;
import fr.pedalons.enums.RelativeWind;
import fr.pedalons.enums.WeatherCheckpointKind;
import fr.pedalons.enums.WeatherCondition;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.repository.weather.WeatherHourRow;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.NavigableMap;
import java.util.TreeMap;
import java.util.function.Function;
import org.jspecify.annotations.Nullable;

/**
 * Every weather computation, as pure functions: passages, the hour read for each, the wind relative
 * to the direction of travel, the stretches and the exposure, the rain alert, the prevailing wind,
 * the statuses. One implementation for the web and the mobile apps alike — the clients only display,
 * translate and convert units.
 */
public final class RideWeatherCalculator {

  /** The speed assumed for a group that gives none, km/h — said on screen ({@code speedIsDefault}). */
  public static final double DEFAULT_SPEED_KMH = 25;

  /** How far ahead the forecast is shown. */
  public static final Duration HORIZON = Duration.ofDays(7);

  /** Probability (%) from which rain is announced. */
  public static final int RAIN_ALERT_PROBABILITY = 50;

  /**
   * How far from the moment asked about an hour may still be read. More than half an hour so a
   * zone with a half-hour offset, whose forecast hours fall at :30 UTC, still finds one.
   */
  static final Duration NEAREST_HOUR_TOLERANCE = Duration.ofMinutes(90);

  /** Share of the wind speed beyond which a stretch is a head- or a tailwind. */
  static final double HEAD_TAIL_THRESHOLD = 0.5;

  private RideWeatherCalculator() {}

  // ---------------------------------------------------------------------------------------------
  // Inputs
  // ---------------------------------------------------------------------------------------------

  /** A group's speed, km/h, and whether it is the default. */
  public record Speed(double kmh, boolean isDefault) {}

  /** The group's own average speed when positive, else {@value #DEFAULT_SPEED_KMH} km/h. */
  public static Speed speed(@Nullable Float averageSpeed) {
    return averageSpeed != null && averageSpeed > 0
        ? new Speed(averageSpeed, false)
        : new Speed(DEFAULT_SPEED_KMH, true);
  }

  /** The passage {@code distanceMeters} from the start at {@code speedKmh}. */
  public static Instant passage(Instant start, double distanceMeters, double speedKmh) {
    double seconds = distanceMeters / (speedKmh / 3.6);
    return start.plusMillis(Math.round(seconds * 1000));
  }

  /** One leg to compute: a group, or the ride itself when it has no group. */
  public record LegInput(
      @Nullable Long groupId, Instant start, Speed speed, @Nullable RouteSamples samples) {

    public double distance() {
      return samples == null ? 0 : samples.totalDistance();
    }

    public Instant arrival() {
      return passage(start, distance(), speed.kmh());
    }
  }

  /**
   * The cached forecast of one cell.
   *
   * @param fetchedAt null when the cell was never fetched (and {@code hours} is then empty)
   */
  public record CellSeries(
      @Nullable Instant fetchedAt, NavigableMap<Instant, WeatherHourRow> hours) {

    public static final CellSeries EMPTY = new CellSeries(null, new TreeMap<>());

    public static CellSeries of(@Nullable Instant fetchedAt, Collection<WeatherHourRow> rows) {
      NavigableMap<Instant, WeatherHourRow> hours = new TreeMap<>();
      for (WeatherHourRow row : rows) {
        hours.put(row.time(), row);
      }
      return new CellSeries(fetchedAt, hours);
    }

    /** The hour nearest {@code moment}, within {@link #NEAREST_HOUR_TOLERANCE}. */
    public @Nullable WeatherHourRow nearest(Instant moment) {
      Map.Entry<Instant, WeatherHourRow> before = hours.floorEntry(moment);
      Map.Entry<Instant, WeatherHourRow> after = hours.ceilingEntry(moment);
      Map.Entry<Instant, WeatherHourRow> best;
      if (before == null) {
        best = after;
      } else if (after == null) {
        best = before;
      } else {
        best =
            Duration.between(before.getKey(), moment)
                        .compareTo(Duration.between(moment, after.getKey()))
                    <= 0
                ? before
                : after;
      }
      if (best == null) {
        return null;
      }
      Duration gap = Duration.between(best.getKey(), moment).abs();
      return gap.compareTo(NEAREST_HOUR_TOLERANCE) <= 0 ? best.getValue() : null;
    }
  }

  // ---------------------------------------------------------------------------------------------
  // One hour
  // ---------------------------------------------------------------------------------------------

  public static Wind wind(WeatherHourRow hour) {
    return new Wind(
        round1(hour.windSpeed()),
        hour.windGusts() == null ? null : round1(hour.windGusts()),
        roundDegrees(hour.windDirection()),
        CompassPoint.fromDegrees(hour.windDirection()));
  }

  /**
   * The forecast of {@code hour}, shown for the moment {@code at} — the departure, a checkpoint's
   * passage. {@code time} stays the model hour; {@code daylight} is judged at {@code at}, not at
   * that round hour: a 08:30 departure with sunrise at 08:28 reads the 08:00 hour yet leaves by
   * day, a 19:20 passage with sunset at 19:13 reads the 19:00 hour yet rides at night.
   */
  public static WeatherConditions conditions(WeatherHourRow hour, Instant at) {
    return new WeatherConditions(
        hour.time(),
        hour.weatherCode(),
        WeatherCondition.fromWmo(hour.weatherCode()),
        daylight(at, hour.sunrise(), hour.sunset()),
        round1(hour.temperature()),
        round1(hour.apparentTemperature()),
        hour.precipitationProbability(),
        round1(hour.precipitation()),
        wind(hour));
  }

  /**
   * Whether {@code time} is between sunrise and sunset. With neither known — polar day or night, or
   * no daily row — it says day: a night icon on a summer noon is the worse mistake.
   */
  static boolean daylight(Instant time, @Nullable Instant sunrise, @Nullable Instant sunset) {
    if (sunrise == null && sunset == null) {
      return true;
    }
    boolean afterSunrise = sunrise == null || !time.isBefore(sunrise);
    boolean beforeSunset = sunset == null || time.isBefore(sunset);
    return afterSunrise && beforeSunset;
  }

  // ---------------------------------------------------------------------------------------------
  // Wind along a stretch
  // ---------------------------------------------------------------------------------------------

  /**
   * The wind on a stretch.
   *
   * @param headwind km/h, signed, positive against the rider
   * @param relativeWindAngle degrees clockwise of the direction the wind blows towards, relative to
   *     the direction of travel: 0 = from behind, 180 = in the face
   */
  public record StretchWind(RelativeWind relativeWind, double headwind, double relativeWindAngle) {}

  /**
   * The wind of speed {@code windSpeed} from {@code windFrom} on the stretch {@code sample} starts:
   * the head component averaged over its sub-segments weighted by their length, and the angle
   * against its mean heading. Null for a stretch of no length (a one-point route).
   */
  public static @Nullable StretchWind stretchWind(
      RouteSamples.Sample sample, double windSpeed, double windFrom) {
    if (sample.length() <= 0) {
      return null;
    }
    double phi = Math.toRadians(windFrom);
    double headwind =
        windSpeed
            * (Math.cos(phi) * sample.sumCos() + Math.sin(phi) * sample.sumSin())
            / sample.length();
    double heading = Math.toDegrees(Math.atan2(sample.sumSin(), sample.sumCos()));
    return new StretchWind(
        classify(headwind, windSpeed),
        round1(headwind),
        roundDegrees(relativeWindAngle(windFrom, heading)));
  }

  /** {@code HEAD} above half the wind speed, {@code TAIL} below minus half, {@code CROSS} between. */
  public static RelativeWind classify(double headwind, double windSpeed) {
    if (headwind > HEAD_TAIL_THRESHOLD * windSpeed) {
      return RelativeWind.HEAD;
    }
    if (headwind < -HEAD_TAIL_THRESHOLD * windSpeed) {
      return RelativeWind.TAIL;
    }
    return RelativeWind.CROSS;
  }

  /**
   * Where the wind blows towards, relative to the heading, clockwise: a wind from the north on a
   * rider heading north blows towards the south, behind them — 180, in the face.
   */
  public static double relativeWindAngle(double windFrom, double heading) {
    return normalize(windFrom + 180 - heading);
  }

  /**
   * Circular mean of directions, in degrees; null for none. A plain average would put the mean of
   * 350° and 10° at 180°.
   */
  public static @Nullable Double circularMean(Collection<Double> degrees) {
    if (degrees.isEmpty()) {
      return null;
    }
    double x = 0;
    double y = 0;
    for (double d : degrees) {
      x += Math.cos(Math.toRadians(d));
      y += Math.sin(Math.toRadians(d));
    }
    if (Math.abs(x) < 1e-9 && Math.abs(y) < 1e-9) {
      return null;
    }
    return normalize(Math.toDegrees(Math.atan2(y, x)));
  }

  /** The prevailing wind of a set of hours: circular mean direction, mean speed, strongest gust. */
  static @Nullable Wind prevailingWind(List<WeatherConditions> conditions) {
    if (conditions.isEmpty()) {
      return null;
    }
    List<Double> directions = new ArrayList<>(conditions.size());
    double speed = 0;
    Double gusts = null;
    for (WeatherConditions c : conditions) {
      directions.add(c.wind().direction());
      speed += c.wind().speed();
      if (c.wind().gusts() != null) {
        gusts = gusts == null ? c.wind().gusts() : Math.max(gusts, c.wind().gusts());
      }
    }
    Double direction = circularMean(directions);
    if (direction == null) {
      // Opposite winds cancelling out: no prevailing direction worth drawing.
      return null;
    }
    return new Wind(
        round1(speed / conditions.size()),
        gusts,
        roundDegrees(direction),
        CompassPoint.fromDegrees(direction));
  }

  static WindExposure exposure(List<WindSegment> segments) {
    double head = 0;
    double cross = 0;
    double tail = 0;
    for (WindSegment segment : segments) {
      double length = segment.toDistance() - segment.fromDistance();
      switch (segment.relativeWind()) {
        case HEAD -> head += length;
        case CROSS -> cross += length;
        case TAIL -> tail += length;
      }
    }
    return new WindExposure(Math.round(head), Math.round(cross), Math.round(tail));
  }

  // ---------------------------------------------------------------------------------------------
  // Departure, legs, ride
  // ---------------------------------------------------------------------------------------------

  /** The departure block, from the departure cell (no elevation band). */
  public static DepartureWeather departure(CellSeries series, Instant departureTime, Instant now) {
    WeatherHourRow hour = series.nearest(departureTime);
    if (hour == null || series.fetchedAt() == null) {
      return new DepartureWeather(WeatherStatus.UNAVAILABLE, null, null, null, series.fetchedAt());
    }
    WeatherStatus status =
        WeatherRefreshPolicy.isStale(series.fetchedAt(), departureTime, now)
            ? WeatherStatus.STALE
            : WeatherStatus.OK;
    return new DepartureWeather(
        status, conditions(hour, departureTime), hour.sunrise(), hour.sunset(), series.fetchedAt());
  }

  /**
   * One leg: a checkpoint per sample with the hour of its passage at its cell, the stretches between
   * them, and what they add up to.
   *
   * <p>Status: {@code NO_LOCATION} without a route, {@code NOT_YET_AVAILABLE} when the leg leaves
   * beyond the horizon (checkpoints and times, no weather, and {@code availableFrom}), {@code UNAVAILABLE} when no checkpoint
   * has weather, {@code STALE} when some lack it or a cell read is overdue, {@code OK} otherwise.
   */
  public static WeatherLeg leg(LegInput input, Function<CellKey, CellSeries> cache, Instant now) {
    Instant start = input.start();
    Speed speed = input.speed();
    RouteSamples samples = input.samples();
    if (samples == null || samples.isEmpty()) {
      return new WeatherLeg(
          input.groupId(),
          WeatherStatus.NO_LOCATION,
          null,
          start,
          speed.kmh(),
          speed.isDefault(),
          0,
          start,
          null,
          List.of(),
          List.of(),
          WindExposure.NONE,
          null,
          null);
    }
    boolean beyondHorizon = start.isAfter(now.plus(HORIZON));
    List<RouteSamples.Sample> points = samples.samples();
    int last = points.size() - 1;

    List<WeatherCheckpoint> checkpoints = new ArrayList<>(points.size());
    List<WindSegment> segments = new ArrayList<>();
    List<WeatherConditions> read = new ArrayList<>();
    RainAlert rainAlert = null;
    Instant oldestFetch = null;
    boolean stale = false;
    int missing = 0;

    for (int i = 0; i <= last; i++) {
      RouteSamples.Sample sample = points.get(i);
      WeatherCheckpointKind kind =
          i == 0
              ? WeatherCheckpointKind.START
              : i == last ? WeatherCheckpointKind.FINISH : WeatherCheckpointKind.EN_ROUTE;
      Instant time = passage(start, sample.distance(), speed.kmh());
      Double elevation =
          sample.elevation() == null ? null : (double) Math.round(sample.elevation());

      WeatherHourRow hour = null;
      CellSeries series = CellSeries.EMPTY;
      if (!beyondHorizon) {
        series = cache.apply(sample.cell());
        hour = series.fetchedAt() == null ? null : series.nearest(time);
      }
      if (hour == null) {
        missing++;
        checkpoints.add(
            new WeatherCheckpoint(
                i, kind, round0(sample.distance()), elevation, time, null, null, null, null));
        continue;
      }
      if (oldestFetch == null || series.fetchedAt().isBefore(oldestFetch)) {
        oldestFetch = series.fetchedAt();
      }
      stale |= WeatherRefreshPolicy.isStale(series.fetchedAt(), time, now);

      WeatherConditions conditions = conditions(hour, time);
      read.add(conditions);
      // The stretch this checkpoint opens; the finish opens none, so it shows the one it closes.
      RouteSamples.Sample stretch = i < last ? sample : points.get(i - 1);
      StretchWind wind =
          i == 0 && last == 0 ? null : stretchWind(stretch, hour.windSpeed(), hour.windDirection());
      if (i < last && wind != null) {
        segments.add(
            new WindSegment(
                round0(sample.distance()),
                round0(points.get(i + 1).distance()),
                wind.relativeWind(),
                wind.headwind()));
      }
      if (rainAlert == null
          && hour.precipitationProbability() != null
          && hour.precipitationProbability() >= RAIN_ALERT_PROBABILITY) {
        rainAlert =
            new RainAlert(
                hour.precipitationProbability(),
                time,
                round0(sample.distance()),
                conditions.condition());
      }
      checkpoints.add(
          new WeatherCheckpoint(
              i,
              kind,
              round0(sample.distance()),
              elevation,
              time,
              conditions,
              wind == null ? null : wind.relativeWind(),
              wind == null ? null : wind.headwind(),
              wind == null ? null : wind.relativeWindAngle()));
    }

    WeatherStatus status;
    if (beyondHorizon) {
      status = WeatherStatus.NOT_YET_AVAILABLE;
    } else if (missing == checkpoints.size()) {
      status = WeatherStatus.UNAVAILABLE;
    } else if (missing > 0 || stale) {
      status = WeatherStatus.STALE;
    } else {
      status = WeatherStatus.OK;
    }
    return new WeatherLeg(
        input.groupId(),
        status,
        beyondHorizon ? availableFrom(start) : null,
        start,
        speed.kmh(),
        speed.isDefault(),
        round0(samples.totalDistance()),
        input.arrival(),
        oldestFetch,
        List.copyOf(checkpoints),
        List.copyOf(segments),
        exposure(segments),
        prevailingWind(read),
        rainAlert);
  }

  /**
   * The ride as a whole, from its departure and its legs. {@code UNAVAILABLE} when nothing at all
   * could be read, {@code STALE} when something was read but not all of it, or some of it late;
   * legs without a route or beyond the horizon do not count either way.
   */
  public static RideWeather ride(DepartureWeather departure, List<WeatherLeg> legs) {
    List<WeatherStatus> parts = new ArrayList<>();
    parts.add(departure.status());
    Instant oldest = departure.fetchedAt();
    for (WeatherLeg leg : legs) {
      if (leg.status() == WeatherStatus.NO_LOCATION
          || leg.status() == WeatherStatus.NOT_YET_AVAILABLE) {
        continue;
      }
      parts.add(leg.status());
      if (leg.fetchedAt() != null && (oldest == null || leg.fetchedAt().isBefore(oldest))) {
        oldest = leg.fetchedAt();
      }
    }
    WeatherStatus status;
    if (parts.stream().allMatch(s -> s == WeatherStatus.UNAVAILABLE)) {
      status = WeatherStatus.UNAVAILABLE;
    } else if (parts.stream().anyMatch(s -> s != WeatherStatus.OK)) {
      status = WeatherStatus.STALE;
    } else {
      status = WeatherStatus.OK;
    }
    return new RideWeather(status, null, oldest, departure, List.copyOf(legs));
  }

  /**
   * A card's summary: the departure hour (its day or night judged at {@code departure} itself),
   * and the extremes over {@code [departure, lastArrival]} —
   * each end widened by half an hour so the hours nearest them count. Null when the cache has no
   * hour near the departure.
   */
  public static @Nullable RideWeatherSummary summary(
      Instant departure,
      Instant lastArrival,
      @Nullable Instant fetchedAt,
      Collection<WeatherHourRow> hours,
      Instant now) {
    if (fetchedAt == null) {
      return null;
    }
    CellSeries series = CellSeries.of(fetchedAt, hours);
    WeatherHourRow first = series.nearest(departure);
    if (first == null) {
      return null;
    }
    Instant from = departure.minus(Duration.ofMinutes(30));
    Instant to = lastArrival.plus(Duration.ofMinutes(30));
    List<WeatherHourRow> window =
        new ArrayList<>(series.hours().subMap(from, true, to, true).values());
    if (window.isEmpty()) {
      window.add(first);
    }
    double min = Double.POSITIVE_INFINITY;
    double max = Double.NEGATIVE_INFINITY;
    Integer maxProbability = null;
    RainAlert rainAlert = null;
    for (WeatherHourRow hour : window) {
      min = Math.min(min, hour.temperature());
      max = Math.max(max, hour.temperature());
      Integer probability = hour.precipitationProbability();
      if (probability != null) {
        maxProbability =
            maxProbability == null ? probability : Math.max(maxProbability, probability);
        if (rainAlert == null && probability >= RAIN_ALERT_PROBABILITY) {
          rainAlert =
              new RainAlert(
                  probability, hour.time(), null, WeatherCondition.fromWmo(hour.weatherCode()));
        }
      }
    }
    WeatherConditions start = conditions(first, departure);
    return new RideWeatherSummary(
        WeatherRefreshPolicy.isStale(fetchedAt, departure, now)
            ? WeatherStatus.STALE
            : WeatherStatus.OK,
        null,
        start.weatherCode(),
        start.condition(),
        start.daylight(),
        start.temperature(),
        round1(min),
        round1(max),
        maxProbability,
        start.wind(),
        rainAlert);
  }

  /**
   * A trip as a whole, from the legs of its stages yet to leave. {@code NO_LOCATION} when none of
   * them has a route; {@code NOT_YET_AVAILABLE} when every one that has is beyond the horizon, with
   * the earliest {@code availableFrom}; otherwise as {@link #ride}: legs without a route or beyond
   * the horizon do not count either way. {@code OUT_OF_RANGE} when no stage is left to leave.
   */
  public static TripWeather trip(List<TripWeather.StageLeg> stages, List<WeatherLeg> upcoming) {
    if (upcoming.isEmpty()) {
      return new TripWeather(WeatherStatus.OUT_OF_RANGE, null, null, List.copyOf(stages));
    }
    List<WeatherStatus> parts = new ArrayList<>();
    Instant oldest = null;
    Instant availableFrom = null;
    for (WeatherLeg leg : upcoming) {
      switch (leg.status()) {
        case NO_LOCATION -> {}
        case NOT_YET_AVAILABLE -> {
          if (leg.availableFrom() != null
              && (availableFrom == null || leg.availableFrom().isBefore(availableFrom))) {
            availableFrom = leg.availableFrom();
          }
        }
        default -> {
          parts.add(leg.status());
          if (leg.fetchedAt() != null && (oldest == null || leg.fetchedAt().isBefore(oldest))) {
            oldest = leg.fetchedAt();
          }
        }
      }
    }
    WeatherStatus status;
    if (parts.isEmpty()) {
      status = availableFrom == null ? WeatherStatus.NO_LOCATION : WeatherStatus.NOT_YET_AVAILABLE;
    } else if (parts.stream().allMatch(s -> s == WeatherStatus.UNAVAILABLE)) {
      status = WeatherStatus.UNAVAILABLE;
    } else if (parts.stream().anyMatch(s -> s != WeatherStatus.OK)) {
      status = WeatherStatus.STALE;
    } else {
      status = WeatherStatus.OK;
    }
    return new TripWeather(
        status,
        status == WeatherStatus.NOT_YET_AVAILABLE ? availableFrom : null,
        oldest,
        List.copyOf(stages));
  }

  /**
   * A leg's weather in one line, for a stage's card: the hour of its first checkpoint read, the
   * extremes over its checkpoints, its rain alert. {@code NOT_YET_AVAILABLE} carries {@code
   * availableFrom} alone; null for any state with nothing to show, or when no checkpoint was read.
   */
  public static @Nullable RideWeatherSummary legSummary(WeatherLeg leg) {
    if (leg.status() == WeatherStatus.NOT_YET_AVAILABLE) {
      return leg.availableFrom() == null
          ? null
          : RideWeatherSummary.notYetAvailable(leg.availableFrom());
    }
    if (leg.status() != WeatherStatus.OK && leg.status() != WeatherStatus.STALE) {
      return null;
    }
    WeatherConditions first = null;
    double min = Double.POSITIVE_INFINITY;
    double max = Double.NEGATIVE_INFINITY;
    Integer maxProbability = null;
    for (WeatherCheckpoint checkpoint : leg.checkpoints()) {
      WeatherConditions weather = checkpoint.weather();
      if (weather == null) {
        continue;
      }
      if (first == null) {
        first = weather;
      }
      min = Math.min(min, weather.temperature());
      max = Math.max(max, weather.temperature());
      Integer probability = weather.precipitationProbability();
      if (probability != null) {
        maxProbability =
            maxProbability == null ? probability : Math.max(maxProbability, probability);
      }
    }
    if (first == null) {
      return null;
    }
    return new RideWeatherSummary(
        leg.status(),
        null,
        first.weatherCode(),
        first.condition(),
        first.daylight(),
        first.temperature(),
        min,
        max,
        maxProbability,
        first.wind(),
        leg.rainAlert());
  }

  /** {@code rideDateTime} minus the horizon: when a ride further out gets its forecast. */
  public static Instant availableFrom(Instant rideDateTime) {
    return rideDateTime.minus(HORIZON);
  }

  /** Whether the ride is beyond the horizon. */
  public static boolean isBeyondHorizon(Instant rideDateTime, Instant now) {
    return rideDateTime.isAfter(now.plus(HORIZON));
  }

  // ---------------------------------------------------------------------------------------------

  static double normalize(double degrees) {
    double d = degrees % 360;
    return d < 0 ? d + 360 : d;
  }

  /** Whole degrees in {@code [0, 360)}: 359.6° is 0°, not 360°. */
  static double roundDegrees(double degrees) {
    return Math.round(normalize(degrees)) % 360;
  }

  static double round1(double value) {
    return Math.round(value * 10) / 10d;
  }

  static double round0(double value) {
    return Math.round(value);
  }
}
