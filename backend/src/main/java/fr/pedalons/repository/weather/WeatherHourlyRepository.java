package fr.pedalons.repository.weather;

import fr.pedalons.domain.weather.WeatherHourly;
import io.quarkus.hibernate.orm.panache.PanacheRepositoryBase;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.Query;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import org.hibernate.query.TypedParameterValue;
import org.hibernate.type.StandardBasicTypes;
import org.jspecify.annotations.Nullable;

/**
 * Forecast hours of the weather cells. Global like the cells (see {@code
 * fr.pedalons.domain.weather}): no query here filters by domain, and every read starts from a ride
 * the caller may already read.
 */
@ApplicationScoped
public class WeatherHourlyRepository
    implements PanacheRepositoryBase<WeatherHourly, WeatherHourly.Key> {

  /** Rows per statement: 10 binds each, far below PostgreSQL's 65535. */
  static final int UPSERT_CHUNK = 200;

  /**
   * The read side's hour columns, joined with the sunrise and sunset of the hour's local date in
   * the cell's zone. Selected as {@code h.*} positions 0–11 after the owner id.
   */
  private static final String HOUR_COLUMNS =
      """
      h.time, h.temperature, h.apparent_temperature, h.precipitation_probability,
      h.precipitation, h.weather_code, h.wind_speed, h.wind_direction, h.wind_gusts,
      d.sunrise, d.sunset
      """;

  private static final String DAILY_JOIN =
      """
      left join weather_daily d on d.cell_id = h.cell_id
        and d.date = cast(h.time at time zone coalesce(c.timezone, 'UTC') as date)
      """;

  /**
   * Writes a refreshed forecast. Native {@code ON CONFLICT DO UPDATE}: a refresh rewrites the hours
   * it already had and adds the new ones in one statement per {@value #UPSERT_CHUNK} hours, with no
   * read first. Hours the provider no longer sends stay until the purge — they are in the past.
   */
  public void upsert(Long cellId, List<WeatherHourly> hours) {
    for (int from = 0; from < hours.size(); from += UPSERT_CHUNK) {
      List<WeatherHourly> chunk = hours.subList(from, Math.min(hours.size(), from + UPSERT_CHUNK));
      StringBuilder sql =
          new StringBuilder(
              "insert into weather_hourly (cell_id, time, temperature, apparent_temperature,"
                  + " precipitation_probability, precipitation, weather_code, wind_speed,"
                  + " wind_direction, wind_gusts) values ");
      for (int i = 0; i < chunk.size(); i++) {
        if (i > 0) {
          sql.append(", ");
        }
        sql.append(
            "(:cell, :t%1$d, :tp%1$d, :at%1$d, :pp%1$d, :pr%1$d, :wc%1$d, :ws%1$d, :wd%1$d, :wg%1$d)"
                .formatted(i));
      }
      sql.append(
          """
           on conflict (cell_id, time) do update set
            temperature = excluded.temperature,
            apparent_temperature = excluded.apparent_temperature,
            precipitation_probability = excluded.precipitation_probability,
            precipitation = excluded.precipitation,
            weather_code = excluded.weather_code,
            wind_speed = excluded.wind_speed,
            wind_direction = excluded.wind_direction,
            wind_gusts = excluded.wind_gusts
          """);
      Query query = getEntityManager().createNativeQuery(sql.toString());
      query.setParameter("cell", cellId);
      for (int i = 0; i < chunk.size(); i++) {
        WeatherHourly hour = chunk.get(i);
        query.setParameter("t" + i, Timestamp.from(hour.getTime()));
        query.setParameter("tp" + i, hour.getTemperature());
        query.setParameter("at" + i, hour.getApparentTemperature());
        query.setParameter(
            "pp" + i,
            new TypedParameterValue<>(
                StandardBasicTypes.INTEGER, hour.getPrecipitationProbability()));
        query.setParameter("pr" + i, hour.getPrecipitation());
        query.setParameter("wc" + i, hour.getWeatherCode());
        query.setParameter("ws" + i, hour.getWindSpeed());
        query.setParameter("wd" + i, hour.getWindDirection());
        query.setParameter(
            "wg" + i, new TypedParameterValue<>(StandardBasicTypes.DOUBLE, hour.getWindGusts()));
      }
      query.executeUpdate();
    }
  }

  /** The housekeeping: hours that ended before {@code cutoff}. */
  public long deleteBefore(Instant cutoff) {
    return delete("time < ?1", cutoff);
  }

  /**
   * The detail path: the hours of {@code cellIds} within {@code [from, to]}, with sunrise and
   * sunset. One query, whatever the number of cells — hence of groups.
   */
  public List<WeatherHourRow> findHours(Collection<Long> cellIds, Instant from, Instant to) {
    if (cellIds.isEmpty()) {
      return List.of();
    }
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                "select h.cell_id, "
                    + HOUR_COLUMNS
                    + " from weather_hourly h join weather_cells c on c.id = h.cell_id "
                    + DAILY_JOIN
                    + " where h.cell_id in (:cellIds) and h.time >= :from and h.time <= :to"
                    + " order by h.cell_id, h.time")
            .setParameter("cellIds", cellIds)
            .setParameter("from", Timestamp.from(from))
            .setParameter("to", Timestamp.from(to))
            .getResultList();
    List<WeatherHourRow> hours = new ArrayList<>(rows.size());
    for (Object[] row : rows) {
      hours.add(hourRow(row, 0));
    }
    return hours;
  }

  /**
   * One ride's window for the list summary, and the hours of its departure cell within it.
   *
   * @param lastArrival the estimated arrival of the latest group
   * @param fetchedAt when the departure cell was last fetched
   */
  public record RideWindowHour(
      long rideId,
      Instant departure,
      Instant lastArrival,
      @Nullable Instant fetchedAt,
      WeatherHourRow hour) {}

  /**
   * The list path: for each ride of a page, the hours of its departure cell from its start to the
   * estimated arrival of its last group, in <b>one</b> query whatever the page size.
   *
   * <p>Everything the Java detail path works out from the entities is spelled here in SQL, so the
   * list never loads a ride's groups:
   *
   * <ul>
   *   <li>the departure point: the meeting point, else the ride's route start, else the start of the
   *       first group's route (by {@code sort_order}) — deleted routes skipped;
   *   <li>its cell, by {@code cellLatIdxSql} / {@code cellLonIdxSql} ({@code CellKey.SQL_*_IDX}),
   *       without elevation band;
   *   <li>each group's start: its stored {@code start_at}, which the detail reads too
   *       (docs/LEDGER_*.md API-60). The cell's zone only dates its daily rows;
   *   <li>its arrival: the start plus the distance of its route (else the ride's) at its average
   *       speed (else {@code defaultSpeed}); a ride without groups rides its own route at the
   *       default speed.
   * </ul>
   *
   * <p>A ride without a departure point, or whose cell was never fetched, returns no row.
   *
   * @param slack how far outside the window an hour is still read, so the hour nearest the start
   *     and the end is in the result
   */
  public List<RideWindowHour> findRideWindowHours(
      Collection<Long> rideIds,
      String cellLatIdxSql,
      String cellLonIdxSql,
      double defaultSpeed,
      java.time.Duration slack) {
    if (rideIds.isEmpty()) {
      return List.of();
    }
    String latIdx = cellLatIdxSql.replace("?1", "r.geom");
    String lonIdx = cellLonIdxSql.replace("?1", "r.geom");
    String sql =
        """
        with r as (
          select te.id as ride_id, te.date_time as departure, rr.distance as ride_distance,
                 coalesce(p.geometry, rr."start",
                   (select gr."start" from ride_groups g
                      join team_entities gr on gr.id = g.route_id and gr.deleted = false
                     where g.ride_id = te.id and gr."start" is not null
                     order by g.sort_order, g.id limit 1)) as geom
          from team_entities te
          left join places p on p.id = te.place_start_id
          left join team_entities rr on rr.id = te.route_id and rr.deleted = false
          where te.id in (:rideIds)
        ),
        rc as (
          select r.ride_id, r.departure, r.ride_distance, c.id as cell_id, c.fetched_at
          from r join weather_cells c
            on c.lat_idx = %1$s and c.lon_idx = %2$s and c.ele_band is null
          where r.geom is not null
        ),
        w as (
          select rc.*, greatest(rc.departure, coalesce(
            (select max(
                g.start_at
                + make_interval(secs => coalesce(gr.distance, rc.ride_distance, 0) * 3.6
                    / case when g.average_speed > 0 then g.average_speed else :defaultSpeed end))
               from ride_groups g
               left join team_entities gr on gr.id = g.route_id and gr.deleted = false
              where g.ride_id = rc.ride_id),
            rc.departure + make_interval(secs => coalesce(rc.ride_distance, 0) * 3.6 / :defaultSpeed)
          )) as last_arrival
          from rc
        )
        select w.ride_id, w.departure, w.last_arrival, w.fetched_at, %3$s
        from w
        join weather_hourly h on h.cell_id = w.cell_id
          and h.time >= w.departure - make_interval(secs => :slack)
          and h.time <= w.last_arrival + make_interval(secs => :slack)
        join weather_cells c on c.id = w.cell_id
        %4$s
        order by w.ride_id, h.time
        """
            .formatted(latIdx, lonIdx, HOUR_COLUMNS, DAILY_JOIN);
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(sql)
            .setParameter("rideIds", rideIds)
            .setParameter("defaultSpeed", defaultSpeed)
            .setParameter("slack", (double) slack.toSeconds())
            .getResultList();
    List<RideWindowHour> hours = new ArrayList<>(rows.size());
    for (Object[] row : rows) {
      hours.add(
          new RideWindowHour(
              ((Number) row[0]).longValue(),
              instant(row[1]),
              instant(row[2]),
              nullableInstant(row[3]),
              hourRow(row, 0, 4)));
    }
    return hours;
  }

  /**
   * One trip's next leg for the list summary, and one hour of its departure cell within it.
   *
   * @param arrival the estimated arrival of that leg
   * @param zone the IANA zone of that leg — the stage's stored one, the trip's for a trip without
   *     stage: the zone its times read in, which is not the trip's when the next stage is elsewhere
   *     (docs/LEDGER_*.md API-60)
   * @param fetchedAt when the departure cell was last fetched; null when it never was
   * @param hour null on the single row of a leg beyond {@code horizonEnd} or without a cached hour
   */
  public record TripLegHour(
      long tripId,
      Instant departure,
      Instant arrival,
      String zone,
      @Nullable Instant fetchedAt,
      @Nullable WeatherHourRow hour) {}

  /**
   * The list path of trips (docs/LEDGER_*.md API-82): for each trip of a page, its current leg — the
   * first live stage (by date, then rank) whose day is not over at {@code now}, else the trip itself
   * when it has no live stage — and the hours of that leg's departure cell from its start to its
   * estimated arrival, in <b>one</b> query whatever the page size. The stages are never loaded.
   *
   * <p>Everything {@code TripWeatherPlans} and {@code RouteSampleLookup} work out from the entities
   * is spelled here in SQL, so the list and the detail read the same cell:
   *
   * <ul>
   *   <li>the departure point is the first point of the leg's route's first non-empty track (by
   *       id) — deleted routes skipped; a leg without one returns no row, as the detail says {@code
   *       NO_LOCATION};
   *   <li>its cell, by {@code cellLatIdxSql} / {@code cellLonIdxSql}, <b>with</b> the elevation band
   *       of that point ({@code floor(ele / band + 0.5) * band}), none when the whole track has no
   *       altitude — the cell the planner fetched for the stage's first sample;
   *   <li>its arrival: the start plus the route's distance at the stage's average speed, else
   *       {@code defaultSpeed}.
   * </ul>
   *
   * <p>A leg's day is over at the end of the local day, in its own zone, of its stored end — else
   * of its departure plus the three hours of {@code PublicationEndCalculator.DEFAULT_DURATION}:
   * {@code RideWeatherCalculator.shownUntil}, the rule of the trip's page, so a stage under way, the
   * last one included, keeps its line (docs/LEDGER_*.md API-170, API-173).
   *
   * <p>A leg leaving after {@code horizonEnd} returns one row with no hour, so the caller can say
   * {@code NOT_YET_AVAILABLE}; so does a leg whose cell has no cached hour in its window.
   *
   * @param slack how far outside the window an hour is still read
   */
  public List<TripLegHour> findTripNextLegHours(
      Collection<Long> tripIds,
      Instant now,
      Instant horizonEnd,
      String cellLatIdxSql,
      String cellLonIdxSql,
      int elevationBand,
      double defaultSpeed,
      java.time.Duration slack) {
    if (tripIds.isEmpty()) {
      return List.of();
    }
    String point = "st_makepoint(cast(p.p0->>'lng' as float8), cast(p.p0->>'lat' as float8))";
    String latIdx = cellLatIdxSql.replace("?1", point);
    String lonIdx = cellLonIdxSql.replace("?1", point);
    String sql =
        """
        with t as (
          select te.id as trip_id, te.date_time as trip_time, te.route_id as trip_route_id,
                 te.timezone as trip_zone,
                 coalesce(te.end_date_time, te.date_time + interval '3 hours') as trip_end
          from team_entities te
          where te.id in (:tripIds)
        ),
        n as (
          select t.trip_id, leg.departure, leg.route_id, leg.speed,
                 coalesce(leg.zone, t.trip_zone) as zone
          from t
          cross join lateral (
            (select s.date_time as departure, s.route_id, s.average_speed as speed,
                    s.timezone as zone
               from team_entities s
              where s.trip_id = t.trip_id and s.deleted = false
                and (date_trunc('day', coalesce(s.end_date_time, s.date_time + interval '3 hours')
                                         at time zone s.timezone)
                     + interval '1 day') at time zone s.timezone > :now
              order by s.date_time, s.sort_order, s.id
              limit 1)
            union all
            (select t.trip_time, t.trip_route_id, cast(null as float4), cast(null as varchar)
              where (date_trunc('day', t.trip_end at time zone t.trip_zone) + interval '1 day')
                      at time zone t.trip_zone > :now
                and not exists (select 1 from team_entities s
                                 where s.trip_id = t.trip_id and s.deleted = false))
          ) leg
        ),
        p as (
          select n.trip_id, n.departure, n.speed, n.zone, r.distance,
                 g.track_points -> 0 as p0,
                 g.track_points
          from n
          join team_entities r on r.id = n.route_id and r.deleted = false
          cross join lateral (
            select gt.track_points from gpx_tracks gt
             where gt.route_id = r.id and jsonb_array_length(gt.track_points) > 0
             order by gt.id
             limit 1
          ) g
        ),
        l as (
          select p.trip_id, p.departure, p.zone,
                 p.departure + make_interval(secs => coalesce(p.distance, 0) * 3.6
                   / case when p.speed > 0 then p.speed else :defaultSpeed end) as arrival,
                 %1$s as lat_idx,
                 %2$s as lon_idx,
                 case
                   when cast(p.p0->>'ele' as float8) <> 0
                     then cast(floor(cast(p.p0->>'ele' as float8) / :band + 0.5) as integer) * :band
                   when jsonb_path_exists(p.track_points, cast(:anyAltitude as jsonpath)) then 0
                 end as ele_band
          from p
        )
        select l.trip_id, l.departure, l.arrival, l.zone, c.fetched_at, %3$s
        from l
        left join weather_cells c
          on c.lat_idx = l.lat_idx and c.lon_idx = l.lon_idx
          and c.ele_band is not distinct from l.ele_band
        left join weather_hourly h on h.cell_id = c.id
          and l.departure <= :horizonEnd
          and h.time >= l.departure - make_interval(secs => :slack)
          and h.time <= l.arrival + make_interval(secs => :slack)
        %4$s
        order by l.trip_id, h.time
        """
            .formatted(latIdx, lonIdx, HOUR_COLUMNS, DAILY_JOIN);
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(sql)
            .setParameter("tripIds", tripIds)
            .setParameter("now", Timestamp.from(now))
            .setParameter("horizonEnd", Timestamp.from(horizonEnd))
            .setParameter("band", elevationBand)
            // A parameter, not a literal: the question mark of a JSON path would read as a JDBC
            // placeholder.
            .setParameter("anyAltitude", "$[*] ? (@.ele != 0)")
            .setParameter("defaultSpeed", defaultSpeed)
            .setParameter("slack", (double) slack.toSeconds())
            .getResultList();
    List<TripLegHour> hours = new ArrayList<>(rows.size());
    for (Object[] row : rows) {
      hours.add(
          new TripLegHour(
              ((Number) row[0]).longValue(),
              instant(row[1]),
              instant(row[2]),
              (String) row[3],
              nullableInstant(row[4]),
              row[5] == null ? null : hourRow(row, 0, 5)));
    }
    return hours;
  }

  private static WeatherHourRow hourRow(Object[] row, int ownerColumn) {
    return hourRow(row, ownerColumn, ownerColumn + 1);
  }

  /** Reads {@link #HOUR_COLUMNS} starting at column {@code first}. */
  private static WeatherHourRow hourRow(Object[] row, int ownerColumn, int first) {
    return new WeatherHourRow(
        ((Number) row[ownerColumn]).longValue(),
        instant(row[first]),
        ((Number) row[first + 1]).doubleValue(),
        ((Number) row[first + 2]).doubleValue(),
        row[first + 3] == null ? null : ((Number) row[first + 3]).intValue(),
        ((Number) row[first + 4]).doubleValue(),
        ((Number) row[first + 5]).intValue(),
        ((Number) row[first + 6]).doubleValue(),
        ((Number) row[first + 7]).doubleValue(),
        row[first + 8] == null ? null : ((Number) row[first + 8]).doubleValue(),
        nullableInstant(row[first + 9]),
        nullableInstant(row[first + 10]));
  }

  /** A {@code timestamptz} column, whichever type the driver hands it as. */
  static Instant instant(Object value) {
    return switch (value) {
      case Instant i -> i;
      case Timestamp t -> t.toInstant();
      case OffsetDateTime o -> o.toInstant();
      default -> throw new IllegalStateException("Not a timestamp: " + value.getClass());
    };
  }

  static @Nullable Instant nullableInstant(@Nullable Object value) {
    return value == null ? null : instant(value);
  }
}
