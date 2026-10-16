package fr.pedalons.service.weather;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.enums.CompassPoint;
import fr.pedalons.enums.RelativeWind;
import fr.pedalons.enums.WeatherCheckpointKind;
import fr.pedalons.enums.WeatherCondition;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.repository.weather.WeatherHourRow;
import fr.pedalons.service.weather.RideWeatherCalculator.CellSeries;
import fr.pedalons.service.weather.RideWeatherCalculator.LegInput;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;

/** The weather computations, one rule per test — no database, no provider. */
class RideWeatherCalculatorTest {

  private static final Instant NOW = Instant.parse("2026-10-05T12:00:00Z");
  private static final Instant DEPARTURE = Instant.parse("2026-10-06T07:00:00Z");

  private static WeatherHourRow hour(
      Instant time, double temperature, @Nullable Integer rain, double windSpeed, double windFrom) {
    return new WeatherHourRow(
        0,
        time,
        temperature,
        temperature - 1,
        rain,
        0,
        rain != null && rain >= 50 ? 61 : 1,
        windSpeed,
        windFrom,
        windSpeed * 1.5,
        Instant.parse("2026-10-06T05:50:00Z"),
        Instant.parse("2026-10-06T17:10:00Z"));
  }

  /** A series with every hour of the day of the ride, all alike but for the temperature. */
  private static CellSeries series(@Nullable Integer rain, double windSpeed, double windFrom) {
    List<WeatherHourRow> rows = new ArrayList<>();
    for (int h = 0; h < 24; h++) {
      rows.add(
          hour(
              Instant.parse("2026-10-06T00:00:00Z").plus(Duration.ofHours(h)),
              8 + h * 0.5,
              rain,
              windSpeed,
              windFrom));
    }
    return CellSeries.of(NOW.minus(Duration.ofMinutes(20)), rows);
  }

  private static RouteSamples northbound(double km) {
    List<TrackPoint> points = new ArrayList<>();
    for (int i = 0; i <= km * 10; i++) {
      double d = i * 100.0;
      points.add(new TrackPoint(45 + d / 111_195, 5, 300, d));
    }
    return RouteSampleLookup.sample(List.of(points), 15_000);
  }

  // --- inputs -----------------------------------------------------------------------------------

  @Test
  void speed_withoutAverage_shouldBeTheDefault25() {
    assertEquals(new RideWeatherCalculator.Speed(25, true), RideWeatherCalculator.speed(null));
    assertEquals(new RideWeatherCalculator.Speed(25, true), RideWeatherCalculator.speed(0f));
    assertEquals(new RideWeatherCalculator.Speed(28, false), RideWeatherCalculator.speed(28f));
  }

  @Test
  void speed_givenByTheGroup_shouldNeverBeReplacedByTheDefault() {
    // Slower or faster than 25 km/h, a speed the organisers entered is the one used.
    assertEquals(new RideWeatherCalculator.Speed(18, false), RideWeatherCalculator.speed(18f));
    assertEquals(new RideWeatherCalculator.Speed(25, false), RideWeatherCalculator.speed(25f));
    assertEquals(new RideWeatherCalculator.Speed(0.5, false), RideWeatherCalculator.speed(0.5f));
    // A negative speed is no speed at all.
    assertEquals(new RideWeatherCalculator.Speed(25, true), RideWeatherCalculator.speed(-3f));
  }

  @Test
  void passage_acrossTheNightClocksGoBack_shouldCountRealElapsedTime() {
    // A 01:30 CEST start on 25 October 2026, 60 km at 25 km/h: 2 h 24 min of riding, so 01:54 UTC
    // (02:54 CET) — not 03:54 local, which adding hours to a wall clock would give.
    Instant start = Instant.parse("2026-10-24T23:30:00Z");
    assertEquals(
        Instant.parse("2026-10-25T01:54:00Z"), RideWeatherCalculator.passage(start, 60_000, 25));
  }

  @Test
  void passage_shouldBeDistanceOverSpeed() {
    assertEquals(
        DEPARTURE.plus(Duration.ofHours(2)), RideWeatherCalculator.passage(DEPARTURE, 50_000, 25));
  }

  // --- one hour ---------------------------------------------------------------------------------

  @Test
  void nearest_shouldPickTheClosestHourWithinTolerance() {
    CellSeries series = series(null, 10, 0);
    assertEquals(
        Instant.parse("2026-10-06T08:00:00Z"),
        series.nearest(Instant.parse("2026-10-06T07:40:00Z")).time());
    assertEquals(
        Instant.parse("2026-10-06T07:00:00Z"),
        series.nearest(Instant.parse("2026-10-06T07:20:00Z")).time());
    // Beyond the last hour plus 90 minutes there is nothing to read.
    assertNull(series.nearest(Instant.parse("2026-10-07T02:00:00Z")));
  }

  @Test
  void conditions_shouldTellDayFromNight() {
    Instant noon = Instant.parse("2026-10-06T12:00:00Z");
    Instant evening = Instant.parse("2026-10-06T19:00:00Z");
    assertTrue(RideWeatherCalculator.conditions(hour(noon, 15, null, 5, 0), noon).daylight());
    assertFalse(
        RideWeatherCalculator.conditions(hour(evening, 15, null, 5, 0), evening).daylight());
  }

  // 18 October 2026 in Paris (CEST, UTC+2): sunrise 08:28, sunset 19:13 local.
  private static final Instant SUNRISE_18 = Instant.parse("2026-10-18T06:28:00Z");
  private static final Instant SUNSET_18 = Instant.parse("2026-10-18T17:13:00Z");
  private static final Instant NOW_17 = Instant.parse("2026-10-17T12:00:00Z");

  /** Every hour of 18 October, with that day's sunrise and sunset. */
  private static CellSeries series18() {
    List<WeatherHourRow> rows = new ArrayList<>();
    for (int h = 0; h < 24; h++) {
      rows.add(
          new WeatherHourRow(
              0,
              Instant.parse("2026-10-18T00:00:00Z").plus(Duration.ofHours(h)),
              12,
              11,
              null,
              0,
              1,
              10,
              0,
              15d,
              SUNRISE_18,
              SUNSET_18));
    }
    return CellSeries.of(NOW_17.minus(Duration.ofMinutes(20)), rows);
  }

  @Test
  void conditions_shouldJudgeDaylightAtTheMomentShown_notAtTheModelHour() {
    CellSeries series = series18();
    // 08:30 local, two minutes after sunrise: the 08:00 model hour is before it, the rider is not.
    Instant departure = Instant.parse("2026-10-18T06:30:00Z");
    WeatherHourRow morning = series.nearest(departure);
    assertEquals(Instant.parse("2026-10-18T06:00:00Z"), morning.time());
    WeatherConditions atDeparture = RideWeatherCalculator.conditions(morning, departure);
    assertTrue(atDeparture.daylight());
    assertEquals(morning.time(), atDeparture.time(), "time stays the model hour");

    // 19:20 local, seven minutes after sunset: the 19:00 model hour is before it, the rider is not.
    Instant passage = Instant.parse("2026-10-18T17:20:00Z");
    WeatherHourRow evening = series.nearest(passage);
    assertEquals(Instant.parse("2026-10-18T17:00:00Z"), evening.time());
    assertFalse(RideWeatherCalculator.conditions(evening, passage).daylight());
  }

  @Test
  void departure_justAfterSunrise_shouldBeDaylightThoughItsModelHourIsBefore() {
    DepartureWeather departure =
        RideWeatherCalculator.departure(series18(), Instant.parse("2026-10-18T06:30:00Z"), NOW_17);
    assertEquals(Instant.parse("2026-10-18T06:00:00Z"), departure.conditions().time());
    assertTrue(departure.conditions().daylight());
  }

  @Test
  void summary_departureJustAfterSunrise_shouldBeDaylight() {
    CellSeries series = series18();
    Instant departure = Instant.parse("2026-10-18T06:30:00Z");
    RideWeatherSummary summary =
        RideWeatherCalculator.summary(
            departure,
            departure.plus(Duration.ofHours(3)),
            series.fetchedAt(),
            series.hours().values(),
            NOW_17);
    assertNotNull(summary);
    assertEquals(Boolean.TRUE, summary.daylight());
  }

  @Test
  void leg_checkpointJustAfterSunset_shouldBeNightThoughItsModelHourIsBefore() {
    // A leg leaving at 19:20 local: its start checkpoint passes then, and reads the 19:00 hour.
    Instant start = Instant.parse("2026-10-18T17:20:00Z");
    LegInput input = new LegInput(3L, start, RideWeatherCalculator.speed(null), northbound(30));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series18(), NOW_17);

    WeatherCheckpoint first = leg.checkpoints().getFirst();
    assertEquals(start, first.time());
    assertEquals(Instant.parse("2026-10-18T17:00:00Z"), first.weather().time());
    assertFalse(first.weather().daylight());
    // A trip stage's card reads its first checkpoint: night too.
    assertEquals(Boolean.FALSE, RideWeatherCalculator.legSummary(leg).daylight());
  }

  @Test
  void wmo_shouldFoldIntoConditions() {
    assertEquals(WeatherCondition.CLEAR, WeatherCondition.fromWmo(0));
    assertEquals(WeatherCondition.FOG, WeatherCondition.fromWmo(48));
    assertEquals(WeatherCondition.FREEZING_RAIN, WeatherCondition.fromWmo(57));
    assertEquals(WeatherCondition.HEAVY_RAIN, WeatherCondition.fromWmo(65));
    assertEquals(WeatherCondition.SNOW, WeatherCondition.fromWmo(86));
    assertEquals(WeatherCondition.THUNDERSTORM, WeatherCondition.fromWmo(99));
    assertEquals(WeatherCondition.OVERCAST, WeatherCondition.fromWmo(42));
  }

  @Test
  void compass_shouldRoundToEightPoints() {
    assertEquals(CompassPoint.N, CompassPoint.fromDegrees(350));
    assertEquals(CompassPoint.NE, CompassPoint.fromDegrees(40));
    assertEquals(CompassPoint.SW, CompassPoint.fromDegrees(225));
    assertEquals(CompassPoint.NW, CompassPoint.fromDegrees(-45));
  }

  // --- wind -------------------------------------------------------------------------------------

  @Test
  void stretchWind_northboundIntoANortherly_shouldBeAHeadwind() {
    RouteSamples.Sample stretch = northbound(30).samples().getFirst();

    RideWeatherCalculator.StretchWind wind = RideWeatherCalculator.stretchWind(stretch, 20, 0);

    assertEquals(RelativeWind.HEAD, wind.relativeWind());
    assertEquals(20, wind.headwind(), 0.1);
    // The wind blows towards the south: straight in the face.
    assertEquals(180, wind.relativeWindAngle());
  }

  @Test
  void stretchWind_northboundWithASoutherly_shouldBeATailwind() {
    RouteSamples.Sample stretch = northbound(30).samples().getFirst();

    RideWeatherCalculator.StretchWind wind = RideWeatherCalculator.stretchWind(stretch, 20, 180);

    assertEquals(RelativeWind.TAIL, wind.relativeWind());
    assertEquals(-20, wind.headwind(), 0.1);
    assertEquals(0, wind.relativeWindAngle());
  }

  @Test
  void stretchWind_northboundWithAWesterly_shouldBeACrosswindFromTheLeft() {
    RouteSamples.Sample stretch = northbound(30).samples().getFirst();

    RideWeatherCalculator.StretchWind wind = RideWeatherCalculator.stretchWind(stretch, 20, 270);

    assertEquals(RelativeWind.CROSS, wind.relativeWind());
    assertEquals(0, wind.headwind(), 0.1);
    // Blowing towards the east: to the rider's right, a quarter turn clockwise.
    assertEquals(90, wind.relativeWindAngle());
  }

  @Test
  void classify_shouldSplitAtHalfTheWindSpeed() {
    assertEquals(RelativeWind.HEAD, RideWeatherCalculator.classify(6, 10));
    assertEquals(RelativeWind.CROSS, RideWeatherCalculator.classify(5, 10));
    assertEquals(RelativeWind.CROSS, RideWeatherCalculator.classify(-5, 10));
    assertEquals(RelativeWind.TAIL, RideWeatherCalculator.classify(-6, 10));
    // Calm: neither for nor against.
    assertEquals(RelativeWind.CROSS, RideWeatherCalculator.classify(0, 0));
  }

  @Test
  void circularMean_shouldWrapAroundNorth() {
    // North, not the 180° of a plain average — either side of 0°, within rounding.
    double north = RideWeatherCalculator.circularMean(List.of(350.0, 10.0));
    assertEquals(0, Math.min(north, 360 - north), 0.001);
    assertEquals(90, RideWeatherCalculator.circularMean(List.of(45.0, 135.0)), 0.001);
    assertNull(RideWeatherCalculator.circularMean(List.of()));
  }

  // --- leg --------------------------------------------------------------------------------------

  @Test
  void leg_shouldHaveACheckpointPerSampleAndAddUpItsStretches() {
    LegInput input =
        new LegInput(42L, DEPARTURE, RideWeatherCalculator.speed(null), northbound(92));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(null, 20, 0), NOW);

    assertEquals(WeatherStatus.OK, leg.status());
    assertEquals(42L, leg.groupId());
    assertTrue(leg.speedIsDefault());
    assertEquals(92_000, leg.distance());
    assertEquals(7, leg.checkpoints().size());
    assertEquals(WeatherCheckpointKind.START, leg.checkpoints().getFirst().kind());
    assertEquals(WeatherCheckpointKind.EN_ROUTE, leg.checkpoints().get(1).kind());
    assertEquals(WeatherCheckpointKind.FINISH, leg.checkpoints().getLast().kind());
    // 15 km at 25 km/h: 36 minutes after the start.
    assertEquals(DEPARTURE.plus(Duration.ofMinutes(36)), leg.checkpoints().get(1).time());
    assertEquals(DEPARTURE.plus(Duration.ofSeconds(92 * 144)), leg.arrivalTime());
    // Due north into a northerly all the way.
    assertEquals(6, leg.segments().size());
    assertEquals(92_000, leg.windExposure().head());
    assertEquals(0, leg.windExposure().tail());
    assertEquals(RelativeWind.HEAD, leg.checkpoints().getLast().relativeWind());
    assertNotNull(leg.prevailingWind());
    assertEquals(CompassPoint.N, leg.prevailingWind().compass());
    assertNull(leg.rainAlert());
  }

  @Test
  void leg_withTheGroupsOwnSpeed_shouldTimeEveryPassageWithIt() {
    LegInput input = new LegInput(7L, DEPARTURE, RideWeatherCalculator.speed(30f), northbound(30));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(null, 10, 0), NOW);

    assertEquals(30, leg.averageSpeed());
    assertFalse(leg.speedIsDefault());
    // 15 km at 30 km/h: half an hour; 30 km: one hour.
    assertEquals(DEPARTURE.plus(Duration.ofMinutes(30)), leg.checkpoints().get(1).time());
    assertEquals(DEPARTURE.plus(Duration.ofHours(1)), leg.arrivalTime());
    assertEquals(DEPARTURE.plus(Duration.ofHours(1)), leg.checkpoints().getLast().time());
  }

  @Test
  void leg_withASlowGroup_shouldKeepItsSpeedRatherThanTheDefault() {
    LegInput input = new LegInput(8L, DEPARTURE, RideWeatherCalculator.speed(18f), northbound(30));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(null, 10, 0), NOW);

    assertEquals(18, leg.averageSpeed());
    assertFalse(leg.speedIsDefault());
    // 30 km at 18 km/h: 1 h 40 min — 1 h 12 min had the default been used.
    assertEquals(DEPARTURE.plus(Duration.ofMinutes(100)), leg.arrivalTime());
  }

  @Test
  void leg_withAGroupTime_shouldStartAtThatTimeAndReadTheMatchingHours() {
    // A 10:00 group (08:00 UTC) on a ride announced for 09:00 Paris.
    Instant start = Instant.parse("2026-10-06T08:00:00Z");
    LegInput input = new LegInput(9L, start, RideWeatherCalculator.speed(null), northbound(30));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(null, 10, 0), NOW);

    assertEquals(Instant.parse("2026-10-06T08:00:00Z"), leg.startTime());
    assertEquals(Instant.parse("2026-10-06T08:00:00Z"), leg.checkpoints().getFirst().time());
    // The hour read is the group's, not the ride's: 08:00 UTC → 8 + 8 × 0.5 °C.
    assertNotNull(leg.checkpoints().getFirst().weather());
    assertEquals(12.0, leg.checkpoints().getFirst().weather().temperature());
    assertEquals(start.plus(Duration.ofSeconds(30 * 144)), leg.arrivalTime());
  }

  @Test
  void leg_shouldClassifyEachStretchAgainstTheWind() {
    // Out north 15 km, then back south: into a northerly, then with it.
    List<TrackPoint> points = new ArrayList<>();
    for (int i = 0; i <= 150; i++) {
      points.add(new TrackPoint(45 + i * 100.0 / 111_195, 5, 300, i * 100.0));
    }
    for (int i = 1; i <= 150; i++) {
      points.add(new TrackPoint(45 + (150 - i) * 100.0 / 111_195, 5, 300, 15_000 + i * 100.0));
    }
    RouteSamples outAndBack = RouteSampleLookup.sample(List.of(points), 15_000);
    LegInput input = new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), outAndBack);

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(null, 20, 0), NOW);

    assertEquals(2, leg.segments().size());
    assertEquals(RelativeWind.HEAD, leg.segments().get(0).relativeWind());
    assertEquals(RelativeWind.TAIL, leg.segments().get(1).relativeWind());
    assertEquals(15_000, leg.windExposure().head(), 1);
    assertEquals(15_000, leg.windExposure().tail(), 1);
    assertEquals(0, leg.windExposure().cross(), 1);
  }

  @Test
  void leg_shouldRaiseTheFirstLikelyRain() {
    LegInput input =
        new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), northbound(30));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(70, 10, 0), NOW);

    assertNotNull(leg.rainAlert());
    assertEquals(70, leg.rainAlert().probability());
    assertEquals(0, leg.rainAlert().distance());
    assertEquals(WeatherCondition.RAIN, leg.rainAlert().condition());
  }

  @Test
  void leg_withNothingInCache_shouldBeUnavailable() {
    LegInput input =
        new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), northbound(30));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> CellSeries.EMPTY, NOW);

    assertEquals(WeatherStatus.UNAVAILABLE, leg.status());
    assertTrue(leg.checkpoints().stream().allMatch(c -> c.weather() == null));
    assertTrue(leg.segments().isEmpty());
  }

  @Test
  void leg_withoutRoute_shouldHaveNoLocation() {
    LegInput input = new LegInput(1L, DEPARTURE, RideWeatherCalculator.speed(null), null);

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(null, 10, 0), NOW);

    assertEquals(WeatherStatus.NO_LOCATION, leg.status());
    assertTrue(leg.checkpoints().isEmpty());
  }

  @Test
  void leg_withAnOldForecast_shouldBeStale() {
    CellSeries old = new CellSeries(NOW.minus(Duration.ofDays(1)), series(null, 10, 0).hours());
    LegInput input =
        new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), northbound(30));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> old, NOW);

    assertEquals(WeatherStatus.STALE, leg.status());
  }

  // --- ride and summary -------------------------------------------------------------------------

  @Test
  void ride_shouldIgnoreLegsWithoutRouteInItsStatus() {
    DepartureWeather departure =
        RideWeatherCalculator.departure(series(null, 10, 0), DEPARTURE, NOW);
    WeatherLeg noRoute =
        RideWeatherCalculator.leg(
            new LegInput(1L, DEPARTURE, RideWeatherCalculator.speed(null), null),
            key -> CellSeries.EMPTY,
            NOW);

    RideWeather ride = RideWeatherCalculator.ride(departure, List.of(noRoute));

    assertEquals(WeatherStatus.OK, ride.status());
    assertEquals(WeatherStatus.OK, departure.status());
    assertNotNull(departure.sunrise());
  }

  @Test
  void summary_shouldSpanTheWindowToTheLastArrival() {
    CellSeries series = series(null, 10, 0);

    RideWeatherSummary summary =
        RideWeatherCalculator.summary(
            DEPARTURE,
            DEPARTURE.plus(Duration.ofHours(4)),
            NOW.minus(Duration.ofMinutes(10)),
            series.hours().values(),
            NOW);

    assertNotNull(summary);
    assertEquals(WeatherStatus.OK, summary.status());
    assertEquals(11.5, summary.temperature()); // 07:00 → 8 + 7 × 0.5
    assertEquals(11.5, summary.temperatureMin());
    assertEquals(13.5, summary.temperatureMax()); // 11:00
    assertNull(summary.rainAlert());
  }

  // --- trip ------------------------------------------------------------------------------------

  private static TripWeather.StageLeg stage(long id, WeatherLeg leg) {
    return new TripWeather.StageLeg(id, leg);
  }

  @Test
  void leg_beyondTheHorizon_shouldSayWhenItsForecastOpens() {
    Instant far = NOW.plus(Duration.ofDays(9));
    LegInput input = new LegInput(null, far, RideWeatherCalculator.speed(null), northbound(30));

    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(null, 10, 0), NOW);

    assertEquals(WeatherStatus.NOT_YET_AVAILABLE, leg.status());
    assertEquals(far.minus(Duration.ofDays(7)), leg.availableFrom());
    assertTrue(leg.checkpoints().stream().allMatch(c -> c.weather() == null));
  }

  @Test
  void trip_shouldCountOnlyTheStagesWithAForecastWithinRange() {
    WeatherLeg tomorrow =
        RideWeatherCalculator.leg(
            new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), northbound(30)),
            key -> series(null, 10, 0),
            NOW);
    WeatherLeg noRoute =
        RideWeatherCalculator.leg(
            new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), null),
            key -> CellSeries.EMPTY,
            NOW);
    WeatherLeg far =
        RideWeatherCalculator.leg(
            new LegInput(
                null,
                NOW.plus(Duration.ofDays(9)),
                RideWeatherCalculator.speed(null),
                northbound(30)),
            key -> CellSeries.EMPTY,
            NOW);
    List<WeatherLeg> legs = List.of(tomorrow, noRoute, far);

    TripWeather trip =
        RideWeatherCalculator.trip(
            List.of(stage(1, tomorrow), stage(2, noRoute), stage(3, far)), legs);

    assertEquals(WeatherStatus.OK, trip.status());
    assertNull(trip.availableFrom());
    assertEquals(3, trip.stages().size());
    assertEquals(tomorrow.fetchedAt(), trip.fetchedAt());
  }

  @Test
  void trip_withEveryLocatedStageBeyondTheHorizon_shouldOpenWithTheFirst() {
    Instant first = NOW.plus(Duration.ofDays(9));
    WeatherLeg a =
        RideWeatherCalculator.leg(
            new LegInput(null, first, RideWeatherCalculator.speed(null), northbound(30)),
            key -> CellSeries.EMPTY,
            NOW);
    WeatherLeg b =
        RideWeatherCalculator.leg(
            new LegInput(
                null, first.plus(Duration.ofDays(1)), RideWeatherCalculator.speed(null), null),
            key -> CellSeries.EMPTY,
            NOW);

    TripWeather trip = RideWeatherCalculator.trip(List.of(stage(1, a), stage(2, b)), List.of(a, b));

    assertEquals(WeatherStatus.NOT_YET_AVAILABLE, trip.status());
    assertEquals(first.minus(Duration.ofDays(7)), trip.availableFrom());
  }

  @Test
  void trip_withoutAnyRoute_shouldHaveNoLocation_andWithNothingLeft_beOutOfRange() {
    WeatherLeg noRoute =
        RideWeatherCalculator.leg(
            new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), null),
            key -> CellSeries.EMPTY,
            NOW);

    assertEquals(
        WeatherStatus.NO_LOCATION,
        RideWeatherCalculator.trip(List.of(stage(1, noRoute)), List.of(noRoute)).status());
    assertEquals(
        WeatherStatus.OUT_OF_RANGE,
        RideWeatherCalculator.trip(List.of(stage(1, noRoute)), List.of()).status());
  }

  @Test
  void legSummary_shouldSpanTheCheckpoints_andKeepTheRainAlertsDistance() {
    LegInput input =
        new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), northbound(92));
    WeatherLeg leg = RideWeatherCalculator.leg(input, key -> series(70, 10, 0), NOW);

    RideWeatherSummary summary = RideWeatherCalculator.legSummary(leg);

    assertNotNull(summary);
    assertEquals(WeatherStatus.OK, summary.status());
    assertEquals(11.5, summary.temperature()); // 07:00 → 8 + 7 × 0.5
    assertEquals(11.5, summary.temperatureMin());
    // The finish, 92 km at 25 km/h later (10:40:48), reads the 11:00 hour.
    assertEquals(13.5, summary.temperatureMax());
    assertEquals(70, summary.maxPrecipitationProbability());
    assertNotNull(summary.rainAlert());
    assertEquals(0.0, summary.rainAlert().distance());
  }

  @Test
  void legSummary_ofALegWithNothingToShow_shouldBeNull() {
    WeatherLeg unavailable =
        RideWeatherCalculator.leg(
            new LegInput(null, DEPARTURE, RideWeatherCalculator.speed(null), northbound(30)),
            key -> CellSeries.EMPTY,
            NOW);
    WeatherLeg far =
        RideWeatherCalculator.leg(
            new LegInput(
                null,
                NOW.plus(Duration.ofDays(9)),
                RideWeatherCalculator.speed(null),
                northbound(30)),
            key -> CellSeries.EMPTY,
            NOW);

    assertNull(RideWeatherCalculator.legSummary(unavailable));
    RideWeatherSummary notYet = RideWeatherCalculator.legSummary(far);
    assertNotNull(notYet);
    assertEquals(WeatherStatus.NOT_YET_AVAILABLE, notYet.status());
    assertEquals(far.availableFrom(), notYet.availableFrom());
  }

  @Test
  void horizon_shouldBeSevenDays() {
    Instant far = NOW.plus(Duration.ofDays(8));
    assertTrue(RideWeatherCalculator.isBeyondHorizon(far, NOW));
    assertEquals(NOW.plus(Duration.ofDays(1)), RideWeatherCalculator.availableFrom(far));
  }
}
