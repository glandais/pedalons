package fr.pedalons.service.weather;

import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.domain.weather.WeatherCell;
import fr.pedalons.domain.weather.WeatherDaily;
import fr.pedalons.domain.weather.WeatherHourly;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoForecast;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.repository.weather.WeatherDailyRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * What the weather tests share: a straight route, a provider answer, and a cache cell written the
 * way the worker writes it — so a test can start from a filled cache without going through the
 * planner.
 */
public final class WeatherTestFixtures {

  /** Metres per degree of latitude. */
  private static final double METRES_PER_DEGREE = 111_195;

  /** Bellecour, Lyon: the meeting point of most weather tests. */
  public static final double LYON_LAT = 45.7578;

  public static final double LYON_LON = 4.8320;

  private WeatherTestFixtures() {}

  /**
   * A straight track due north from ({@code lat}, {@code lon}), a point every 100 m, {@code km}
   * long, climbing 1 m per km from {@code ele}.
   */
  public static List<TrackPoint> northbound(double lat, double lon, double km, double ele) {
    List<TrackPoint> points = new ArrayList<>();
    for (int i = 0; i <= km * 10; i++) {
      double d = i * 100.0;
      points.add(new TrackPoint(lat + d / METRES_PER_DEGREE, lon, ele + i * 0.1, d));
    }
    return points;
  }

  /**
   * An Open-Meteo answer for {@code location}: {@code hours} hours from two hours ago, all at
   * {@code temperature} °C with a 20 km/h wind from {@code windFrom}, and sunrise/sunset from
   * yesterday to the day after tomorrow.
   */
  public static OpenMeteoForecast forecast(
      Location location, int hours, double temperature, double windFrom) {
    return forecast(
        location,
        Instant.now().truncatedTo(ChronoUnit.HOURS).minus(Duration.ofHours(2)),
        LocalDate.now(ZoneOffset.UTC),
        hours,
        temperature,
        windFrom);
  }

  /**
   * The same from a fixed first hour and day — for a test that compares two answers and must not
   * see them differ because an hour went by in between.
   */
  public static OpenMeteoForecast forecast(
      Location location,
      Instant start,
      LocalDate today,
      int hours,
      double temperature,
      double windFrom) {
    List<OpenMeteoForecast.Hour> rows = new ArrayList<>();
    for (int h = 0; h < hours; h++) {
      rows.add(
          new OpenMeteoForecast.Hour(
              start.plus(Duration.ofHours(h)),
              temperature,
              temperature - 1,
              10,
              0,
              2,
              20,
              windFrom,
              35.0));
    }
    List<OpenMeteoForecast.Day> days = new ArrayList<>();
    for (int d = -1; d < 3; d++) {
      LocalDate date = today.plusDays(d);
      days.add(
          new OpenMeteoForecast.Day(
              date,
              date.atTime(5, 0).toInstant(ZoneOffset.UTC),
              date.atTime(18, 0).toInstant(ZoneOffset.UTC)));
    }
    return new OpenMeteoForecast(
        location.latitude(),
        location.longitude(),
        location.elevation() == null ? 180.0 : location.elevation(),
        "Europe/Paris",
        rows,
        days);
  }

  /** 48 mild hours with a northerly. */
  public static OpenMeteoForecast forecast(Location location) {
    return forecast(location, 48, 15, 0);
  }

  /** The cell stored under {@code key}, or null. Inside a transaction. */
  public static @Nullable WeatherCell cell(WeatherCellRepository cells, CellKey key) {
    return cells.findByKey(key.latIdx(), key.lonIdx(), key.eleBand());
  }

  /**
   * Writes a cell as the planner then the worker would: demanded at {@code demandedAt}, fetched at
   * {@code fetchedAt} (none when null), with one row per hour of {@code hourTimes} at {@code
   * temperature} °C and a day row per date of {@code dates}. Inside a transaction.
   *
   * @return the cell id
   */
  public static long seedCell(
      WeatherCellRepository cells,
      WeatherHourlyRepository hourly,
      WeatherDailyRepository daily,
      CellKey key,
      Instant demandedAt,
      @Nullable Instant fetchedAt,
      List<Instant> hourTimes,
      double temperature,
      List<LocalDate> dates) {
    cells.upsertDemand(
        key.latIdx(),
        key.lonIdx(),
        key.eleBand(),
        key.centerLat(),
        key.centerLon(),
        demandedAt,
        Duration.ofHours(1),
        demandedAt);
    cells.flush();
    WeatherCell cell = cell(cells, key);
    if (cell == null) {
      throw new IllegalStateException("Cell not upserted: " + key);
    }
    long id = cell.getId();
    if (fetchedAt != null) {
      cells.markFetched(id, 180.0, "Europe/Paris", fetchedAt, fetchedAt.plus(Duration.ofHours(1)));
    }
    List<WeatherHourly> hours = new ArrayList<>();
    for (Instant time : hourTimes) {
      WeatherHourly row = new WeatherHourly();
      row.setCellId(id);
      row.setTime(time);
      row.setTemperature(temperature);
      row.setApparentTemperature(temperature - 1);
      row.setPrecipitationProbability(10);
      row.setPrecipitation(0);
      row.setWeatherCode(2);
      row.setWindSpeed(20);
      row.setWindDirection(0);
      row.setWindGusts(35.0);
      hours.add(row);
    }
    hourly.upsert(id, hours);
    List<WeatherDaily> days = new ArrayList<>();
    for (LocalDate date : dates) {
      WeatherDaily row = new WeatherDaily();
      row.setCellId(id);
      row.setDate(date);
      row.setSunrise(date.atTime(5, 0).toInstant(ZoneOffset.UTC));
      row.setSunset(date.atTime(18, 0).toInstant(ZoneOffset.UTC));
      days.add(row);
    }
    daily.upsert(id, days);
    return id;
  }

  /** Every hour from {@code from} (included) to {@code to} (included). */
  public static List<Instant> hours(Instant from, Instant to) {
    List<Instant> hours = new ArrayList<>();
    for (Instant t = from; !t.isAfter(to); t = t.plus(Duration.ofHours(1))) {
      hours.add(t);
    }
    return hours;
  }

  /** Every date from {@code from} (included) to {@code to} (included). */
  public static List<LocalDate> dates(LocalDate from, LocalDate to) {
    List<LocalDate> dates = new ArrayList<>();
    for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
      dates.add(d);
    }
    return dates;
  }
}
